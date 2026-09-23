# Hair Done backend

Postgres on Supabase, Stripe for money. **Live project:** `hair-done` in the Tapinoir organisation,
Sydney region, ref `yohqeunmgrxyakviofua` (`https://yohqeunmgrxyakviofua.supabase.co`).
Everything in this folder is deployed there. What's left to switch on is in `../docs/go-live.md`.

## What's here

| Path | What |
|---|---|
| `migrations/0001_init.sql` | Tables, enums, triggers, storage buckets |
| `migrations/0002_rls.sql` | Row-level security (several policies replaced in 0003) |
| `migrations/0003_operational.sql` | Privacy, server-side prices, the state machine with the spec's timings, reliability, the sweep, account deletion, column guards |
| `migrations/0004_hardening.sql` | Security-advisor tidy-ups |
| `migrations/0005_schedule.sql` | pg_cron: `sweep_bookings()` every 10 min, the `settle` function every 5 min |
| `migrations/0006_plain_coordinates.sql` | `lat`/`lng` columns on addresses and pros |
| `functions/create-payment-intent` | Takes the card for a new booking: a hold if it's within 6 days, else a saved card. `action: "confirm"` marks it held |
| `functions/pay-booking` | The client's Pay on the Done sheet: capture plus an optional tip |
| `functions/settle` | Timed Stripe work: deferred holds, releases, cancellation charges, auto-capture |
| `functions/stripe-webhook` | Keeps bookings, saved cards and payouts in step with Stripe |
| `functions/connect-onboarding` | Stripe Connect Express link for a pro's payouts |
| `functions/payouts-return` | The page Stripe sends a pro back to; hands her to `hairdone://payouts/...` |

## How the app talks to it

Clients never see a pro's exact location, ABN or Stripe id, and never write prices.

- Browse: `pros_near(lat, lng, cat)`, `pro_card(id)`, `pro_cards(ids)`, `pro_reviews(id)`, `pro_slots(id, day, minutes)`.
- Book: save an address, then `create_booking(pro, service_ids, starts_at, address_id, notes)`. The server prices it and checks the slot under a lock. Then `create-payment-intent` → PaymentSheet → `create-payment-intent {action: "confirm"}`.
- Move: `move_booking(id, status, reason)`. The server decides who may do what (spec §5). System lines in the thread are written by the server.
- Pro side: `bookings_for_pro()`. The street address stays blank until she confirms.
- Pay: `pay-booking {booking_id, tip_cents}`. Everything else about money is the server's.
- "Something wrong?": `flag_booking(id, detail)`. Delete account: `delete_my_account()`.

## Money, as the code does it

- Client total = services + travel + $3. Hold placed at booking (manual capture). If the start is more than 6 days away the card is saved and `settle` places the hold 6 days before, because Stripe holds lapse at 7.
- Captured when she taps Pay, or automatically 12 h after done unless she's pressed "Something wrong?" (48 h pause).
- `application_fee_amount` = 12% of (services + travel) + $3. The rest goes to the pro's Express account (`transfer_data.destination`). A pro without payouts set up can't be booked.
- Cancellation: free with 24 h notice or while requested; 50% of the pro's price under 24 h; 100% + $3 once she's arrived or on a no-show. `settle` captures that amount from the hold, or releases it.
- Tips are a second charge with no fee, 100% to the pro.

## Timers

| Job | Every | Does |
|---|---|---|
| `hairdone-sweep` | 10 min | Unpaid requests lapse at 30 min; unanswered requests decline at 2 h (−2 reliability); in-progress becomes done 12 h after the end |
| `hairdone-settle` | 5 min | Calls `functions/v1/settle` with the secret from `private.settings` |

## Changing things

Use the Supabase MCP or CLI. For a fresh project: apply the migrations in order, deploy the six functions
(`settle`, `stripe-webhook` and `payouts-return` with JWT verification off), change the URL in
`0005_schedule.sql`, then follow `../docs/go-live.md`.
