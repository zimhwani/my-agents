-- Row-level security. Default deny; each table opens exactly what a role needs.

alter table profiles        enable row level security;
alter table addresses       enable row level security;
alter table payment_methods enable row level security;
alter table pros            enable row level security;
alter table services        enable row level security;
alter table work_items      enable row level security;
alter table availability    enable row level security;
alter table days_off        enable row level security;
alter table bookings        enable row level security;
alter table booking_services enable row level security;
alter table booking_inspo   enable row level security;
alter table booking_events  enable row level security;
alter table reviews         enable row level security;
alter table threads         enable row level security;
alter table messages        enable row level security;
alter table favourites      enable row level security;
alter table blocks          enable row level security;
alter table reports         enable row level security;
alter table payouts         enable row level security;
alter table payout_items    enable row level security;
alter table devices         enable row level security;

create or replace function is_party(b_pro uuid, b_client uuid) returns boolean language sql stable as $$
  select auth.uid() = b_pro or auth.uid() = b_client
$$;

-- Profiles: you can read yourself; pros' public bits are read through the pros table.
create policy profiles_self_read   on profiles for select using (id = auth.uid());
create policy profiles_self_write  on profiles for update using (id = auth.uid());
create policy profiles_self_insert on profiles for insert with check (id = auth.uid());
-- A pro can see the first name of a client who booked her, and vice versa.
create policy profiles_counterparty on profiles for select using (
  exists (select 1 from bookings b where (b.client_id = profiles.id and b.pro_id = auth.uid()) or (b.pro_id = profiles.id and b.client_id = auth.uid()))
);

alter table profile_contacts enable row level security;
create policy contacts_own on profile_contacts for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy addresses_own on addresses for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy payment_methods_own on payment_methods for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Pros are public to read (that's the marketplace). Only the pro edits her own row.
create policy pros_public_read on pros for select using (is_active or id = auth.uid());
create policy pros_self_write  on pros for update using (id = auth.uid());
create policy pros_self_insert on pros for insert with check (id = auth.uid());

create policy services_public_read on services for select using (is_active or pro_id = auth.uid());
create policy services_own_write   on services for all using (pro_id = auth.uid()) with check (pro_id = auth.uid());

create policy work_public_read on work_items for select using (true);
create policy work_own_write   on work_items for all using (pro_id = auth.uid()) with check (pro_id = auth.uid());

create policy availability_public_read on availability for select using (true);
create policy availability_own_write   on availability for all using (pro_id = auth.uid()) with check (pro_id = auth.uid());
create policy days_off_public_read on days_off for select using (true);
create policy days_off_own_write   on days_off for all using (pro_id = auth.uid()) with check (pro_id = auth.uid());

-- Bookings: only the two parties. Clients create; status moves are validated by `move_booking`.
create policy bookings_party_read on bookings for select using (is_party(pro_id, client_id));
create policy bookings_client_insert on bookings for insert with check (client_id = auth.uid() and status = 'requested');
-- Updates go through the RPC below (security definer) so the state machine can't be skipped.

-- What a pro reads: the street address and access notes appear only once she's confirmed.
create view bookings_for_pro with (security_invoker = true) as
  select b.id, b.reference, b.pro_id, b.client_id, b.status, b.starts_at, b.ends_at,
    case when b.status = 'requested' then null else b.address_label end as address_label,
    case when b.status = 'requested' then null else b.address_line1 end as address_line1,
    b.address_suburb, b.address_state, b.address_postcode,
    case when b.status = 'requested' then null else b.address_location end as address_location,
    case when b.status = 'requested' then '' else b.address_instructions end as address_instructions,
    b.notes, b.services_cents, b.travel_fee_cents, b.booking_fee_cents, b.tip_cents, b.discount_cents,
    b.platform_fee_cents, b.cancellation_charge_cents, b.decline_reason, b.created_at, b.updated_at
  from bookings b where b.pro_id = auth.uid();
grant select on bookings_for_pro to authenticated;

create policy booking_services_party on booking_services for select using (
  exists (select 1 from bookings b where b.id = booking_id and is_party(b.pro_id, b.client_id)));
create policy booking_services_client_insert on booking_services for insert with check (
  exists (select 1 from bookings b where b.id = booking_id and b.client_id = auth.uid()));

create policy booking_inspo_party on booking_inspo for select using (
  exists (select 1 from bookings b where b.id = booking_id and is_party(b.pro_id, b.client_id)));
create policy booking_inspo_client_insert on booking_inspo for insert with check (
  exists (select 1 from bookings b where b.id = booking_id and b.client_id = auth.uid()));

create policy booking_events_party on booking_events for select using (
  exists (select 1 from bookings b where b.id = booking_id and is_party(b.pro_id, b.client_id)));

-- Reviews: public read; the client writes once after done/paid; the pro replies once.
create policy reviews_public_read on reviews for select using (true);
create policy reviews_client_insert on reviews for insert with check (
  client_id = auth.uid() and exists (select 1 from bookings b where b.id = booking_id and b.client_id = auth.uid() and b.status in ('done', 'paid')));
create policy reviews_pro_reply on reviews for update using (pro_id = auth.uid() and pro_reply is null) with check (pro_id = auth.uid());

create policy threads_party on threads for select using (is_party(pro_id, client_id));
create policy threads_party_update on threads for update using (is_party(pro_id, client_id));
create policy messages_party_read on messages for select using (
  exists (select 1 from threads t where t.id = thread_id and is_party(t.pro_id, t.client_id)));
create policy messages_party_insert on messages for insert with check (
  sender_id = auth.uid() and exists (select 1 from threads t where t.id = thread_id and is_party(t.pro_id, t.client_id))
  and not exists (select 1 from blocks k join threads t on t.id = thread_id
                  where (k.blocker_id = t.pro_id and k.blocked_id = t.client_id) or (k.blocker_id = t.client_id and k.blocked_id = t.pro_id)));

create policy favourites_own on favourites for all using (client_id = auth.uid()) with check (client_id = auth.uid());
create policy blocks_own on blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy reports_own_insert on reports for insert with check (reporter_id = auth.uid());
create policy reports_own_read on reports for select using (reporter_id = auth.uid());

create policy payouts_own on payouts for select using (pro_id = auth.uid());
create policy payout_items_own on payout_items for select using (
  exists (select 1 from payouts p where p.id = payout_id and p.pro_id = auth.uid()));

create policy devices_own on devices for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Storage: work and avatars are public to read, owner-only to write. Inspo is private to the booking's parties.
create policy work_read   on storage.objects for select using (bucket_id in ('work', 'avatars'));
create policy work_write  on storage.objects for insert with check (bucket_id in ('work', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy work_delete on storage.objects for delete using (bucket_id in ('work', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy inspo_write on storage.objects for insert with check (bucket_id = 'inspo' and (storage.foldername(name))[1] = auth.uid()::text);
create policy inspo_read  on storage.objects for select using (
  bucket_id = 'inspo' and exists (
    select 1 from booking_inspo i join bookings b on b.id = i.booking_id
    where i.image_path = storage.objects.name and is_party(b.pro_id, b.client_id)));

-- ---------------------------------------------------------------------------
-- The state machine, as one RPC. Called by the app; the edge functions call it with the service role.
-- ---------------------------------------------------------------------------
create or replace function move_booking(b_id uuid, new_status booking_status, reason text default null)
returns bookings language plpgsql security definer as $$
declare b bookings; me uuid := auth.uid(); is_pro boolean; is_client boolean; hours_until numeric;
begin
  select * into b from bookings where id = b_id for update;
  if not found then raise exception 'not_found'; end if;
  is_pro := (me = b.pro_id); is_client := (me = b.client_id);
  if not (is_pro or is_client or me is null) then raise exception 'forbidden'; end if;
  hours_until := extract(epoch from (b.starts_at - now())) / 3600;

  -- Who may move what, from where.
  -- Instant book: the client's own request confirms itself once the hold is placed; otherwise the pro (or the service role) confirms.
  if new_status = 'confirmed'        and not ((is_pro or me is null or (is_client and (select instant_book from pros where id = b.pro_id))) and b.status = 'requested') then raise exception 'bad_transition'; end if;
  if new_status = 'declined'         and not ((is_pro or me is null) and b.status = 'requested') then raise exception 'bad_transition'; end if;
  if new_status = 'onHerWay'         and not (is_pro and b.status = 'confirmed') then raise exception 'bad_transition'; end if;
  if new_status = 'arrived'          and not (is_pro and b.status = 'onHerWay') then raise exception 'bad_transition'; end if;
  if new_status = 'inProgress'       and not (is_pro and b.status in ('arrived','confirmed')) then raise exception 'bad_transition'; end if;
  if new_status = 'done'             and not (is_pro and b.status in ('inProgress','arrived','onHerWay','confirmed')) then raise exception 'bad_transition'; end if;
  if new_status = 'noShow'           and not (is_pro and b.status in ('arrived','onHerWay') and now() > b.starts_at + interval '20 minutes') then raise exception 'bad_transition'; end if;
  if new_status = 'cancelledByPro'   and not (is_pro and b.status in ('requested','confirmed','onHerWay')) then raise exception 'bad_transition'; end if;
  if new_status = 'cancelledByClient' and not ((is_client or me is null) and b.status in ('requested','confirmed','onHerWay','arrived')) then raise exception 'bad_transition'; end if;
  if new_status = 'paid'             and me is not null then raise exception 'bad_transition'; end if; -- only the webhook, with the service role

  if new_status = 'cancelledByClient' then
    if b.status = 'requested' or hours_until >= 24 then b.cancellation_charge_cents := 0;
    elsif b.status = 'arrived' then b.cancellation_charge_cents := b.services_cents + b.travel_fee_cents + b.booking_fee_cents;
    else b.cancellation_charge_cents := round((b.services_cents + b.travel_fee_cents) * 0.5); end if;
  elsif new_status = 'noShow' then
    b.cancellation_charge_cents := b.services_cents + b.travel_fee_cents + b.booking_fee_cents;
  end if;

  update bookings set status = new_status, decline_reason = coalesce(reason, decline_reason),
    cancellation_charge_cents = b.cancellation_charge_cents
    where id = b_id returning * into b;
  return b;
end $$;

-- Auto-decline requests nobody answered in 2 hours, auto-capture 12 hours after done. Run by pg_cron.
create or replace function sweep_bookings() returns void language sql security definer as $$
  update bookings set status = 'declined', decline_reason = 'No reply in time'
    where status = 'requested' and created_at < now() - interval '2 hours';
$$;
