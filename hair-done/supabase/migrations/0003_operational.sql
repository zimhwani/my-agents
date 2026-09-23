-- Hair Done: what it takes to run for real.
--
-- 1. Privacy. A pro's exact location, ABN and Stripe id are never public; clients browse through
--    pros_near() / pro_card(), which round the location to about a kilometre. A pro reads her
--    bookings through bookings_for_pro(), which hides the street address until she has confirmed.
--    Policies that looked through `bookings` now use security-definer helpers, so they work for
--    both parties without opening the table.
-- 2. Prices are worked out here, not trusted from the phone. Clients book through create_booking(),
--    which checks the slot, the services, the travel area and blocks, then writes the booking.
-- 3. Money timing, per product-spec §5 and §7. `hold_state` says where the Stripe side is; the
--    `settle` edge function (run every five minutes by pg_cron) does the Stripe calls that are due:
--    place a deferred hold six days out, release, partial capture, auto-capture 12 hours after done.
-- 4. Reliability is 0–100 with the spec's deductions, and instant book turns off below 70.
-- 5. The sweep: auto-decline after 2 hours (−2 reliability), unfinished payments lapse after 30
--    minutes, inProgress becomes done 12 hours after the end.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
alter table profile_contacts add column if not exists stripe_customer_id text;

do $$ begin
  create type hold_state as enum ('none', 'saved', 'held', 'released', 'captured', 'failed');
exception when duplicate_object then null; end $$;

alter table bookings
  add column if not exists hold_state hold_state not null default 'none',
  add column if not exists stripe_setup_intent_id text,
  add column if not exists stripe_payment_method text,
  add column if not exists capture_paused_until timestamptz,
  add column if not exists done_at timestamptz,
  add column if not exists settle_error text;

-- The old pros_near returned whole pro rows, exact location included. Replaced below.
drop function if exists pros_near(double precision, double precision, category, int);

-- Reliability as the spec has it: an integer out of 100.
alter table pros alter column reliability_score drop default;
alter table pros alter column reliability_score type int using round(reliability_score * 100)::int;
alter table pros alter column reliability_score set default 100;
alter table pros add constraint pros_reliability_range check (reliability_score between 0 and 100);

-- A private place for settings only the server reads.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.settings (key text primary key, value text not null);
insert into private.settings (key, value)
  values ('cron_secret', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
  on conflict (key) do nothing;

create or replace function check_cron_secret(s text) returns boolean
language sql stable security definer set search_path = public, private, extensions as $$
  select exists (select 1 from private.settings where key = 'cron_secret' and value = s)
$$;
revoke execute on function check_cron_secret(text) from public, anon, authenticated;
grant execute on function check_cron_secret(text) to service_role;

-- ---------------------------------------------------------------------------
-- Helpers that look at bookings without opening them
-- ---------------------------------------------------------------------------
create or replace function is_booking_party(b_id uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from bookings b where b.id = b_id and auth.uid() in (b.pro_id, b.client_id))
$$;

create or replace function has_booking_with(other uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from bookings b
    where (b.client_id = other and b.pro_id = auth.uid()) or (b.pro_id = other and b.client_id = auth.uid()))
$$;

-- ---------------------------------------------------------------------------
-- Policies: replace the ones that leaked or couldn't see through bookings
-- ---------------------------------------------------------------------------
-- Bookings: the client reads her own rows. The pro reads through bookings_for_pro().
drop policy if exists bookings_party_read on bookings;
create policy bookings_client_read on bookings for select using (client_id = auth.uid());
-- Clients no longer insert bookings directly; create_booking() does, with server prices.
drop policy if exists bookings_client_insert on bookings;
drop policy if exists booking_services_client_insert on booking_services;

drop view if exists bookings_for_pro;

drop policy if exists profiles_counterparty on profiles;
create policy profiles_counterparty on profiles for select using (has_booking_with(id));

drop policy if exists booking_services_party on booking_services;
create policy booking_services_party on booking_services for select using (is_booking_party(booking_id));

drop policy if exists booking_inspo_party on booking_inspo;
create policy booking_inspo_party on booking_inspo for select using (is_booking_party(booking_id));
drop policy if exists booking_inspo_client_insert on booking_inspo;
create policy booking_inspo_client_insert on booking_inspo for insert with check (
  exists (select 1 from bookings b where b.id = booking_id and b.client_id = auth.uid()));

drop policy if exists booking_events_party on booking_events;
create policy booking_events_party on booking_events for select using (is_booking_party(booking_id));

drop policy if exists inspo_read on storage.objects;
create policy inspo_read on storage.objects for select using (
  bucket_id = 'inspo' and exists (
    select 1 from booking_inspo i where i.image_path = storage.objects.name and is_booking_party(i.booking_id)));

-- Reviews only from paid, as the spec says, and within 14 days of it.
drop policy if exists reviews_client_insert on reviews;
create policy reviews_client_insert on reviews for insert with check (
  client_id = auth.uid() and exists (
    select 1 from bookings b where b.id = booking_id and b.client_id = auth.uid()
      and b.pro_id = reviews.pro_id and b.status = 'paid' and b.updated_at > now() - interval '14 days'));

-- Reviews: the two parties read the row; everyone else reads pro_reviews(), which shows a first name only.
drop policy if exists reviews_public_read on reviews;
create policy reviews_party_read on reviews for select using (client_id = auth.uid() or pro_id = auth.uid());

-- Card rows are written by the Stripe webhook. The owner reads, deletes, and picks a default.
drop policy if exists payment_methods_own on payment_methods;
create policy payment_methods_own_read on payment_methods for select using (profile_id = auth.uid());
create policy payment_methods_own_delete on payment_methods for delete using (profile_id = auth.uid());
create policy payment_methods_own_update on payment_methods for update using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Pros: a pro reads her own row in full. Everyone else goes through pros_near() / pro_card().
drop policy if exists pros_public_read on pros;
create policy pros_self_read on pros for select using (id = auth.uid());

-- ---------------------------------------------------------------------------
-- What a client sees of a pro
-- ---------------------------------------------------------------------------
drop type if exists pro_card cascade;
create type pro_card as (
  id uuid, first_name text, last_initial text, avatar_url text, seed int,
  specialties category[], headline text, bio text, suburb text,
  approx_lat double precision, approx_lng double precision,
  travel_radius_km numeric, travel_fee_cents int, instant_book boolean,
  years_experience int, response_minutes int, is_verified boolean, insurance_on_file boolean,
  rating numeric, review_count int, completed_bookings int, is_reliable boolean,
  buffer_minutes int, step_minutes int, distance_km double precision
);

create or replace function pro_cards_where(filter_ids uuid[], lat double precision, lng double precision, cat category, within_reach boolean, limit_n int)
returns setof pro_card language sql stable security definer set search_path = public, extensions as $$
  select p.id, pr.first_name, p.last_initial, pr.avatar_url, pr.seed,
    p.specialties, p.headline, p.bio, p.suburb,
    round(st_y(p.location::geometry)::numeric, 2)::double precision,
    round(st_x(p.location::geometry)::numeric, 2)::double precision,
    p.travel_radius_km, p.travel_fee_cents, p.instant_book,
    p.years_experience, p.response_minutes, p.is_verified, p.insurance_on_file,
    p.rating, p.review_count, p.completed_bookings,
    (p.reliability_score >= 90 and p.completed_bookings >= 5),
    p.buffer_minutes, p.step_minutes,
    case when lat is null or lng is null then null
      else round((st_distance(p.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography) / 1000)::numeric, 1)::double precision end
  from pros p join profiles pr on pr.id = p.id
  where p.is_active and p.reliability_score >= 50
    and (filter_ids is null or p.id = any (filter_ids))
    and (cat is null or cat = any (p.specialties))
    and (not within_reach or lat is null or lng is null
         or st_dwithin(p.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography, p.travel_radius_km * 1000))
    and not exists (select 1 from blocks k where (k.blocker_id = auth.uid() and k.blocked_id = p.id)
                                                or (k.blocker_id = p.id and k.blocked_id = auth.uid()))
  order by case when lat is null or lng is null then 0
    else st_distance(p.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography) end
  limit limit_n
$$;
revoke execute on function pro_cards_where(uuid[], double precision, double precision, category, boolean, int) from public, anon, authenticated;

create or replace function pros_near(lat double precision, lng double precision, cat category default null, limit_n int default 50)
returns setof pro_card language sql stable security definer set search_path = public, extensions as $$
  select * from pro_cards_where(null, lat, lng, cat, true, limit_n)
$$;

create or replace function pro_card(p uuid, lat double precision default null, lng double precision default null)
returns setof pro_card language sql stable security definer set search_path = public, extensions as $$
  select * from pro_cards_where(array[p], lat, lng, null, false, 1)
$$;

create or replace function pro_cards(ids uuid[], lat double precision default null, lng double precision default null)
returns setof pro_card language sql stable security definer set search_path = public, extensions as $$
  select * from pro_cards_where(ids, lat, lng, null, false, 200)
$$;

-- Reviews with the reviewer's first name, for a pro's profile.
create or replace function pro_reviews(p uuid, limit_n int default 50)
returns table (id uuid, rating smallint, text text, service_name text, first_name text,
               pro_reply text, pro_replied_at timestamptz, created_at timestamptz)
language sql stable security definer set search_path = public, extensions as $$
  select r.id, r.rating, r.text, r.service_name, pr.first_name, r.pro_reply, r.pro_replied_at, r.created_at
  from reviews r join profiles pr on pr.id = r.client_id
  where r.pro_id = p order by r.created_at desc limit limit_n
$$;

-- ---------------------------------------------------------------------------
-- A pro's bookings: street address and access notes only once she's confirmed
-- ---------------------------------------------------------------------------
create or replace function bookings_for_pro()
returns setof bookings language sql stable security definer set search_path = public, extensions as $$
  select b.id, b.reference, b.pro_id, b.client_id, b.status, b.starts_at, b.ends_at,
    case when b.status = 'requested' then '' else b.address_label end,
    case when b.status = 'requested' then '' else b.address_line1 end,
    b.address_suburb, b.address_state, b.address_postcode,
    case when b.status = 'requested'
      then st_setsrid(st_makepoint(round(st_x(b.address_location::geometry)::numeric, 2), round(st_y(b.address_location::geometry)::numeric, 2)), 4326)::geography
      else b.address_location end,
    case when b.status = 'requested' then '' else b.address_instructions end,
    b.notes, b.services_cents, b.travel_fee_cents, b.booking_fee_cents, b.tip_cents, b.discount_cents,
    b.platform_fee_cents, b.cancellation_charge_cents,
    null::text, null::text, null::uuid,          -- Stripe ids and the client's card stay with the client
    b.captured_at, b.decline_reason, b.created_at, b.updated_at,
    b.hold_state, null::text, null::text, b.capture_paused_until, b.done_at, null::text
  from bookings b
  where b.pro_id = auth.uid()
    -- A request she can't act on yet (payment not finished) isn't shown to her.
    and not (b.status = 'requested' and b.hold_state = 'none')
  order by b.starts_at
$$;

-- ---------------------------------------------------------------------------
-- Slots: security definer so a client's check sees every booking's time, and nothing else
-- ---------------------------------------------------------------------------
create or replace function pro_slots(p uuid, day date, duration_minutes int, tz text default 'Australia/Melbourne')
returns table (starts_at timestamptz, is_available boolean, reason text)
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  r record; m int; s timestamptz; e timestamptz; buf int; step int;
begin
  select buffer_minutes, step_minutes into buf, step from pros where id = p and is_active;
  if not found then return; end if;
  if exists (select 1 from days_off d where d.pro_id = p and d.day = pro_slots.day) then return; end if;
  for r in select * from availability a where a.pro_id = p and a.weekday = extract(dow from pro_slots.day) order by a.start_minutes loop
    m := r.start_minutes;
    while m + duration_minutes <= r.end_minutes loop
      s := (pro_slots.day::timestamp + make_interval(mins => m)) at time zone tz;
      e := s + make_interval(mins => duration_minutes);
      starts_at := s; is_available := true; reason := null;
      if s < now() + interval '90 minutes' then
        is_available := false; reason := 'Too soon, she needs 90 minutes'' notice';
      elsif exists (select 1 from bookings b
          where b.pro_id = p and b.status in ('requested','confirmed','onHerWay','arrived','inProgress')
            and b.starts_at - make_interval(mins => buf) < e and b.ends_at + make_interval(mins => buf) > s) then
        is_available := false; reason := 'She''s booked';
      end if;
      return next;
      m := m + step;
    end loop;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Booking: prices from the pro's own list, the slot checked under a lock
-- ---------------------------------------------------------------------------
create or replace function create_booking(p_pro uuid, p_service_ids uuid[], p_starts_at timestamptz,
                                          p_address_id uuid, p_notes text default '')
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid(); pr pros; a addresses; n int; svc_cents int; total_min int; b bookings;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_pro = me then raise exception 'own_booking'; end if;
  select * into pr from pros where id = p_pro and is_active and reliability_score >= 50;
  if not found then raise exception 'pro_not_found'; end if;
  if exists (select 1 from blocks k where (k.blocker_id = p_pro and k.blocked_id = me) or (k.blocker_id = me and k.blocked_id = p_pro)) then
    raise exception 'blocked';
  end if;
  select * into a from addresses where id = p_address_id and profile_id = me;
  if not found then raise exception 'address_not_found'; end if;
  if not st_dwithin(pr.location, a.location, pr.travel_radius_km * 1000) then raise exception 'outside_travel_area'; end if;

  select count(distinct s.id), coalesce(sum(s.price_cents), 0), coalesce(sum(s.minutes), 0)
    into n, svc_cents, total_min
    from services s where s.id = any (p_service_ids) and s.pro_id = p_pro and s.is_active;
  if n = 0 or n <> cardinality(p_service_ids) then raise exception 'bad_services'; end if;

  -- One booking at a time per pro, so two clients can't take the same slot.
  perform pg_advisory_xact_lock(hashtext(p_pro::text));
  if not exists (select 1 from pro_slots(p_pro, (p_starts_at at time zone 'Australia/Melbourne')::date, total_min) sl
                 where sl.starts_at = p_starts_at and sl.is_available) then
    raise exception 'slot_taken';
  end if;

  insert into bookings (pro_id, client_id, status, starts_at, ends_at,
    address_label, address_line1, address_suburb, address_state, address_postcode, address_location, address_instructions,
    notes, services_cents, travel_fee_cents, booking_fee_cents)
  values (p_pro, me, 'requested', p_starts_at, p_starts_at + make_interval(mins => total_min),
    a.label, a.line1, a.suburb, a.state, a.postcode, a.location, a.instructions,
    left(coalesce(p_notes, ''), 1000), svc_cents, pr.travel_fee_cents, 300)
  returning * into b;

  insert into booking_services (booking_id, service_id, name, category, price_cents, minutes, sort_order)
  select b.id, s.id, s.name, s.category, s.price_cents, s.minutes,
         (array_position(p_service_ids, s.id) - 1)
  from services s where s.id = any (p_service_ids) and s.pro_id = p_pro;

  return b;
end $$;

-- Called by the create-payment-intent function once Stripe has the card: the hold is on (or the
-- card is saved for a hold six days out). Instant book confirms here.
create or replace function booking_hold_placed(b_id uuid, state hold_state, pm text)
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare b bookings; instant boolean;
begin
  select p.instant_book into instant from bookings x join pros p on p.id = x.pro_id where x.id = b_id;
  -- One update, so instant book says "Confirmed" once rather than "You asked" then "Confirmed".
  update bookings set hold_state = state, stripe_payment_method = coalesce(pm, stripe_payment_method),
    status = case when coalesce(instant, false) and status = 'requested' then 'confirmed'::booking_status else status end
    where id = b_id and hold_state in ('none', 'saved', 'failed') returning * into b;
  if not found then select * into b from bookings where id = b_id; end if;
  return b;
end $$;
revoke execute on function booking_hold_placed(uuid, hold_state, text) from public, anon, authenticated;
grant execute on function booking_hold_placed(uuid, hold_state, text) to service_role;

-- ---------------------------------------------------------------------------
-- The state machine, with the spec's timings and who-may-do-what
-- ---------------------------------------------------------------------------
create or replace function move_booking(b_id uuid, new_status booking_status, reason text default null)
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare b bookings; me uuid := auth.uid(); is_pro boolean; is_client boolean; is_system boolean; hours_until numeric;
begin
  select * into b from bookings where id = b_id for update;
  if not found then raise exception 'not_found'; end if;
  is_pro := (me = b.pro_id); is_client := (me = b.client_id); is_system := (me is null);
  if not (is_pro or is_client or is_system) then raise exception 'forbidden'; end if;
  hours_until := extract(epoch from (b.starts_at - now())) / 3600;

  if new_status = 'confirmed'         and not ((is_pro or is_system) and b.status = 'requested' and b.hold_state <> 'none') then raise exception 'bad_transition'; end if;
  if new_status = 'declined'          and not ((is_pro or is_system) and b.status = 'requested') then raise exception 'bad_transition'; end if;
  if new_status = 'onHerWay'          and not (is_pro and b.status = 'confirmed') then raise exception 'bad_transition'; end if;
  if new_status = 'arrived'           and not (is_pro and b.status = 'onHerWay') then raise exception 'bad_transition'; end if;
  if new_status = 'inProgress'        and not (is_pro and b.status in ('arrived', 'confirmed')) then raise exception 'bad_transition'; end if;
  if new_status = 'done'              and not ((is_pro and b.status in ('inProgress', 'arrived')) or (is_system and b.status = 'inProgress')) then raise exception 'bad_transition'; end if;
  if new_status = 'noShow'            and not (is_pro and b.status = 'arrived' and now() > b.starts_at + interval '15 minutes'
                                               and exists (select 1 from messages m join threads t on t.id = m.thread_id
                                                           where t.booking_id = b.id and m.sender_id = b.pro_id)) then raise exception 'bad_transition'; end if;
  if new_status = 'cancelledByPro'    and not (is_pro and b.status in ('confirmed', 'onHerWay', 'arrived')) then raise exception 'bad_transition'; end if;
  if new_status = 'cancelledByClient' and not ((is_client or is_system) and b.status in ('requested', 'confirmed', 'onHerWay', 'arrived')) then raise exception 'bad_transition'; end if;
  if new_status = 'paid'              and not is_system then raise exception 'bad_transition'; end if;
  if new_status = 'requested' then raise exception 'bad_transition'; end if;

  if new_status = 'cancelledByClient' then
    if b.status = 'requested' or hours_until >= 24 then b.cancellation_charge_cents := 0;
    elsif b.status = 'arrived' then b.cancellation_charge_cents := b.services_cents + b.travel_fee_cents + b.booking_fee_cents;
    else b.cancellation_charge_cents := round((b.services_cents + b.travel_fee_cents) * 0.5); end if;
  elsif new_status = 'noShow' then
    b.cancellation_charge_cents := b.services_cents + b.travel_fee_cents + b.booking_fee_cents;
  end if;

  update bookings set status = new_status,
    decline_reason = coalesce(reason, decline_reason),
    cancellation_charge_cents = b.cancellation_charge_cents,
    done_at = case when new_status = 'done' then now() else done_at end
    where id = b_id returning * into b;
  return b;
end $$;

-- ---------------------------------------------------------------------------
-- Status side effects: the event log, counters, reliability, system lines in the thread
-- ---------------------------------------------------------------------------
create or replace function booking_when(t timestamptz) returns text language sql immutable as $$
  select trim(to_char(t at time zone 'Australia/Melbourne', 'FMDay FMDD FMMonth')) || ' at '
      || lower(trim(to_char(t at time zone 'Australia/Melbourne', 'FMHH12:MI am')))
$$;

create or replace function add_reliability(p uuid, delta int) returns void
language sql security definer set search_path = public, extensions as $$
  update pros set reliability_score = least(100, greatest(0, reliability_score + delta)),
    instant_book = case when least(100, greatest(0, reliability_score + delta)) < 70 then false else instant_book end
  where id = p;
$$;
revoke execute on function add_reliability(uuid, int) from public, anon, authenticated;

create or replace function bookings_on_status() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare t_id uuid; line text; pro_name text; hours_until numeric;
begin
  if tg_op = 'INSERT' then
    insert into threads (booking_id, pro_id, client_id, last_message_at) values (new.id, new.pro_id, new.client_id, now())
      returning id into t_id;
  else
    select id into t_id from threads where booking_id = new.id;
  end if;

  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into booking_events (booking_id, status, actor_id) values (new.id, new.status, auth.uid());
    select first_name into pro_name from profiles where id = new.pro_id;
    hours_until := extract(epoch from (new.starts_at - now())) / 3600;

    if new.status in ('done', 'paid') and (tg_op = 'INSERT' or old.status not in ('done', 'paid')) then
      update pros set completed_bookings = completed_bookings + 1 where id = new.pro_id;
    end if;
    if new.status = 'cancelledByPro' then
      perform add_reliability(new.pro_id, case
        when (new.starts_at at time zone 'Australia/Melbourne')::date = (now() at time zone 'Australia/Melbourne')::date then -30
        when hours_until < 24 then -20 else -10 end);
    end if;
    if new.status = 'declined' and new.decline_reason = 'No reply in time' then
      perform add_reliability(new.pro_id, -2);
    end if;
    if new.status = 'arrived' then
      perform add_reliability(new.pro_id, case when now() <= new.starts_at + interval '15 minutes' then 1 else -3 end);
    end if;

    line := case new.status
      when 'requested' then 'You asked for ' || booking_when(new.starts_at) || '.'
      when 'confirmed' then 'Confirmed for ' || booking_when(new.starts_at) || '.'
      when 'declined' then case when new.decline_reason = 'No reply in time'
                                then coalesce(pro_name, 'She') || ' didn''t answer in time. Not your fault.'
                                else coalesce(pro_name, 'She') || ' can''t do this one.' end
      when 'cancelledByPro' then coalesce(pro_name, 'She') || ' cancelled. You won''t be charged.'
      when 'cancelledByClient' then 'Cancelled.'
      when 'onHerWay' then coalesce(pro_name, 'She') || '''s on her way.'
      when 'arrived' then coalesce(pro_name, 'She') || '''s here.'
      when 'done' then 'Done.'
      when 'paid' then 'Paid. Receipt''s in your inbox.'
      when 'noShow' then 'Marked as missed.'
      else null end;
    -- The request line waits until the payment is in, so a half-finished booking says nothing.
    if line is not null and t_id is not null and not (new.status = 'requested' and new.hold_state = 'none') then
      insert into messages (thread_id, sender_id, text) values (t_id, null, line);
    end if;
  end if;

  -- The request line, once the hold is in.
  if tg_op = 'UPDATE' and new.status = 'requested' and old.hold_state = 'none' and new.hold_state <> 'none' and t_id is not null then
    insert into messages (thread_id, sender_id, text) values (t_id, null, 'You asked for ' || booking_when(new.starts_at) || '.');
  end if;
  return new;
end $$;
drop trigger if exists bookings_status on bookings;
create trigger bookings_status after insert or update of status, hold_state on bookings
  for each row execute function bookings_on_status();

create or replace function messages_after_insert() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin update threads set last_message_at = new.sent_at where id = new.thread_id; return null; end $$;

-- ---------------------------------------------------------------------------
-- "Something wrong?": pauses auto-capture for up to 48 hours. The client calls this.
-- ---------------------------------------------------------------------------
create or replace function flag_booking(b_id uuid, detail text default '')
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare b bookings;
begin
  update bookings set capture_paused_until = now() + interval '48 hours'
    where id = b_id and client_id = auth.uid() and status in ('done', 'noShow') returning * into b;
  if not found then raise exception 'bad_transition'; end if;
  insert into reports (reporter_id, reported_id, booking_id, reason, detail)
    values (auth.uid(), b.pro_id, b.id, 'something_wrong', left(coalesce(detail, ''), 2000));
  return b;
end $$;

-- ---------------------------------------------------------------------------
-- The sweep, every ten minutes. Stripe work is the settle function's, every five.
-- ---------------------------------------------------------------------------
create or replace function sweep_bookings() returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  -- Payment never finished: let the slot go.
  update bookings set status = 'declined', decline_reason = 'Payment not finished'
    where status = 'requested' and hold_state = 'none' and created_at < now() - interval '30 minutes';
  -- Nobody answered in two hours.
  update bookings set status = 'declined', decline_reason = 'No reply in time'
    where status = 'requested' and hold_state <> 'none' and created_at < now() - interval '2 hours';
  -- Started but never marked done: done 12 hours after the end.
  update bookings set status = 'done', done_at = now()
    where status = 'inProgress' and ends_at < now() - interval '12 hours';
end $$;
revoke execute on function sweep_bookings() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Account deletion (App Store 5.1.1(v)). Refused while a booking is live.
-- ---------------------------------------------------------------------------
create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if exists (select 1 from bookings where (client_id = me or pro_id = me)
             and status in ('requested', 'confirmed', 'onHerWay', 'arrived', 'inProgress', 'done')) then
    raise exception 'live_booking';
  end if;
  -- Past bookings keep their money trail but lose the person.
  update pros set is_active = false where id = me;
  delete from auth.users where id = me;
end $$;

-- ---------------------------------------------------------------------------
-- Column guards: what the app may write. Verification, ratings, reliability, Stripe ids and
-- read receipts' neighbours are the server's.
-- ---------------------------------------------------------------------------
revoke insert, update on pros from anon, authenticated;
grant insert (id, last_initial, specialties, headline, bio, suburb, location, travel_radius_km, travel_fee_cents,
              instant_book, years_experience, abn, buffer_minutes, step_minutes) on pros to authenticated;
grant update (last_initial, specialties, headline, bio, suburb, location, travel_radius_km, travel_fee_cents,
              instant_book, years_experience, abn, is_active, buffer_minutes, step_minutes) on pros to authenticated;

-- Instant book is for verified pros with reliability 70 or more (spec §11).
create or replace function pros_guard() returns trigger language plpgsql as $$
begin
  if new.instant_book and (not new.is_verified or new.reliability_score < 70) then new.instant_book := false; end if;
  return new;
end $$;
drop trigger if exists pros_guard on pros;
create trigger pros_guard before insert or update on pros for each row execute function pros_guard();

revoke update on threads from anon, authenticated;
grant update (client_read_at, pro_read_at) on threads to authenticated;

revoke update on reviews from anon, authenticated;
grant update (pro_reply, pro_replied_at) on reviews to authenticated;

revoke insert, update on profile_contacts from anon, authenticated;
grant insert (profile_id, phone, email) on profile_contacts to authenticated;
grant update (phone, email) on profile_contacts to authenticated;

revoke insert, update on payment_methods from anon, authenticated;
grant update (is_default) on payment_methods to authenticated;

revoke insert, update, delete on bookings, booking_services, booking_events from anon, authenticated;

-- Deleting an account keeps the other side's history: the booking stays, the person goes.
alter table bookings alter column client_id drop not null, alter column pro_id drop not null;
alter table bookings drop constraint bookings_client_id_fkey,
  add constraint bookings_client_id_fkey foreign key (client_id) references profiles (id) on delete set null;
alter table bookings drop constraint bookings_pro_id_fkey,
  add constraint bookings_pro_id_fkey foreign key (pro_id) references pros (id) on delete set null;
alter table threads alter column client_id drop not null, alter column pro_id drop not null;
alter table threads drop constraint threads_client_id_fkey,
  add constraint threads_client_id_fkey foreign key (client_id) references profiles (id) on delete set null;
alter table threads drop constraint threads_pro_id_fkey,
  add constraint threads_pro_id_fkey foreign key (pro_id) references pros (id) on delete set null;
alter table messages drop constraint messages_sender_id_fkey,
  add constraint messages_sender_id_fkey foreign key (sender_id) references profiles (id) on delete set null;
alter table booking_events drop constraint booking_events_actor_id_fkey,
  add constraint booking_events_actor_id_fkey foreign key (actor_id) references profiles (id) on delete set null;
alter table payout_items drop constraint payout_items_booking_id_fkey,
  add constraint payout_items_booking_id_fkey foreign key (booking_id) references bookings (id) on delete cascade;

-- ---------------------------------------------------------------------------
-- Grants: the RPCs the app calls
-- ---------------------------------------------------------------------------
-- Every function is closed to the public first. With no signed-in user, move_booking() would
-- otherwise treat the caller as the system.
revoke execute on function move_booking(uuid, booking_status, text) from public, anon;
revoke execute on function create_booking(uuid, uuid[], timestamptz, uuid, text) from public, anon;
revoke execute on function bookings_for_pro() from public, anon;
revoke execute on function flag_booking(uuid, text) from public, anon;
revoke execute on function delete_my_account() from public, anon;
revoke execute on function pro_cards(uuid[], double precision, double precision) from public, anon;
revoke execute on function refresh_pro_rating(uuid) from public, anon, authenticated;
grant execute on function pros_near(double precision, double precision, category, int) to anon, authenticated;
grant execute on function pro_card(uuid, double precision, double precision) to anon, authenticated;
grant execute on function pro_cards(uuid[], double precision, double precision) to authenticated;
grant execute on function pro_reviews(uuid, int) to anon, authenticated;
grant execute on function pro_slots(uuid, date, int, text) to anon, authenticated;
grant execute on function create_booking(uuid, uuid[], timestamptz, uuid, text) to authenticated;
grant execute on function move_booking(uuid, booking_status, text) to authenticated;
grant execute on function bookings_for_pro() to authenticated;
grant execute on function flag_booking(uuid, text) to authenticated;
grant execute on function delete_my_account() to authenticated;
