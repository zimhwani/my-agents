# Direct booking with Stripe — plan

The site is static today and sends guests to Airbnb. This is the smallest path to
taking direct bookings on the same site, in three stages. Nothing here changes the
live site until `DIRECT_BOOKING_URL` in `assets/js/main.js` is set.

## Stage 1 — enquiry-to-invoice (no code)
Keep the enquiry form (connect Web3Forms). When a guest asks for dates, reply with a
Stripe Payment Link or invoice from the Stripe dashboard. Zero build, works today.
Add the booking manually to your Airbnb calendar to block the dates.

## Stage 2 — self-serve checkout (one serverless function)
- `api/checkout.js` on Vercel: takes check-in, check-out and guests; validates
  against availability; prices the stay; creates a Stripe Checkout Session
  (mode `payment`) with the total, cleaning fee and a 3-night minimum; redirects.
- Availability: Airbnb exposes an iCal export URL for the listing. The function
  fetches it (cached 10 min) and rejects dates that overlap a booked block. Blocks
  from direct bookings are written back by importing a Stripe-driven iCal feed
  into Airbnb (`api/ical.js`), so both calendars stay in sync.
- Pricing config lives in one JSON file: base nightly, weekend and peak-season
  rates, cleaning fee, min nights, max guests 9.
- Front end: a `book.html` page with a date picker (native inputs are fine),
  guest count, live quote, and a "Pay with Stripe" button that POSTs to the
  function. Set `DIRECT_BOOKING_URL = "/book"` and every primary CTA switches
  to it automatically; Airbnb stays as the secondary link.
- Webhook `api/stripe-webhook.js`: on `checkout.session.completed`, email the
  guest (Resend or Postmark) with the guest guide link, the address and entry
  details, and notify you. Store bookings in a Supabase table (the Supabase MCP
  is already connected in this workspace) or a Vercel KV store.
- Secrets in Vercel project env: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
  `AIRBNB_ICAL_URL`, `EMAIL_API_KEY`. The static folder needs no build step
  changes: Vercel serves `api/*.js` as functions alongside the HTML.

## Stage 3 — polish
Deposit + balance schedules, promo codes, a guest portal at `/my-stay` keyed by
booking ID, and a cancellation policy page. Register the business name and add
terms and a privacy note to the footer before taking card payments.

Effort: Stage 2 is roughly a day's build plus Stripe account setup. Ask for it when
you're ready and it can be built in this repo.
