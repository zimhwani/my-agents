# Hair Done backend

Postgres on Supabase, Stripe for money. The iOS app ships against `MockDataService`; this is what it talks to once `SupabaseDataService` is wired up.

## What's here

| Path | What |
|---|---|
| `migrations/0001_init.sql` | Tables, enums, indexes, triggers, `pro_slots()` and `pros_near()` functions, storage buckets |
| `migrations/0002_rls.sql` | Row-level security for every table, the `move_booking()` state machine, `sweep_bookings()` |
| `functions/create-payment-intent` | Places the hold (manual capture) for a booking; returns what PaymentSheet needs |
| `functions/stripe-webhook` | Keeps bookings and payouts in step with Stripe |
| `functions/connect-onboarding` | Stripe Connect Express link for a pro's payouts |
| `config.toml` | Supabase CLI config (phone auth, Apple sign-in, function JWT settings) |

## Privacy, as the code does it

- `profiles` holds names only. Phone and email are in `profile_contacts`, readable by the owner alone. Edge functions read them with the service role.
- A pro reads bookings through the `bookings_for_pro` view: suburb and postcode always, the street address and access notes only once the booking is confirmed.
- `availability.weekday` uses Postgres `dow` (0 = Sunday). The app's `Weekday` is 1 = Sunday, so store `Weekday.rawValue - 1`.

## Money, as the code does it

- Client total = services + travel fee + $3 booking fee (`bookings.booking_fee_cents`).
- Hold placed at booking with `capture_method: manual`; captured when the pro marks done (or 12 h later by the sweep).
- Stripe `application_fee_amount` = 12% of (services + travel) + the $3 booking fee. The rest goes to the pro's Express account via `transfer_data.destination`.
- Cancellation: `move_booking()` sets `cancellation_charge_cents` (0 with 24 h+ notice, 50% under, 100% no-show). Capture that amount instead of the full hold.
- Tips after the fact are a second PaymentIntent (`stripe_tip_intent_id`) with no application fee.

## Running it

```bash
supabase start                      # local stack
supabase db reset                   # applies migrations
supabase functions serve            # edge functions locally
supabase secrets set STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_...
```

For the cloud project: `supabase link --project-ref <ref>` then `supabase db push` and `supabase functions deploy`.

Schedule the sweep with pg_cron once the project is linked:

```sql
select cron.schedule('sweep-bookings', '*/10 * * * *', $$select sweep_bookings()$$);
```

Auto-capture 12 h after done is a second cron job that calls `stripe.paymentIntents.capture` for `done` bookings older than 12 h; do it in an edge function on a schedule, not in SQL.

## Wiring the app

1. Add `supabase-swift` to the Xcode target.
2. In `SupabaseDataService.swift`, implement each method against the tables above. `pros(near:)` → `rpc("pros_near")`. `slots` → `rpc("pro_slots")`. Status changes → `rpc("move_booking")`.
3. In `StripePaymentService.swift`, call `create-payment-intent`, present `PaymentSheet` with the returned `client_secret`, `customer_id` and `ephemeral_key`.
4. Swap the services in `HairDoneApp.swift`.
