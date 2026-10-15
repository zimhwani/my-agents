-- Hair Done: "No show" opens 15 minutes after the later of the start time and her arrival.
-- Before, it counted from the start time only, so a pro who arrived late could mark it before
-- waiting 15 minutes, and the app (counting from arrival) offered it to an early pro the server refused.
create or replace function move_booking(b_id uuid, new_status booking_status, reason text default null)
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare b bookings; me uuid := auth.uid(); is_pro boolean; is_client boolean; is_system boolean; hours_until numeric;
  arrived_at timestamptz;
begin
  select * into b from bookings where id = b_id for update;
  if not found then raise exception 'not_found'; end if;
  is_pro := (me = b.pro_id); is_client := (me = b.client_id); is_system := (me is null);
  if not (is_pro or is_client or is_system) then raise exception 'forbidden'; end if;
  hours_until := extract(epoch from (b.starts_at - now())) / 3600;
  select max(e.at) into arrived_at from booking_events e where e.booking_id = b.id and e.status = 'arrived';

  if new_status = 'confirmed'         and not ((is_pro or is_system) and b.status = 'requested' and b.hold_state <> 'none') then raise exception 'bad_transition'; end if;
  if new_status = 'declined'          and not ((is_pro or is_system) and b.status = 'requested') then raise exception 'bad_transition'; end if;
  if new_status = 'onHerWay'          and not (is_pro and b.status = 'confirmed') then raise exception 'bad_transition'; end if;
  if new_status = 'arrived'           and not (is_pro and b.status = 'onHerWay') then raise exception 'bad_transition'; end if;
  if new_status = 'inProgress'        and not (is_pro and b.status in ('arrived', 'confirmed')) then raise exception 'bad_transition'; end if;
  if new_status = 'done'              and not ((is_pro and b.status in ('inProgress', 'arrived')) or (is_system and b.status = 'inProgress')) then raise exception 'bad_transition'; end if;
  if new_status = 'noShow'            and not (is_pro and b.status = 'arrived'
                                               and now() > greatest(b.starts_at, coalesce(arrived_at, b.starts_at)) + interval '15 minutes'
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
