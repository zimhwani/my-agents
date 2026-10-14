-- Hair Done: the server half of the UX audit fixes (docs/qa/ux-audit.md).
--   - A pro is a draft until she finishes onboarding (onboarded_at), can close her pro profile
--     (closed_at) and come back, and says how much notice she needs (notice_minutes).
--   - ID check: she uploads photo ID and a selfie to the private id-docs bucket; a person checks it.
--   - Reschedule (client, 24 hours' notice or more), who's free today, and search across all pros.
--   - Hours and days off save in one go, so a failed save can't leave her with no hours.

alter table pros
  add column if not exists notice_minutes integer not null default 90 check (notice_minutes between 60 and 2880),
  add column if not exists onboarded_at timestamptz,
  add column if not exists closed_at timestamptz,
  add column if not exists id_submitted_at timestamptz;

-- Everyone who's already a pro finished the old onboarding.
update pros set onboarded_at = created_at where onboarded_at is null;

grant insert (notice_minutes, onboarded_at), update (notice_minutes, onboarded_at) on pros to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Listing and booking: only finished, open, verified pros with payouts on.
-- ---------------------------------------------------------------------------------------------
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
    and (filter_ids is not null
         or (p.is_verified and p.payouts_connected and p.onboarded_at is not null and p.closed_at is null
             and p.id is distinct from auth.uid()))
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

/** True when clients can book her: the same test the lists use. */
create or replace function pro_is_bookable(p_pro uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from pros p where p.id = p_pro and p.is_active and p.reliability_score >= 50
                 and p.is_verified and p.payouts_connected and p.onboarded_at is not null and p.closed_at is null)
$$;
grant execute on function pro_is_bookable(uuid) to anon, authenticated;

create or replace function create_booking(p_pro uuid, p_service_ids uuid[], p_starts_at timestamptz, p_address_id uuid, p_notes text default '')
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid(); pr pros; a addresses; n int; svc_cents int; total_min int; b bookings;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_pro = me then raise exception 'own_booking'; end if;
  if not pro_is_bookable(p_pro) then raise exception 'pro_not_found'; end if;
  select * into pr from pros where id = p_pro;
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

-- ---------------------------------------------------------------------------------------------
-- Slots: her own notice instead of a fixed 90 minutes.
-- ---------------------------------------------------------------------------------------------
create or replace function pro_slots(p uuid, day date, duration_minutes integer, tz text default 'Australia/Melbourne')
returns table(starts_at timestamptz, is_available boolean, reason text)
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  r record; m int; s timestamptz; e timestamptz; buf int; step int; notice int;
begin
  select buffer_minutes, step_minutes, notice_minutes into buf, step, notice from pros where id = p and is_active;
  if not found then return; end if;
  if exists (select 1 from days_off d where d.pro_id = p and d.day = pro_slots.day) then return; end if;
  for r in select * from availability a where a.pro_id = p and a.weekday = extract(dow from pro_slots.day) order by a.start_minutes loop
    m := r.start_minutes;
    while m + duration_minutes <= r.end_minutes loop
      s := (pro_slots.day::timestamp + make_interval(mins => m)) at time zone tz;
      e := s + make_interval(mins => duration_minutes);
      starts_at := s; is_available := true; reason := null;
      if s < now() + make_interval(mins => notice) then
        is_available := false;
        reason := case when notice >= 1440 then 'Too soon, she needs a day''s notice'
                       else 'Too soon, she needs ' || (case when notice % 60 = 0 then (notice / 60) || ' hours'''
                                                            else notice || ' minutes''' end) || ' notice' end;
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

-- ---------------------------------------------------------------------------------------------
-- Who's free today, from real slots, and search across every bookable pro.
-- ---------------------------------------------------------------------------------------------
create or replace function whos_free(lat double precision, lng double precision, cat category default null, limit_n int default 12)
returns table(pro_id uuid, first_free timestamptz)
language sql stable security definer set search_path = public, extensions as $$
  select c.id, f.first_free
  from pro_cards_where(null, lat, lng, cat, true, 60) c
  cross join lateral (
    select min(sl.starts_at) as first_free
    from pro_slots(c.id, (now() at time zone 'Australia/Melbourne')::date,
                   coalesce((select min(s.minutes) from services s where s.pro_id = c.id and s.is_active), 60)) sl
    where sl.is_available
  ) f
  where f.first_free is not null
  order by f.first_free
  limit limit_n
$$;
grant execute on function whos_free(double precision, double precision, category, int) to anon, authenticated;

create or replace function pros_search(q text, lat double precision default null, lng double precision default null, limit_n int default 40)
returns setof pro_card language sql stable security definer set search_path = public, extensions as $$
  select * from pro_cards_where(array(
      select p.id from pros p join profiles pr on pr.id = p.id
      where pro_is_bookable(p.id) and p.id is distinct from auth.uid()
        and length(trim(q)) >= 2
        and (pr.first_name ilike '%' || trim(q) || '%' or p.suburb ilike '%' || trim(q) || '%'
             or p.headline ilike '%' || trim(q) || '%'
             or exists (select 1 from services s where s.pro_id = p.id and s.is_active and s.name ilike '%' || trim(q) || '%')
             or exists (select 1 from unnest(p.specialties) sp where sp::text ilike '%' || trim(q) || '%'))
    ), lat, lng, null, false, limit_n)
$$;
grant execute on function pros_search(text, double precision, double precision, int) to anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Reschedule: the client moves a booking with 24 hours' notice or more. Same services and price,
-- so the hold stands. The pro is told; no acceptance needed (product-spec §5).
-- ---------------------------------------------------------------------------------------------
create or replace function reschedule_booking(b_id uuid, new_start timestamptz)
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid(); b bookings; pr pros; dur interval; new_end timestamptz; local_day date; mins int; t uuid;
begin
  select * into b from bookings where id = b_id for update;
  if not found or b.client_id is distinct from me then raise exception 'not_found'; end if;
  if b.status not in ('requested', 'confirmed') then raise exception 'bad_transition'; end if;
  if b.starts_at < now() + interval '24 hours' then raise exception 'too_late_to_move'; end if;
  -- A placed card hold lasts 7 days; a time past that would outlive it.
  if b.hold_state = 'held' and new_start > now() + interval '6 days' then raise exception 'too_far_to_move'; end if;

  select * into pr from pros where id = b.pro_id;
  dur := b.ends_at - b.starts_at;
  new_end := new_start + dur;
  local_day := (new_start at time zone 'Australia/Melbourne')::date;
  mins := extract(hour from new_start at time zone 'Australia/Melbourne') * 60
        + extract(minute from new_start at time zone 'Australia/Melbourne');

  perform pg_advisory_xact_lock(hashtext(b.pro_id::text));
  if new_start < now() + make_interval(mins => pr.notice_minutes)
     or exists (select 1 from days_off d where d.pro_id = b.pro_id and d.day = local_day)
     or not exists (select 1 from availability a where a.pro_id = b.pro_id and a.weekday = extract(dow from local_day)
                    and a.start_minutes <= mins and mins + extract(epoch from dur) / 60 <= a.end_minutes)
     or exists (select 1 from bookings o where o.pro_id = b.pro_id and o.id <> b.id
                and o.status in ('requested','confirmed','onHerWay','arrived','inProgress')
                and o.starts_at - make_interval(mins => pr.buffer_minutes) < new_end
                and o.ends_at + make_interval(mins => pr.buffer_minutes) > new_start) then
    raise exception 'slot_taken';
  end if;

  update bookings set starts_at = new_start, ends_at = new_end where id = b.id returning * into b;

  select id into t from threads where booking_id = b.id;
  if t is not null then
    insert into messages (thread_id, sender_id, text)
    values (t, null, 'Moved to ' || to_char(new_start at time zone 'Australia/Melbourne', 'FMDay FMDD FMMonth, FMHH12:MI ') ||
                     lower(to_char(new_start at time zone 'Australia/Melbourne', 'AM')) || '.');
  end if;
  perform private.call_notify(jsonb_build_object('event', 'moved', 'booking_id', b.id));
  return b;
end $$;
revoke execute on function reschedule_booking(uuid, timestamptz) from public, anon;
grant execute on function reschedule_booking(uuid, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Closing and reopening her pro profile; sending her ID.
-- ---------------------------------------------------------------------------------------------
create or replace function close_pro_profile() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if exists (select 1 from bookings where pro_id = me
             and status in ('requested', 'confirmed', 'onHerWay', 'arrived', 'inProgress', 'done')) then
    raise exception 'live_booking';
  end if;
  update pros set closed_at = now(), is_active = false where id = me;
end $$;

create or replace function reopen_pro_profile() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  update pros set closed_at = null, is_active = true where id = me;
end $$;

create or replace function submit_id_check() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if (select count(*) from storage.objects where bucket_id = 'id-docs' and (storage.foldername(name))[1] = me::text) < 2 then
    raise exception 'id_docs_missing';
  end if;
  update pros set id_submitted_at = now() where id = me;
end $$;

revoke execute on function close_pro_profile() from public, anon;
revoke execute on function reopen_pro_profile() from public, anon;
revoke execute on function submit_id_check() from public, anon;
grant execute on function close_pro_profile() to authenticated;
grant execute on function reopen_pro_profile() to authenticated;
grant execute on function submit_id_check() to authenticated;

insert into storage.buckets (id, name, public) values ('id-docs', 'id-docs', false) on conflict (id) do nothing;
create policy id_docs_write on storage.objects for insert to authenticated
  with check (bucket_id = 'id-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy id_docs_read_own on storage.objects for select to authenticated
  using (bucket_id = 'id-docs' and (storage.foldername(name))[1] = auth.uid()::text);
-- Replacing a photo re-uploads to the same path (upsert), which needs update.
create policy id_docs_update_own on storage.objects for update to authenticated
  using (bucket_id = 'id-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy work_update_own on storage.objects for update to authenticated
  using (bucket_id in ('work', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text);

-- Profile photos: she sets her own avatar_url (the column is already hers to write).
