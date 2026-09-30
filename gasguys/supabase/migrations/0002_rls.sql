-- Row-level security. Default deny; each table opens exactly what a role needs. Money and meter
-- state are only ever written by edge functions using the service role, never by the browser.

alter table customers      enable row level security;
alter table meters         enable row level security;
alter table payments       enable row level security;
alter table refill_orders  enable row level security;
alter table alerts         enable row level security;
alter table bot_sessions   enable row level security;
alter table settings       enable row level security;
alter table staff          enable row level security;
alter table private.meter_keys enable row level security; -- and no policies: service role only
revoke all on schema private from anon, authenticated;

create or replace function me() returns uuid language sql stable security definer set search_path = public as $$
  select id from customers where auth_user = auth.uid()
$$;

create or replace function is_staff() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff where user_id = auth.uid())
$$;

-- Customers: read and rename yourself. Phone is fixed (it's the login).
create policy customers_self_read  on customers for select using (auth_user = auth.uid() or is_staff());
create policy customers_self_write on customers for update using (auth_user = auth.uid()) with check (auth_user = auth.uid());

-- Meters: owners read their own; linking and credit go through functions.
create policy meters_owner_read on meters for select using (customer_id = me() or is_staff());

-- Payments: what you paid for, and what was paid onto your meters (gifts in).
create policy payments_read on payments for select using (
  customer_id = me() or meter_id in (select id from meters where customer_id = me()) or is_staff()
);

create policy refills_read on refill_orders for select using (
  meter_id in (select id from meters where customer_id = me()) or is_staff()
);
create policy refills_staff_write on refill_orders for update using (is_staff()) with check (is_staff());

create policy alerts_read on alerts for select using (
  meter_id in (select id from meters where customer_id = me()) or is_staff()
);

create policy settings_read on settings for select using (true);
create policy staff_self_read on staff for select using (user_id = auth.uid());
-- bot_sessions: no policies; only the WhatsApp webhook (service role) touches them.

-- Realtime: the app's gauge updates live when telemetry lands.
alter publication supabase_realtime add table meters, payments;
