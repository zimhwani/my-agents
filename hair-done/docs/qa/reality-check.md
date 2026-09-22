# Reality check — Hair Done iOS, 22 Sep 2026

## 1. Verdict

**NEEDS WORK.** Not certified for a real user.

What this verdict is based on:

- Read: `README.md`, `docs/build-brief.md` (§3, §5, §6, §7), `docs/product-spec.md` (§5 state machine, §6 fees, §7 cancellation), `docs/qa/copy-audit.md`, all 52 Swift files under `HairDone/` (11,285 lines: App, DesignSystem, Models, Services, every Features folder), `supabase/migrations/0001_init.sql`, `0002_rls.sql`, the three edge functions, `supabase/README.md`, `config.toml`, `project.yml`, and the relevant build settings in `HairDone.xcodeproj/project.pbxproj`.
- Ran: `node …/check-swift.js HairDone` → `52 files, 0 with parse errors`. This is tree-sitter. It checks syntax only. It does not type-check, resolve overloads, check API availability, or link.
- Ran: the greps in §6 below.
- **Not done, and not possible here:** there is no Xcode, no Swift toolchain and no simulator in this environment. Nothing has been compiled, launched, tapped or screenshotted. Every "Built" in §2 means "the code for it exists and reads as complete", not "it was seen working". The first person to press Run will be the founder.

What "NEEDS WORK" rests on, in order of weight:

1. Zero compile evidence (see §5).
2. The money flow stops at "hold placed": nothing in the app or the backend captures, partially captures, or cancels a PaymentIntent (§3).
3. In a release build a booking can never reach `paid`; the only `done → paid` path is the `#if DEBUG` Simulate menu (§2, client 5).
4. Trust-and-safety items are drawn but inert: report/block is a toast, phone numbers are never released, no-show doesn't exist on either side (§2).
5. Backend state machine and RLS disagree with the spec in ways that leak data or refuse valid transitions (§3, §7).

The copy audit's 25 fixes have landed (§6). The design system matches the brief's palette, type and shape tokens. Neither of those makes it ready.

## 2. Scope coverage (build-brief §5)

Paths are relative to `hair-done/HairDone/` unless noted.

### Client

| # | Item | Status | Where | Evidence / gap |
|---|---|---|---|---|
| 1 | Welcome → phone or Apple sign-in (mocked) → name → allow location → home | Built | `Features/Onboarding/OnboardingFlow.swift` | Any AU mobile (`AUPhone.isValid`) then any 6 digits: `OnboardingCode.verify` → `MockDataService.signIn` sleeps 700 ms and returns Tash. `SignInWithAppleButton` is the real `AuthenticationServices` control with no Sign in with Apple entitlement in the project (no `.entitlements` file), so on device it will fail with an `ASAuthorizationError` and show "Apple didn't come back to us." Location: real `CLLocationManager`; deny or skip and you get Fitzroy (`LocationService.fallback`). |
| 2 | Home: greeting, Who's free, categories, Near you list/map, search, Book again | Built | `Features/Home/HomeView.swift` | All sections present. `HomeMap` is MapKit with `Annotation` pins. "Who's free" is derived from the weekly hours template only (`nextFreeLabel`), not from bookings, so a fully booked pro still shows as free. `MockDataService.pros(near:)` sorts by distance but never filters by `travelRadiusKm`; all 10 seeded pros appear wherever the device is. |
| 3 | Pro profile: cover work, name, specialty, stars/reviews, distance, comes-to, about, services, work grid, reviews, availability preview, sticky Book | Built | `Features/ProProfile/ProProfileView.swift` | Every listed element is there, including `ProfileCover` (4-tile stagger), `ProfileAvailabilityStrip` (7 days) and `StickyBar(title: "Book")`. Services can be multi-selected on the profile and carry into the flow. |
| 4 | Booking: services → day/time (real slots) → where → notes + 3 inspo → review (services, travel, fee, total) → pay (Apple Pay or card, hold now) → You're booked | Built | `Features/Booking/BookingFlowView.swift`, `BookingReviewStep.swift`, `SlotPicker.swift`, `AddressEditor.swift`, `AddCardSheet.swift` | Slots come from `MockDataService.slots` (weekly ranges, 30-min step, 30-min buffer, 90-min notice, clashes against upcoming bookings). Address: saved, "Use my location", or typed (real `CLGeocoder`, falls back to current coordinate). Inspo: real `PhotosPicker`, but the picks are discarded and replaced by `Int.random` seeds (`NotesStep.onChange`, line 511 comment says so). Review lists services, travel fee, "Hair Done fee" $3, total. Pay → `MockPaymentService.authorise` (900 ms sleep). `LacquerCheck` draws. Copy gap: review step line 143 says the hold is charged "12 hours after your booking, whichever's first"; spec and Help say 12 h after done. |
| 5 | Bookings: upcoming/past, status timeline, message, reschedule, cancel (policy shown), rate and tip | Partly | `Features/Bookings/BookingsView.swift`, `BookingDetailView.swift`, `BookingHelpers.swift`, `ReviewSheet.swift`, `Features/Booking/RescheduleSheet.swift` | Timeline, message, reschedule, cancel sheet with exact charge, and rate + tip are all built. Gaps: (a) `done → paid` exists only in `simulateMenu` behind `#if DEBUG` (`BookingDetailView.swift:322-354`); nothing in `AppState`, `MockDataService.submitReview` or the pro side moves a booking to `paid`, so in a release build every booking stops at "Done. Charging your card now." (b) Cancel is offered only for `.requested` and `.confirmed` (`actions`, line 248); spec allows cancel from `onHerWay` (50%) and `arrived` (100%). (c) `MockDataService.reschedule` drops a request-to-book pro's booking to `requested` regardless of notice; spec keeps it `confirmed` with ≥24 h. (d) After a late cancel `updateStatus` rewrites `price.servicesCents` to the charge and zeroes travel and fee, so the detail screen shows the original service rows ($150) above a total of $82.50 that they don't add up to; `receiptText` has the same problem. |
| 6 | Inbox: threads per booking, quick replies | Built | `Features/Inbox/InboxView.swift`, `ThreadView.swift` | One thread per booking, system messages, unread badges on the tab, six quick replies per side (client set uses the unit number from the address). |
| 7 | You: profile, addresses, payment methods, favourites, notifications, help, Pro mode, log out | Built | `Features/Account/AccountView.swift` | All eight rows exist and work against the mock. Notifications sheet is three `@AppStorage` toggles; it never asks for permission and nothing is ever sent. Help's "Message us" is a `mailto:`. Log out clears client state but keeps `proSelf`. |

### Pro

| # | Item | Status | Where | Evidence / gap |
|---|---|---|---|---|
| 1 | Onboarding: specialty, services and prices, travel area, availability, work photos, ID and ABN (mocked), payout setup (Connect Express, mocked) | Built (mocked) | `Features/Pro/ProOnboardingFlow.swift`, `ProShared.swift` | Seven steps, seeded starter services per specialty. "Verify ID" is `Task.sleep(1.4 s)` then `.checked`. "Set up payouts" calls `MockPaymentService.payoutOnboardingURL` which returns `https://connect.stripe.com/express/onboarding/mock`, opens it in Safari (it will 404) and then sets `payoutsOn = true` unconditionally. It passes `app.client?.id` as the pro id (line 381). Work photos are placeholder tiles (see Work). |
| 2 | Today: next job card, earnings today/week, requests with accept/decline and reason | Built | `Features/Pro/ProTodayView.swift`, `ProShared.swift` (`StatusActionButton`, `DeclineSheet`) | Next job with On my way / I'm here / Start / Mark done (four steps; the deck has three), requests with the five decline reasons plus "Something else". "Reply by 11:40 am or it lapses" is copy only: nothing in the app auto-declines. The Pending tile shows seeded `Payout` rows whose amounts don't equal the sum of their bookings (see §3). |
| 3 | Calendar: week view, availability editing, block time off | Built | `Features/Pro/ProCalendarView.swift`, `ProShared.swift` (`AvailabilityEditor`) | Week strip with dots, day detail with free gaps, one range per weekday, buffer stepper, block a day with clash warning, Save writes `proSelf.availability`. |
| 4 | Inbox, pro side | Built | `Features/Inbox/InboxView.swift` | Same view, `app.mode == .pro` flips the other party. |
| 5 | Work: upload and reorder, tag by category, pin favourites | Partly | `Features/Pro/ProWorkView.swift` | Add via `PhotosPicker` (picks discarded, `WorkItem.placeholder` with random seed), caption, tag, pin (max 4), delete, "Move to front". No drag-to-reorder beyond move-to-front. No image is ever stored or displayed. |
| 6 | Earnings: this week, pending, history, fee breakdown, tips | Built | `Features/Pro/ProEarningsView.swift` | Week total, seven bars, pending, history with per-booking rows, breakdown card, Payout details sheet. Numbers come from `ProMoney` over `proBookings` plus the seeded `Payout` list; the two sources disagree (§3). |
| 7 | Profile edit: bio, services, prices, travel fee, radius, instant book on/off | Built | `Features/Pro/ProProfileEditView.swift` | All present plus ABN, active toggle, "See it as a client". Photo change just re-rolls the avatar seed. |

### Trust and safety

| Item | Status | Where | Evidence / gap |
|---|---|---|---|
| Verified badge (ID checked) | Built | `DesignSystem/Components/Chips.swift` (`VerifiedBadge`), `ProProfileView.swift:84` explainer | Reads "ID checked" everywhere after the copy audit. Backend `pros.is_verified`, `id_checked_at`. |
| Reviews only after a completed booking | Built | `BookingsView.swift` (`canRate`), `ReviewSheet.swift` | Rate offered when `status.isFinished && review == nil`; tip section only when finished. Backend `reviews_client_insert` allows `done` or `paid` (spec: `paid` only). |
| Report / block | Partly | `ProProfileView.swift` (`ProfileReportSheet`) | Collects a reason and note, then `app.show("Sent…")` / `app.show("Blocked.")` and dismisses. Nothing is stored; the blocked pro stays in Home, her thread stays open. Backend has `reports` and `blocks` tables and the message-insert policy honours blocks; the app never writes to them. |
| Share booking details with a friend | Built | `BookingReviewStep.swift:291`, `BookingDetailView.swift:255` | `ShareLink` with the deck's line. |
| In-app messaging, no phone numbers until confirmed | Partly | `ThreadView.swift:73-79` | Messaging works. No phone number is shown to anyone at any status, so "Phone numbers are shared once she's confirmed" is a promise with nothing behind it. Backend: `profiles_counterparty` (0002_rls.sql:34) lets a pro read the client's `phone` and `email` as soon as any booking row exists, i.e. at `requested`; `bookings_party_read` (line 58) exposes the full address at `requested`. Spec releases both at `confirmed`. |
| No-show | Missing | — | No "No show" button on the pro side (`ProFlow.nextStep` has four steps and stops at `done`); `noShow` is unreachable in the app. Backend `move_booking` supports it. |
| Pro cancels → full refund, reliability drops | Partly | `ProBookingDetailView.swift:158-170`, `MockDataService.updateStatus` | Pro can cancel from confirmed/onHerWay/arrived; `reliabilityScore` never changes in the mock. Copy at line 168 says "clients see it"; spec §7 says reliability is not public. Backend drops 0.05 flat (spec: −10/−20/−30 by notice, −2 per auto-decline). |

## 3. Money rules (build-brief §6)

### Rule by rule

| Rule | In the app | In the backend | Agree? |
|---|---|---|---|
| Hold at booking, captured when the pro marks done (or auto 12 h later) | `AppState.book` calls `payments.authorise` before `data.createBooking`, keeps the returned intent id nowhere (`_ =`), and never calls `capture` or `cancelHold`. Grep: the only references to `capture(`/`cancelHold(` are the protocol and the two implementations. If `createBooking` throws `slotTaken` after `authorise` succeeded, the hold is leaked. | `create-payment-intent` creates the PI with `capture_method: "manual"`, correct amount and `application_fee_amount`, stores the id. Nothing anywhere calls `stripe.paymentIntents.capture` or `.cancel` (grep of `supabase/`: 0 hits outside the README). `stripe-webhook` maps `payment_intent.succeeded` → `paid`, but nothing causes that event. README line 41 says auto-capture should be "an edge function on a schedule"; no such function exists. `sweep_bookings` auto-declines but does not release the hold. | Hold: yes. Capture, release, auto-capture: **not implemented on either side.** |
| 12% from the pro, plus $3 to the client, fee line always shown | `Models/Booking.swift`: `Fees.platformRate = 0.12`, `Fees.bookingFeeCents = 300`. `PriceBreakdown.platformFeeCents = Int((Double(services + travel) * 0.12).rounded())`, `clientTotalCents = services + travel + 300 + tip − discount`, `proPayoutCents = services + travel − platformFee + tip`. Fee line rendered on review (`BookingReviewStep:93`), detail (`BookingDetailView:189`), receipt (`BookingHelpers:47`). | `bookings_defaults` trigger: `platform_fee_cents := round((services_cents + travel_fee_cents) * 0.12)`; `booking_fee_cents` default 300. `create-payment-intent`: `amount = services + travel + booking_fee − discount`, `application_fee_amount = round((services + travel) * 0.12) + booking_fee`, `transfer_data.destination` = pro's Express account. `PLATFORM_RATE = 0.12`, `BOOKING_FEE_CENTS = 300` in `_shared/stripe.ts`. | Yes. Rounding: Swift `.rounded()` and Postgres `round(numeric)` are both half-away-from-zero; JS `Math.round` is half-up. Identical for positive cents. |
| Travel fee: set by the pro, flat, on her profile | `Pro.travelFeeCents`; profile shows "Travel fee $15, flat" (`ProProfileView:178`); editable in onboarding and profile edit; `BookingDraft.price` copies it in. | `pros.travel_fee_cents` (check ≥ 0); `bookings.travel_fee_cents` frozen at insert. | Yes. |
| Cancellation: free ≥24 h; <24 h client pays 50%; no-show 100%; pro cancels → full refund, reliability drops | `Booking.cancellationChargeCents`: 0 if `requested` or `hoursUntil ≥ 24`; otherwise `round((services + travel) × 0.5)`. There is no 100% branch: from `arrived` it would return 50%. `cancelBody`/`cancelButtonTitle` show the amount. `MockDataService.updateStatus` on `cancelledByClient` sets `servicesCents = charge`, `travelFeeCents = 0`, `bookingFeeCents = 0`. Pro cancel: status change only; no refund logic, no reliability change. | `move_booking`: `cancelledByClient` → 0 if `requested` or `hours_until ≥ 24`, else `round((services + travel) * 0.5)`; from `arrived` also 50% (spec: 100% + $3). `noShow` → `services + travel` (spec: + $3; the $3 is dropped). `cancelledByPro` → no money logic; trigger drops reliability by 0.05. `cancellation_charge_cents` is stored but nothing captures it. Also: `move_booking` requires `is_client` for `cancelledByClient`, so the webhook's service-role call (`stripe-webhook/index.ts:39`, `auth.uid()` null) will raise `bad_transition`. | Percentages: both match each other and match spec for the 0% and 50% cases. Both get `arrived` wrong (50% instead of 100% + $3). Backend drops the $3 on no-show. Neither side moves any money. |
| Tips: optional, after done, 100% to the pro | `ReviewSheet`: chips $0/$10/$20/$30/Other, shown only when `status.isFinished`; `submitReview` sets `price.tipCents`; `proPayoutCents` adds the tip with no fee; `clientTotalCents` adds it. No second charge is made; the mock edits the number. There is no "Done. Pay $168?" sheet at `done` (spec §5); tipping is only reachable through rating. | `bookings.tip_cents` and `stripe_tip_intent_id` columns exist. No function creates the tip PaymentIntent. README says "a second PaymentIntent with no application fee". | Rule agrees; nothing charges a tip. |
| Payouts: Stripe Connect Express, daily | `MockPaymentService.payoutOnboardingURL` returns a fixed mock URL; `PayoutDetailsSheet.open` marks `payoutsConnected = true` after `openURL` returns, regardless of what happened in Safari. `Payout` rows are seeded. | `connect-onboarding`: Express, `country: "AU"`, `interval: "daily"`, `delay_days: 2`, `mcc 7230`. Webhook `account.updated` → `payouts_connected`. `payout.paid` matches `payouts.stripe_transfer_id` against a Stripe **payout** id (`po_…`), which is not a transfer id (`tr_…`), and nothing inserts `payouts`/`payout_items` rows in the first place. | Partly. Onboarding link is real; the payout ledger is not wired. |

### Worked example: $150 gel set + $15 travel (product-spec §6), by hand

`PriceBreakdown(servicesCents: 15000, travelFeeCents: 1500)` with defaults `bookingFeeCents = 300`, `tipCents = 0`, `discountCents = 0`:

| Line | Formula | Cents | `Money.format` | Spec |
|---|---|---|---|---|
| Client total | 15000 + 1500 + 300 + 0 − 0 | 16800 | `$168` (whole dollars, no cents) | $168 ✓ |
| Platform fee | round(16500 × 0.12) = round(1980.0) | 1980 | `$19.80` | $19.80 ✓ |
| Pro payout | 16500 − 1980 + 0 | 14520 | `$145.20` | $145.20 ✓ |
| Hair Done revenue | 1980 + 300 | 2280 | `$22.80` | $22.80 ✓ (13.6% of $168) |

With a $15 tip after done (`tipCents = 1500`): client total 18300 → `$183` ✓; payout 16020 → `$160.20` ✓; platform fee unchanged 1980 ✓.

Late cancel (<24 h) on the same booking: `cancellationChargeCents = round(16500 × 0.5) = 8250` → button "Cancel and pay $82.50" ✓. After `updateStatus`, `servicesCents = 8250`, travel 0, fee 0 → `platformFeeCents = round(8250 × 0.12) = 990` → `$9.90` ✓; `proPayoutCents = 8250 − 990 = 7260` → `$72.60` ✓. Matches spec §7's worked line. (But see §2 client 5(d): the detail screen still lists the original $150 row above the $82.50 total.)

Against the SQL and TypeScript, same inputs (`services_cents 15000`, `travel_fee_cents 1500`, `booking_fee_cents 300`, `discount_cents 0`):

- `bookings_defaults`: `platform_fee_cents = round(16500 * 0.12) = 1980` ✓.
- `create-payment-intent`: `amount = 15000 + 1500 + 300 − 0 = 16800` ✓; `applicationFee = Math.round(16500 × 0.12) + 300 = 1980 + 300 = 2280` ✓; the remaining 14520 is what `transfer_data.destination` would receive on capture ✓.
- `move_booking` late cancel: `cancellation_charge_cents = round(16500 * 0.5) = 8250` ✓. No-show: `16500` (spec says 16800).

The arithmetic agrees across app, SQL and TS for the happy path. What's missing is every Stripe call that would turn the arithmetic into a charge.

### Seed data that contradicts the rules on screen

`Services/MockData.swift:340-348` hard-codes payout amounts that don't equal the sum of the bookings they list, and Earnings > History renders both side by side:

- `po_1` (pending, `pb_1`, `pb_2`, `pb_7`) = 36960 → `$369.60`. Computed from the bookings: `pb_1` (9500 + 1500 − 1320 + 1000 tip) 10680 + `pb_2` (13000 + 1500 − 1740) 12760 + `pb_7` (12760 + 1500 tip) 14260 = **37700 → $377.00**. Off by $7.40.
- `po_2` (paid, `pb_8`, `pb_9`) = 24120 → `$241.20`. Computed: `pb_8` (7000 + 1500 − 1020) 7480 + `pb_9` (9500 + 1500 − 1320 + 500) 10180 = **17660 → $176.60**. Off by $64.60.

The README's "the 12% shown plainly" promise is undermined by the first history card a pro opens.

## 4. Mocked vs real: what actually happens on the device

| Area | What runs | Exactly what a tester will see |
|---|---|---|
| Sign-in, phone | `MockDataService.signIn` | Enter any number that passes `AUPhone.isValid` (04 + 8 digits). No SMS is sent. Type any six digits and it "checks" for ~700 ms then signs you in as Tash Okafor. The "Send it again" timer is a local 30 s countdown that sends nothing. There is no wrong-code path reachable. |
| Sign-in, Apple | Real `SignInWithAppleButton`, mock completion | The system sheet may appear on a signed-in device, but with no Sign in with Apple capability the request fails and the screen shows "Apple didn't come back to us. Try again, or use your phone." If it ever succeeds, the app ignores the credential and signs in as Tash. |
| Location | Real `CLLocationManager` (`Services/LocationService.swift`) | The real permission prompt appears (usage string is in the pbxproj). Allow → real coordinate and reverse-geocoded suburb; deny or "Not now" → Fitzroy (−37.7986, 144.9784). Pros are sorted by distance from wherever you are and never filtered by radius, so from Sydney every pro shows "~700 km" and "Use my location" in the booking flow will be refused as outside her travel area (`Pro.comesTo`); saved Fitzroy North / Collins St addresses still work. |
| Payments | `MockPaymentService` | The "Apple Pay" row is `ApplePayPill`, an `HStack` of an SF Symbol and the word "Pay" on a black capsule (`BookingBits.swift:105`). No `PassKit` import anywhere; no payment sheet appears. Tapping Pay sleeps 900 ms and succeeds. Cards: "Add a card" accepts any ≥12 digits with a future MM/YY and a 3–4 digit CVC; brand is guessed from the first digit; nothing is validated with Luhn or sent anywhere. The declined path exists (`failNext`) but nothing sets it, so it's unreachable in the demo. |
| Photos | Real `PhotosPicker`, discarded | The system picker opens. Whatever you choose is thrown away; the app appends `Int.random(in: 1...9_999)` seeds and draws procedural gradient tiles (`NotesStep`, `ProWorkView.add`, `ProOnboardingFlow.onChange(of: picks)`). "Change photo" on the pro profile re-rolls the avatar tint. No image bytes are kept, so nothing survives a relaunch and no photo is ever shown. |
| Push / notifications | Nothing | No `UserNotifications` import, no permission request, no token. The three toggles in You › Notifications are `@AppStorage` booleans. |
| Backend | `MockDataService`, in memory | Every screen reads seeded arrays. Changes persist only until the app is killed. `SupabaseDataService` is a stub where every method throws `DataError.network`; nothing selects it. No network call is made by the app except Apple's geocoder and MapKit tiles. |
| Timers (2 h auto-decline, 12 h auto-capture, 15-min no-show) | Nothing | Copy references all three; none run. |
| Report / block | Toast | See §2. |
| Payout setup | Opens a dead URL | `https://connect.stripe.com/express/onboarding/mock` in Safari, then the app marks payouts as connected. |

## 5. Compile risk

None of the following has been tested by a compiler. They are what reading turns up, ordered by how likely they are to be the first red line.

Items the earlier reviewers flagged as "only Xcode can settle", checked by reading:

1. **Tuple key paths, `Features/Pro/ProEarningsView.swift:80, 83, 102.** `days` is `[(day: Date, cents: Int)]`; the code uses `days.map(\.cents)` and `ForEach(days, id: \.day)`. Key paths to labelled tuple elements have been accepted by the Swift compiler since 5.4, and Xcode 16 ships a newer toolchain, so this should compile. If it doesn't, replace the tuple with a two-field struct. Low risk.
2. **`%` inside interpolated `Text`, `ProTodayView.swift:76`, `ProProfileEditView.swift:190`, `ProShared.swift:126`.** `Text("\(n)% of bookings kept")` is a `LocalizedStringKey`, so the literal goes through a format string. This compiles. The risk is rendering: if the percent sign comes out wrong or eats the next argument, switch to `Text(verbatim:)` or build the `String` first. Runtime check, not compile.
3. **ViewBuilder child count.** The two largest containers are exactly ten children: `ProProfileView.swift:38-53` (about, Hairline, services, Hairline, work, Hairline, reviews, Hairline, availability, HStack) and `ProProfileEditView.swift:52-202` (eight cards, the Save button, one `if`). Neither exceeds ten, and the iOS 17 SDK in Xcode 15+ removed the limit anyway. No risk found.
4. **`Text + Text` with `foregroundStyle`, `DesignSystem/Components/Bits.swift:235.** `Text("everything ") + Text("done").italic() + Text(".").foregroundStyle(Palette.lacquer)` needs the iOS 17 `Text.foregroundStyle(_:) -> Text` overload to win over the `View` one. It should, since `Text` is more specific. If the build complains that `+` can't take `some View`, change to `.foregroundColor(Palette.lacquer)` (deprecated, still returns `Text`). Medium-low risk; it's the one line I'd expect to see in an error first.
5. **Swift 5 mode.** `SWIFT_VERSION = 5.0` and `SWIFT_STRICT_CONCURRENCY = minimal` in both `project.pbxproj` (lines 279–280) and `project.yml`. That matches brief §7. Expect Sendable warnings (`MockDataService`, `LocationService`, `AppState` closures inside `Task`), not errors. Do not enable Swift 6 mode.

Things I found myself:

6. **Project format.** `objectVersion = 77` with a `PBXFileSystemSynchronizedRootGroup` (pbxproj lines 6, 13–19). Xcode 15 cannot open this; Xcode 16.0 or newer is required. `project.yml` is the fallback.
7. **No entitlements, no Info.plist file.** Usage strings are `INFOPLIST_KEY_*` build settings (pbxproj 258–260) with `GENERATE_INFOPLIST_FILE = YES`. Location and photo prompts will work. Sign in with Apple and Apple Pay will not (no capability).
8. **Initialiser call sites.** I checked every custom view and model initialiser call against its memberwise parameter order (e.g. `IconButton(symbol:label:filled:tint:action:)`, `HDTextField(label:placeholder:text:keyboard:contentType:axis:)`, `StickyBar` trailing closures, `Pro`, `Booking`, `Client`, `Address`, `Service`, `WorkItem`, `MessageThread`, `PaymentMethod`). No order or label mismatches found.
9. **`String(format: "%d:%02d %@", h12, min, suffix)`** (`Models/Availability.swift:34`) passes a Swift `String` to `%@`. Works on Apple platforms through bridging.
10. **`@Observable final class LocationService: NSObject, CLLocationManagerDelegate`.** Fine on iOS 17; the macro tolerates an `NSObject` superclass.
11. **`Booking`/`Pro` declare custom `==` and `hash(into:)` alongside `Codable`.** Synthesis of `Codable` is unaffected.
12. **`previewApp` is `@MainActor`** and is called inside `#Preview` blocks; fine in Xcode 16.
13. **`HomeView.searchFocused`** is a local `@FocusState` property, not the iOS 18 `.searchFocused` modifier (it tripped my API grep; see §6).

### First steps in Xcode, in order

1. Use Xcode 16.0 or later. Open `hair-done/HairDone.xcodeproj`. If Xcode refuses the file: `brew install xcodegen`, then `cd hair-done && xcodegen generate` and open the regenerated project.
2. Let indexing finish. Scheme `HairDone`. Destination: iPhone 16 (iOS 18) or iPhone 15 (iOS 17.x). Product › Build (⌘B) before Run.
3. If the build fails, read only the first error. Files most likely to be in it, in order: `DesignSystem/Components/Bits.swift` (Wordmark, line 235); `Features/Pro/ProEarningsView.swift` (lines 80–102); `Features/Pro/ProShared.swift` (`AvailabilityEditor` bindings 509–527, `ServiceEditorSheet.init` 358); `Features/Booking/BookingFlowView.swift` (`footer` trailing closures 130–179); `Features/Account/AccountView.swift` (`HDTextField` calls 183–188). `Services/PaymentService.swift` only matters once a Stripe package is added.
4. Warnings about Sendable or main-actor isolation are expected in Swift 5 mode. Leave them.
5. Run. Onboarding: any 04 number, any six digits, a name, "Not now". Home should say Fitzroy. Tap Kiara → Book → complete the flow. Bookings → tonight's booking → the `…` menu top-right is the debug Simulate menu; step it to Paid, then rate. You › Pro mode.
6. On a real phone: Signing & Capabilities → pick a Team. Don't tap Continue with Apple; use the phone path.

## 6. Consistency checks run

All greps over `HairDone/**/*.swift` unless stated. Counts are lines.

| Check | Result |
|---|---|
| Parse (`check-swift.js`, tree-sitter-swift) | 52 files, 0 parse errors. Syntax only. |
| Banned words (brief §3 list, case-insensitive, word-bounded) | **2**, both code comments: `// MARK: Discovery` in `Services/MockDataService.swift:43` and `// Discovery` in `Services/DataService.swift:16`. Neither reaches UI. 0 in string literals. "experience" as a noun: 0 (only the `yearsExperience` identifier). |
| "Hair Did" / "hairdid" / "hair_did", whole repo | **0**. |
| iOS 18-only APIs (`.zoom`, `navigationTransition`, `matchedTransitionSource`, `Tab(`, `TabSection`, `sidebarAdaptable`, `onScrollGeometryChange`, `Group(subviews:)`, `@Entry`, `presentationSizing`, `MeshGradient`, `Color.mix`, `TextRenderer`, `@Previewable`, `onScrollPhaseChange`, `.searchFocused`, `onGeometryChange`, `writingToolsBehavior`, symbol wiggle/breathe/rotate) | **0**. The regex matched 3 lines in `HomeView.swift` for `searchFocused`, which is a local `@FocusState` variable name, not the modifier. iOS 17 APIs in use (fine for a 17.0 target): `@Observable` ×2 classes, two-parameter `onChange` ×23, `Map(position:)`/`Map(initialPosition:)`, `UserAnnotation`, `Marker`, `annotationTitles`, `mapControlVisibility`, `contentMargins`, `symbolEffect`. |
| Duplicate top-level type names | **0** across 186 declarations (`struct`/`enum`/`class`/`protocol`/`typealias`). 0 duplicate `private` top-level types across files. 14 extension members that live in different files (`friendlyDayInSentence`, `hdSeed`, `minutesLabel`, `replyWindow`, …) each defined exactly once. |
| `TODO` / `FIXME` / `XXX` / `HACK` in `HairDone/` and `supabase/` | **0**. |
| Hard-coded hex colours outside `Palette.swift` and `Placeholder.swift` (`0xRRGGBB`, `#RRGGBB`, `Color(hex:`, `Color(red:`) | **0**. `Color.black`/`.white`/`.clear` literals outside those two files: 9 lines, all scrims, rings or Apple's black Apple Pay pill (`Bits.swift:215`, `Avatar.swift:25`, `Layout.swift:47`, `BookingBits.swift:113,116`, `ProProfileView.swift:400,562,573,589`). None stands in for a palette token. |
| Emoji in Swift source | **0**. |
| `!` inside string literals | **1**, `MockData.swift:331`, a seeded client message ("Hi! Any chance…"), i.e. a user's own words, which brief §3 rule 6 permits. |
| Copy-audit fixes (re-grepped 16 of the 25 "current" strings: `"Verified"`, `Verified pro`, `····`, `No-show`, `Marked as a no-show`, `All done. Your card`, `processing`, `said no`, `Having a moment`, `Pick another?`, `Replies in ~`, `Member since`, `payment provider`, `Auto-declines`, `Now Today`, `never share your location`, ` likes"`) | **0** hits each, in Swift and in the pbxproj usage string. Borderline items left as the audit suggested: `"Verify ID"` (`ProOnboardingFlow.swift:302`); `"Everything"` (`HomeView.swift:265,277`) vs `"All"` (`ProWorkView.swift:82`) still both present. |
| Interpolated `Text` containing `%` | 3 (`ProTodayView.swift:76`, `ProProfileEditView.swift:190`, `ProShared.swift:126`). |
| `Text + Text` concatenation | 1 (`Bits.swift:235`). |
| `Task.sleep` (mock latency) | 11 sites. |
| Imports of `PassKit`, `UserNotifications`, `Supabase`, `Stripe*` | 0, 0, 0, 0. Only `#if canImport(StripePaymentSheet)` in `PaymentService.swift:53`. |
| Stripe `paymentIntents.capture` / `.cancel` in `supabase/` | 0 outside `README.md`. |
| Distinct string literals with 3+ letters in UI-bearing folders (rough) | ~1,050 (audit said ~970 user-facing; the rest are identifiers and seeds). |

## Fixed straight after this pass

- `paid` is reachable in release builds: the mock charges a done booking six seconds later (`AppState.scheduleMockCapture`), standing in for the 12-hour auto-capture.
- `Booking.cancellationChargeCents` charges the full amount plus the $3 fee once she's arrived; `move_booking` does the same and adds the $3 on no-show.
- `move_booking` accepts the service role (webhook) for `confirmed`, `declined` and `cancelledByClient`, and lets an instant-book client's request confirm itself.
- Phone and email moved to `profile_contacts` (self-only); pros read bookings through `bookings_for_pro`, which hides the street address and access notes until confirmed. Edge functions updated.
- Seeded payouts now add up ($377.00 and $176.60). Hold copy on the review step and the reliability line on the pro cancel sheet corrected.

Still open from the list below: capture/cancel/partial-capture edge functions (2), report and block doing something (6), real sign-in (7), real payment UI (8), photo uploads (9), and the rest of item 10.

## 7. Before a real person uses it, in order

1. **Build and run it once in Xcode 16.** Every other line in this document is downstream of that. Fix whatever the first red line is (most likely candidates in §5).
2. **Finish the money flow in `supabase/functions`.** Capture on `done`, cancel the PaymentIntent on decline / client free-cancel / pro cancel, partial capture of `cancellation_charge_cents` on late cancel and no-show, a tip PaymentIntent, and the scheduled auto-capture (12 h) and auto-decline (2 h, and release the hold). Today a card is held and never charged or released.
3. **Make `paid` reachable outside `#if DEBUG`,** and build the spec's "Done. Pay $168?" sheet with tip chips at `done`. Right now a release build stops at "Done. Charging your card now." for ever, on both sides.
4. **Fix `move_booking`** (`0002_rls.sql:114-147`): the service-role `cancelledByClient` call from the webhook raises `bad_transition`; `arrived` must charge 100% + $3; `noShow` must add the $3; instant-book has no server path from client insert to `confirmed` (insert policy forces `requested`, `confirmed` requires `is_pro`); reliability should drop per spec §7, not a flat 0.05. Mirror the `arrived` rule in `Booking.cancellationChargeCents` and offer cancel at `onHerWay`/`arrived` in `BookingDetailView.actions`.
5. **Close the RLS privacy holes:** `profiles_counterparty` and `bookings_party_read` expose phone, email and full address at `requested`. Gate on `status <> 'requested'` (or a view that strips them). Then actually show the phone number at `confirmed` in the app, or remove the ThreadView promise.
6. **Make report and block do something:** write to `reports`/`blocks` (or the mock equivalent), remove the blocked pro from Home and close the thread. A toast is not a safety feature.
7. **Real sign-in:** Supabase phone OTP (Twilio is configured in `config.toml` but the app never calls it) and the Sign in with Apple capability. Any six digits works today; the Apple button errors.
8. **Real payment UI:** `stripe-ios` PaymentSheet behind `StripePaymentService`, the Apple Pay merchant ID and entitlement, and store the intent id `AppState.book` currently discards. Replace the hand-drawn `ApplePayPill`.
9. **Keep the photos.** Inspo (`inspo` bucket, `booking_inspo`) and work (`work` bucket, `work_items.image_path`) uploads; `WorkTile` already renders `imageURL`. Until then every picker selection is thrown away and a pro's "work" is gradients.
10. **Fix the contradictions this pass found:** review-step hold copy ("12 hours after your booking" → after done, `BookingReviewStep.swift:143`); "your reliability score drops, and clients see it" (`ProBookingDetailView.swift:168`, spec says not public); seeded payouts that don't sum (`MockData.swift:342-343`, $369.60 vs $377.00 and $241.20 vs $176.60); the late-cancel receipt showing full line items over a halved total (`MockDataService.updateStatus`); reschedule dropping request-to-book bookings to `requested` regardless of notice (`MockDataService.reschedule`); "Who's free" ignoring bookings and Near you ignoring radius (`HomeView.nextFreeLabel`, `MockDataService.pros(near:)`); the pro-side No show button that doesn't exist (`ProFlow.nextStep`).

Not in the ten but still missing before launch: push notifications (nothing is wired), the `payouts`/`payout_items` ledger and its webhook match, `pro_slots` weekday mapping (Postgres `dow` 0 = Sunday vs `Weekday.sunday = 1`), and legal pages that are more than a two-paragraph sheet.

Realistic expectation: two to three more revision cycles, the first of which is "it compiles and the happy path runs on a simulator", before this is ready for a friend to book a real nail appointment with real money.

---

Assessed by: Reality Checker, 22 Sep 2026. Evidence: this file, the greps in §6, `check-swift.js` output. No screenshots exist because nothing has run. Re-assess after a successful Xcode build and a recorded walk-through of the client and pro happy paths.
