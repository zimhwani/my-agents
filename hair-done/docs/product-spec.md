# Hair Done — v1 product spec

Companion to `build-brief.md` and `brand.md`. The brief wins on names, voice, palette, categories, scope, money and tech; the brand doc wins on how copy and colour are used. This document says what v1 does in enough detail to build it. Where it makes a decision the brief leaves open, it says so in a "Decision" line so the reasoning can be revisited.

Contents

1. The problem
2. Who it is for
3. Jobs to be done
4. The marketplace model
5. The booking state machine
6. Pricing and fees
7. Cancellation and no-show rules
8. Reviews and ratings
9. Instant book vs request-to-book
10. Availability model
11. Trust and safety
12. Notifications matrix
13. Analytics events
14. Not in v1
15. Success metrics, first 90 days

---

## 1. The problem

Mobile beauty in Melbourne runs on Instagram and bank transfers. It works, barely, and both sides pay for it in time, money and nerves.

### From the client's side

How it goes today, reconstructed from how women in the launch suburbs actually book:

1. She finds a pro on Instagram: a friend's tagged post, a hashtag, a story. She scrolls the grid to judge the work. There is no price list, or it is a highlight from 2023.
2. She DMs. "Hi! Are you free Saturday arvo for a gel set?" Then she waits. Hours, sometimes a day. The pro is doing hair and cannot type.
3. They go back and forth on times. The pro asks for her address and a deposit by bank transfer (PayID if lucky), usually $30–$50, to "secure the spot". The client sends money to a stranger and a screenshot as proof.
4. The day arrives. She does not know if the pro is coming until the pro is at the door, or has messaged "running 20 late sorry". Sometimes the pro simply does not come and the deposit is gone.
5. She pays the rest in cash or by transfer, in the hallway, doing mental arithmetic. There is no receipt.
6. If it was great, she saves the profile and starts again from step 2 next time. If it was bad, she has nowhere to say so and nobody else finds out.

What she cannot get today: a real price before she asks, a real available time without a conversation, a way to pay that does not involve trusting a stranger with a transfer, any signal about reliability, and any recourse.

### From the pro's side

1. Her calendar lives in her head, her Notes app and her DMs. Double-bookings happen. She turns down work because she cannot check availability fast enough.
2. Every booking costs her ten to twenty messages. Half of the enquiries go quiet after she quotes.
3. Deposits by transfer are awkward to ask for and awkward to enforce. When a client cancels the morning of, the deposit rarely covers the two hours she blocked out and the other client she turned away.
4. No-shows. She has driven to Elwood with a kit, and the client is not answering.
5. Her work is on Instagram, where it competes with everything else and where the algorithm decides who sees it. She gets no reviews she can point to, only comments.
6. Getting paid means chasing. "Did the transfer go through?" A day of hair can end with two clients still owing.

What she cannot get today: a calendar that fills without conversation, guaranteed money for confirmed bookings, protection when a client cancels late or does not show, and somewhere her work and her reviews build up in her favour.

### Why now, why here

Melbourne's inner north and inner south are dense, walkable, well served by pros who already travel, and full of women who already spend on this. The Instagram-DM model is universal and universally disliked. Nobody has built the calendar-and-payments layer for this vertical in Australia at a quality level that matches the pros' own work. Airtasker is too generic and too male in tone; salon-booking apps assume a salon.

---

## 2. Who it is for

### Launch area

Melbourne, two clusters. A client can be anywhere, but the "Who's free" and "Near you" content is only good in these suburbs at launch because that is where the first 50 pros are recruited.

Inner north: Fitzroy, Collingwood, Carlton, Brunswick, Brunswick East, Northcote.

Inner south: South Yarra, Prahran, Windsor, St Kilda, Elwood, South Melbourne.

Postcodes for the launch-area check in code: 3053, 3056, 3057, 3065, 3066, 3070, 3141, 3181, 3182, 3184, 3205. Outside these the app still works, but Home shows an honest empty state ("We're not in your suburb yet") rather than a thin list. Anita in Glen Waverley (brand doc) is a real person we want and cannot serve yet; the empty state takes her suburb so we know where to go next.

### The client

A woman, 22–45, in one of those suburbs or visiting one (hotel, friend's place, the bride's mum's place). She has booked a mobile pro before, at least once, via DM. She has an iPhone, uses Apple Pay, and books things (Ubers, tables, Airbnbs) without phoning anyone. She books for one of three reasons: an event (wedding, formal, birthday, a work thing), a regular (nails every three weeks, brows every five), or a "tonight" (last-minute, "who's free").

### The pro

A woman, 20–40, working for herself as a mobile hair stylist, nail tech, makeup artist, lash tech or brow artist. She has an ABN or is about to get one. She has 500–15,000 Instagram followers, does 8–25 jobs a week, and drives or rides between them. She is good at the work and bad at admin, by her own description. She is on her phone between jobs, not at a desk.

### People used in this spec

From `brand.md`. They are composites, not research subjects, and they are the names in the seed data.

Ruby, 31, Brunswick East. Books nails every three weeks and hair for events. Three nail techs have left her on read this month. Wants to see the price, tap a time, and know the pro is coming.

Kiara, 27, nail tech based in Coburg, travels across the inner north. Does 15 sets a week. Her French tip is genuinely very good. Wants a calendar that fills itself and money in her account the next day.

Mel, 38, hair stylist based in Werribee, bridal and event hair. Wants the empty weeks filled by women in her area.

---

## 3. Jobs to be done

### Client

1. When I have something on this weekend, I want to see who can do my hair or nails at my place on a specific day and time, so I can lock it in without a conversation.
2. When I am choosing between pros, I want to see their real work and what other women said after a real booking, so I do not get burnt by a nice grid and a bad set.
3. When I book, I want to pay in the app and know exactly what I am paying, so I never have to transfer money to a stranger or pay in the hallway.
4. On the day, I want to know she is actually coming and roughly when, so I can stop watching the door.
5. When it was good, I want to book her again in two taps and tell other women, so the good ones get busier.

### Pro

1. When a client wants a time, I want the app to offer only times that really fit around my other jobs and travel, so I stop double-booking and stop typing "what about 3:30?".
2. When a booking is confirmed, I want the money held and paid out without me asking, so I never chase a transfer again.
3. When a client cancels late or does not show, I want to be paid something for the time I blocked, so a bad morning does not cost me a day.
4. When I am between jobs, I want to see everything about the next one on one screen (who, where, when, what, notes, inspo), so I turn up ready.
5. When I do good work, I want the photos and reviews to build up somewhere that sends me clients, so I depend less on the Instagram algorithm.

---

## 4. The marketplace model

Supply first. A client who opens the app and sees three pros, none free this week, does not come back. A pro who joins and gets a booking in her first fortnight tells every other pro she knows. So the first 50 pros come before any client acquisition spend, and they come by hand.

### Recruiting the first 50 pros

Target mix across the two clusters: 15 nail techs, 12 hair stylists, 10 makeup artists, 7 lash techs, 6 brow artists. Many will list in two categories. Roughly half based inner north, half inner south, since pros cross the river but not happily.

Channels, in order of expected yield:

1. Instagram, by hand. Search location tags and hashtags (Fitzroy, Brunswick, St Kilda, "mobile nails Melbourne", "mobile hair Melbourne", "mobile makeup Melbourne"). Shortlist pros whose grid shows recent, consistent work and whose bio says mobile. DM from the founder's own account, not a brand account: a short, specific message naming a piece of their work. Aim for 200 DMs to get 50 conversations to get 25 sign-ups.
2. Referral from each signed pro. At the end of the onboarding visit, ask "who else is good?". Pros know exactly who is good and who is not. Expect 1 referral per pro, which is the second 25.
3. Facebook groups for Melbourne mobile beauty and wedding vendors. Lower quality, higher volume. Use for lash and brow, which are thinner on Instagram.
4. Beauty schools and TAFEs (Chisholm, Holmesglen, private academies) for recent graduates with a mobile business already running. They need the 3 work photos and the first booking like anyone else.

Founder-led onboarding: every one of the first 50 gets a 30-minute visit or video call with a Hair Done team member. The team member walks her through onboarding on her own phone, checks her photos are good enough, and books the first booking (see below). This is slow by design. It is how the seed data gets real and how the first 50 become advocates.

What we promise them: no joining fee, no monthly fee, the fee rules exactly as in the brief (12% from her side, $3 booking fee from the client), daily payouts, and a "Founding pro" line on her profile that never goes away. We do not promise volume, and we do not discount the fee. The first bookings come from the team.

### What makes a pro "verified"

A pro can finish onboarding and sit in "pending" indefinitely, but she only appears to clients once every one of these is true:

| Check | What it is | Who does it | Mocked in v1? |
|---|---|---|---|
| ID check | Government photo ID matched to a selfie. Name on ID must match the name on the profile | Third-party ID service, later. For v1, a team member eyeballs it on the onboarding call | Yes (photo upload stored, status flipped by the team) |
| ABN | A valid, active ABN registered to her or her business. Sole traders are fine | Looked up on ABN Lookup by the team | Yes (11-digit format check only) |
| Insurance | Public liability insurance, certificate uploaded. Optional. If uploaded and checked, her profile shows "Insured" | Team reads the certificate | Yes |
| 3 work photos minimum | Three photos of her own work, in at least one category she lists, taken by her. Screenshots of other people's work get rejected on the call | Team looks at them | Yes (count check enforced in the app) |
| First booking with a Hair Done team member | A team member books and pays for a real service through the app at the team member's home or office. The pro goes through the whole flow: request, confirm, on her way, arrived, done, paid. The team member leaves the first review. This is her first review and the first data point on reliability | Team | Real flow, real (mock) money |

Once all five are green she is "verified": the badge appears on her profile, she appears in search, Who's free and Near you, and she can turn on instant book. The badge copy is `Verified` with a small tick, and the tap-through sheet says exactly what was checked: "ID checked. ABN checked. Insured. First booking done."

Insurance being optional is a launch pragmatism: many good pros do not carry it yet, and requiring it would halve the supply. The app nudges for it after 10 bookings.

### The client side of verification

Clients verify a phone number at sign-in (mocked in v1 with a fixed code). That is enough. A client's own reliability is tracked (no-shows, late cancels) but not shown to pros in v1; it is used internally to decide whether to ask for a phone re-verification and to inform support.

---

## 5. The booking state machine

Eleven states, exactly as named in code. The diagram is a list because the transitions are what matter.

```
requested ──(pro accepts)──────────────► confirmed
requested ──(pro declines / 2h timer)──► declined
requested ──(client cancels)───────────► cancelledByClient
[instant book: pay ──────────────────► confirmed directly]

confirmed ──(pro taps On my way)───────► onHerWay
confirmed ──(client cancels)───────────► cancelledByClient
confirmed ──(pro cancels)──────────────► cancelledByPro

onHerWay  ──(pro taps I'm here)────────► arrived
onHerWay  ──(client cancels)───────────► cancelledByClient
onHerWay  ──(pro cancels)──────────────► cancelledByPro

arrived   ──(pro taps Start)───────────► inProgress
arrived   ──(pro marks no-show, 15 min)► noShow
arrived   ──(client cancels)───────────► cancelledByClient (charged as a no-show, 100%)
arrived   ──(pro cancels)──────────────► cancelledByPro

inProgress ──(pro taps Done)───────────► done
inProgress ──(system, end+12h)─────────► done (auto)

done ──(client taps Pay / tips)────────► paid
done ──(system, 12h timer)─────────────► paid (auto-capture)
```

Terminal states: `paid`, `cancelledByClient`, `cancelledByPro`, `declined`, `noShow`. A terminal booking can still receive a review (only from `paid`) and messages for 7 days.

### Each state in detail

Copy below is the status line shown on the booking card. Colour follows `brand.md`: `success` for confirmed, done and paid; `warn` for requested and pending; `inkSoft` for cancelled, declined and missed. Payment column describes the Stripe PaymentIntent (mocked by `MockPaymentService` with the same states).

| State | Who triggers | Client sees | Pro sees | Payment hold | Timers |
|---|---|---|---|---|---|
| `requested` | Client, at end of pay step, when the pro is request-to-book | Status "Waiting on Kiara", `warn` dot. Timeline: requested done, confirmed pending. "Kiara usually replies within an hour. She's got 2 hours before it goes to someone else." Cancel is free from here | New request card on Today with `Accept` and `Decline`. Client's first name, suburb (not address), services, time, what she'll earn, notes, inspo photos | Hold placed for the client total (services + travel + $3). If the start is more than 6 days away, the card is saved and the hold is placed 6 days before the start (Stripe holds expire at 7 days); the booking is still treated as held in every screen | Auto-decline 2h after request. Push to pro at 0, 60 and 105 minutes if unanswered |
| `confirmed` | Pro accepts; or instant book on successful hold | Status "Confirmed", `success`. "You're booked. Kiara's coming Saturday at 2:00 pm." Address now shown to the pro; phone numbers released both ways. Cancel policy visible in one line | Job on Today and Calendar with full address, map link, client phone. `On my way` button appears from 3 hours before start | Held. If a hold was deferred (start more than 6 days out), it is placed 6 days before start; on failure, client gets a push and 24 hours to fix her card, after which the booking is cancelled with no charge and the pro is told | Reminder pushes: client 24h and 2h before; pro 24h before and morning of |
| `onHerWay` | Pro taps `On my way` | Status "On her way". "Kiara's on her way, about 20 minutes." ETA is the pro's travel estimate from her last known location, refreshed every 60 seconds while the pro app is foregrounded, otherwise from her tap time | Big `I'm here` button. Address and client phone one tap away | Held | If the pro has not tapped I'm here by start + 20 min, client gets "Kiara's running late" and the pro gets a nudge |
| `arrived` | Pro taps `I'm here` | Status "She's here". Push: "Kiara's at your door." | `Start` button. `No show` button appears after 15 minutes | Held | 15-minute wait before No show is enabled. Client is pushed at arrival and again at 10 minutes if the pro has not tapped Start |
| `inProgress` | Pro taps `Start` | Status "In progress". Cancel disappears | `Done` button. Timer shows elapsed vs booked duration | Held | If the pro has not tapped Done by scheduled end + 2h she gets a push; at end + 12h the system marks done on her behalf and the booking shows "Marked done automatically" |
| `done` | Pro taps `Done`, or system at end + 12h | Sheet: "Done. Pay $168 to Kiara?" with tip chips (none, $10, $15, $20, custom) and `Pay $168`. Also "Something wrong?" link. Status "Done, paying" | Status "Done. Paying you." with the payout figure | Capture is queued. Client tapping `Pay` (with or without tip) captures immediately: hold captured for the total, tip charged as a second payment. "Something wrong?" pauses auto-capture for up to 48h and opens a support thread | Auto-capture 12h after done if the client has done nothing |
| `paid` | Capture succeeds | Status "Paid", `success`. "Paid. $168 to Kiara, receipt in your inbox." Rate prompt appears. `Book again` button | Status "Paid" with payout amount and expected payout date ("In your account tomorrow") | Captured. Payout line created for the daily Stripe Connect transfer | Review window: 14 days from paid |
| `cancelledByClient` | Client, from requested, confirmed, onHerWay or arrived | Status "Cancelled", `inkSoft`. Line stating what was charged: "No charge", "You paid $82.50 for late cancellation" or "You paid $168" | Status "Cancelled by client" with what she is paid: "You'll get $72.60 for the late cancellation" | From requested or ≥24h: hold released. Under 24h: partial capture of 50% of the pro's price. From arrived: capture 100% + $3 (section 7) | None |
| `cancelledByPro` | Pro, from confirmed, onHerWay or arrived | Push and status "Kiara cancelled", `inkSoft`. "You won't be charged. Sorry about that. Here's who else is free." with a Who's free strip filtered to the same category and day | Status "You cancelled". Reliability drop shown: "Reliability −10" | Hold released in full | None |
| `declined` | Pro taps Decline with a reason, or system after 2h | Status "Declined", `inkSoft`. Reason shown verbatim from the pro's chosen option: "Kiara's not free then", "Kiara doesn't travel to Elwood", "Kiara can't do that service at the moment". Auto: "Kiara didn't answer in time. Not your fault." Followed by other pros free at that time | Request card gone; appears in Calendar history as declined. Auto-declines count against reliability (−2) | Hold released | None |
| `noShow` | Pro, from arrived, after 15 minutes, having messaged the client at least once | Status "Missed", `inkSoft`. "Kiara waited 15 minutes at 8 Glenlyon Rd. You've been charged $168." "Something wrong?" link | Status "No show. You'll be paid in full." | Capture 100% of the pro's price + $3 | Client can dispute within 12h, which pauses payout (not capture) for support |

### Rules that span states

- Address is released to the pro only at `confirmed`. Before that she sees the suburb.
- Phone numbers are released both ways at `confirmed` and hidden again 24h after a terminal state.
- In-app messaging is open from `requested` until 7 days after a terminal state.
- Reschedule: with ≥24h notice the client picks a new slot and the booking stays `confirmed` with the new time; the pro is told, no acceptance needed. Under 24h, the reschedule is a request; the booking stays as is until the pro accepts the new time, and if she declines, the original stands and the client can cancel under the normal rules.
- A pro cannot mark `noShow` without having sent at least one message in the thread since `arrived`. The button is disabled with the reason until she has.
- Every transition writes a `BookingEvent { state, actor, at, note }` so the timeline on both sides is rebuilt from events, not from a single status field.

---

## 6. Pricing and fees

Exactly per the brief. The rules, then a worked example.

- The pro sets her service prices and one flat travel fee. Both show on her profile before anyone books.
- Hair Done's fee is 12% taken from the pro's side. Decision: the 12% applies to everything the pro sets, services plus travel fee, because both are her price and both are what the client pays her for.
- A $3 booking fee is charged to the client, shown on its own line, never folded into the total.
- Prices shown to the client are all-in except that fee line, which is always visible on the review step, the receipt and the booking detail.
- Tips are optional, after done, and go 100% to the pro. No fee on tips, from either side.
- Payouts are daily via Stripe Connect Express.

### Worked example: $150 gel set + $15 travel fee

What the client sees on the review step:

```
Gel set (90 min)            $150
Travel fee                   $15
Hair Done booking fee         $3
─────────────────────────────────
Total                       $168
```

Button: `Pay $168`. The hold is for $168. One sentence above the button: "We hold $168 on your card now and charge it when she's done."

What the pro sees on the job card and in Earnings:

```
Gel set                     $150
Travel fee                   $15
Hair Done fee (12%)        −$19.80
─────────────────────────────────
Your payout                $145.20
```

Hair Done's revenue on the booking: $19.80 + $3 = $22.80, which is 13.6% of the $168 the client paid.

If the client tips $15 at done: the client is charged $15 more (total $183), the pro's payout is $160.20, Hair Done's revenue is unchanged.

Rounding: fee is computed in cents, rounded half up, on the sum of the pro's lines. Display whole dollars without cents where the amount is whole ($150), otherwise two decimals ($145.20). All money is stored in integer cents.

---

## 7. Cancellation and no-show rules

From the brief: free with 24h+ notice; under 24h the client pays 50%; no-show pays 100%. Pro cancels: client refunded in full, pro's reliability score drops.

Decision: percentages apply to the pro's price (services + travel). The $3 booking fee is charged only when the pro is paid in full (done, or no-show), never on a free or late cancellation. "Notice" is measured from the moment the client taps `Cancel booking` to the booking's scheduled start.

| Situation | Client pays | Pro gets | Hair Done keeps |
|---|---|---|---|
| Client cancels while `requested` | $0 | $0 | $0 |
| Client cancels, ≥24h before start | $0 | $0 | $0 |
| Client cancels, <24h before start (including while onHerWay) | 50% of pro's price | 50% of her price less 12% | 12% of the 50% |
| Client cancels after pro has tapped `I'm here`, or pro marks no-show | 100% of pro's price + $3 | Her full payout | 12% + $3 |
| Pro cancels, any time | $0 | $0, reliability −10 (−20 if under 24h, −30 if on the day) | $0 |
| Pro declines or auto-declines | $0 | $0 (auto-decline reliability −2) | $0 |
| Booking cancelled because a deferred hold failed | $0 | $0 | $0 |

Worked examples on the same $150 gel set + $15 travel:

- Ruby cancels Thursday 9:00 am for a Saturday 2:00 pm booking. 53 hours' notice. No charge, hold released. Kiara sees "Ruby cancelled, no charge" and her calendar opens up.
- Ruby cancels Saturday 9:00 am for the 2:00 pm booking. 5 hours' notice. Client pays 50% of $165 = $82.50. Kiara's payout: $82.50 − $9.90 = $72.60. The screen says: "Less than 24 hours' notice, so Kiara keeps half. You'll pay $82.50. She's already turned down other work for you." The client confirms with `Cancel and pay $82.50`.
- Kiara arrives at 2:00, messages at 2:03 and 2:10, no answer, taps `No show` at 2:16. Client pays $165 + $3 = $168. Kiara's payout: $145.20. Client gets a push: "Kiara waited 15 minutes. You've been charged $168."
- Kiara cancels Friday for the Saturday booking. Ruby is refunded in full (hold released), sees who else is free Saturday afternoon. Kiara's reliability drops 20 points; nothing changes on her public profile (reliability is not public), but if she does this often instant book turns off (section 11).

The cancel sheet always shows the exact dollar consequence before the client confirms, and the confirm button carries the amount when it is not zero.

---

## 8. Reviews and ratings

- A review can only be written from a booking in `paid` (a real, completed, charged booking). No other path exists.
- One review per booking, by the client, within 14 days of `paid`. The prompt appears on the Paid sheet and stays on the booking card until written or the window closes.
- Stars 1–5, required. Text optional, up to 600 characters. Photos optional, up to 3, from the client's own library or camera.
- The pro can reply once, up to 400 characters, within 30 days. Her reply shows under the review with "Kiara replied".
- Reviews cannot be edited after submission in v1. A client can ask support to remove one. A pro can report one (section 11).
- Reviews show the client's first name and initial, the month, and the service booked ("Gel set · August").

### How the shown rating is computed

A new pro with two reviews, one of them a 1-star from a bad day, should not show "3.0" next to a pro with 200 reviews at 4.8. The shown rating is a Bayesian average with a prior of 4.6 over 10 reviews:

```
shown = (4.6 × 10 + sum of stars) / (10 + n)
```

rounded to one decimal, where `n` is the count of reviews and `sum of stars` their total. The count shown next to it is always the true `n`.

Examples:

- No reviews: show `New` instead of a number, and no count.
- One 5-star: (46 + 5) / 11 = 4.64 → "4.6 · 1 review".
- One 1-star: (46 + 1) / 11 = 4.27 → "4.3 · 1 review". Hurts, does not crush.
- Ten reviews, all 5: (46 + 50) / 20 = 4.8.
- 212 reviews at a raw 4.92: (46 + 1043) / 222 = 4.905 → "4.9 · 212 reviews". By here the prior has almost no weight.

The same shown value is used for sorting and for the "4.9 · 212 reviews" line everywhere. The pro sees both her shown rating and her raw average on Pro mode Profile, with a one-line explanation of why they differ.

The prior of 4.6 is chosen because it is a little under what a well-run marketplace's median pro settles at, so the number can only be earned upwards. Review the prior after 90 days against the real distribution.

---

## 9. Instant book vs request-to-book

A per-pro toggle in Pro mode Profile, default off until verified, then the app suggests turning it on.

| | Instant book | Request-to-book |
|---|---|---|
| What happens at the review step's button | `Pay $168`. Hold placed, booking goes straight to `confirmed`. Client sees the lacquer check and "You're booked." | `Request for $168`. Hold placed, booking goes to `requested`. Client sees "Sent. Kiara usually replies within an hour." |
| Pro profile label | "Instant book" chip next to the availability preview, bolt icon, `lacquer` on `lacquerSoft` | "Usually replies in 20 min" (computed from her median accept time over the last 20 requests; "Usually replies within 2 hours" if no data) |
| Who can turn it on | Verified pros with reliability ≥ 70 | Everyone verified |
| When it turns off automatically | Reliability drops below 70; pro is told why and how to earn it back | n/a |
| Client filters | "Instant book only" toggle in Near you and search | |
| Slots offered | Only real slots from her availability model (section 10). Lead time default 3 hours | Same, lead time default 2 hours. Requests outside her template are not possible in v1; the client messages her instead |

Request-to-book is the default because the first 50 pros are hand-picked and reliable, but they are also nervous about a stranger booking their Saturday without a look. Instant book is the goal for the marketplace because it removes the wait; the Who's free strip on Home prefers instant-book pros in its ordering (section 10) for the same reason.

---

## 10. Availability model

The model has four parts. Slots are computed from all four at request time; they are never stored.

### Weekly template

Per weekday, zero or more windows. `Mon 9:00–17:00`, `Thu 12:00–21:00`, `Sat 8:00–16:00`. Windows are in 15-minute increments and cannot overlap. A pro with no windows is "off" and shows no slots. Edited in Calendar → Availability.

### Exceptions

Date-specific overrides, each one of:

- Off all day (holiday, sick).
- Off for a window (school pickup 15:00–16:00).
- Extra window on a day that is normally off, or extending a day.

An exception always beats the template for that date. Edited from Calendar by long-pressing a day or via "Block time off".

### Buffer time between jobs

One value per pro: 0, 15, 30, 45 or 60 minutes. Default 30. Applied after every booking before the next one can start, on top of travel time. Covers packing up, parking, a coffee.

### Travel time estimate

For a candidate slot, travel is estimated from the pro's previous booking's address (or her base suburb if it is the first job of the day) to the candidate address, and from the candidate to her next booking's address.

v1 heuristic (no routing API): straight-line distance in km between the two points, times 3, in minutes, minimum 10, maximum 60. Coburg to Fitzroy is about 6 km straight-line, so about 18 minutes, which is close to a real drive on a normal afternoon. The estimate is shown to the client on the pro profile as "About 15 min from you" and used in the ETA on `onHerWay`. Replace with a routing API after v1; the interface is `TravelEstimator.minutes(from:to:)` so the swap is one file.

### Slot generation

Given a pro, a candidate date, a total service duration `D` (sum of the picked services' durations) and the client's address:

1. Take the windows for that date (exceptions over template).
2. Take the pro's bookings for that date in non-terminal states, each expanded by buffer on both ends plus the travel estimate to and from the candidate address.
3. Candidate start times are every 30 minutes from each window's start. A candidate `t` is available when `t..t+D` is inside a window, does not intersect any expanded booking, `t ≥ now + lead time`, and `t ≤ now + 60 days`.
4. Chips are grouped: morning (before 12:00), afternoon (12:00–16:59), evening (17:00 onwards).
5. Unavailable candidates within a window are still shown as disabled chips, each with a reason (below). Candidates outside all windows are not shown, but the day strip marks the day as "off" if it has no windows.

Reasons a chip is disabled, shown on tap in a small popover, in the pro's voice:

| Cause | Reason copy |
|---|---|
| Overlaps a booking | "Kiara's booked then" |
| Fits the window but not the buffer/travel | "Not enough time before her next job" |
| Doesn't fit `D` before window end | "She finishes at 5, this would run over" |
| Before lead time | "Too soon. Kiara needs 2 hours' notice" |
| Exception blocks it | "She's off then" |
| Client address outside her travel area | Handled earlier: the Where step warns before the time step is reached |

Travel area: a centre suburb and a radius in km (2, 5, 10, 15), plus a flat travel fee. The client's chosen address must be inside the radius or the Where step says "Kiara doesn't come to Elwood. Her area is 10 km from Coburg." with `Change address` and `Message her`.

Who's free today, on Home: pros with at least one available slot in the next 8 hours for any of their services, at the client's current or saved address, sorted by instant book first, then shown rating, then distance.

---

## 11. Trust and safety

Both sides, per the brief. Everything here ships in v1.

- Verified badge. As in section 4. Only verified pros are visible. The badge sheet lists what was checked.
- Reviews only after a completed, paid booking. Section 8.
- Share booking with a friend. From the booking detail, `Share with a friend` opens the system share sheet with a text: "I'm getting my nails done by Kiara (Hair Done) on Saturday 2:00–3:30 pm at 8 Glenlyon Rd, Brunswick East. I'll text you when she's done." No link, since there is no web in v1. The client can also nominate a friend's number on the booking so the friend gets an SMS at `arrived` and `paid`; v1 mock stores the number and logs the sends, the real SMS goes through the Supabase edge function.
- In-app messaging. Threads per booking, both sides, quick replies. Messages are stored server-side and readable by support on report. No phone numbers or addresses in the thread before `confirmed`: the client composer blocks a message that looks like a phone number or contains a street address pattern with "You'll swap numbers once she confirms."
- Address released only on confirmation. Section 5. Before that, the pro sees suburb only.
- No phone numbers until confirmed. Both sides see a `Call` button from `confirmed` until 24h after a terminal state. The number is dialled via the system dialler.
- Report and block. On a pro profile, a booking, a review, and a thread. Reasons: "Didn't show", "Not who was on the profile", "Made me uncomfortable", "Unsafe", "Work wasn't as shown", "Something else" with a text field. Report goes to the support inbox with the full thread and booking. Block hides the pro from the client everywhere and prevents the pro from seeing or messaging the client; existing bookings are cancelled by Hair Done with no charge. Pro side: same reasons adapted ("Client didn't show", "Made me uncomfortable", "Unsafe address", "Something else"); blocking a client hides her from future requests.
- Pro reliability score. Integer 0–100, starts at 100 after verification. Not public. Changes: completed on time (I'm here within 15 min of start) +1 up to 100; late arrival over 15 min −3; pro cancel −10, −20 under 24h, −30 same day; auto-decline (no answer in 2h) −2; no-show marked against her by a client dispute upheld −25. Effects: below 70, instant book turns off and she gets a message from the team; below 50, she is hidden from search until a call with the team. Clients see a `Reliable` chip on the profile when the score is ≥ 90 and she has done ≥ 5 bookings. The pro sees her exact number on Pro mode Profile with the last five changes listed.
- Client reliability. Tracked the same way (no-shows −25, late cancels −10). Not shown to anyone in v1. Below 50, the client must re-verify her phone before booking and instant book is unavailable to her.
- Location. The client's precise address is stored per booking, never on the public profile. The pro's location is only shared with the client as an ETA number, never as a pin.
- Photos. Inspo photos are visible only to the booked pro. Work photos and review photos are public. Review photos and work photos can be reported; a report hides the photo pending the team's look.

---

## 12. Notifications matrix

Push is delivered via APNs (mocked as local notifications in the simulator). In-app is a row in the Inbox tab's "Updates" list plus the status change on the booking card. Every push deep-links to the booking or thread. Quiet hours: no pushes to clients between 22:00 and 7:00 except `arrived`, `onHerWay` and `cancelledByPro` for a booking today; pros always get request pushes because a 2-hour timer is running.

| Event | Client push | Client in-app | Pro push | Pro in-app |
|---|---|---|---|---|
| Booking requested | "Sent. Kiara usually replies within an hour." | Yes | "New request: Ruby, gel set, Sat 2:00 pm, Brunswick East. $145.20 to you." | Yes, request card on Today |
| Request unanswered 60 min | — | — | "Ruby's still waiting. 1 hour left." | — |
| Request unanswered 105 min | — | — | "15 minutes left on Ruby's request." | — |
| Booking confirmed (pro accepted) | "You're booked. Kiara's coming Saturday at 2:00 pm." | Yes | — | Yes, job on Today |
| Booking confirmed (instant) | — (she's on the Booked screen) | Yes | "Booked: Ruby, gel set, Sat 2:00 pm, Brunswick East." | Yes |
| Declined by pro | "Kiara can't do Saturday. Here's who else is free." | Yes | — | Yes |
| Auto-declined | "Kiara didn't answer in time. Not your fault. Here's who else is free." | Yes | "You missed Ruby's request. It's gone to someone else." | Yes |
| Deferred hold failed | "We couldn't hold your card for Saturday. Fix it in 24 hours to keep the booking." | Yes | — | — |
| Booking cancelled (hold failed) | "Saturday with Kiara is cancelled, we couldn't hold your card." | Yes | "Ruby's Saturday booking fell through on payment. Your slot's open again." | Yes |
| Reminder 24h before | "Kiara's coming tomorrow at 2:00 pm." | — | "Tomorrow: Ruby, gel set, 2:00 pm in Brunswick East." | — |
| Reminder 2h before (client) / morning of (pro) | "Kiara's coming at 2:00 pm. Two hours to go." | — | "Today: 2 jobs. First is Ruby at 2:00 pm." | — |
| Pro on her way | "Kiara's on her way, about 20 minutes." | Yes | — | — |
| Pro running late (start + 20 min, not arrived) | "Kiara's running late. Message her?" | Yes | "You're 20 minutes past Ruby's start. Let her know." | — |
| Pro arrived | "Kiara's at your door." | Yes | — | — |
| Arrived, not started after 10 min | "Kiara's waiting outside." | — | — | — |
| No-show enabled (15 min) | — | — | "It's been 15 minutes. You can mark Ruby as a no-show." | Yes |
| Marked no-show | "Kiara waited 15 minutes. You've been charged $168." | Yes | — | Yes |
| Started | — | Yes | — | — |
| Done | "Done. Pay $168 to Kiara and tip if you like." | Yes | — | Yes |
| Auto-done reminder (end + 2h) | — | — | "Did you finish Ruby's set? Mark it done to get paid." | — |
| Paid | "Paid. $168 to Kiara, receipt in your inbox." | Yes, receipt | "Paid. $145.20 from Ruby, in your account tomorrow." | Yes |
| Tip received | — | — | "Ruby tipped $15. Lovely." | Yes |
| Rate reminder (paid + 24h, no review) | "How was Kiara? Rate her in two taps." | — | — | — |
| Review received | — | — | "Ruby left you 5 stars." | Yes |
| Pro replied to review | "Kiara replied to your review." | Yes | — | — |
| Client cancelled | — | Yes, with charge | "Ruby cancelled Saturday. [No charge / You'll get $72.60]" | Yes |
| Pro cancelled | "Kiara cancelled Saturday. You won't be charged. Here's who else is free." | Yes | — | Yes, with reliability change |
| Reschedule (≥24h) | "Moved. Kiara's now coming Sunday at 11:00 am." | Yes | "Ruby moved Saturday to Sunday 11:00 am." | Yes |
| Reschedule request (<24h) | "Sent. Kiara needs to say yes to Sunday 11:00 am." | Yes | "Ruby wants to move to Sunday 11:00 am. Yes or no?" | Yes |
| New message | "Kiara: 'Do you want a French tip or plain?'" | Yes, thread | "Ruby: 'Buzzer's broken, call when you're here.'" | Yes, thread |
| Payout sent | — | — | "$312.40 is on its way to your account." | Yes, Earnings |
| Verification complete | — | — | "You're verified. You're live on Hair Done." | Yes |
| Reliability dropped below 70 | — | — | "Instant book is off for now. Here's why." | Yes |
| Report received (either side) | In-app only: "We've got your report. Someone from Hair Done will be in touch." | Yes | Same | Yes |

Clients can turn off reminders and rate prompts in You → Notifications. Status changes for an active booking and messages cannot be turned off. Pros can turn off reminders and payout pushes; requests and status pushes cannot be turned off.

---

## 13. Analytics events

Twenty-five events. Names are snake_case, sent from the client with `mode` (`client` or `pro`), `user_id`, `session_id`, `app_version`, `os_version` and `ts` on every event; only event-specific properties are listed. No PII in properties (no names, addresses, phone numbers, message text). Money is in cents.

| # | Event | Fired when | Properties |
|---|---|---|---|
| 1 | `app_opened` | App becomes active | `source` (cold, warm, push, share), `push_type` if from push |
| 2 | `signed_in` | Sign-in completes | `method` (phone, apple), `new_account` (bool) |
| 3 | `location_permission_answered` | System prompt answered | `status` (allowed, denied, later), `in_launch_area` (bool) |
| 4 | `home_viewed` | Home appears | `time_bucket` (morning, afternoon, evening, late), `whos_free_count`, `near_you_count`, `book_again_count`, `in_launch_area` |
| 5 | `category_tapped` | Category tile tapped | `category` (hair, nails, makeup, lashes, brows, the_lot), `results_count` |
| 6 | `search_performed` | Search submitted or debounced | `query_length`, `results_count`, `has_filters` |
| 7 | `near_you_view_toggled` | List/map toggle | `view` (list, map) |
| 8 | `pro_profile_viewed` | Profile appears | `pro_id`, `source` (whos_free, near_you, search, category, favourites, book_again, share, inbox), `distance_km`, `instant_book`, `shown_rating`, `review_count`, `is_new` |
| 9 | `work_photo_viewed` | Full-screen photo opened | `pro_id`, `photo_index`, `category` |
| 10 | `pro_favourited` | Heart toggled | `pro_id`, `favourited` (bool), `source` |
| 11 | `booking_started` | Book bar tapped, sheet opens | `pro_id`, `source`, `instant_book` |
| 12 | `booking_step_completed` | The step's action button tapped | `step` (services, time, where, notes, review, pay), `elapsed_ms`, `services_count`, `total_cents` |
| 13 | `booking_abandoned` | Sheet dismissed before booked | `step`, `elapsed_ms`, `services_count` |
| 14 | `slot_unavailable_tapped` | Disabled chip tapped | `pro_id`, `reason` (booked, buffer, runs_over, too_soon, off), `days_ahead`, `time_bucket` |
| 15 | `booking_submitted` | Pay succeeds (hold placed or deferred) | `booking_id`, `pro_id`, `category`, `services_count`, `duration_min`, `services_cents`, `travel_cents`, `fee_cents`, `total_cents`, `instant_book`, `lead_hours`, `payment_method` (apple_pay, card), `hold_deferred`, `inspo_count`, `has_notes`, `address_source` (saved, current, typed) |
| 16 | `booking_confirmed` | Enters confirmed | `booking_id`, `by` (instant, pro), `accept_minutes` |
| 17 | `booking_declined` | Enters declined | `booking_id`, `reason` (not_free, area, service, auto), `minutes_open` |
| 18 | `booking_status_changed` | Any other transition | `booking_id`, `from`, `to`, `actor` (client, pro, system), `minutes_vs_scheduled` (for onHerWay, arrived, done) |
| 19 | `booking_cancelled` | Enters cancelledByClient or cancelledByPro | `booking_id`, `by` (client, pro), `hours_notice`, `charged_cents`, `from_state` |
| 20 | `no_show_marked` | Enters noShow | `booking_id`, `wait_minutes`, `messages_sent` |
| 21 | `payment_captured` | Enters paid | `booking_id`, `amount_cents`, `tip_cents`, `auto` (bool), `hours_after_done` |
| 22 | `review_submitted` | Review saved | `booking_id`, `pro_id`, `stars`, `has_text`, `photos_count`, `hours_after_paid` |
| 23 | `message_sent` | Message sent in a thread | `thread_id`, `booking_state`, `quick_reply` (bool), `chars`, `blocked_contact_details` (bool) |
| 24 | `booking_shared` | Share sheet completed | `booking_id`, `channel` (from share sheet activity type), `friend_number_added` (bool) |
| 25 | `pro_onboarding_step_completed` | Each onboarding step's action button | `step` (specialty, services, area, availability, photos, id_abn, payout, review), `elapsed_ms`, `photos_count`, `services_count`, `instant_book` |

Two derived funnels are built from these, not sent as events: booking funnel (`booking_started` → each `booking_step_completed` → `booking_submitted` → `booking_confirmed` → `payment_captured`), and pro onboarding funnel (`pro_onboarding_step_completed` by step → verification complete, which is a server-side flag).

---

## 14. Not in v1

Explicit, so nobody builds it by accident and nobody expects it.

Product

- Android, web, iPad layouts. iPhone only.
- Any city other than Melbourne; any currency other than AUD.
- Group bookings (more than one person getting done) and multi-pro bookings. "The lot" in v1 is one pro who offers a bundle.
- Recurring bookings, waitlists, "notify me when she's free".
- Promo codes, referral credits, gift cards, packages, subscriptions, loyalty.
- Salon or fixed-location bookings. Pros come to the client; a pro cannot list a location for clients to visit.
- Pros rating clients. Client reliability is tracked, not shown.
- Live map tracking of the pro. Status plus an ETA number only.
- In-app calling or masked numbers. Real numbers are released at confirmed and dialled via the system.
- Automatic SMS status texts to the nominated friend beyond the mock log (the edge function exists as a stub).
- Dispute tooling in the app beyond "Something wrong?" which opens a support thread. Refunds outside the rules in section 7 are done by the team in the Stripe dashboard.
- Editing a review after submission.
- Photo moderation by machine. Reports are handled by the team.
- Pro-set deposits, custom cancellation policies, per-service travel fees. One policy, one flat travel fee.
- Search by anything other than pro name, service name and category. No filters beyond instant book, category and "free today".
- Home screen widgets, Live Activities, Apple Watch, Siri.
- Localisation. Australian English only.
- Client accounts for men. The product is built for women; nothing in the app blocks anyone, but no copy, imagery or category is aimed elsewhere.

Tech

- Real ID verification provider. Photos are stored; a team member flips the flag.
- Real ABN lookup. Format check only.
- Real Stripe in the default build. `StripePaymentService` compiles only behind `#if canImport(StripePaymentSheet)`; the demo runs on `MockPaymentService`.
- Real Supabase in the default build. `SupabaseDataService` is a stub; the demo runs on `MockDataService`.
- Routing-API travel times. The straight-line heuristic in section 10.
- Push via a real APNs backend in the demo. Local notifications stand in.
- Swift 6 strict concurrency, Combine, third-party packages.

---

## 15. Success metrics, first 90 days

Day 0 is the day the 50th pro is verified. Metrics are measured over the two launch clusters only.

Supply

- 50 verified pros at day 0; 80 by day 90, with no category under 8.
- 60% of verified pros complete at least one booking a week by day 90 (the retention signal that matters).
- Median request accept time under 30 minutes; request acceptance rate ≥ 80%; auto-decline rate ≤ 5%.
- ≥ 40% of pros with instant book on by day 90.
- Pro cancellation rate ≤ 3% of confirmed bookings.

Demand

- 300 paid bookings by day 90, with at least 120 in the last 30 days (the slope matters more than the total).
- Booking flow completion (booking_started → booking_submitted) ≥ 45%.
- Rebooking: ≥ 35% of clients who complete a first booking complete a second within 60 days.
- Book again share: ≥ 25% of bookings after day 30 come via Book again or Favourites.
- Client no-show rate ≤ 2%; client late-cancel rate ≤ 6%.

Quality and trust

- Shown rating across paid bookings ≥ 4.7; review rate ≥ 60% of paid bookings.
- Reports ≤ 1 per 100 bookings; none unanswered by the team for more than 24 hours.
- Pro on-time rate (arrived within 15 minutes of start) ≥ 90%.
- Support contacts ≤ 5 per 100 bookings.

Money

- Take rate lands at 13–14% of client GMV (12% pro side + $3 on a roughly $120 average booking).
- Payouts land next business day for ≥ 99% of paid bookings.
- Zero bookings charged outside the rules in section 7 without a team note.

App

- Crash-free sessions ≥ 99.5%.
- Cold start to Home under 1.5 s on an iPhone 12.
- Booking flow works end to end offline against mock data on first run, every build.

If by day 45 the request acceptance rate is under 60% or the rebooking rate is under 20%, stop adding pros and fix the flow; those two numbers say whether the model works before anything else does.
