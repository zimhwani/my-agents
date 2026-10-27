-- Hair Done: pro vetting. When a pro sends their ID, the vetting function (every 15 min) checks what a
-- machine can (ABN against the government's ABN Lookup, both ID photos there, work photos not reused from
-- another pro, prices and travel area against everyone else's) and emails Keith a link to the review page
-- on hairdonenailsdone.app/review/. Keith looks at the ID and selfie himself and approves or sends it back.
--   - Nothing here looks at the ID photos except Keith: the privacy policy says they're never shown to
--     anyone outside the Hair Done team, and no AI service is on its list of processors.
--   - A review link is signed (HMAC, key in private.settings), lasts 72 hours and works once.
--   - Sent back: id_submitted_at is cleared, so the app shows the ID step again.

create table if not exists private.vetting_reviews (
  id            uuid primary key default gen_random_uuid(),
  pro_id        uuid not null references public.pros (id) on delete cascade,
  submitted_at  timestamptz not null,           -- the pros.id_submitted_at this review is about
  verdict       text not null,                  -- pass, look_closer, problem
  checks        jsonb not null,
  created_at    timestamptz not null default now(),
  email         text,                           -- what happened to the email to Keith
  decided_at    timestamptz,
  decision      text,                           -- approved, sent_back
  reason        text,
  unique (pro_id, submitted_at)
);

insert into private.settings (key, value) values ('vetting_key', encode(extensions.gen_random_bytes(32), 'hex'))
  on conflict (key) do nothing;

-- Everything the checks need about one pro, or every pro waiting with no review yet.
create or replace function vetting_queue(only_pro uuid default null) returns jsonb
language sql stable security definer set search_path = public, private, storage, extensions as $$
with waiting as (
  select p.* from pros p
  where (only_pro is not null and p.id = only_pro)
     or (only_pro is null and not p.is_sample and not p.is_verified and p.closed_at is null and p.id_submitted_at is not null
         and not exists (select 1 from private.vetting_reviews v where v.pro_id = p.id and v.submitted_at = p.id_submitted_at))
),
medians as (
  select s.category, percentile_cont(0.5) within group (order by s.price_cents) as median_cents, count(*) as n
  from services s join pros p on p.id = s.pro_id
  where s.is_active and p.is_active and p.closed_at is null
  group by s.category
)
select coalesce(jsonb_agg(jsonb_build_object(
  'id', p.id,
  'first_name', pf.first_name, 'last_name', pf.last_name, 'last_initial', p.last_initial,
  'email', coalesce(nullif(pc.email, ''), u.email),
  'specialties', p.specialties, 'suburb', p.suburb, 'abn', nullif(trim(p.abn), ''),
  'travel_radius_km', p.travel_radius_km, 'travel_fee_cents', p.travel_fee_cents,
  'joined', p.created_at, 'submitted', p.id_submitted_at, 'is_verified', p.is_verified,
  'id_docs', (select coalesce(jsonb_agg(jsonb_build_object('name', o.name, 'size', (o.metadata->>'size')::int,
                'type', o.metadata->>'mimetype', 'uploaded', o.updated_at)), '[]')
              from storage.objects o where o.bucket_id = 'id-docs' and (storage.foldername(o.name))[1] = p.id::text),
  'work', (select coalesce(jsonb_agg(jsonb_build_object('path', o.name, 'size', (o.metadata->>'size')::int,
              -- The same file (by its hash) in another person's folder: a photo that isn't theirs, or a second account.
              'also_in', (select count(distinct (storage.foldername(x.name))[1]) from storage.objects x
                          where x.bucket_id in ('work', 'avatars') and x.metadata->>'eTag' = o.metadata->>'eTag'
                            and (storage.foldername(x.name))[1] <> p.id::text),
              'copies', (select count(*) from storage.objects x where x.bucket_id = 'work'
                         and x.metadata->>'eTag' = o.metadata->>'eTag' and (storage.foldername(x.name))[1] = p.id::text))), '[]')
           from storage.objects o where o.bucket_id = 'work' and (storage.foldername(o.name))[1] = p.id::text),
  'services', (select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'category', s.category, 'price_cents', s.price_cents,
                 'minutes', s.minutes, 'median_cents', m.median_cents, 'median_of', m.n) order by s.sort_order), '[]')
               from services s left join medians m on m.category = s.category where s.pro_id = p.id and s.is_active)
)), '[]')
from waiting p
left join profiles pf on pf.id = p.id
left join profile_contacts pc on pc.profile_id = p.id
left join auth.users u on u.id = p.id
$$;

create or replace function vetting_save(p_pro uuid, p_submitted timestamptz, p_verdict text, p_checks jsonb)
returns uuid language sql security definer set search_path = private, public as $$
  insert into private.vetting_reviews (pro_id, submitted_at, verdict, checks) values (p_pro, p_submitted, p_verdict, p_checks)
  on conflict (pro_id, submitted_at) do update set verdict = excluded.verdict, checks = excluded.checks
  returning id
$$;

create or replace function vetting_emailed(p_review uuid, p_email text) returns void
language sql security definer set search_path = private, public as $$
  update private.vetting_reviews set email = p_email where id = p_review
$$;

-- Signed review links: <review id>.<expiry, unix seconds>.<hmac>
create or replace function private.vetting_sig(p_body text) returns text
language sql stable security definer set search_path = private, extensions as $$
  select encode(extensions.hmac(p_body, (select value from private.settings where key = 'vetting_key'), 'sha256'), 'hex')
$$;

create or replace function vetting_token(p_review uuid, p_hours int default 72) returns text
language sql stable security definer set search_path = private, public as $$
  select b || '.' || private.vetting_sig(b)
  from (select p_review::text || '.' || (extract(epoch from now())::bigint + p_hours * 3600)::text as b) t
$$;

-- The review a token is for, if the token is genuine and in date; null otherwise.
create or replace function private.vetting_check(p_token text) returns uuid
language plpgsql stable security definer set search_path = private, public as $$
declare parts text[] := string_to_array(coalesce(p_token, ''), '.');
begin
  if coalesce(array_length(parts, 1), 0) <> 3 or parts[1] !~ '^[0-9a-f-]{36}$' or parts[2] !~ '^\d{9,11}$' then return null; end if;
  if private.vetting_sig(parts[1] || '.' || parts[2]) <> parts[3] then return null; end if;
  if parts[2]::bigint < extract(epoch from now()) then return null; end if;
  return parts[1]::uuid;
end $$;

-- What the review page shows. Storage links are made by the review function, which calls this first.
create or replace function vetting_open(p_token text) returns jsonb
language sql stable security definer set search_path = private, public as $$
  select case when r.id is null then null else jsonb_build_object(
    'review', r.id, 'pro_id', r.pro_id, 'submitted_at', r.submitted_at, 'verdict', r.verdict, 'checks', r.checks,
    'decided_at', r.decided_at, 'decision', r.decision,
    -- She sent new photos since this review was written, or someone already decided: the link is spent.
    'stale', p.id_submitted_at is distinct from r.submitted_at or p.is_verified,
    'pro', (select q.value from jsonb_array_elements(vetting_queue(r.pro_id)) q limit 1)) end
  from (select private.vetting_check(p_token) as id) t
  left join private.vetting_reviews r on r.id = t.id
  left join pros p on p.id = r.pro_id
$$;

-- Keith's decision. Works once per review, and only while the photos are the ones the review was about.
create or replace function vetting_decide(p_token text, p_decision text, p_reason text, p_insurance boolean)
returns jsonb language plpgsql security definer set search_path = private, public as $$
declare rid uuid := private.vetting_check(p_token); r private.vetting_reviews; p pros;
begin
  if rid is null then return jsonb_build_object('error', 'link_expired'); end if;
  select * into r from private.vetting_reviews where id = rid for update;
  if r.decided_at is not null then return jsonb_build_object('error', 'already_decided', 'decision', r.decision); end if;
  select * into p from pros where id = r.pro_id for update;
  if p.id_submitted_at is distinct from r.submitted_at or p.is_verified then
    return jsonb_build_object('error', 'stale');
  end if;
  if p_decision = 'approved' then
    update pros set is_verified = true, id_checked_at = now(), insurance_on_file = coalesce(p_insurance, false) where id = p.id;
  elsif p_decision = 'sent_back' then
    update pros set id_submitted_at = null where id = p.id;
  else
    return jsonb_build_object('error', 'bad_decision');
  end if;
  update private.vetting_reviews set decided_at = now(), decision = p_decision, reason = left(p_reason, 500) where id = rid;
  return jsonb_build_object('ok', true, 'pro_id', p.id, 'decision', p_decision);
end $$;

revoke execute on function vetting_queue(uuid) from public, anon, authenticated;
revoke execute on function vetting_save(uuid, timestamptz, text, jsonb) from public, anon, authenticated;
revoke execute on function vetting_emailed(uuid, text) from public, anon, authenticated;
revoke execute on function vetting_token(uuid, int) from public, anon, authenticated;
revoke execute on function vetting_open(text) from public, anon, authenticated;
revoke execute on function vetting_decide(text, text, text, boolean) from public, anon, authenticated;
revoke execute on function private.vetting_sig(text) from public;
revoke execute on function private.vetting_check(text) from public;
grant execute on function vetting_queue(uuid) to service_role;
grant execute on function vetting_save(uuid, timestamptz, text, jsonb) to service_role;
grant execute on function vetting_emailed(uuid, text) to service_role;
grant execute on function vetting_token(uuid, int) to service_role;
grant execute on function vetting_open(text) to service_role;
grant execute on function vetting_decide(text, text, text, boolean) to service_role;

-- Calls the vetting function: everyone new waiting (null), or one pro again with a fresh link.
create or replace function private.call_vetting(p_pro uuid default null) returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/vetting',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := case when p_pro is null then '{}'::jsonb else jsonb_build_object('pro_id', p_pro) end,
    timeout_milliseconds := 60000)
$$;
revoke execute on function private.call_vetting(uuid) from public;

-- Every 15 minutes: anyone new waiting gets checked and Keith gets the email.
select cron.schedule('hairdone-vetting', '*/15 * * * *', $$select private.call_vetting()$$);
