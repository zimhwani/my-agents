-- Hair Done: schema v1.
-- Money is integer cents in AUD. Times are timestamptz. Ids are uuid.
-- See docs/product-spec.md for the booking state machine this enforces.

create extension if not exists "pgcrypto";
create extension if not exists "postgis";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type category as enum ('hair', 'nails', 'makeup', 'lashes', 'brows', 'theLot');

create type booking_status as enum (
  'requested', 'confirmed', 'onHerWay', 'arrived', 'inProgress', 'done', 'paid',
  'cancelledByClient', 'cancelledByPro', 'declined', 'noShow'
);

create type payout_status as enum ('pending', 'paid', 'failed');

-- ---------------------------------------------------------------------------
-- Profiles: one row per auth user. Everyone is a client; some are also pros.
-- ---------------------------------------------------------------------------
create table profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  first_name    text not null,
  last_name     text not null default '',
  phone         text,
  email         text,
  avatar_url    text,
  seed          int  not null default floor(random() * 1000)::int,
  notifications_on boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table addresses (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references profiles (id) on delete cascade,
  label         text not null default 'Home',
  line1         text not null,
  suburb        text not null,
  state         text not null default 'VIC',
  postcode      text not null,
  location      geography(point, 4326) not null,
  instructions  text not null default '',
  created_at    timestamptz not null default now()
);
create index addresses_profile_idx on addresses (profile_id);

-- Card details never touch our database. We keep Stripe's ids only.
create table payment_methods (
  id                    uuid primary key default gen_random_uuid(),
  profile_id            uuid not null references profiles (id) on delete cascade,
  stripe_customer_id    text not null,
  stripe_pm_id          text not null,
  brand                 text not null,
  last4                 text not null,
  expiry                text not null,
  is_default            boolean not null default false,
  created_at            timestamptz not null default now(),
  unique (profile_id, stripe_pm_id)
);

-- ---------------------------------------------------------------------------
-- Pros
-- ---------------------------------------------------------------------------
create table pros (
  id                    uuid primary key references profiles (id) on delete cascade,
  last_initial          text not null,
  specialties           category[] not null check (cardinality(specialties) > 0),
  headline              text not null default '',
  bio                   text not null default '',
  suburb                text not null,
  location              geography(point, 4326) not null,
  travel_radius_km      numeric(5,1) not null default 8 check (travel_radius_km between 1 and 50),
  travel_fee_cents      int not null default 0 check (travel_fee_cents >= 0),
  instant_book          boolean not null default false,
  years_experience      int not null default 0,
  response_minutes      int not null default 60,
  is_verified           boolean not null default false,
  id_checked_at         timestamptz,
  abn                   text,
  insurance_on_file     boolean not null default false,
  is_active             boolean not null default true,
  buffer_minutes        int not null default 30,
  step_minutes          int not null default 30,
  stripe_account_id     text,
  payouts_connected     boolean not null default false,
  -- Denormalised, refreshed by trigger on reviews and bookings.
  rating                numeric(3,2) not null default 0,
  review_count          int not null default 0,
  completed_bookings    int not null default 0,
  reliability_score     numeric(3,2) not null default 1.00,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index pros_location_idx on pros using gist (location);
create index pros_specialties_idx on pros using gin (specialties);

create table services (
  id            uuid primary key default gen_random_uuid(),
  pro_id        uuid not null references pros (id) on delete cascade,
  name          text not null,
  category      category not null,
  price_cents   int not null check (price_cents > 0),
  minutes       int not null check (minutes between 10 and 600),
  detail        text not null default '',
  is_popular    boolean not null default false,
  sort_order    int not null default 0,
  is_active     boolean not null default true
);
create index services_pro_idx on services (pro_id);

create table work_items (
  id            uuid primary key default gen_random_uuid(),
  pro_id        uuid not null references pros (id) on delete cascade,
  category      category not null,
  caption       text not null default '',
  image_path    text,               -- storage object path in bucket `work`
  seed          int not null default floor(random() * 100000)::int,
  is_pinned     boolean not null default false,
  likes         int not null default 0,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);
create index work_items_pro_idx on work_items (pro_id);

-- Weekly template: one row per weekday range. 0 = Sunday … 6 = Saturday (Postgres dow).
create table availability (
  id            uuid primary key default gen_random_uuid(),
  pro_id        uuid not null references pros (id) on delete cascade,
  weekday       smallint not null check (weekday between 0 and 6),
  start_minutes int not null check (start_minutes between 0 and 1440),
  end_minutes   int not null check (end_minutes between 0 and 1440 and end_minutes > start_minutes)
);
create index availability_pro_idx on availability (pro_id);

create table days_off (
  pro_id        uuid not null references pros (id) on delete cascade,
  day           date not null,
  primary key (pro_id, day)
);

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------
create table bookings (
  id                    uuid primary key default gen_random_uuid(),
  reference             text not null unique,
  pro_id                uuid not null references pros (id),
  client_id             uuid not null references profiles (id),
  status                booking_status not null default 'requested',
  starts_at             timestamptz not null,
  ends_at               timestamptz not null,
  -- Address is copied at booking time so a later edit doesn't change history.
  address_label         text not null,
  address_line1         text not null,
  address_suburb        text not null,
  address_state         text not null default 'VIC',
  address_postcode      text not null,
  address_location      geography(point, 4326) not null,
  address_instructions  text not null default '',
  notes                 text not null default '',
  -- Money, frozen at booking time.
  services_cents        int not null check (services_cents >= 0),
  travel_fee_cents      int not null default 0 check (travel_fee_cents >= 0),
  booking_fee_cents     int not null default 300,
  tip_cents             int not null default 0 check (tip_cents >= 0),
  discount_cents        int not null default 0,
  platform_fee_cents    int not null default 0,
  cancellation_charge_cents int not null default 0,
  -- Stripe
  stripe_payment_intent_id text,
  stripe_tip_intent_id  text,
  payment_method_id     uuid references payment_methods (id),
  captured_at           timestamptz,
  decline_reason        text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index bookings_pro_time_idx on bookings (pro_id, starts_at);
create index bookings_client_idx on bookings (client_id, starts_at desc);
create index bookings_status_idx on bookings (status);

-- Services on a booking, copied by value.
create table booking_services (
  booking_id    uuid not null references bookings (id) on delete cascade,
  service_id    uuid references services (id) on delete set null,
  name          text not null,
  category      category not null,
  price_cents   int not null,
  minutes       int not null,
  sort_order    int not null default 0,
  primary key (booking_id, sort_order)
);

create table booking_inspo (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings (id) on delete cascade,
  image_path    text not null,     -- storage object path in bucket `inspo`
  created_at    timestamptz not null default now()
);

create table booking_events (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings (id) on delete cascade,
  status        booking_status not null,
  actor_id      uuid references profiles (id),
  note          text,
  at            timestamptz not null default now()
);
create index booking_events_booking_idx on booking_events (booking_id, at);

-- ---------------------------------------------------------------------------
-- Reviews: one per booking, only after done/paid. Pro can reply once.
-- ---------------------------------------------------------------------------
create table reviews (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null unique references bookings (id) on delete cascade,
  pro_id        uuid not null references pros (id) on delete cascade,
  client_id     uuid not null references profiles (id) on delete cascade,
  rating        smallint not null check (rating between 1 and 5),
  text          text not null default '',
  service_name  text not null default '',
  photo_path    text,
  pro_reply     text,
  pro_replied_at timestamptz,
  created_at    timestamptz not null default now()
);
create index reviews_pro_idx on reviews (pro_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Messaging: one thread per booking.
-- ---------------------------------------------------------------------------
create table threads (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null unique references bookings (id) on delete cascade,
  pro_id        uuid not null references pros (id),
  client_id     uuid not null references profiles (id),
  last_message_at timestamptz,
  client_read_at  timestamptz,
  pro_read_at     timestamptz
);

create table messages (
  id            uuid primary key default gen_random_uuid(),
  thread_id     uuid not null references threads (id) on delete cascade,
  sender_id     uuid references profiles (id),   -- null = system
  text          text not null check (char_length(text) between 1 and 2000),
  sent_at       timestamptz not null default now()
);
create index messages_thread_idx on messages (thread_id, sent_at);

-- ---------------------------------------------------------------------------
-- Favourites, blocks, reports, payouts, devices
-- ---------------------------------------------------------------------------
create table favourites (
  client_id     uuid not null references profiles (id) on delete cascade,
  pro_id        uuid not null references pros (id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (client_id, pro_id)
);

create table blocks (
  blocker_id    uuid not null references profiles (id) on delete cascade,
  blocked_id    uuid not null references profiles (id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create table reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references profiles (id) on delete cascade,
  reported_id   uuid not null references profiles (id) on delete cascade,
  booking_id    uuid references bookings (id) on delete set null,
  reason        text not null,
  detail        text not null default '',
  created_at    timestamptz not null default now(),
  handled_at    timestamptz
);

create table payouts (
  id                    uuid primary key default gen_random_uuid(),
  pro_id                uuid not null references pros (id) on delete cascade,
  amount_cents          int not null,
  status                payout_status not null default 'pending',
  stripe_transfer_id    text,
  arrives_on            date,
  created_at            timestamptz not null default now()
);
create index payouts_pro_idx on payouts (pro_id, created_at desc);

create table payout_items (
  payout_id     uuid not null references payouts (id) on delete cascade,
  booking_id    uuid not null references bookings (id),
  amount_cents  int not null,
  primary key (payout_id, booking_id)
);

create table devices (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references profiles (id) on delete cascade,
  apns_token    text not null unique,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger profiles_updated before update on profiles for each row execute function set_updated_at();
create trigger pros_updated     before update on pros     for each row execute function set_updated_at();
create trigger bookings_updated before update on bookings for each row execute function set_updated_at();

-- Booking reference like HD-4K2P (no 0/O/1/I).
create or replace function gen_reference() returns text language plpgsql as $$
declare chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; out text := ''; i int;
begin
  for i in 1..4 loop out := out || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
  return 'HD-' || out;
end $$;

create or replace function bookings_defaults() returns trigger language plpgsql as $$
begin
  if new.reference is null or new.reference = '' then
    loop
      new.reference := gen_reference();
      exit when not exists (select 1 from bookings where reference = new.reference);
    end loop;
  end if;
  new.platform_fee_cents := round((new.services_cents + new.travel_fee_cents) * 0.12);
  return new;
end $$;
create trigger bookings_defaults before insert on bookings for each row execute function bookings_defaults();

-- Log every status change and keep pro counters fresh.
create or replace function bookings_on_status() returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into booking_events (booking_id, status, actor_id) values (new.id, new.status, auth.uid());
    if new.status in ('done', 'paid') and (tg_op = 'INSERT' or old.status not in ('done', 'paid')) then
      update pros set completed_bookings = completed_bookings + 1 where id = new.pro_id;
    end if;
    if new.status = 'cancelledByPro' then
      update pros set reliability_score = greatest(0, reliability_score - 0.05) where id = new.pro_id;
    end if;
    if tg_op = 'INSERT' then
      insert into threads (booking_id, pro_id, client_id, last_message_at) values (new.id, new.pro_id, new.client_id, now());
    end if;
  end if;
  return new;
end $$;
create trigger bookings_status after insert or update of status on bookings for each row execute function bookings_on_status();

-- Shown rating uses a Bayesian prior (4.6 over 10 reviews) so a new pro isn't sunk by one bad night.
create or replace function refresh_pro_rating(p uuid) returns void language sql security definer as $$
  update pros set
    review_count = (select count(*) from reviews where pro_id = p),
    rating = (select round(((4.6 * 10) + coalesce(sum(rating), 0)) / (10 + count(*)), 2) from reviews where pro_id = p)
  where id = p;
$$;

create or replace function reviews_after_change() returns trigger language plpgsql as $$
begin perform refresh_pro_rating(coalesce(new.pro_id, old.pro_id)); return null; end $$;
create trigger reviews_refresh after insert or update or delete on reviews for each row execute function reviews_after_change();

create or replace function messages_after_insert() returns trigger language plpgsql as $$
begin update threads set last_message_at = new.sent_at where id = new.thread_id; return null; end $$;
create trigger messages_touch after insert on messages for each row execute function messages_after_insert();

-- ---------------------------------------------------------------------------
-- Availability: slots for a pro on a day, honouring buffer and existing bookings.
-- ---------------------------------------------------------------------------
create or replace function pro_slots(p uuid, day date, duration_minutes int, tz text default 'Australia/Melbourne')
returns table (starts_at timestamptz, is_available boolean, reason text)
language plpgsql stable as $$
declare
  r record; m int; s timestamptz; e timestamptz; buf int; step int; clash record;
begin
  select buffer_minutes, step_minutes into buf, step from pros where id = p;
  if exists (select 1 from days_off d where d.pro_id = p and d.day = pro_slots.day) then return; end if;
  for r in select * from availability a where a.pro_id = p and a.weekday = extract(dow from pro_slots.day) loop
    m := r.start_minutes;
    while m + duration_minutes <= r.end_minutes loop
      s := (pro_slots.day::timestamp + make_interval(mins => m)) at time zone tz;
      e := s + make_interval(mins => duration_minutes);
      starts_at := s; is_available := true; reason := null;
      if s < now() + interval '90 minutes' then
        is_available := false; reason := 'Too soon, she needs 90 minutes'' notice';
      else
        select * into clash from bookings b
          where b.pro_id = p and b.status in ('requested','confirmed','onHerWay','arrived','inProgress')
            and b.starts_at - make_interval(mins => buf) < e and b.ends_at + make_interval(mins => buf) > s
          limit 1;
        if found then is_available := false; reason := 'She''s booked'; end if;
      end if;
      return next;
      m := m + step;
    end loop;
  end loop;
end $$;

-- Pros near a point, within their own travel radius, optional category.
create or replace function pros_near(lat double precision, lng double precision, cat category default null, limit_n int default 50)
returns setof pros language sql stable as $$
  select p.* from pros p
  where p.is_active
    and (cat is null or cat = any (p.specialties))
    and st_dwithin(p.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography, p.travel_radius_km * 1000)
  order by p.location <-> st_setsrid(st_makepoint(lng, lat), 4326)::geography
  limit limit_n;
$$;

-- ---------------------------------------------------------------------------
-- Storage buckets
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('work', 'work', true) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('inspo', 'inspo', false) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict do nothing;
