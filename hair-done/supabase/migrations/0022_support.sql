-- Hair Done: support and safety. Everything people send us lands in one queue, private.support_items:
--   - email to hello@hairdonenailsdone.app (Cloudflare Email Routing > the hairdone-mail Worker, which also
--     forwards the original to Keith, then posts it to functions/support-inbound)
--   - in-app reports, block reports and "Something wrong?" (a trigger on reports, below)
-- The support function (functions/support) sorts each one: safety goes to Keith straight away; everything
-- else gets a drafted reply he reads, edits and sends from hairdonenailsdone.app/reply/. Nothing is sent,
-- refunded or cancelled without Keith.
-- The drafting uses Claude only while private.app_flags 'support_ai' is on. It starts off: the privacy
-- policy has to name Anthropic as a processor first. Off, every item is still sorted and emailed to Keith,
-- with an empty reply for him to write.

create table if not exists private.support_items (
  id           uuid primary key default gen_random_uuid(),
  received_at  timestamptz not null default now(),
  source       text not null,                    -- email, report
  from_email   text,
  from_name    text,
  subject      text,
  body         text,                             -- what they wrote, as plain text (first 20,000 characters)
  message_id   text,                             -- the email's Message-ID, for threading the reply
  report_id    uuid references public.reports (id) on delete set null,
  profile_id   uuid,                             -- matched by email, or the reporter
  booking_ref  text,                             -- a reference like HD-7Q2K, if they mention one
  category     text,                             -- safety, money, booking, pro, account, other
  urgency      text,                             -- now, today, later
  summary      text,
  draft        text,
  status       text not null default 'new',      -- new, waiting (emailed to Keith), sent, closed
  notified     text,                             -- what happened to the email to Keith
  replied_at   timestamptz,
  reply        text,
  reply_error  text
);
create index if not exists support_items_status_idx on private.support_items (status, received_at);
create unique index if not exists support_items_message_idx on private.support_items (message_id) where message_id is not null;

insert into private.settings (key, value) values ('mail_secret', encode(extensions.gen_random_bytes(32), 'hex'))
  on conflict (key) do nothing;
insert into private.app_flags (key, value) values ('support_ai', false) on conflict (key) do nothing;

create or replace function check_mail_secret(s text) returns boolean
language sql stable security definer set search_path = private, public as $$
  select exists (select 1 from private.settings where key = 'mail_secret' and value = s)
$$;

-- An email from the Worker. Returns the item's id; the same Message-ID twice is stored once.
create or replace function support_receive(p jsonb) returns uuid
language plpgsql security definer set search_path = private, public as $$
declare rid uuid; ref text;
begin
  ref := upper(substring(coalesce(p->>'subject', '') || ' ' || coalesce(p->>'body', '') from '(?i)\m(HD-[A-Z0-9]{4,8})\M'));
  insert into private.support_items (source, from_email, from_name, subject, body, message_id, booking_ref, profile_id)
  values ('email', lower(trim(p->>'from_email')), left(p->>'from_name', 200), left(p->>'subject', 300),
          left(p->>'body', 20000), nullif(p->>'message_id', ''), ref,
          (select pc.profile_id from public.profile_contacts pc where lower(pc.email) = lower(trim(p->>'from_email')) limit 1))
  on conflict (message_id) where message_id is not null do nothing
  returning id into rid;
  if rid is null then
    select id into rid from private.support_items where message_id = p->>'message_id';
  end if;
  return rid;
end $$;

-- Everything the agent needs about one item: who wrote, their bookings, and the item itself.
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
                          case when bk.client_id = i.who then 'client' else 'pro' end as their_side,
                          (select string_agg(bs.name, ', ' order by bs.sort_order) from booking_services bs where bs.booking_id = bk.id) as services,
                          (select first_name from profiles where id = case when bk.client_id = i.who then bk.pro_id else bk.client_id end) as other_first_name
                   from bookings bk
                   where i.who is not null and (bk.client_id = i.who or bk.pro_id = i.who)
                      or bk.reference = i.booking_ref
                      or bk.id = (select r.booking_id from reports r where r.id = i.report_id)
                   order by bk.starts_at desc limit 6) b)
  ) from i
$$;

create or replace function support_new() returns setof uuid
language sql stable security definer set search_path = private, public as $$
  select id from private.support_items where status = 'new' order by received_at limit 20
$$;

create or replace function support_save(p_item uuid, p jsonb) returns void
language sql security definer set search_path = private, public as $$
  update private.support_items set category = p->>'category', urgency = p->>'urgency', summary = left(p->>'summary', 500),
    draft = left(p->>'draft', 8000), status = 'waiting', notified = p->>'notified'
  where id = p_item and status = 'new'
$$;

-- Review links for the reply page: <item id>.<expiry>.<hmac>, signed apart from vetting links.
create or replace function support_token(p_item uuid, p_days int default 7) returns text
language sql stable security definer set search_path = private, public as $$
  select b || '.' || private.vetting_sig('support.' || b)
  from (select p_item::text || '.' || (extract(epoch from now())::bigint + p_days * 86400)::text as b) t
$$;

create or replace function private.support_check(p_token text) returns uuid
language plpgsql stable security definer set search_path = private, public as $$
declare parts text[] := string_to_array(coalesce(p_token, ''), '.');
begin
  if coalesce(array_length(parts, 1), 0) <> 3 or parts[1] !~ '^[0-9a-f-]{36}$' or parts[2] !~ '^\d{9,11}$' then return null; end if;
  if private.vetting_sig('support.' || parts[1] || '.' || parts[2]) <> parts[3] then return null; end if;
  if parts[2]::bigint < extract(epoch from now()) then return null; end if;
  return parts[1]::uuid;
end $$;

create or replace function support_open(p_token text) returns jsonb
language sql stable security definer set search_path = private, public as $$
  select support_context(id) from (select private.support_check(p_token) as id) t where id is not null
$$;

-- Keith sent the reply (or closed it). Once only.
create or replace function support_done(p_token text, p_status text, p_reply text, p_error text) returns jsonb
language plpgsql security definer set search_path = private, public as $$
declare rid uuid := private.support_check(p_token); s private.support_items;
begin
  if rid is null then return jsonb_build_object('error', 'link_expired'); end if;
  select * into s from private.support_items where id = rid for update;
  if s.status in ('sent', 'closed') then return jsonb_build_object('error', 'already_done', 'status', s.status); end if;
  if p_error is not null then
    update private.support_items set reply_error = left(p_error, 500) where id = rid;
    return jsonb_build_object('error', 'send_failed');
  end if;
  update private.support_items set status = p_status, reply = left(p_reply, 8000), replied_at = now(), reply_error = null where id = rid;
  if s.report_id is not null then update public.reports set handled_at = coalesce(handled_at, now()) where id = s.report_id; end if;
  return jsonb_build_object('ok', true, 'status', p_status);
end $$;

-- Calls the support function: check anything new now.
create or replace function private.call_support() returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/support',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000)
$$;

-- For support-inbound: look at the new email now rather than on the next tick.
create or replace function support_kick() returns bigint
language sql security definer set search_path = private, public as $$ select private.call_support() $$;

-- In-app reports join the same queue, and go to the agent straight away.
create or replace function private.support_from_report() returns trigger
language plpgsql security definer set search_path = private, public as $$
begin
  insert into private.support_items (source, profile_id, report_id, subject, body, booking_ref)
  values ('report', new.reporter_id, new.id, 'Report: ' || replace(new.reason, '_', ' '), new.detail,
          (select reference from bookings where id = new.booking_id));
  perform private.call_support();
  return null;
end $$;
drop trigger if exists reports_to_support on public.reports;
create trigger reports_to_support after insert on public.reports for each row execute function private.support_from_report();

revoke execute on function check_mail_secret(text) from public, anon, authenticated;
revoke execute on function support_receive(jsonb) from public, anon, authenticated;
revoke execute on function support_context(uuid) from public, anon, authenticated;
revoke execute on function support_new() from public, anon, authenticated;
revoke execute on function support_save(uuid, jsonb) from public, anon, authenticated;
revoke execute on function support_token(uuid, int) from public, anon, authenticated;
revoke execute on function support_open(text) from public, anon, authenticated;
revoke execute on function support_done(text, text, text, text) from public, anon, authenticated;
revoke execute on function support_kick() from public, anon, authenticated;
revoke execute on function private.support_check(text) from public;
revoke execute on function private.call_support() from public;
revoke execute on function private.support_from_report() from public;
grant execute on function check_mail_secret(text) to service_role;
grant execute on function support_receive(jsonb) to service_role;
grant execute on function support_context(uuid) to service_role;
grant execute on function support_new() to service_role;
grant execute on function support_save(uuid, jsonb) to service_role;
grant execute on function support_token(uuid, int) to service_role;
grant execute on function support_open(text) to service_role;
grant execute on function support_done(text, text, text, text) to service_role;
grant execute on function support_kick() to service_role;

-- Every 5 minutes: the backstop for anything the instant calls missed.
select cron.schedule('hairdone-support', '*/5 * * * *', $$select private.call_support()$$);
