# Copy audit — Hair Done iOS, 22 Sep 2026

Read about 970 distinct user-facing strings across 52 Swift files (Features, App, Models, DesignSystem, Services) plus the 3 Info.plist usage strings. Mock seed data, previews, comments, identifiers and SF Symbol names were skipped.
25 strings need a change. None use a banned word; the misses are wrong terms, deck contradictions, and a handful of lines that read like the bank wrote them. Another 16 are fine but worth a look.

Method: `grep -rn` for every string literal, then each file read in context so the line was judged as it renders. Checked against `build-brief.md` §2 and §3, `brand.md` "How to tell if copy is off", and `copy-deck.md`. No emoji, no exclamation marks and no American spelling anywhere in UI strings. Note that model-layer strings (`Models/Booking.swift`, `Services/PaymentService.swift`, `Services/DataService.swift`) do reach the screen through `status.label`, `clientLine`, `proLine`, `PaymentMethod.label` and `error.localizedDescription`, so they are audited as UI.

## 1. Needs a change

Paths are relative to `hair-done/HairDone/` unless noted. Where the deck already has the line, it is used verbatim and the key is named.

| # | File | Line | Current | Replace with | Why |
|---|---|---|---|---|---|
| 1 | DesignSystem/Components/Chips.swift | 51 | `Verified` | `ID checked` | Deck `profile.verified`. The badge says "Verified"; the sheet it opens (ProProfileView:84) is titled "ID checked". One thing, one name. Brief §5 calls it "verified badge (ID checked)" and the deck picks the concrete half. |
| 2 | DesignSystem/Components/Chips.swift | 54 | `Verified pro` (accessibilityLabel) | `ID checked` | Same as 1. |
| 3 | Models/Booking.swift | 33 | `\(brand) ····\(last4)` | `\(brand) ending \(last4)` | Deck `payment.card`, "Visa ending 4242". The review step (BookingReviewStep:124) already says "ending"; You > Payment methods (AccountView:94, 332) shows the dots. Same card, two spellings. |
| 4 | Models/Booking.swift | 75 | `No-show` | `Missed` | Deck `status.noShow`. BookingHelpers:86 already calls the timeline step "Missed"; the chip beside it says "No-show". "No-show" is the industry's word, "Missed" is hers. |
| 5 | Models/Booking.swift | 92 | `Marked as a no-show.` | `Missed. Charged in full.` | Deck `status.noShow`. Passive "marked as" is machine-written, and it doesn't say what happened to her money. |
| 6 | Models/Booking.swift | 87 | `All done. Your card gets charged in a bit.` | `Done. Charging your card now.` | Deck `detail.timeline.done.sub` is "Charging {price} now." Brief §6: captured when the pro marks done. "In a bit" is vague where the deck is exact. (`clientLine` has no price param; if it can be threaded through, use the deck line verbatim.) |
| 7 | Models/Booking.swift | 104 | `Done. Payment's processing.` | `Done. Your payout lands tomorrow.` | "Processing" is the bank's word. Deck `today.next.done.toast` says what happens and when. Shows on ProBookingDetailView:43. |
| 8 | Features/Pro/ProShared.swift | 131 | `Payment's processing. \(payout) to you tomorrow.` | `Done. \(payout) to you tomorrow.` | Deck `today.next.done.toast`, verbatim. Drop "processing". |
| 9 | Services/PaymentService.swift | 22 | `Your card said no. Try another one, or Apple Pay.` | `That card didn't go through. Nothing's been charged. Try another, or Apple Pay.` | Deck `payment.declined`. This string reaches the screen via AddCardSheet:113 and BookingFlowView:267 (`.other(error.localizedDescription)`). brand.md's error order is what happened, what we did, what she can do; the current line skips the middle one, which is the one about her money. |
| 10 | Services/PaymentService.swift | 24 | `Payments are having a moment. Try again in a minute.` | `Couldn't place the hold. Nothing's been charged. Try again in a minute.` | Deck `payment.hold.failed` plus the timing. "Having a moment" is a wink in place of information, and it never says whether she was charged. |
| 11 | Services/DataService.swift | 63 | `Someone just took that time. Pick another?` | `Someone just took that time. Here's what's still free.` | Deck `slot.taken`. Rhetorical question. BookingFlowView:21 already carries the deck line for the same event, so the two paths disagree. |
| 12 | Models/Availability.swift | 29 | `9 am – 5 pm` (en dash, `TimeRange.label`) | `9 am to 5 pm` | Deck `calendar.availability.hours` "{start} to {end}". Rendered on the pro week view (ProCalendarView:153); the availability editor two taps away (ProShared:480) already says "to". Nobody texts an en dash. |
| 13 | Features/ProProfile/ProProfileView.swift | 215 | `Replies in ~\(m) min` | `Replies in about \(m) min` | The tilde is code, not a word. Brief §3: concrete, like a text from a friend. |
| 14 | Features/ProProfile/ProProfileView.swift | 217 | `Replies in ~\(h) hr` | `Replies in about an hour` / `Replies in about \(h) hours` | Same as 13, and matches `replyWithin` (line 220) which already says "an hour". |
| 15 | Features/Account/AccountView.swift | 77 | `Member since \(month) \(year)` | `Booking since \(month) \(year)` | "Member" is a bank or loyalty-scheme word. She isn't a member of anything; she books. |
| 16 | Features/Account/AccountView.swift | 553 | `…Your card is held by our payment provider, never by us…` | `…Your card details go to Stripe, not to us…` | Deck `payment.secure`. "Provider" is on the never list (brief §2), and Stripe is named on every other screen (AddCardSheet:52, BookingReviewStep:146, ProEarningsView:244). |
| 17 | Features/Bookings/BookingDetailView.swift | 189 | `Hair Done booking fee` | `Hair Done fee` | Deck `booking.review.line.fee`. The review screen (BookingReviewStep:93) says "Hair Done fee"; the detail screen says "booking fee". brand.md, Money: nothing on a receipt that wasn't on the review screen, and that includes the words. |
| 18 | Features/Bookings/BookingHelpers.swift | 47 | `Hair Done booking fee  \(price)` (shared receipt) | `Hair Done fee  \(price)` | Same as 17. |
| 19 | Features/Bookings/BookingHelpers.swift | 57 | `I'm getting my \(services) done with \(pro) from Hair Done. \(day), at \(address). Booking \(ref).` | `I've got \(pro) coming \(day) at \(time), \(address.short). Booked on Hair Done.` | Deck `booked.share.text`. BookingReviewStep:265 already uses the deck line for the same share; the detail screen's share sends a different text. Also "from Hair Done" reads as if we're the pro's agency. |
| 20 | Services/MockDataService.swift | 111 | `Booking confirmed for Today, 6:15 pm.` | `Confirmed for today at 6:15 pm.` | Deck `inbox.system.confirmed`. "Booking confirmed" is the bank's SMS, and `friendlyDayTime` puts a capital "Today" mid-sentence. Use `friendlyDayInSentence`. |
| 21 | Services/MockDataService.swift | 112 | `You asked \(pro) for Today, 6:15 pm.` | `You asked for today at 6:15 pm.` | Deck `inbox.system.requested`. Same capital-Today problem. |
| 22 | Features/Booking/RescheduleSheet.swift | 37 | `Now Today, 6:15 pm · 45 min` | `Booked for today at 6:15 pm · 45 min` | "Now Today" reads as a stutter, and the capital mid-line is wrong. Use `friendlyDayInSentence`. |
| 23 | Features/Pro/ProShared.swift | 82–83 | `Auto-declines any minute` / `Auto-declines in \(duration)` | `About to lapse.` / `Reply by \(deadline.clock) or it lapses.` | Deck `today.requests.expires`. "Auto-declines" is what the system does; "lapses" is what she'd say, and the deck line says the time (brief §3 rule 4). Shows on ProTodayView:160 and ProBookingDetailView:56. |
| 24 | Features/Pro/ProWorkView.swift | 195 | `1 like` / `\(n) likes` (with a heart) | Remove the row | Instagram's word and Instagram's mechanic. Nothing on the client side lets anyone like a photo, so the number is invented. brand.md: magazine, not marketplace; stars and reviews are the only counters. If a real "saved" count exists later, "Saved by 12" is the line. |
| 25 | HairDone.xcodeproj/project.pbxproj | 259, 297 | `So we can show you who's near you right now. We never share your location with anyone.` | `Hair Done shows pros near you and works out travel fees. Only while you're in the app.` | Deck `perm.location.system`. "Never share with anyone" is a promise the app can't keep: her address goes to the pro once confirmed, and the pro sees distance from base. The deck line states the scope that actually matches the when-in-use permission. |

## 2. Fine, but borderline

For the founder to call. None of these break a rule outright.

- **Duration format.** `Formatting.swift:66–67` renders "1 hr 30 min" and "2 hr"; the deck's conventions say "1 h 30". One of them has to change, and it feeds every service row, summary and "replies within" line. Recommendation: change the deck, not the code. "45 min" already uses a word, so "1 hr 30 min" is the consistent one; "1 h 30" reads as a French-ism.
- **`Declined` chip** (`Models/Booking.swift:74`). Deck `status.declined` is "{pro} couldn't do it", but `label` has no pro param and the line under the chip already says "Kiara couldn't make it this time." Fine as a chip; "She couldn't do it" if you want it warmer.
- **`Popular` tag** (`ProProfileView:456`, `BookingFlowView:289`, `ProShared:440`) and **`Mark as popular`** (`ProShared:407`). Not in the deck. It's a marketplace word, but the alternative ("Most booked") has to be true to say it. Keep if it's pro-chosen, and say so in the toggle's caption: "Shows a small tag on your profile. Your call."
- **`Everything` chip** to clear a category (`HomeView:265, 277`). The Work tab uses "All" for the same job (`ProWorkView:82`). Pick one.
- **`212 done` tag** on the profile (`ProProfileView:197`). Cheeky and concrete, but "done" is also a status word on the same screens. "212 bookings" is duller and clearer.
- **`Not now`** on the location screen (`OnboardingFlow:566`). Deck `location.pre.skip` is "I'll type a suburb", which is better only if a suburb screen exists. The code silently falls back to Fitzroy and shows "Location's off. Showing Fitzroy." on Home. Build the suburb step, or keep "Not now".
- **`Verify ID`** button (`ProOnboardingFlow:302`). Works, but "Check my ID" would match the "ID checked" vocabulary everywhere else.
- **`Stripe Express`** as a row title (`ProOnboardingFlow:332`). It's the product's real name; fine. The deck has "Set up payouts" for the button, which the code already uses.
- **`Start`** as a fourth pro step (arrived → in progress, `ProShared:64`). The deck's flow is three steps (On my way, I'm here, Mark done). Product call, not copy.
- **`Get receipt`** (`BookingDetailView:271`) vs deck `detail.receipt` "Receipt". Either.
- **Receipt sign-off** `Paid in the app. Questions? Message us from Help.` (`BookingHelpers:51`). A question, but not a headline and not rhetorical. Fine.
- **`No worries, nothing was charged.`** (`PaymentService:23`). "No worries" is good Australian. Fine.
- **Info.plist camera and photos strings** differ from the deck's `perm.camera.system` / `perm.photos.system`, but the code lines are warmer and talk to her. Keep them; consider adding "Only the ones you pick." to the photos one, since the app uses the limited picker and that's the thing she'll want to know.
- **`Her` as a fallback name** when a pro can't be loaded (`InboxView:57`, `ThreadView:33`). Rare path, but a capital "Her" in a name slot looks like a bug. "A pro" is safer.
- **`Photo updated. Save to keep it.`** (`ProProfileEditView:66`). "Updated" is a touch system-y. "New photo. Save to keep it." if you're passing.
- **`Nothing further to simulate` / `Simulate`** (`BookingDetailView:333, 339`). `#if DEBUG` only; never ships. Ignore, but keep it behind the flag.

## 3. Voice rules to add to the brief

Based on where the misses were, not on theory.

1. **Model strings are UI.** Anything returned from a `label`, `errorDescription` or `localizedDescription` ends up on a screen. Write them from the deck. Three of the four worst lines in this audit lived in `Models/` and `Services/`, where nobody was thinking about voice.
2. **Money verbs only.** Held, charged, refunded, lands, drops off. Never "processing", "transaction", "pending payment" or "said no". Every money line says what has happened to her dollars right now.
3. **No symbols standing in for words.** "about" not "~", "to" not "–", "and" not "+". The middle dot "·" is the one separator, and it separates facts, not clauses.
4. **Day words are lowercase mid-sentence.** "today", "tomorrow" after any other word. `friendlyDay` starts a line; `friendlyDayInSentence` follows one.
5. **One name per thing, everywhere it appears.** A fee, a badge, a status or a card is called the same thing on the card, the review screen, the detail screen, the receipt and the accessibility label. If two screens name it differently, the review screen wins.
6. **Say what the system does in her words.** "lapses" not "auto-declines", "checked" not "verified", "booking since" not "member since". If the word belongs to a backend or a bank, translate it.
7. **No social counters.** No likes, followers, views or hearts. Stars and reviews are the only numbers a pro is judged by.
8. **A cute error is a failed error.** "Having a moment" and "said no" replace information with a wink. Three sentences, in order: what happened, what happened to the money, what to do.
9. **Debug-only copy is exempt, but only behind `#if DEBUG`.** If it can ship, it's UI.
