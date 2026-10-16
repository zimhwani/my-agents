# Pro Today: proposal

Mockups for the founder's sign-off. Nothing is built yet. This doc answers "Today looks kinda basic".

| Frame | File |
|---|---|
| Busy day, top | `mockups/08-pro-today-busy.png` |
| Quiet day, top (Mati's real Friday) | `mockups/09-pro-today-quiet.png` |
| Busy day, scrolled | `mockups/10-pro-today-scrolled.png` |
| Quiet day, scrolled | `mockups/11-pro-today-quiet-scrolled.png` |
| All four side by side | `mockups/00-overview-today.png` |

Rebuild with `python3 docs/design/mockups/build_today.py` (HTML next to each PNG). Each state is one scrolling column. The scrolled frame is the same column moved up, so the two frames can't disagree.

## Why it looks basic now

Not because it's plain. Because **it's mostly words about nothing**. On Mati's Friday the screen says "nothing" three times ("Nothing on today." in the day line, then again under Next up, then "Nothing tomorrow either"), shows three money tiles where two are $0, says "No new requests", and stops. Nothing on it is big, nothing is a photo, and nothing gives her something to do. On a quiet day, a pro's real question is "will I get booked, and what can I do about it?". Today doesn't answer it.

## The idea

Today answers one question in each state.

- **Busy: "what do I do next?"** The thing that expires (a request) comes first. The thing she drives to (the next job) is the one big ink object on the screen. Everything else is a quiet row.
- **Quiet: "how do I get booked?"** Show her open time as something she has, not as a gap. Then up to four things that genuinely help, then the facts that say she's good at this (rating, latest review, reliability), then the money that's on its way.

Same parts in both states: header, week strip, money row. Only the middle changes. Paper for reading, ink for the one thing she commits to (the next job, today's cell in the strip).

## What's on the screen, top to bottom

### Both states

1. **Header.** `PRO · MATI` eyebrow, then "Morning, *Mati*." in serif 40 with her cover at 32x40 top right (opens Profile, as now). The day line under it says what today is in one line: "Friday 16 October · 4 jobs · $334.40 to you" or "Friday 16 October · Nothing booked today."
2. **Week strip (`NEXT 7 DAYS`, `Calendar ›`).** Seven cells starting today. Each cell: day, date, one ink dot per booked job, a ring for an open request, and the hours still open ("5 h") or "Off". Today is the ink cell. Tap a cell to open Calendar on that day.
   *Why seven days from today and not Monday to Sunday:* on a Friday a Mon to Sun strip is mostly last week, and there's nothing to do about the past. Calendar keeps its Monday week. This is a change from the brief's "this week", so the line says "the next seven days" in substance, not "this week".
3. **Money row.** One hairline row: "$642.40 this week · $237.60 on its way", "Lands Mon 19 Oct." under it, chevron to Earnings. The full stop after the date is lacquer: the one money moment on the screen, same as the "$113 held." ticket. A $0 figure is left out rather than shown.
4. **Pro tab bar.** Unchanged: solid ink, outline glyphs, lacquer dot under Today. On the busy day Today also carries the lacquer unread dot because a request is waiting (current behaviour).

### Busy only (08, 10)

5. **New request** (only while one is open; the earliest lapse first). Eyebrow `NEW REQUEST`, and on the right a warn dot with "1 h 12 min to answer". Under it a 1pt line that empties as the two hours run down. Then "Tash wants a French tip set" (serif 22), "Tomorrow, 10:00 am · Thornbury", her note as a serif quote, "$110 to you · 1 h 30", and her first inspo photo at 56x70 on the right. `Accept` (ink fill) and `Decline` (outline) side by side. Caption: "Lapses at 12:00 pm. A lapsed request counts against you."
   *Why first:* it's the only thing on the screen that goes away without her, and lapsing costs her reliability.
6. **Next up, the ink hero.** `NEXT UP · CONFIRMED` with a success dot. The time is the biggest thing on the screen: "12:30 pm" in SF light 56. Her inspo photos (up to 2) sit beside it. Then "Ruby · BIAB overlay" (serif 24), the full address, "1 h 15 · $96.80 to you". `On my way` as a paper-filled button on the ink, then `Directions` and `Message Ruby` as text actions. The whole block opens the job.
7. **Later today.** Hairline rows: time, client name in serif, "Gel pedicure · 1 h · Fitzroy North", payout on the right. Confirmed jobs carry no badge (it's the default); anything else does.
8. **Earlier.** Today's finished jobs, same row, with the status badge ("DONE · PAYING YOU").
   The old **Tomorrow** list goes: the strip shows tomorrow, and Calendar has the detail.

### Quiet only (09, 11)

5. **Open hours.** Inside the strip block: "You've 31 hours open." (serif 28) and "You're live, so clients can book any of them." This replaces both "Nothing on today" repeats and "No new requests. Your profile's live."
6. **Get booked.** Up to four hairline rows, each with an outline glyph, one line of why, and one action. A row disappears once it's done; the section goes when all are done.
   - **Share your profile.** "Send it to your regulars, so they book you here and not in your DMs." Action: `Share` (the share sheet).
   - **Add more work photos.** "5 of 8. Close, in daylight, your own work." Her five photos as thumbnails, three empty frames. Opens Work.
   - **Open Saturday mornings.** "You start at 12 on Saturdays. Opening at 9 adds 3 hours a week." Action: `Add` (opens her hours).
   - **Instant book.** "Your ID's checked, so you can. Clients book your open hours straight in." The `HDSwitch`, off. Before her ID is checked this row reads "After your ID check" with no switch.
   No claims about demand ("most clients book mornings") and no views or analytics. We don't track them, and voice rule 15 bans social counters.
7. **Your record.** Two facts side by side, like the old money row: `RATING` with an outline star and "4.9", "23 reviews". `RELIABILITY` with "100% kept", "Only you see this." Under them, her latest review as a serif quote, "Ruby · BIAB overlay · October", and `All 23 ›`.
8. **Money row** (as above): "$80.40 on its way", "Lands Mon 19 Oct."

States not drawn are unchanged and keep their place at the top: not live (the checklist), paused, offline bar, loading skeleton, error.

## Where each section's data comes from

"Exists" means it's in the app today (`ProTodayView.swift`, `ProShared.swift`, `AppState`, models). "New" says what's needed.

| Section | Data | Source |
|---|---|---|
| Eyebrow | her name | Exists: `ProEyebrow(name: pro.displayName)`. **Bug:** `displayName` trims only spaces, so a last initial holding a newline or other non-letter gives "MATI ." Fix: keep the initial only if it's a letter; otherwise "PRO · MATI". `ProProfileEditView` line 197 builds "\(firstName) \(lastInitial)." without the empty check too. |
| Greeting, cover | time of day, cover | Exists: `ProFlow.greetingLead`, `ProFacePhoto`. |
| Day line | job count, payout total | Exists: `dayLine`. Copy changes only. |
| Request | client, services, day, suburb, notes, payout, duration | Exists: `app.openRequests`, `clientName`, `servicesLine`, `start.friendlyDayTime`, `address.suburb`, `notes`, `price.proPayoutCents`, `minutes`. |
| Request countdown | time left, lapse time | Exists: `ProFlow.deadline` / `timeLeft` (new wording), `ProgressLine(fraction:)` for the 1pt line (fraction = time left / 2 h). Today already refreshes every minute while a request is open. |
| Request photo | her first inspo | Exists: `booking.inspoURLs`. Hidden when there are none. |
| Accept style | | **Change:** today `Accept` drops to outline whenever `On my way` is live. The request now sits on paper and the job on ink, so they don't compete; keep `Accept` as an ink fill always. Never lacquer. |
| Next up hero | time, client, services, address, duration, payout, status | Exists: `nextJob`, `nextHero`. **Token:** `HDFont.timeDisplay` goes from 40 to 56 light; Today is its only user. |
| Hero photos | her inspo, up to 2 | Exists: `inspoURLs`. New on Today, hidden when there are none. |
| `On my way` | | Exists: `StatusActionButton(onInk: true)`. **New:** it shows for any confirmed job today; the spec (§5) says from 3 hours before start. Before that, the hero shows "On my way opens at 9:30 am." in its place. |
| `Message Ruby` | | New on Today: a link to the booking's thread (`app.thread(for:)` exists). `Directions` exists. |
| Later today, Earlier | | Exists: `laterToday`, `doneToday`, `ProBookingRow`. Change: payout on the right, no badge when confirmed. |
| Week strip | jobs per day, requests per day, open hours per day | Jobs and requests exist (`app.proBookings`). **New:** an open-hours helper: `availability.ranges(on:)` (already respects `daysOff`) minus her jobs that day plus `bufferMinutes`, minus time already past and `noticeMinutes` for today. Every input exists; only the sum is new. Tap: new, select that day in Calendar. |
| "31 hours open" | | New: the same helper summed over the seven days. |
| Share your profile | | Exists: the share text on `ProProfileView` (`shareText`). **Needs** the web link (`AppState.shareURL` notes `hairdonenailsdone.app/pro/<id>`) to work for people without the app; until then it sends the App Store line. New: remember she's shared (a local flag) to retire the row. |
| Work photos | count, thumbnails | Exists: `pro.work`. **New:** the target of 8 is a product call. The app only knows "3 to go live" today. |
| Saturday mornings | her hours | Exists: `availability.hours`. **New:** a simple rule. If a day she works starts at 12 or later, suggest 9 and say how many hours it adds. One hours suggestion at a time. Opens `ProHoursScreen` (Today already routes there). |
| Instant book | on/off, ID checked, reliability | Exists: `pro.instantBook`, `pro.isVerified`, `pro.reliabilityScore`, saved with `app.saveProSelf`. Shown only when off; switch only when ID checked and reliability is 70 or more. |
| Rating | shown rating, count | Exists: `pro.rating`, `pro.reviewCount`. No reviews: "New", no count (spec §8). |
| Latest review | text, first name, service, month | Exists: `pro.reviews` (newest first). `Review` has a first name only, so no initial. **New:** `All 23` needs a route from Pro mode to her reviews (the client-side Reviews screen, read-only). |
| Reliability | | Exists: `pro.reliabilityScore`. Today it shows only when under 100%; here it always shows on quiet days. |
| Money row | this week, on its way, lands | Exists: `ProMoney.payout(weekOf:)`, `app.pendingEarningsCents`, `app.nextPayoutDate`. Today's figure moves into the day line. |
| Which state | | Busy when there's a job or request today; quiet otherwise. Requests always show, in either state. |

## Copy

Every line on the four frames. Voice: build-brief §3. No em dashes, no exclamation marks.

| Where | Line | Notes |
|---|---|---|
| Eyebrow | PRO · MATI | Fixes "PRO · MATI ." |
| Greeting | Morning, *Mati*. / Afternoon, *Mati*. | Unchanged |
| Day line, busy | Friday 16 October · 4 jobs · $334.40 to you | Was "$334.40 booked". "Booked" is a status word here; "to you" is the money verb pros already see |
| Day line, quiet | Friday 16 October · Nothing booked today. | Said once. Was repeated under Next up |
| Request eyebrow | NEW REQUEST | |
| Countdown | 1 h 12 min to answer | Was "1h 12m left". The deck's "m" means metres ("800 m"), so minutes are "min". Under an hour: "48 min to answer". At the end: "About to lapse" |
| Request title | Tash wants a French tip set | `today.requests.card` |
| Request facts | Tomorrow, 10:00 am · Thornbury | |
| Request money | $110 to you · 1 h 30 | |
| Request caption | Lapses at 12:00 pm. A lapsed request counts against you. | Replaces "…left. After that it lapses and counts against you." |
| Buttons | Accept · Decline | Accept is ink |
| Hero eyebrow | NEXT UP · CONFIRMED | |
| Hero facts | Ruby · BIAB overlay / 8 Glenlyon Rd, Brunswick East / 1 h 15 · $96.80 to you | |
| Hero photos | Her inspo | |
| Hero actions | On my way · Directions · Message Ruby | |
| Before 3 hours out | On my way opens at 9:30 am. | New |
| Sections | Later today · EARLIER | |
| Service lines | Gel removal and manicure | `servicesLine` joins with " + "; rule 11 says "and" |
| Strip | NEXT 7 DAYS · Calendar · Off · 5 h | |
| Strip line, busy | 10 jobs booked, 19 hours still open. | |
| Strip, quiet | You've 31 hours open. / You're live, so clients can book any of them. | Replaces "Nothing tomorrow either. Check Calendar's got you on." and "No new requests. Your profile's live." |
| Get booked | Get booked | Section head. Same words as pro onboarding's first screen |
| Share | Share your profile / Send it to your regulars, so they book you here and not in your DMs. / Share | |
| Photos | Add more work photos / 5 of 8. Close, in daylight, your own work. | |
| Hours | Open Saturday mornings / You start at 12 on Saturdays. Opening at 9 adds 3 hours a week. / Add | |
| Instant book | Instant book / Your ID's checked, so you can. Clients book your open hours straight in. | Before ID check: "After your ID check" |
| Record | Your record · RATING · 23 reviews · RELIABILITY · 100% kept · Only you see this. · All 23 | |
| Money, busy | $642.40 this week · $237.60 on its way / Lands Mon 19 Oct. | Was three tiles with "Pending" (rule 10 bans "pending" for money) |
| Money, quiet | $80.40 on its way / Lands Mon 19 Oct. | $0 figures are left out |

## Decisions for the founder

1. **Seven days from today** for the strip, not Monday to Sunday (reason above).
2. **Accept stays ink** even while `On my way` is live.
3. **The target of 8 photos** for the nudge. Pick the number; 8 is a placeholder.
4. **Gate `On my way` to 3 hours before**, as the spec says. It isn't gated in the build today.
5. **The lacquer full stop** on "Lands Mon 19 Oct." Keep it as the one money moment, or drop it and have no lacquer on Today but the tab dots.

## Notes for the build

- Accessibility: each strip cell reads as one element ("Friday 16, today, 4 jobs, 1 hour open"). At accessibility text sizes the strip becomes seven hairline rows, as the money tiles do now. The countdown line is decorative; the words carry it.
- Dark mode: tokens swap, nothing else changes. The hero and today's cell use `inkGround` with `inkEdge`.
- Mockup type is a stand-in: Newsreader for New York, Inter for SF Pro. Photos are the bundled placeholders in `HairDone/Resources/Work/`; on the device they're her photos and the client's inspo.
