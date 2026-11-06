-- Hair Done: the pro pipeline. Every Monday morning the pipeline function looks for mobile pros in Melbourne on
-- ABN Lookup (registered business names like "mobile nails" or "bridal makeup"), adds the best new ones, notices
-- who has since joined Hair Done or been ID checked, and emails Keith what's due: pros to message, follow-ups,
-- and referrals to ask for. The page on hairdonenailsdone.app/pipeline/ shows each one with a drafted message.
--   - It never sends anything to a prospect. Keith copies the message and sends it from his own account.
--   - ABN Lookup gives a business name, ABN and postcode, never contact details. Keith adds Instagram or email.
--   - The pipeline link is signed (same key as vetting links, its own prefix) and lasts 8 days: a new one comes
--     with each Monday email.
--   - Closed prospects (declined, not a fit, gone quiet) are deleted a year after they close.
-- The rules and the message drafts are in functions/pipeline/assess.ts.

create table if not exists private.prospects (
  id                uuid primary key default gen_random_uuid(),
  source            text not null check (source in ('abn', 'keith', 'referral')),
  status            text not null default 'new'
                    check (status in ('new', 'messaged', 'followed_up', 'replied', 'signed_up', 'verified', 'quiet', 'declined', 'not_a_fit')),
  name              text not null,
  first_name        text,
  abn               text unique,                 -- digits only
  email             text,
  instagram         text,
  postcode          text,
  suburb            text,
  categories        text[] not null default '{}',
  mobile            boolean not null default false,
  score             int not null default 0,
  note              text,                        -- Keith's: what caught his eye, how the chat went
  referred_by       uuid references public.pros (id) on delete set null,
  pro_id            uuid references public.pros (id) on delete set null,
  messaged_at       timestamptz,
  followed_up_at    timestamptz,
  replied_at        timestamptz,
  referral_asked_at timestamptz,
  closed_at         timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table if not exists private.pipeline_runs (
  id      bigint generated always as identity primary key,
  ran_at  timestamptz not null default now(),
  summary jsonb not null,
  email   text
);

-- Everything the function and the page need: every prospect, and the real pros to match them against.
create or replace function pipeline_snapshot() returns jsonb
language sql stable security definer set search_path = public, private as $$
  select jsonb_build_object(
    'prospects', (select coalesce(jsonb_agg(to_jsonb(x) order by x.score desc, x.created_at), '[]') from private.prospects x),
    'pros', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'abn', nullif(trim(p.abn), ''), 'is_verified', p.is_verified,
               'first_name', pf.first_name, 'email', coalesce(nullif(pc.email, ''), u.email))), '[]')
             from pros p left join profiles pf on pf.id = p.id left join profile_contacts pc on pc.profile_id = p.id
             left join auth.users u on u.id = p.id
             where not p.is_sample and p.closed_at is null))
$$;

-- New leads from ABN Lookup. An ABN already in the pipeline is left alone.
create or replace function pipeline_add_leads(p_leads jsonb) returns int
language sql security definer set search_path = private as $$
  with ins as (
    insert into private.prospects (source, name, abn, postcode, categories, mobile, score)
    select 'abn', l.name, l.abn, l.postcode, l.categories, coalesce(l.mobile, false), coalesce(l.score, 0)
    from jsonb_to_recordset(p_leads) as l(name text, abn text, postcode text, categories text[], mobile boolean, score int)
    on conflict (abn) do nothing
    returning 1)
  select count(*)::int from ins
$$;

-- One prospect, by hand from the page: someone Keith found on Instagram, or a pro's referral.
create or replace function pipeline_add(p jsonb) returns uuid
language sql security definer set search_path = private as $$
  insert into private.prospects (source, name, first_name, email, instagram, suburb, postcode, categories, note, referred_by, score, abn)
  values (case when p->>'referred_by' is not null then 'referral' else 'keith' end,
          left(trim(p->>'name'), 120), nullif(left(trim(p->>'first_name'), 60), ''), nullif(left(lower(trim(p->>'email')), 200), ''),
          nullif(left(trim(p->>'instagram'), 200), ''), nullif(left(trim(p->>'suburb'), 60), ''), nullif(left(trim(p->>'postcode'), 4), ''),
          coalesce((select array_agg(c) from jsonb_array_elements_text(p->'categories') c
                    where c in ('hair', 'nails', 'makeup', 'lashes', 'brows')), '{}'),
          nullif(left(trim(p->>'note'), 1000), ''), (p->>'referred_by')::uuid, coalesce((p->>'score')::int, 0),
          nullif(regexp_replace(coalesce(p->>'abn', ''), '\D', '', 'g'), ''))
  returning id
$$;

-- A change to one prospect: a new status (stamping when it happened) and/or Keith's edits to their details.
-- p_status 'referral_asked' only stamps referral_asked_at. Returns the prospect, or null if there's none.
create or replace function pipeline_change(p_id uuid, p_status text, p_fields jsonb default '{}', p_pro uuid default null)
returns jsonb language plpgsql security definer set search_path = private as $$
declare r private.prospects;
begin
  if p_status is not null and p_status not in ('new', 'messaged', 'followed_up', 'replied', 'signed_up', 'verified', 'quiet',
      'declined', 'not_a_fit', 'referral_asked') then
    raise exception 'bad status %', p_status;
  end if;
  update private.prospects set
    status = case when p_status is null or p_status = 'referral_asked' then status else p_status end,
    messaged_at = case when p_status = 'messaged' then coalesce(messaged_at, now()) else messaged_at end,
    followed_up_at = case when p_status = 'followed_up' then now() else followed_up_at end,
    replied_at = case when p_status = 'replied' then coalesce(replied_at, now()) else replied_at end,
    referral_asked_at = case when p_status = 'referral_asked' then now() else referral_asked_at end,
    closed_at = case when p_status in ('quiet', 'declined', 'not_a_fit') then now()
                     when p_status is not null and p_status <> 'referral_asked' then null else closed_at end,
    pro_id = coalesce(p_pro, pro_id),
    first_name = case when p_fields ? 'first_name' then nullif(left(trim(p_fields->>'first_name'), 60), '') else first_name end,
    email = case when p_fields ? 'email' then nullif(left(lower(trim(p_fields->>'email')), 200), '') else email end,
    instagram = case when p_fields ? 'instagram' then nullif(left(trim(p_fields->>'instagram'), 200), '') else instagram end,
    suburb = case when p_fields ? 'suburb' then nullif(left(trim(p_fields->>'suburb'), 60), '') else suburb end,
    note = case when p_fields ? 'note' then nullif(left(trim(p_fields->>'note'), 1000), '') else note end,
    updated_at = now()
  where id = p_id returning * into r;
  return case when r.id is null then null else to_jsonb(r) end;
end $$;

create or replace function pipeline_record(p_summary jsonb, p_email text) returns void
language sql security definer set search_path = private as $$
  insert into private.pipeline_runs (summary, email) values (p_summary, p_email);
  delete from private.prospects where closed_at < now() - interval '1 year';
$$;

-- The page link: board.<expiry>.<hmac>, signed apart from vetting and support links.
create or replace function pipeline_token(p_days int default 8) returns text
language sql stable security definer set search_path = private, public as $$
  select b || '.' || private.vetting_sig('pipeline.' || b)
  from (select 'board.' || (extract(epoch from now())::bigint + p_days * 86400)::text as b) t
$$;

create or replace function pipeline_check(p_token text) returns boolean
language plpgsql stable security definer set search_path = private, public as $$
declare parts text[] := string_to_array(coalesce(p_token, ''), '.');
begin
  if coalesce(array_length(parts, 1), 0) <> 3 or parts[1] <> 'board' or parts[2] !~ '^\d{9,11}$' then return false; end if;
  if private.vetting_sig('pipeline.' || parts[1] || '.' || parts[2]) <> parts[3] then return false; end if;
  return parts[2]::bigint >= extract(epoch from now());
end $$;

revoke execute on function pipeline_snapshot() from public, anon, authenticated;
revoke execute on function pipeline_add_leads(jsonb) from public, anon, authenticated;
revoke execute on function pipeline_add(jsonb) from public, anon, authenticated;
revoke execute on function pipeline_change(uuid, text, jsonb, uuid) from public, anon, authenticated;
revoke execute on function pipeline_record(jsonb, text) from public, anon, authenticated;
revoke execute on function pipeline_token(int) from public, anon, authenticated;
revoke execute on function pipeline_check(text) from public, anon, authenticated;
grant execute on function pipeline_snapshot() to service_role;
grant execute on function pipeline_add_leads(jsonb) to service_role;
grant execute on function pipeline_add(jsonb) to service_role;
grant execute on function pipeline_change(uuid, text, jsonb, uuid) to service_role;
grant execute on function pipeline_record(jsonb, text) to service_role;
grant execute on function pipeline_token(int) to service_role;
grant execute on function pipeline_check(text) to service_role;

create or replace function private.call_pipeline() returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/pipeline',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000)
$$;
revoke execute on function private.call_pipeline() from public;

-- Monday 8 am in Melbourne in daylight saving (7 am the rest of the year): Sunday 21:00 UTC, after finance.
select cron.schedule('hairdone-pipeline', '0 21 * * 0', $$select private.call_pipeline()$$);
