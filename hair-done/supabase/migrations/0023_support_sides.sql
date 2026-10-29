-- Hair Done: support_context names both sides of a booking (client and pro), and only says which side the
-- writer is on when the email matched an account. A booking reference alone doesn't say who wrote.
create or replace function support_context(p_item uuid) returns jsonb
language sql stable security definer set search_path = private, public as $$
  with i as (
    select s.*, coalesce(s.profile_id, (select u.id from auth.users u where lower(u.email) = s.from_email limit 1)) as who
    from private.support_items s where s.id = p_item
  )
  select jsonb_build_object(
    'item', to_jsonb(i) - 'who',
    'person', (select jsonb_build_object('id', pf.id, 'first_name', pf.first_name, 'joined', pf.created_at,
                 'is_pro', exists (select 1 from pros p where p.id = pf.id),
                 'email', coalesce(nullif(pc.email, ''), u.email))
               from profiles pf left join profile_contacts pc on pc.profile_id = pf.id left join auth.users u on u.id = pf.id
               where pf.id = i.who),
    'report', (select jsonb_build_object('reason', r.reason, 'created', r.created_at, 'booking_id', r.booking_id,
                 'about_pro', exists (select 1 from pros p where p.id = r.reported_id))
               from reports r where r.id = i.report_id),
    'bookings', (select coalesce(jsonb_agg(b order by b.starts_at desc), '[]') from (
                   select bk.reference, bk.status, bk.hold_state, bk.starts_at, bk.address_suburb,
                          bk.services_cents + bk.travel_fee_cents + bk.booking_fee_cents - bk.discount_cents as total_cents,
                          bk.tip_cents, bk.cancellation_charge_cents, bk.captured_at, bk.capture_paused_until,
                          -- Which side they're on, only when we know who wrote: a reference alone doesn't say.
                          case when i.who is null then null when bk.client_id = i.who then 'client' else 'pro' end as their_side,
                          (select string_agg(bs.name, ', ' order by bs.sort_order) from booking_services bs where bs.booking_id = bk.id) as services,
                          (select first_name from profiles where id = bk.client_id) as client_first_name,
                          (select first_name from profiles where id = bk.pro_id) as pro_first_name
                   from bookings bk
                   where i.who is not null and (bk.client_id = i.who or bk.pro_id = i.who)
                      or bk.reference = i.booking_ref
                      or bk.id = (select r.booking_id from reports r where r.id = i.report_id)
                   order by bk.starts_at desc limit 6) b)
  ) from i
$$;

