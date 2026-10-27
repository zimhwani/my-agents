-- Hair Done: the watchdog. Once a morning it emails Keith what needs him; once an hour it emails only
-- if something new has gone red (money stuck, a timer failing, a report). It never changes the app's data:
--   - watchdog_snapshot() is STABLE, so Postgres refuses any insert, update or delete inside it.
--   - The only thing it writes is its own log, private.watchdog_runs, through watchdog_record().
-- The rules that turn this snapshot into findings are in functions/watchdog/assess.ts.

create table if not exists private.watchdog_runs (
  id        bigint generated always as identity primary key,
  ran_at    timestamptz not null default now(),
  mode      text not null,                    -- 'digest' (morning) or 'alert' (hourly)
  level     text not null,                    -- worst finding: red, amber or clear
  findings  jsonb not null,
  alerted   text[] not null default '{}',     -- red finding keys this run emailed
  email     text                              -- 'sent', 'skipped', 'not_configured' or the error
);

create or replace function watchdog_snapshot() returns jsonb
language sql stable security definer set search_path = public, private, extensions as $$
with bk as (
  select b.*, coalesce(p.is_sample, false) as sample
  from bookings b left join pros p on p.id = b.pro_id
),
real_pros as (select * from pros where not is_sample)
select jsonb_build_object(
  'now', now(),

  -- Money the settle function couldn't move.
  'settle_errors', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'status', status, 'hold', hold_state,
      'error', left(settle_error, 200), 'since', updated_at, 'sample', sample) order by updated_at), '[]')
    from bk where settle_error is not null),
  -- Live bookings whose card didn't go through.
  'card_failed', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'status', status,
      'starts', starts_at, 'sample', sample) order by starts_at), '[]')
    from bk where hold_state = 'failed' and status in ('requested', 'confirmed')),
  -- Done with the card still held more than 13 h later (auto-capture is due at 12 h).
  'capture_late', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'done_at', done_at, 'sample', sample)), '[]')
    from bk where status = 'done' and hold_state = 'held' and done_at < now() - interval '13 hours'
      and (capture_paused_until is null or capture_paused_until < now() - interval '1 hour')),
  -- A cancellation or no-show charge still not taken an hour on.
  'charge_late', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'status', status,
      'cents', cancellation_charge_cents, 'since', updated_at, 'sample', sample)), '[]')
    from bk where status in ('cancelledByClient', 'noShow') and cancellation_charge_cents > 0
      and hold_state in ('held', 'saved') and updated_at < now() - interval '1 hour'
      and (capture_paused_until is null or capture_paused_until < now() - interval '1 hour')),
  -- A client's money still held an hour after it should have been let go.
  'release_late', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'status', status,
      'hold', hold_state, 'since', updated_at, 'sample', sample)), '[]')
    from bk where hold_state in ('held', 'saved', 'failed') and updated_at < now() - interval '1 hour'
      and (status in ('declined', 'cancelledByPro') or (status = 'cancelledByClient' and cancellation_charge_cents = 0))),
  -- Inside the 6-day window for over an hour and the hold still isn't placed.
  'hold_late', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'starts', starts_at, 'sample', sample)), '[]')
    from bk where status in ('requested', 'confirmed') and hold_state = 'saved'
      and starts_at < now() + interval '6 days' - interval '1 hour'),
  -- The sweep should have lapsed or declined these by now.
  'sweep_late', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'status', status,
      'created', created_at, 'ends', ends_at, 'sample', sample)), '[]')
    from bk where (status = 'requested' and hold_state = 'none' and created_at < now() - interval '50 minutes')
       or (status = 'requested' and hold_state <> 'none' and created_at < now() - interval '2 hours 20 minutes')
       or (status = 'inProgress' and ends_at < now() - interval '12 hours 20 minutes')),

  -- Requests a pro hasn't answered yet (they decline themselves at 2 h).
  'waiting_reply', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'created', created_at,
      'starts', starts_at, 'sample', sample) order by created_at), '[]')
    from bk where status = 'requested' and hold_state <> 'none'),
  -- Confirmed, the start was 3 h ago, and nothing has happened since.
  'start_passed', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'starts', starts_at, 'sample', sample)
      order by starts_at), '[]')
    from bk where status = 'confirmed' and starts_at < now() - interval '3 hours'),
  -- Clients who pressed "Something wrong?": their charge is paused.
  'capture_paused', (select coalesce(jsonb_agg(jsonb_build_object('ref', reference, 'until', capture_paused_until,
      'sample', sample)), '[]')
    from bk where status in ('done', 'noShow') and capture_paused_until > now()),
  'today', (select jsonb_build_object(
      'starting_next_36h', count(*) filter (where status = 'confirmed' and starts_at between now() and now() + interval '36 hours'),
      'live_now', count(*) filter (where status in ('onHerWay', 'arrived', 'inProgress')))
    from bk where not sample),

  -- Trust and safety.
  'reports_open', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'reason', r.reason,
      'detail', left(r.detail, 400), 'created', r.created_at, 'ref', b.reference) order by r.created_at), '[]')
    from reports r left join bookings b on b.id = r.booking_id where r.handled_at is null),
  'low_reviews', (select coalesce(jsonb_agg(jsonb_build_object('rating', v.rating, 'service', v.service_name,
      'text', left(v.text, 300), 'created', v.created_at, 'ref', b.reference,
      'pro', pf.first_name || ' ' || coalesce(p.last_initial, ''), 'sample', coalesce(p.is_sample, false))
      order by v.created_at), '[]')
    from reviews v left join bookings b on b.id = v.booking_id left join pros p on p.id = v.pro_id
    left join profiles pf on pf.id = v.pro_id
    where v.rating <= 3 and v.created_at > now() - interval '7 days'),

  -- Supply: the pros the business runs on.
  'id_waiting', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id,
      'name', pf.first_name || ' ' || coalesce(p.last_initial, ''), 'specialties', p.specialties, 'suburb', p.suburb,
      'submitted', p.id_submitted_at, 'abn', p.abn is not null and p.abn <> '', 'insurance', p.insurance_on_file,
      'payouts', p.payouts_connected) order by p.id_submitted_at), '[]')
    from real_pros p left join profiles pf on pf.id = p.id
    where p.id_submitted_at is not null and not p.is_verified and p.closed_at is null),
  'payouts_stuck', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id,
      'name', pf.first_name || ' ' || coalesce(p.last_initial, ''), 'since', p.updated_at)), '[]')
    from real_pros p left join profiles pf on pf.id = p.id
    where p.stripe_account_id is not null and not p.payouts_connected and p.closed_at is null
      and p.updated_at < now() - interval '3 days'),
  'payouts_failed', (select coalesce(jsonb_agg(jsonb_build_object('pro', pf.first_name, 'cents', po.amount_cents,
      'created', po.created_at)), '[]')
    from payouts po left join profiles pf on pf.id = po.pro_id
    where po.status = 'failed' and po.created_at > now() - interval '30 days'),
  'supply', (select jsonb_build_object(
      'real_pros', count(*),
      'bookable', count(*) filter (where is_verified and is_active and payouts_connected and closed_at is null),
      'sample_pros_live', (select count(*) from pros where is_sample and is_active))
    from real_pros),

  -- The last 24 hours, real people only (sample pros' bookings left out).
  'day', jsonb_build_object(
    'new_people', (select count(*) from profiles where created_at > now() - interval '24 hours'),
    'new_pros', (select count(*) from real_pros where created_at > now() - interval '24 hours'),
    'bookings_made', (select count(*) from bk where not sample and created_at > now() - interval '24 hours'),
    'paid', (select count(*) from booking_events e join bk on bk.id = e.booking_id
             where not bk.sample and e.status = 'paid' and e.at > now() - interval '24 hours')),
  'week_paid_cents', (select coalesce(sum(services_cents + travel_fee_cents + booking_fee_cents - discount_cents + tip_cents), 0)
    from bk where not sample and status = 'paid' and captured_at > now() - interval '7 days'),

  -- The machinery.
  'cron', (select coalesce(jsonb_agg(jsonb_build_object('name', j.jobname, 'schedule', j.schedule, 'active', j.active,
      'last_run', (select max(d.start_time) from cron.job_run_details d where d.jobid = j.jobid),
      'failed_24h', (select count(*) from cron.job_run_details d where d.jobid = j.jobid
                     and d.status <> 'succeeded' and d.start_time > now() - interval '24 hours'),
      'last_error', (select left(d.return_message, 200) from cron.job_run_details d where d.jobid = j.jobid
                     and d.status <> 'succeeded' order by d.start_time desc limit 1)) order by j.jobname), '[]')
    from cron.job j),
  -- What the functions the timers call answered (pg_net keeps about six hours). A cron run "succeeds"
  -- as soon as the request is queued, so this is where a failing function shows up.
  'http_failures', (select coalesce(jsonb_agg(jsonb_build_object('code', status_code, 'timed_out', timed_out,
      'error', err, 'body', body, 'n', n, 'last', last)), '[]')
    from (select status_code, timed_out, left(error_msg, 160) err, left(content, 160) body, count(*) n, max(created) last
          from net._http_response
          where created > now() - interval '24 hours'
            and (timed_out or error_msg is not null or status_code is null or status_code not between 200 and 299)
          group by 1, 2, 3, 4) f),
  'http_ok_24h', (select count(*) from net._http_response where created > now() - interval '24 hours'
                  and status_code between 200 and 299),
  'rls_off', (select coalesce(jsonb_agg(c.relname order by c.relname), '[]')
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
      and c.relname <> 'spatial_ref_sys'),  -- PostGIS's own table, read-only reference data
  'flags', (select coalesce(jsonb_object_agg(key, value), '{}') from private.app_flags),
  'last_runs', (select coalesce(jsonb_agg(jsonb_build_object('mode', mode, 'ran_at', ran_at, 'email', email)
      order by ran_at desc), '[]')
    from (select * from private.watchdog_runs order by ran_at desc limit 3) r)
)
$$;

-- Red keys already emailed in the last day, so the hourly alert only speaks up about something new.
create or replace function watchdog_recent_alerts(hours int default 24) returns text[]
language sql stable security definer set search_path = private, public as $$
  select coalesce(array_agg(distinct k), '{}') from private.watchdog_runs r, unnest(r.alerted) k
  where r.ran_at > now() - make_interval(hours => hours)
$$;

create or replace function watchdog_record(p_mode text, p_level text, p_findings jsonb, p_alerted text[], p_email text)
returns void language sql security definer set search_path = private, public as $$
  insert into private.watchdog_runs (mode, level, findings, alerted, email)
  values (p_mode, p_level, p_findings, coalesce(p_alerted, '{}'), p_email);
  delete from private.watchdog_runs where ran_at < now() - interval '90 days';
$$;

revoke execute on function watchdog_snapshot() from public, anon, authenticated;
revoke execute on function watchdog_recent_alerts(int) from public, anon, authenticated;
revoke execute on function watchdog_record(text, text, jsonb, text[], text) from public, anon, authenticated;
grant execute on function watchdog_snapshot() to service_role;
grant execute on function watchdog_recent_alerts(int) to service_role;
grant execute on function watchdog_record(text, text, jsonb, text[], text) to service_role;

create or replace function private.call_watchdog(p_mode text) returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/watchdog',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := jsonb_build_object('mode', p_mode),
    timeout_milliseconds := 60000)
$$;
revoke execute on function private.call_watchdog(text) from public;

-- Morning digest at 20:30 UTC: 7:30 am in Melbourne in daylight saving, 6:30 am the rest of the year.
-- Hourly alert at seven past, every hour; it only emails when a red finding is new.
select cron.schedule('hairdone-watchdog-digest', '30 20 * * *', $$select private.call_watchdog('digest')$$);
select cron.schedule('hairdone-watchdog-alert', '7 * * * *', $$select private.call_watchdog('alert')$$);
