-- Hair Done: switches the app reads at launch, so a feature can be turned on or off without a new build.
--   phone_sign_in  off until Twilio's Australian sender registration is approved (texts to AU need it).
-- To turn one on:  update private.app_flags set value = true where key = 'phone_sign_in';
create table if not exists private.app_flags (
  key   text primary key,
  value boolean not null
);
insert into private.app_flags (key, value) values ('phone_sign_in', false) on conflict (key) do nothing;

create or replace function app_flags() returns jsonb
language sql stable security definer set search_path = private, public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from private.app_flags
$$;
grant execute on function app_flags() to anon, authenticated;
