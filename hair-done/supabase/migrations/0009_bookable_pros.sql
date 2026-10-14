-- Hair Done: only bookable pros are shown and booked.
-- A pro is bookable once she's verified and Stripe can pay her. Before that, Discover, search and
-- "near you" leave her out, and so does her own Discover (she never sees herself in a list).
-- Looking a pro up by id (a past booking, a favourite, her own "See it as a client") still works,
-- so old bookings don't lose their pro's card. create_booking refuses an unbookable pro.

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
         or (p.is_verified and p.payouts_connected and p.id is distinct from auth.uid()))
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

create or replace function create_booking(p_pro uuid, p_service_ids uuid[], p_starts_at timestamptz, p_address_id uuid, p_notes text default '')
returns bookings language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid(); pr pros; a addresses; n int; svc_cents int; total_min int; b bookings;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_pro = me then raise exception 'own_booking'; end if;
  select * into pr from pros where id = p_pro and is_active and reliability_score >= 50
    and is_verified and payouts_connected;
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
