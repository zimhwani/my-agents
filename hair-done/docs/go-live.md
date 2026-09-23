# Going live: the settings only you can switch on

The backend is built and deployed: the Supabase project `hair-done` (Sydney, ref `yohqeunmgrxyakviofua`),
its database rules, six functions and two timers. These are the switches in Stripe, Supabase and Apple
that need your logins. Do them in test mode first. Nothing here needs code.

Never paste a secret key into a chat, an issue or the repo. They go straight into the dashboards below.

## 1. Stripe (test mode first)

1. **Turn on Connect.** Dashboard → Connect → Get started. Choose a platform or marketplace with
   **Express** accounts, Australia. Fill in the platform profile: pros are paid through you for services
   booked in the app.
2. **Two webhooks**, both to the same address:
   `https://yohqeunmgrxyakviofua.supabase.co/functions/v1/stripe-webhook`
   - **Your account** endpoint. Developers → Webhooks → Add endpoint. Events:
     `payment_intent.amount_capturable_updated`, `payment_intent.succeeded`,
     `payment_intent.canceled`, `setup_intent.succeeded`.
   - **Connected accounts** endpoint. Add endpoint again and choose "Events on Connected accounts". Events:
     `account.updated`, `payout.paid`.
   - Each endpoint shows a signing secret (`whsec_…`). Keep both for step 3.
3. **Give the secrets to Supabase.** Supabase → project `hair-done` → Edge Functions → Secrets. Add:

   | Name | Value |
   |---|---|
   | `STRIPE_SECRET_KEY` | Your test secret key, `sk_test_…` (Developers → API keys) |
   | `STRIPE_WEBHOOK_SECRET` | The signing secret of the "your account" endpoint |
   | `STRIPE_CONNECT_WEBHOOK_SECRET` | The signing secret of the "connected accounts" endpoint |

   Until these are in, the payment functions answer "not configured" and charge nothing.
4. **The publishable key** (`pk_test_…`) goes in your Mac's `HairDone.xcconfig` as `HAIRDONE_STRIPE_KEY`.
   It's public by design, but the xcconfig keeps it out of the repo anyway.

## 2. Apple Pay

1. developer.apple.com → Identifiers → **Merchant IDs** → +. Use `merchant.com.keithchinyanda.hairdone`.
2. Stripe → Settings → Payment methods → Apple Pay → **iOS certificates** → Add. Download the CSR it gives you.
3. Back in Apple: your merchant ID → Apple Pay Payment Processing Certificate → Create. Upload Stripe's CSR,
   download the `.cer`, and upload it to Stripe.
4. Identifiers → your app ID `com.keithchinyanda.hairdone` → tick **Apple Pay Payment Processing** and pick the
   merchant ID. Tick **Sign in with Apple** while you're there.
5. Put the merchant ID in `HairDone.xcconfig` as `HAIRDONE_MERCHANT_ID`.
6. Add the Apple Pay entitlement to `HairDone/HairDone.entitlements` (it's left out so builds work before the
   merchant ID exists; an empty one breaks signing on a phone):
   ```xml
   <key>com.apple.developer.in-app-payments</key>
   <array>
       <string>merchant.com.keithchinyanda.hairdone</string>
   </array>
   ```
   Until then Apple Pay just doesn't show in the payment sheet; cards work.

## 3. Sign-in (Supabase → Authentication → Sign In / Providers)

- **Phone.** Turn it on and pick **Twilio** (or Twilio Verify, or MessageBird). You'll need a Twilio account
  with an Australian-capable sender. For testing without SMS, add test numbers in "Test phone numbers
  and OTPs", like `61400000001=123456`. They sign in with that fixed code and nothing is sent.
- **Apple.** Turn it on. In **Client IDs** put `com.keithchinyanda.hairdone`. The app signs in natively, so no
  secret key is needed for the iPhone.
- **URL configuration.** Set the site URL to `hairdone://auth`.

## 4. The app on your Mac

In `hair-done/HairDone.xcconfig` (it's gitignored), alongside the team and App Store Connect lines:

```
HAIRDONE_SUPABASE_URL = https:/$()/yohqeunmgrxyakviofua.supabase.co
HAIRDONE_SUPABASE_KEY = sb_publishable_dDCoMmIEzBXsLRi4itW94g_fNS5KY0s
HAIRDONE_STRIPE_KEY = pk_test_...
HAIRDONE_MERCHANT_ID = merchant.com.keithchinyanda.hairdone
```

The `$()` in the URL is on purpose: in an xcconfig, `//` starts a comment. With the Supabase lines empty,
the app runs on its built-in sample data, as it does today.

## 5. Your first real pros

There's no admin screen yet. Until there is, you do these in Supabase → SQL editor:

- **Verify a pro** once you've checked her ID, ABN and insurance:
  `update pros set is_verified = true, id_checked_at = now(), insurance_on_file = true where id = '<her id>';`
  Only verified pros can switch on instant book.
- **Read reports** (report, block and "Something wrong?"):
  `select * from reports where handled_at is null order by created_at;`
- **See stuck payments:** `select reference, status, hold_state, settle_error from bookings where settle_error is not null;`

A pro can't be booked until she's finished Stripe payout setup in the app (Pro mode → payouts). In test
mode, Stripe's onboarding accepts its test data: phone `000 000 0000`, code `000000`, and the test bank details it offers.

## 6. Try it end to end (test mode)

1. Sign up as a pro on one phone. Add services, availability and a photo, then finish payouts.
2. Verify her (step 5).
3. Sign in as a client on another phone. Book her using Stripe's test card `4242 4242 4242 4242`,
   any future date and any CVC.
4. The pro accepts, then taps On my way, Here, Start and Done. The client taps Pay, with a tip.
5. In Stripe, the payment shows a $3 + 12% application fee and a transfer to the pro's test account.

Then repeat with a late cancel and a request left unanswered, to see the timers work.

## 7. Before real money

- Switch Stripe to live mode. Repeat steps 1.2 and 1.3 with the live keys and live webhook secrets.
- Twilio live sender approved for Australia.
- Terms, privacy policy and the pro agreement, reviewed by a lawyer, linked from the app and the App Store listing.
- The Supabase project on a paid plan. Free projects pause after a week without traffic, and the timers stop with them.
