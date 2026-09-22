# TestFlight — Test Information

## Beta App Description
_(App Store Connect → TestFlight → Test Information. 4000 char limit.)_

Hair Done is an app for getting your hair, nails, makeup, lashes or brows done wherever you are, by a vetted mobile pro who comes to you. Melbourne, for now.

You open it, see who's near you and free, look at her work and what other women said, pick a time, and book. Pay in the app: we hold the money when you book and charge it when she's done. Message her in the app, rate her after.

Pros get the other side of the same app: Pro mode. Requests come in, she accepts or declines with a reason, her calendar fills, and she's paid out daily without chasing anyone.

WHAT THIS BUILD IS

An early build on seeded data. The pros you'll see are made up, the bookings are made up, and nothing you do charges a real card or reaches a real person. Every screen works and every flow can be walked end to end, so what we want from you is what it feels like, where it's confusing, and what's missing. Not whether the money works. It doesn't yet.

WHAT'S IN IT

• Home: who's free today near you, the six categories, pros closest first, a map.
• A pro's profile: her work, her prices, her stars and reviews, when she's next free.
• Booking: pick services, a real slot from her calendar, where she's coming to, notes and inspo photos, then the price with every fee on its own line.
• Bookings: what's coming up, what's happened, a timeline as she's on her way, here, done, paid.
• Inbox: one thread per booking, quick replies.
• You: addresses, cards, favourites, and the switch into Pro mode.
• Pro mode: today's jobs, new requests, calendar and availability, her work photos, earnings with the 12% shown plainly.

WHAT'S NOT REAL YET

Any phone number and any six-digit code signs you in. Apple Pay is drawn, not wired. Photos you pick become placeholder tiles. There are no push notifications. Sign in with Apple will fail on this build.

---

## What to Test — build 1
_(Per-build field.)_

First build. Everything on screen is seeded data; nothing charges anything.

1. BOOK SOMEONE. Home → Kiara → tick BIAB → Book. Go through all six steps. Tell me where you hesitated, and whether the price screen answered your questions before you asked them.

2. THE WORDS. Read every screen like it's a text from a friend. Anything that sounds like an app wrote it, screenshot it.

3. PRO MODE. You tab → Pro mode. You're Kiara. Accept one request, decline the other. Then Today → the next job → On my way → I'm here → Done. Does the money on that screen make sense to a nail tech?

4. THE MAP. On Home, switch to Map. Is it obvious who's who and what they cost?

5. RATE HER. Bookings → Past → the Priya booking → Rate. Stars, a line, a tip.

6. DARK MODE. Flip your phone to dark and go back through 1 and 3.

Known and not worth reporting: photos are coloured tiles, the code screen accepts anything, Apple sign-in errors, no notifications.

---

## Other fields on that screen

| Field | Value |
|---|---|
| Feedback Email | your address |
| Privacy Policy URL | needed before external testing, not for internal |
| Marketing URL | leave blank |
| Beta App Review | not needed for internal testing |
