-- Hair Done: the finance agent. Every Monday morning it checks that what Stripe says happened to the money
-- matches what the bookings say should have: the amount charged, Hair Done's fee (12% plus the $3 booking
-- fee), the transfer to the pro, tips, refunds and disputes. It also tracks Hair Done's own fees over the
-- last 12 months against the GST threshold, and the ATO's twice-yearly platform reporting.
-- Read-only: finance_snapshot() is STABLE, so Postgres refuses writes inside it, and Stripe only gets GETs.
-- The rules are in functions/finance/assess.ts.

create table if not exists private.finance_runs (
  id        bigint generated always as identity primary key,
  ran_at    timestamptz not null default now(),
  week_from timestamptz not null,
  week_to   timestamptz not null,
  level     text not null,          -- red, amber or clear
  report    jsonb not null,
  email     text
);

create or replace function finance_snapshot(p_from timestamptz, p_to timestamptz) returns jsonb
language sql stable security definer set search_path = public, private, extensions as $$
with bk as (
  select b.*, coalesce(p.is_sample, false) as sample, p.stripe_account_id as pro_account
  from bookings b left join pros p on p.id = b.pro_id
),
-- What Hair Done's fee should be on a charge, mirroring applicationFee() in _shared/stripe.ts.
fees as (
  select bk.*, case
    when status in ('cancelledByClient', 'noShow') then cancellation_charge_cents
    else services_cents + travel_fee_cents + booking_fee_cents - discount_cents end as charged_cents
  from bk
)
select jsonb_build_object(
  'from', p_from, 'to', p_to, 'now', now(),
  -- Every booking money was taken for in the window.
  'charged', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'ref', reference, 'status', status, 'sample', sample, 'pro_account', pro_account,
      'services', services_cents, 'travel', travel_fee_cents, 'booking_fee', booking_fee_cents, 'discount', discount_cents,
      'tip', tip_cents, 'cancellation', cancellation_charge_cents, 'charged', charged_cents,
      'pi', stripe_payment_intent_id, 'tip_pi', stripe_tip_intent_id, 'captured_at', captured_at) order by captured_at), '[]')
    from fees where hold_state = 'captured' and captured_at >= p_from and captured_at < p_to),
  -- Every booking that has ever had a Stripe payment, to tell a payment with no booking from one that has.
  'known', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'ref', reference, 'pi', stripe_payment_intent_id,
      'tip_pi', stripe_tip_intent_id, 'cancellation', cancellation_charge_cents)), '[]')
    from bk where stripe_payment_intent_id is not null or stripe_tip_intent_id is not null or cancellation_charge_cents > 0),
  -- Hair Done's own fees on real bookings over the last 12 months, for the GST threshold.
  'fees_12m', (select coalesce(sum(case
      when pro_account is null then 0
      when status in ('cancelledByClient', 'noShow') then round(cancellation_charge_cents * 0.12)
      else round((services_cents + travel_fee_cents) * 0.12) + booking_fee_cents - discount_cents end), 0)
    from bk where not sample and hold_state = 'captured' and captured_at > now() - interval '12 months'),
  'gross_12m', (select coalesce(sum(services_cents + travel_fee_cents + booking_fee_cents - discount_cents + tip_cents), 0)
    from bk where not sample and status = 'paid' and captured_at > now() - interval '12 months'),
  -- Pros paid in this reporting half (Jan to Jun, or Jul to Dec, Melbourne time), for the ATO report.
  'half', (with h as (select date_trunc('year', (now() at time zone 'Australia/Melbourne'))
                            + case when extract(month from (now() at time zone 'Australia/Melbourne')) >= 7 then interval '6 months' else interval '0' end as start)
           select jsonb_build_object('start', (select start from h),
             'pros', (select count(distinct b.pro_id) from bk b where not b.sample and b.hold_state = 'captured'
                      and (b.captured_at at time zone 'Australia/Melbourne') >= (select start from h)),
             'pros_without_abn', (select count(distinct b.pro_id) from bk b join pros p on p.id = b.pro_id
                      where not b.sample and b.hold_state = 'captured' and (b.captured_at at time zone 'Australia/Melbourne') >= (select start from h)
                        and (p.abn is null or trim(p.abn) = '')),
             'paid_to_pros_cents', (select coalesce(sum(case
                      when status in ('cancelledByClient', 'noShow') then cancellation_charge_cents - round(cancellation_charge_cents * 0.12)
                      else services_cents + travel_fee_cents - round((services_cents + travel_fee_cents) * 0.12) + tip_cents end), 0)
                      from bk b where not b.sample and b.hold_state = 'captured' and b.pro_account is not null
                        and (b.captured_at at time zone 'Australia/Melbourne') >= (select start from h)))),
  'payouts', (select coalesce(jsonb_agg(jsonb_build_object('pro', pf.first_name, 'cents', po.amount_cents, 'status', po.status,
      'created', po.created_at)), '[]')
    from payouts po left join profiles pf on pf.id = po.pro_id where po.created_at >= p_from and po.created_at < p_to)
)
$$;

create or replace function finance_record(p_from timestamptz, p_to timestamptz, p_level text, p_report jsonb, p_email text)
returns void language sql security definer set search_path = private, public as $$
  insert into private.finance_runs (week_from, week_to, level, report, email) values (p_from, p_to, p_level, p_report, p_email);
$$;

revoke execute on function finance_snapshot(timestamptz, timestamptz) from public, anon, authenticated;
revoke execute on function finance_record(timestamptz, timestamptz, text, jsonb, text) from public, anon, authenticated;
grant execute on function finance_snapshot(timestamptz, timestamptz) to service_role;
grant execute on function finance_record(timestamptz, timestamptz, text, jsonb, text) to service_role;

create or replace function private.call_finance() returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/finance',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000)
$$;
revoke execute on function private.call_finance() from public;

-- Monday 7 am in Melbourne in daylight saving (6 am the rest of the year): Sunday 20:00 UTC.
select cron.schedule('hairdone-finance', '0 20 * * 0', $$select private.call_finance()$$);
