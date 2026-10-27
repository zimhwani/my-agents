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
| `migrations/0019_watchdog.sql`, `functions/watchdog` | The watchdog: a read-only health check that emails Keith every morning, and within the hour when something new goes red |
| `migrations/0020_vetting.sql`, `functions/vetting`, `functions/vetting-review` | Pro vetting: checks each pro who sends their ID and emails Keith a review link for `site/review/` |

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
| `hairdone-watchdog-digest` | daily, 20:30 UTC | Morning email: what needs Keith today, what to watch, the numbers |
| `hairdone-watchdog-alert` | hourly, :07 | Emails only when a red finding is new in the last 24 h |
| `hairdone-vetting` | 15 min | Checks pros who sent their ID and emails Keith each one |

## The watchdog

It reads and reports; it never changes a booking, a payment or an account. `watchdog_snapshot()` is a
STABLE function, so Postgres refuses any write inside it, and Stripe and App Store Connect only get GET
requests. Its one write is its own log, `private.watchdog_runs`.

- **What it checks.** Money the timers should have moved (settle errors, holds not placed or not let go,
  charges not taken), bookings stuck past the sweep, open reports, low reviews, pros waiting on their ID
  check, failed payouts, every timer and what its function answered, RLS, Stripe webhooks, failed
  deliveries and disputes, live Stripe with sample pros still showing, and App Store review and TestFlight
  expiry. The rules and their levels are in `functions/watchdog/assess.ts`.
- **Test the rules:** `node supabase/functions/watchdog/assess.test.ts` (Node 23.6 or later). A made-up
  snapshot with one of everything has to trip all 30 rules at the right level; the quiet one has to come back clear.
- **Try it without emailing:** in the SQL editor,
  `select net.http_post(url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/watchdog', headers := jsonb_build_object('content-type','application/json','x-cron-secret',(select value from private.settings where key='cron_secret')), body := '{"mode":"digest","dry":true}'::jsonb);`
  then read the answer from `net._http_response` by the id it returns. `"preview"` is the email as text.
- **Send one now:** `select private.call_watchdog('digest');`
- **Its own history:** `select ran_at, mode, level, email from private.watchdog_runs order by ran_at desc limit 20;`
- **Switch it on:** `tools/setup-watchdog.sh` (where to email, sender, a read-only Stripe key, App Store
  Connect, and optionally an Anthropic key for the two lines at the top). Until `WATCHDOG_TO` is set it runs
  and logs but emails nobody.
- **What it can't see:** errors inside functions the app calls directly (`pay-booking`,
  `create-payment-intent`), which only show in Supabase's logs; and anything Stripe doesn't report on the
  platform account. If the morning email doesn't arrive, that's the signal: the watchdog itself is down.

## Changing things

Use the Supabase MCP or CLI. For a fresh project: apply the migrations in order, deploy the six functions
(`settle`, `stripe-webhook` and `payouts-return` with JWT verification off), change the URL in
`0005_schedule.sql`, then follow `../docs/go-live.md`.

## Pro vetting

When a pro sends their photo ID and selfie, within 15 minutes Keith gets an email: what the checks found,
a verdict (looks good, look closer, problem) and a button to the review page,
`hairdonenailsdone.app/review/` (`site/review/index.html`). There he sees the ID, the selfie and their work
side by side and taps Approve, or sends it back with a reason. Either way the pro is emailed; sent back,
the app asks them for their photos again (`id_submitted_at` is cleared).

- **What it checks:** both ID photos are there (and not tiny files), the ABN (check digits; then the
  government's ABN Lookup: active, and the name matches theirs), work photos (none the same file as one in
  another account, none uploaded twice), prices against everyone else's for the same category, travel area
  and fee. Rules: `functions/vetting/assess.ts`; test: `node supabase/functions/vetting/assess.test.ts`.
- **What it never does:** look at the ID photo or selfie. The privacy policy says they're never shown to
  anyone outside the Hair Done team, and no AI service is on its list of processors. Checking a face
  against an ID is Keith's job on the review page.
- **The link** is signed with a key in `private.settings`, lasts 72 hours, decides once, and stops working
  if the pro sends new photos. Photos on the page are signed storage links that last 10 minutes.
  A fresh link for a pro: `select private.call_vetting('<pro id>');`
- **ABN Lookup:** `tools/setup-vetting.sh` saves the GUID (register free at abr.business.gov.au). Without
  it, ABNs are only checked for typos.
- **Try it without saving or emailing:** `select net.http_post(url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/vetting', headers := jsonb_build_object('content-type','application/json','x-cron-secret',(select value from private.settings where key='cron_secret')), body := jsonb_build_object('dry', true, 'pro_id', '<pro id>'));`
- **History:** `select pro_id, verdict, email, decision, reason, decided_at from private.vetting_reviews order by created_at desc;`
- **The review page is on the website,** because Supabase serves HTML from `*.supabase.co` as plain text.
  It goes live with the rest of `site/`. Until it does, the email carries the same decision as SQL lines.
