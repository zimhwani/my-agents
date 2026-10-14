-- Hair Done: push notifications.
-- The app registers its APNs token with register_device(). Booking status changes and new messages
-- call the `notify` edge function through pg_net; the settle cron also asks it for timed reminders.
-- private.push_log makes every push idempotent: one row per (booking or message, kind, recipient).

alter table devices
  add column if not exists environment text not null default 'production'
    check (environment in ('sandbox', 'production')),
  add column if not exists updated_at timestamptz not null default now(),
  -- Tokens are switched off, never deleted: a phone that signs out, or one APNs says is gone.
  add column if not exists active boolean not null default true;

create table if not exists private.push_log (
  key        text primary key,          -- e.g. 'status:<booking>:confirmed:<profile>'
  sent_at    timestamptz not null default now()
);

-- A phone moves between accounts (sign out, sign in as someone else): the token follows the person
-- signed in now. Security definer so it can move a row that belongs to someone else.
create or replace function register_device(p_token text, p_environment text default 'production')
returns void language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_token is null or length(p_token) < 32 or length(p_token) > 400 then raise exception 'bad_token'; end if;
  insert into devices (profile_id, apns_token, environment, active, updated_at)
    values (me, p_token, case when p_environment = 'sandbox' then 'sandbox' else 'production' end, true, now())
  on conflict (apns_token) do update set profile_id = excluded.profile_id,
    environment = excluded.environment, active = true, updated_at = now();
end $$;

create or replace function unregister_device(p_token text)
returns void language sql security definer set search_path = public, extensions as $$
  update devices set active = false, updated_at = now() where apns_token = p_token and profile_id = auth.uid();
$$;

revoke execute on function register_device(text, text) from public, anon;
revoke execute on function unregister_device(text) from public, anon;
grant execute on function register_device(text, text) to authenticated;
grant execute on function unregister_device(text) to authenticated;

-- Call the notify function. Fire-and-forget through pg_net; the secret stays in the database.
create or replace function private.call_notify(body jsonb) returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/notify',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := body,
    timeout_milliseconds := 20000)
$$;
revoke execute on function private.call_notify(jsonb) from public;

create or replace function bookings_push() returns trigger
language plpgsql security definer set search_path = public, private, extensions as $$
begin
  -- A request only exists for the pro once the money's held.
  if new.status = 'requested' and new.hold_state = 'none' then return null; end if;
  if tg_op = 'UPDATE' and new.status is not distinct from old.status
     and not (new.status = 'requested' and old.hold_state = 'none' and new.hold_state <> 'none') then
    return null;
  end if;
  perform private.call_notify(jsonb_build_object('event', 'status', 'booking_id', new.id, 'status', new.status));
  return null;
end $$;
revoke execute on function bookings_push() from public, anon, authenticated;
create or replace trigger bookings_push after insert or update of status, hold_state on bookings
  for each row execute function bookings_push();

create or replace function messages_push() returns trigger
language plpgsql security definer set search_path = public, private, extensions as $$
begin
  -- System lines are covered by the status pushes.
  if new.sender_id is null then return null; end if;
  perform private.call_notify(jsonb_build_object('event', 'message', 'message_id', new.id));
  return null;
end $$;
revoke execute on function messages_push() from public, anon, authenticated;
create or replace trigger messages_push after insert on messages for each row execute function messages_push();

-- Timed reminders (unanswered requests, the day before, two hours before) every five minutes.
select cron.schedule('hairdone-reminders', '*/5 * * * *',
  $$select private.call_notify('{"event":"reminders"}'::jsonb)$$);

-- The notify function claims each push before sending it, so a retry or a doubled trigger can't
-- send the same thing twice. Server only.
create or replace function claim_push(p_key text) returns boolean
language plpgsql security definer set search_path = public, private, extensions as $$
begin
  insert into private.push_log (key) values (p_key);
  return true;
exception when unique_violation then
  return false;
end $$;
revoke execute on function claim_push(text) from public, anon, authenticated;
grant execute on function claim_push(text) to service_role;

create or replace function push_sent(p_key text) returns boolean
language sql stable security definer set search_path = public, private, extensions as $$
  select exists (select 1 from private.push_log where key = p_key)
$$;
revoke execute on function push_sent(text) from public, anon, authenticated;
grant execute on function push_sent(text) to service_role;
