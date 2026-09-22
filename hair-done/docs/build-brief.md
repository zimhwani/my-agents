# Hair Done — build brief

The one document every part of this build answers to. If a screen, a line of
copy or a colour disagrees with this file, this file wins.

## 1. What it is

**Hair done, nails done, everything done.** A mobile app for women in Australia
who want their hair, nails, makeup, lashes or brows done wherever they are —
at home, at the hotel, at the bride's mum's place — by a vetted mobile pro
who comes to them. Think Airtasker, but for getting ready, built by women
for women.

Two sides of one app:

- **Clients** open the app, see pros near them, look at their actual work,
  read what other women said, book a time, pay in the app, and get done.
- **Pros** (mobile hair stylists, nail techs, makeup artists, lash and brow
  artists) get a calendar that fills itself, get paid without chasing, and
  show their work somewhere that isn't a DM request on Instagram.

Launch city: Melbourne. Currency: AUD. Spelling: Australian English
(colour, favourite, organise, mum).

## 2. Names and words

| Thing | Call it | Never |
|---|---|---|
| The app | **Hair Done** (short), wordmark *hair done, nails done, everything done.* | HDNDED, HDN, "the platform" |
| Home-screen label | `Hair Done` | anything longer (it truncates) |
| A person who books | **you** in copy; "client" in code and pro-facing screens | customer, user, consumer |
| A person who does the work | **pro** (umbrella). Specialty labels: hair stylist, nail tech, makeup artist, lash tech, brow artist | technician (too clinical in UI), vendor, provider, tasker, service provider |
| The thing you book | **booking** | appointment (formal), task, gig, job (client side; "job" is fine pro side) |
| A pro's photos of past work | **work** ("her work", "see her work") | portfolio (code only), gallery, body of work |
| Pro's travel area | **she'll come to** / travel area | service radius (code only) |
| Ratings | **stars** and **reviews** ("4.9 · 212 reviews") | feedback score, trust rating |
| Money going to a pro | **payout** | disbursement |
| Client-side app section | Home · Bookings · Inbox · You | Dashboard, Explore, Discover |
| Pro-side app section | Today · Calendar · Inbox · Work · Earnings | |
| Switching sides | **Pro mode** | Business account, Partner app |

Categories (exactly these, this order, these names):
`Hair`, `Nails`, `Makeup`, `Lashes`, `Brows`, and `The lot` (bundles: hair +
makeup, hair + nails + makeup for events).

## 3. Voice

Like a text from your most put-together friend: warm, direct, a bit cheeky,
never gushing. She knows a good nail tech and she will tell you straight.

Rules:

1. Sentence case everywhere. Full stops on sentences, none on labels.
2. Short. Buttons are one to three words: `Book`, `Pay $180`, `Get ready`.
3. Concrete over abstract. "Kiara can be at yours by 6:30" beats "Convenient
   scheduling".
4. Say the price. Say the time. Say the suburb.
5. One exclamation mark per screen at most, and usually zero.
6. No emoji in UI copy. Pros can use them in their own bios; we don't.
7. Talk to one woman, not a market. "your" not "users'".
8. Australian English. "Mum", "arvo" is fine in a push notification, not in a
   receipt.

Rules added after the first copy audit (docs/qa/copy-audit.md):

9. Model strings are UI. Anything returned from a `label`, `errorDescription` or `localizedDescription` ends up on a screen. Write it from the deck.
10. Money verbs only: held, charged, refunded, lands, drops off. Never "processing", "transaction", "pending payment" or "said no". Every money line says what has happened to her dollars right now.
11. No symbols standing in for words: "about" not "~", "to" not "–", "and" not "+". The middle dot separates facts, not clauses.
12. Day words are lowercase mid-sentence: "today", "tomorrow" after any other word.
13. One name per thing, everywhere it appears. If two screens name it differently, the review screen wins.
14. Say what the system does in her words: "lapses" not "auto-declines", "ID checked" not "verified", "booking since" not "member since".
15. No social counters. No likes, followers, views or hearts. Stars and reviews are the only numbers a pro is judged by.
16. A cute error is a failed error. Three sentences, in order: what happened, what happened to the money, what to do.
17. Debug-only copy is exempt, but only behind `#if DEBUG`.

Banned words and patterns (these read as machine-written; do not use them
anywhere, including code comments that might leak into UI):
`elevate`, `unlock`, `seamless(ly)`, `effortless(ly)`, `journey`, `empower`,
`curated`, `discover`, `explore` (as a verb for browsing), `experience`
(as a noun for a booking), `indulge`, `pamper`, `treat yourself`,
`self-care ritual`, `your best self`, `glow up` (as copy), `vibe`,
`bespoke`, `premium` (as an adjective in copy), `hassle-free`,
`stress-free`, `at your fingertips`, `in the comfort of your own home`,
`look no further`, `we've got you covered`, `whether you're… or…`,
`from X to Y, we…`, `Welcome to`, any sentence starting with `Imagine`,
tricolons of adjectives ("simple, fast, beautiful"), rhetorical questions
as headlines ("Ready to shine?"), title-case headlines.

Good lines to steal the tone from:

- "Who's free tonight." (home header, evening)
- "Kiara does a very good French tip."
- "She's 12 minutes away and free from 5."
- "You're booked. Sit tight, she's on her way at 6:15."
- "Nothing on. Want to change that?"
- "Paid. $180 to Kiara, receipt in your inbox."
- "Cancel with more than 24 hours' notice and it's free. Less than that and
  she keeps half. She's already turned down other work for you."

## 4. Look

Magazine, not marketplace. Warm paper, ink, and one lacquer red. Serif
display type, sans body. Lots of air. Photos do the talking.

### Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#F8F3EC` | `#171210` | screen background |
| `card` | `#FFFFFF` | `#221B18` | cards, sheets |
| `ink` | `#241A16` | `#F4ECE4` | primary text |
| `inkSoft` | `#6F625B` | `#B5A79D` | secondary text |
| `line` | `#E8DFD5` | `#3A302B` | hairlines, dividers |
| `lacquer` | `#C8323A` | `#E2504F` | primary action, the one accent |
| `lacquerSoft` | `#F6DEDC` | `#4A2626` | accent tint backgrounds |
| `honey` | `#E9B96A` | `#E9B96A` | stars |
| `success` | `#3E7A5A` | `#6FBF8F` | confirmed, paid |
| `warn` | `#B9741F` | `#E6A44C` | pending, waiting |

Category tints (used on tiles and chips, light mode; darken 60% for dark):
Hair `#EAD9CB`, Nails `#F3D0CB`, Makeup `#E8D2DF`, Lashes `#D8D4E5`,
Brows `#D9DED0`, The lot `#EFE3C8`.

### Type

- Display: system serif (`.fontDesign(.serif)`), e.g. `Font.system(.largeTitle, design: .serif)` with `.fontWeight(.medium)`; italic for one word of emphasis.
- Body: SF Pro default. Numbers in prices use `.monospacedDigit()`.
- Scale: `hero` 40/44 serif · `title` 28/32 serif · `heading` 20/24 serif medium · `body` 17/22 · `sub` 15/20 · `caption` 13/16 · `label` 12/14 uppercase tracked 0.08em (used sparingly).

### Shape and space

- Spacing unit 4. Screen gutter 20. Card padding 16. Section gap 32.
- Radius: cards 20, tiles 16, buttons full pill (height 52), chips pill (height 36), inputs 14.
- Shadows: none on paper; cards use a 1px `line` hairline in light and a slightly lighter surface in dark. One soft shadow only on floating CTAs: `ink` at 12% opacity, y 8, blur 24.
- Hairlines over boxes. Air over borders.

### Motion and feel

- Springs: `.spring(response: 0.35, dampingFraction: 0.85)` default.
- Haptics: `.light` on selection, `.medium` on primary actions, `.success` notification on booked/paid.
- One delightful moment per flow, not five: the lacquer check that draws itself on "You're booked", the star that fills with honey when you rate, the pro card that lifts slightly on press.
- Images: placeholders are a warm procedural gradient with a soft grain overlay, tinted by category. Never a grey box, never a broken-image icon.

## 5. Product scope (v1, in this repo)

Client:
1. Welcome → phone or Apple sign-in (mocked) → name → allow location → home.
2. Home: greeting by time of day, "Who's free" strip (pros available today
   near you), categories, "Near you" list/map toggle, search, "Book again".
3. Pro profile: cover work, name, specialty, stars/reviews, distance, "comes
   to" area, about, services with prices and durations, work grid, reviews,
   availability preview, sticky `Book`.
4. Booking: pick services → pick day and time (real slots from her
   availability) → where (saved address, current location, or type one) →
   notes + up to 3 inspo photos → review (price breakdown: services, travel
   fee, Hair Done fee, total) → pay (Apple Pay or saved card; hold now,
   charged when she's done) → "You're booked".
5. Bookings: upcoming and past; each with status timeline (requested → confirmed → on her way → done → paid), message her, reschedule, cancel (policy shown plainly), rate and tip after.
6. Inbox: threads per booking; quick replies.
7. You: profile, addresses, payment methods, favourites, notifications, help, switch to Pro mode, log out.

Pro:
1. Pro onboarding: specialty, services and prices, travel area, availability, work photos, ID and ABN (mocked), payout setup (Stripe Connect Express link, mocked).
2. Today: next job card with client, address, time, what's booked; earnings today/this week; new requests to accept or decline (with the reason shown to the client).
3. Calendar: week view, availability editing, block time off.
4. Inbox: same threads, pro side.
5. Work: upload and reorder work photos, tag by category, pin favourites.
6. Earnings: this week, pending payouts, history, fee breakdown, tips.
7. Profile edit: bio, services, prices, travel fee, radius, instant book on/off.

Trust and safety, both sides: verified badge (ID checked), reviews only
after a completed booking, report/block, share booking details with a
friend, in-app messaging (no phone numbers until confirmed).

## 6. Money

- Client pays in the app. Hold placed at booking, captured when the pro marks done (or auto 12h later).
- Hair Done fee: 12% from the pro's side, plus a $3 booking fee shown to the client. Prices in the app are the client's all-in price except the fee line, which is always shown, never hidden in the total.
- Travel fee is set by the pro, flat, shown on her profile.
- Cancellation: free with 24h+ notice; under 24h the client pays 50%; no-show pays 100%. Pro cancels: client refunded in full, pro's reliability score drops.
- Tips: optional, after done, 100% to the pro.
- Payouts: Stripe Connect Express, daily.

## 7. Tech

- SwiftUI, iOS 17+, Xcode 16. No third-party packages required to build. Swift 5.10 language mode (do not enable Swift 6 strict concurrency).
- `@Observable` models, `NavigationStack`, `TabView`. No Combine.
- `DataService` protocol with `MockDataService` (rich seeded data, in-memory, deterministic) and a `SupabaseDataService` stub. `PaymentService` protocol with `MockPaymentService` and a `StripePaymentService` behind `#if canImport(StripePaymentSheet)`.
- Everything works offline against mock data on first run. No network needed to demo.
- Backend in `supabase/`: Postgres schema + RLS + edge functions for payments.
- Project at `hair-done/HairDone.xcodeproj` using an Xcode 16 synchronized folder, plus `hair-done/project.yml` for XcodeGen as a fallback.
