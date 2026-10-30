-- Hair Done: the ATO platform report's half, as finance/assess.ts nextReport() has it. Until a due date
-- passes, the half before it is the one to report: in January, last July to December; in July, January
-- to June. 0025 counted the calendar half you're in, which in January and July is the wrong one.
create or replace function private.report_half(p_now timestamptz default now()) returns table (h_start timestamp, h_end timestamp)
language sql stable set search_path = pg_catalog as $$
  with t as (select (p_now at time zone 'Australia/Melbourne') as l)
  select case when extract(month from l) = 1 then date_trunc('year', l) - interval '6 months'
              when extract(month from l) <= 7 then date_trunc('year', l)
              else date_trunc('year', l) + interval '6 months' end,
         case when extract(month from l) = 1 then date_trunc('year', l)
              when extract(month from l) <= 7 then date_trunc('year', l) + interval '6 months'
              else date_trunc('year', l) + interval '1 year' end
  from t
$$;
revoke execute on function private.report_half(timestamptz) from public;

-- finance_snapshot's 'half' now uses it.
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
  -- Pros paid in the half the next ATO platform report covers (private.report_half), Melbourne time.
  'half', (with h as (select h_start as start, h_end as finish from private.report_half(now()))
           select jsonb_build_object('start', (select start from h), 'end', (select finish from h),
             'pros', (select count(distinct b.pro_id) from bk b, h where not b.sample and b.hold_state = 'captured'
                      and (b.captured_at at time zone 'Australia/Melbourne') >= h.start and (b.captured_at at time zone 'Australia/Melbourne') < h.finish),
             'pros_without_abn', (select count(distinct b.pro_id) from bk b join pros p on p.id = b.pro_id, h
                      where not b.sample and b.hold_state = 'captured'
                        and (b.captured_at at time zone 'Australia/Melbourne') >= h.start and (b.captured_at at time zone 'Australia/Melbourne') < h.finish
                        and (p.abn is null or trim(p.abn) = '')),
             'paid_to_pros_cents', (select coalesce(sum(case
                      when status in ('cancelledByClient', 'noShow') then cancellation_charge_cents - round(cancellation_charge_cents * 0.12)
                      else services_cents + travel_fee_cents - round((services_cents + travel_fee_cents) * 0.12) + tip_cents end), 0)
                      from bk b, h where not b.sample and b.hold_state = 'captured' and b.pro_account is not null
                        and (b.captured_at at time zone 'Australia/Melbourne') >= h.start and (b.captured_at at time zone 'Australia/Melbourne') < h.finish))),
  'payouts', (select coalesce(jsonb_agg(jsonb_build_object('pro', pf.first_name, 'cents', po.amount_cents, 'status', po.status,
      'created', po.created_at)), '[]')
    from payouts po left join profiles pf on pf.id = po.pro_id where po.created_at >= p_from and po.created_at < p_to)
)
$$;

