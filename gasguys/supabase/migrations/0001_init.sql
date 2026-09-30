-- Gasguys core schema. Mirrors core/types.ts; the edge functions map rows to those types in
-- functions/_shared/store.ts.

create extension if not exists pgcrypto;

create table customers (
  id          uuid primary key default gen_random_uuid(),
  auth_user   uuid unique references auth.users(id) on delete set null, -- set when they sign in on the web
  phone       text not null unique check (phone ~ '^2637[1378][0-9]{7}$'),
  name        text not null default '',
  lang        text not null default 'en' check (lang in ('en', 'sn', 'nd')),
  created_at  timestamptz not null default now()
);

create table meters (
  id               text primary key check (id ~ '^[0-9]{11}$'),
  customer_id      uuid references customers(id) on delete set null,
  suburb           text not null default '',
  cylinder_kg      int  not null default 9 check (cylinder_kg in (9, 14, 19, 48)),
  gas_grams        int  not null default 0,
  credit_grams     int  not null default 0,
  valve            text not null default 'closed' check (valve in ('open', 'closed')),
  online           boolean not null default false,
  battery_pct      int  not null default 100,
  leak             boolean not null default false,
  tamper           boolean not null default false,
  token_counter    int  not null default 0, -- highest counter the backend has issued
  avg_daily_grams  int  not null default 180,
  last_seen        timestamptz not null default now(),
  installed_at     timestamptz
);
create index meters_customer on meters(customer_id);

-- Per-valve secrets live outside the API-exposed schema; only the service role reads them.
create schema if not exists private;
create table private.meter_keys (
  meter_id  text primary key references public.meters(id) on delete cascade,
  key_hex   text not null check (key_hex ~ '^[0-9a-f]{64}$')
);

create table payments (
  id            uuid primary key default gen_random_uuid(),
  reference     text not null unique,
  customer_id   uuid references customers(id) on delete set null,
  payer_phone   text not null,
  payer_name    text not null default '',
  meter_id      text not null references meters(id),
  method        text not null check (method in ('ecocash', 'innbucks', 'card')),
  currency      text not null check (currency in ('USD', 'ZWG')),
  amount        numeric(12, 2) not null check (amount > 0),
  amount_usd    numeric(12, 2) not null,
  grams         int not null check (grams >= 0),
  status        text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'expired')),
  provider_ref  text,
  poll_url      text,
  gift          boolean not null default false,
  gift_message  text,
  token         text,     -- 12-digit offline token; also sent to the customer
  delivery      text check (delivery in ('online', 'token')),
  channel       text not null check (channel in ('web', 'whatsapp')),
  created_at    timestamptz not null default now(),
  settled_at    timestamptz
);
create index payments_customer on payments(customer_id, created_at desc);
create index payments_meter on payments(meter_id, created_at desc);
create index payments_pending on payments(status) where status = 'pending';

create table refill_orders (
  id          uuid primary key default gen_random_uuid(),
  meter_id    text not null references meters(id),
  status      text not null default 'requested' check (status in ('requested', 'scheduled', 'out_for_delivery', 'delivered', 'cancelled')),
  slot        text not null default '',
  auto        boolean not null default false,
  created_at  timestamptz not null default now()
);
create unique index refill_one_open on refill_orders(meter_id) where status in ('requested', 'scheduled', 'out_for_delivery');

create table alerts (
  id        uuid primary key default gen_random_uuid(),
  meter_id  text not null references meters(id),
  kind      text not null check (kind in ('leak', 'low_gas', 'low_credit', 'tamper', 'offline', 'low_battery')),
  at        timestamptz not null default now(),
  resolved  boolean not null default false
);
create index alerts_open on alerts(meter_id) where not resolved;

create table bot_sessions (
  phone       text primary key,
  state       jsonb not null,
  updated_at  timestamptz not null default now()
);

-- Tariff and exchange rate, changed by ops rather than by deploys.
create table settings (
  key    text primary key,
  value  jsonb not null
);
insert into settings(key, value) values
  ('tariff', '{"usdPerKg": 1.85, "zwgPerUsd": 26.5, "minUsd": 0.5, "maxUsd": 200}');

-- Staff (ops console, technicians). Customers never appear here.
create table staff (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  role     text not null check (role in ('admin', 'ops', 'technician'))
);
