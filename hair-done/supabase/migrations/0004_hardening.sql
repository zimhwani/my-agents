-- Hair Done: tidy-ups from the Supabase security advisor after 0003.

-- Triggers and helpers aren't API. Policies still call the two helpers as the signed-in user.
revoke execute on function bookings_on_status() from public, anon, authenticated;
revoke execute on function messages_after_insert() from public, anon, authenticated;
revoke execute on function is_booking_party(uuid) from public, anon;
revoke execute on function has_booking_with(uuid) from public, anon;
grant execute on function is_booking_party(uuid) to authenticated;
grant execute on function has_booking_with(uuid) to authenticated;

alter function set_updated_at() set search_path = public, extensions;
alter function gen_reference() set search_path = public, extensions;
alter function bookings_defaults() set search_path = public, extensions;
alter function reviews_after_change() set search_path = public, extensions;
alter function is_party(uuid, uuid) set search_path = public, extensions;
alter function booking_when(timestamptz) set search_path = public, extensions;
alter function pros_guard() set search_path = public, extensions;
alter function refresh_pro_rating(uuid) set search_path = public, extensions;

-- pg_net belongs in `extensions`, not `public`.
drop extension if exists pg_net;
create extension if not exists pg_net with schema extensions;

-- Left as is: postgis lives in `public` and can't be moved after install, so the advisor will keep
-- listing spatial_ref_sys (read-only reference data) and st_estimatedextent. Neither holds user data.
