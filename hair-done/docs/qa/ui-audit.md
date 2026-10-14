# UI audit: Hair Done against the luxe direction

Date: 14 October 2026. Read against `docs/brand.md`, `docs/build-brief.md` §4, `docs/design/luxe-benchmark.md` §4, and the approved mockups 03, 04, 05, 06 and 07. Every Swift file under `HairDone/DesignSystem/` and `HairDone/Features/` was read. Nothing was compiled or run, so every finding comes from the code. Line numbers are from the current `main`.

## 1. Verdict

The three rebuilt areas (Home, the pro profile, Check it over and You're booked) are close to the mockups and look like one product. Everything else is still the old card-and-capsule app, and the seams are visible in one tap: Home's Next up card opens Bookings, which is white 18pt cards, initial avatars and pill chips; the booking detail behind it has a stock iOS nav bar, a lacquer pill button and a lacquer timeline. Pro mode is untouched and has no visual signal that she has switched sides. The cause is mostly systemic, not screen by screen: the shared tokens still encode the old direction (serif in medium weight, 18 and 14pt radii, capsule chips, lacquer as the default button and the global tint, a build brief that still says "full pill"), and the rebuilt screens each invented private tokens (`HomeFont`, `ProfileType`, `BookingInk`) instead of fixing the shared ones. Fix the tokens and the core components first and roughly half the old-style issues move with them; then rebuild Bookings, booking detail, the booking steps and Pro Today, which are the screens the founder will see next. As it stands, a tester who leaves Home will read the app as "half finished", which is the exact complaint about the last pass.

## 2. Every screen

Status key: **Luxe** matches the approved direction. **Partly** has the right bones with visible old pieces. **Old** is the pre-luxe card-and-capsule style.

| # | Screen | File | Status | Top issue |
|---|---|---|---|---|
| 1 | Tab bar (client) | `App/RootView.swift` | Luxe | Labels fixed at 10pt, no large content viewer. |
| 2 | Tab bar (pro) | `App/RootView.swift` | Partly | Identical to client; nothing says "Pro mode". |
| 3 | Toast | `App/RootView.swift` | Partly | Ink capsule; should be a squared 6pt ink bar. |
| 4 | Welcome | `Features/Onboarding/OnboardingFlow.swift` | Partly | Apple button clipped to a capsule next to a 6pt button; `preferredColorScheme(.dark)` flips the whole window. |
| 5 | Phone, code, name | `Features/Onboarding/OnboardingFlow.swift` | Old | Boxed 14pt inputs, circle back button, lacquer used as error red. |
| 6 | Location ask | `Features/Onboarding/OnboardingFlow.swift` | Old | Initial avatars and a lacquerSoft disc as the hero art. |
| 7 | Home | `Features/Home/HomeView.swift`, `HomeParts.swift` | Luxe | Near you rows have a fixed 131pt height; clips at large text. |
| 8 | Home map | `Features/Home/HomeView.swift` | Old | 18pt card, initial-avatar pins ringed in lacquer, capsule price and Recentre chips. |
| 9 | Home category filter chips | `Features/Home/HomeView.swift` | Old | "Everything" and the category as pill chips with an SF symbol. |
| 10 | Home loading skeleton | `Features/Home/HomeView.swift` | Partly | Shapes don't match the layout (squares and 230pt cards instead of 4:5 tiles and rows). |
| 11 | Pro profile | `Features/ProProfile/ProProfileView.swift` | Luxe | Saved heart turns lacquer, a second lacquer element when services are picked. |
| 12 | Work viewer | `Features/ProProfile/ProProfileView.swift` | Luxe | None of note. |
| 13 | ID checked / Instant book explainer | `Features/ProProfile/ProProfileView.swift` | Partly | Lacquer "Got it" for an acknowledgement; fixed 280pt detent. |
| 14 | All reviews sheet | `Features/ProProfile/ProProfileView.swift` | Partly | Old SheetHeader with a disc close button. |
| 15 | Report or block | `Features/ProProfile/ProProfileView.swift` | Old | 18pt cards, lacquer radio, lacquer "Block", system red destructive action. |
| 16 | Booking step 1, services | `Features/Booking/BookingFlowView.swift` | Old | SelectableCard (white, 18pt, lacquer ring and filled check), "Popular" capsule. |
| 17 | Booking step 2, time | `BookingFlowView.swift`, `SlotPicker.swift` | Old | Capsule time chips, 14pt day cells, lacquer bolt line. |
| 18 | Booking step 3, where | `BookingFlowView.swift` | Old | Cards plus three lacquer elements (icon, add link, button). |
| 19 | Address editor | `Features/Booking/AddressEditor.swift` | Old | Pill chips with icons, boxed fields, lacquer Save. |
| 20 | Booking step 4, notes | `BookingFlowView.swift` | Old | 14pt tiles, dashed "Add photos" card. |
| 21 | Booking chrome (steps 1 to 4) | `BookingFlowView.swift`, `BookingBits.swift` | Old | Disc back and close, lacquer progress segments, lacquer "Next" on every step. |
| 22 | Check it over | `Features/Booking/BookingReviewStep.swift` | Luxe | Pay buttons fixed at 56pt with scale-down text. |
| 23 | Pay with sheet | `BookingReviewStep.swift` | Old | Paper card sheet with lacquer radios pops over the ink ticket. |
| 24 | Add a card | `Features/Booking/AddCardSheet.swift` | Old | Boxed fields, lacquer button, opened from the ink screen. |
| 25 | You're booked | `BookingReviewStep.swift` | Luxe | "Add to Apple Wallet" from mockup 05 is missing. |
| 26 | Bookings | `Features/Bookings/BookingsView.swift` | Old | Pill Upcoming/Past chips, white cards, initial avatars, lacquer "Book again" on every past card. |
| 27 | Booking detail | `Features/Bookings/BookingDetailView.swift` | Old | Stock nav bar with a long truncating title, lacquer capsule Message button, lacquer timeline. |
| 28 | Cancel sheet | `BookingDetailView.swift` | Old | Lacquer button for cancelling. |
| 29 | Reschedule | `Features/Booking/RescheduleSheet.swift` | Old | Same chips and cells as step 2, paper StickyBar with lacquer. |
| 30 | Rate and tip | `Features/Bookings/ReviewSheet.swift` | Old | 72pt initials avatar, honey glow blob, pill tip chips, old disc check. |
| 31 | Inbox | `Features/Inbox/InboxView.swift` | Old | Whole list inside one 18pt white card; lacquer timestamp and dot per unread row. |
| 32 | Thread | `Features/Inbox/ThreadView.swift` | Old | Stock nav bar, pill quick replies, filled lacquer paperplane in a disc. |
| 33 | You | `Features/Account/AccountView.swift` | Old | Stack of 18pt cards, initials avatar, lacquerSoft Pro mode card. |
| 34 | Your details, Addresses, Payment methods | `AccountView.swift` | Old | `List(.insetGrouped)`, swipe-to-delete in system red, success-green "Default" capsule. |
| 35 | Notifications | `AccountView.swift` | Old | Three stock Toggles in lacquer inside a card. |
| 36 | Help, Terms | `AccountView.swift` | Old | FAQ in a card; otherwise readable. |
| 37 | Log out, delete account | `AccountView.swift` | Old | System action sheets with red, and a stock `.alert`. |
| 38 | Pro onboarding (8 screens) | `Features/Pro/ProOnboardingFlow.swift` | Old | No way out on the intro or any step (full-screen cover, no close). Tinted icon circles, pills, lacquer everywhere. |
| 39 | Today | `Features/Pro/ProTodayView.swift` | Old | Three white money tiles in serif, request cards, lacquer "Back to booking", disc gear. |
| 40 | Pro booking detail | `Features/Pro/ProBookingDetailView.swift` | Old | Stock nav bar, capsule Message and Directions, initials avatar. |
| 41 | Decline sheet | `Features/Pro/ProShared.swift` | Old | Decline is a lacquer button; lacquer radios. |
| 42 | Calendar, week | `Features/Pro/ProCalendarView.swift` | Old | System segmented `Picker`, disc chevrons, lacquer today and dots. |
| 43 | Calendar, availability | `ProCalendarView.swift`, `ProShared.swift` | Old | Seven stock Toggles, menu Pickers in boxes, stock Stepper and DatePicker. |
| 44 | Work | `Features/Pro/ProWorkView.swift` | Old | "Cover" and "Pinned" capsules on photos, lacquer pill "Add photos", tinted chips. |
| 45 | Work photo sheet | `ProWorkView.swift` | Old | Photo at 18pt radius, tinted chips, lacquer "Delete". |
| 46 | Earnings | `Features/Pro/ProEarningsView.swift` | Old | Seven lacquer bars on lacquerSoft tracks, serif money, status capsules. |
| 47 | Payout details | `ProEarningsView.swift` | Old | Card with a green filled seal, lacquer button. |
| 48 | Profile edit | `Features/Pro/ProProfileEditView.swift` | Old | Nine 18pt cards, initials avatar where clients see her cover, stock Slider and Toggles. |
| 49 | Service editor | `ProShared.swift` | Old | Tinted pill chips, stock Stepper and Toggle. |

Count: 7 luxe, 9 partly, 33 old.

## 3. Findings by severity

### 3.1 Major: system level (fix these first, they move many screens at once)

**M1. The global tint is lacquer.** `App/HairDoneApp.swift:224` sets `.tint(Palette.lacquer)` on the root. Every system control that isn't styled by hand turns lacquer: nav bar back chevrons and titles on the four pushed screens, the debug ellipsis menu, `DatePicker`, `Picker`, `ShareLink`, link text, action-sheet buttons. This alone puts two to four lacquer elements on screens that should have one.
Fix: `.tint(Palette.ink)`. Set lacquer explicitly on the few things that earn it.

**M2. Serif weight disagrees between rebuilt and old screens.** The approved screens use New York **regular** (`HomeFont.scaledSerif` `HomeParts.swift:26`, `ProfileType` `ProProfileView.swift:603-618`, `BookingInk.serif` `BookingReviewStep.swift:21`). The shared scale uses **medium** (`DesignSystem/Typography.swift:11-15`: `hero`, `title`, `heading`, `name`). So every old screen's titles ("Bookings", "Inbox", "Today", every sheet title) look heavier and more "app" than Home and the profile.
Fix: in `Typography.swift`, make `hero`, `title`, `heading`, `name` `.regular`. Then fold the three private scales into `HDFont` so there is one scale:
- `display` serif 40 regular, relative to `.largeTitle` (Home greeting, tab-root titles, "You're booked." at 42 can use it too).
- `title` serif 34 regular (step titles, "Kiara at yours.", detail headlines).
- `section` serif 26 regular, relative to `.title1` (section heads).
- `name` serif 22 regular (names in rows), `nameSmall` serif 19 (names under photos).
- `quote` serif 19 regular (bio, reviews, record lines).
- `body` 17, `sub` 15, `caption` 13, `eyebrow` 12 medium uppercase tracked 1.0.
Delete `HomeFont`, `ProfileType` and `BookingInk.serif/sans` once callers move.

**M3. Prices are set in serif in old screens.** `HDFont.priceLarge` (`Typography.swift:24`) is serif, and `HDFont.hero` is used for money (`ProEarningsView.swift:312`, `ProTodayView.swift:103, 143, 202`). Brand and benchmark P8: prices are SF with monospaced digits; the approved ticket total is SF 36 (`BookingReviewStep.swift:247`).
Fix: `priceLarge = Font.system(.title2).monospacedDigit()` (SF 22 regular); add `priceDisplay` SF 36 regular monospaced for the one big number per screen. Never serif for numbers.

**M4. Shape tokens are still the old system.** `DesignSystem/Layout.swift:17-21`: `card 18`, `tile 14`, `input 14`, `chip 999`. Only `button 6` was changed. The approved screens use 6pt for blocks and 2pt for photos and avoid cards. 38 `.card()` calls and 22 `Capsule()` shapes inherit the old look.
Fix: `card 6`, `tile 2` (photos), `input` retired in favour of an underline field, `chip` retired. Add `Radius.photo = 2`. Then remove `.card()` from lists in favour of hairline rows (see the screen specs in M10 onwards).

**M5. The build brief still specifies the old look, and it wins over everything.** `docs/build-brief.md` §4 "Shape and space" says buttons are full pills at 52, chips pills at 36, cards 20, tiles 16, inputs 14. `brand.md` says "where the two disagree, the brief wins". `brand.md` "Colour" rules 6 and 7 still put lacquerSoft and category tints on chips and tiles. The next builder who follows the brief will rebuild the old style.
Fix: update brief §4 and brand.md "Colour" to the luxe tokens (6pt blocks, 2pt photos, no capsules, no category tints in UI, lacquer only for Pay, unread, the check and the active-tab dot, ink as the default action colour). This is a docs change but it is the root cause.

**M6. Lacquer is the default button, so most screens have three or more lacquer elements.** `PrimaryButton` (`Components/Buttons.swift:4-35`) is lacquer and is used for Save, Next, Got it, Accept, Decline, Cancel, Rate, Add card, Set up payouts. Benchmark §4 keeps lacquer for the pay button, the unread dot and the check. Worst offenders:
- Booking steps 1 to 4: lacquer progress (`BookingBits.swift:16`), lacquer selected ring and check (`BookingBits.swift:37-47`), lacquer bolt (`BookingFlowView.swift:368`), lacquer location icon (`:402`), lacquer "Add an address" (`:435`), lacquer Next (`:177-206`).
- Booking detail: lacquer back (tint), timeline dots and line (`BookingDetailView.swift:409, 443-446`), Message (`:311`), Cancel (`:264`), map marker (`:169`).
- Earnings: seven lacquer bars plus lacquerSoft tracks and a lacquer weekday (`ProEarningsView.swift:343-350`).
- Calendar: lacquer today numeral (`ProCalendarView.swift:101`), lacquer booking dots (`:105`), lacquer "Today" (`:73`), lacquer Save (`:255`), seven lacquer toggles (`ProShared.swift:476`).
- Decline is a lacquer button (`ProShared.swift:207`); Cancel booking is a lacquer button (`BookingDetailView.swift:512`). Destructive actions should never borrow the commit colour.
Fix: add `InkButton` (ink fill, paper text, SF 17 semibold, radius 6, `minHeight: 52`) and `OutlineButton` (ink 1pt border, ink text, radius 6). Make `InkButton` the default. Keep `PrimaryButton` (lacquer) for `Pay $X`, `Request · $X` and nothing else. Swap every other `PrimaryButton`. `SecondaryButton` becomes `OutlineButton` on paper (no white card fill).

**M7. Capsule chips and tags everywhere.** `Chip` (`Components/Chips.swift:23-24`) and `Tag` (`:77`) are pills. They appear as segment controls (Bookings Upcoming/Past `BookingsView.swift:24`), filters (`HomeView.swift:275-276`, `ProWorkView.swift:84`), options (tips `ReviewSheet.swift:160`, km presets `ProOnboardingFlow.swift:235`, address labels `AddressEditor.swift:209`), quick replies (`ThreadView.swift:332`), and as labels on photos ("Cover", "Pinned" `ProWorkView.swift:102-103`; "Open in Maps" `BookingDetailView.swift:181`; "Directions" `ProBookingDetailView.swift:207`). Benchmark §4 retires capsules on photos and the pill shape generally.
Fix, three replacements:
- `TextTabs`: the approved List/Map pattern (`HomeParts`/`HomeView.swift:477-511`), SF 15, ink underline 1pt on the selected one, aligned to the section heading baseline. Use for Upcoming/Past, Week/Hours, Work filters.
- `OptionBox`: radius 6, 1pt `line` border, SF 15 medium, height 40 min; selected = ink fill, paper text. Use for tips, km presets, time slots, address labels, quick replies.
- Tags become text: an eyebrow line ("POPULAR", "DEFAULT", "PINNED") in 12pt tracked inkSoft beside or above the item, never on a photo.

**M8. System chrome and system red.** Four pushed screens show a stock nav bar: `BookingDetailView.swift:27, 51` (title is "BIAB overlay and 2 more with Kiara" in SF semibold, truncates), `ThreadView.swift:146, 232`, `ProBookingDetailView.swift:23-24`, `ProProfileEditView.swift:29-30`. Seven `confirmationDialog`s use `role: .destructive`, which is system red: `AccountView.swift:59, 65, 424`, `ProProfileView.swift:1075`, `BookingFlowView.swift:72`, `ProWorkView.swift:233`, `ProBookingDetailView.swift:165`. Swipe-to-delete is red (`AccountView.swift:302, 382`). One stock `.alert` (`AccountView.swift:70`).
Fix:
- `HDNavHeader`: 44pt row, bare `chevron.left` glyph (19pt regular, ink, no disc) on the left, optional serif 17 title centred, optional bare trailing glyph; hairline under it only after scroll. Hide the system bar (`.toolbar(.hidden, for: .navigationBar)`) on every pushed screen. `BookingInkIconButton` is already this component on ink; generalise it.
- `ConfirmSheet`: a short paper sheet (`.presentationDetents([.medium])`, content-sized): serif 28 question, one 15pt inkSoft sentence, `InkButton` for the action ("Cancel it", "Log out", "Delete"), text button "Keep it". No red anywhere. Use it for all seven dialogs and the alert.
- Replace swipe-to-delete with a "Remove" text button inside the edit view of each row.

**M9. Default controls with no styling.** Stock `Toggle` (`AccountView.swift:482`, `ProShared.swift:405, 469`, `ProProfileEditView.swift:391, 424`), `Stepper` (`ProShared.swift:402`, `ProCalendarView.swift:220`), segmented `Picker` (`ProCalendarView.swift:42-45`, explicitly retired by the benchmark), menu `Picker` in a 14pt box (`ProShared.swift:495-502`), compact `DatePicker` (`ProCalendarView.swift:227`), `Slider` in lacquer (`ProProfileEditView.swift:375`, `ProOnboardingFlow.swift:231`), `List(.insetGrouped)` (`AccountView.swift:272-305, 354-390`).
Fix:
- `HDSwitch`: a `ToggleStyle`, 44x26 track at radius 13 is acceptable here only if ink; better a squared 40x24 radius 6 track, `line` when off, ink when on, paper 18pt knob radius 4. No lacquer.
- `HDStepper`: value in SF 17 monospaced between two bare 44pt `minus` and `plus` glyphs in ink.
- Time ranges: show "9:00 am to 5:00 pm" as a tappable SF 15 monospaced value; tap opens a sheet with two wheel pickers and an `InkButton` "Done".
- Slider: `.tint(Palette.ink)`.
- Lists: plain `VStack` of hairline rows on paper, 20pt gutter, no inset group.

### 3.2 Major: screens still in the old style, with the luxe version spelled out

Shared rules for every rebuild below: paper ground, 20pt gutter, no `.card()`, rows separated by 1pt hairlines in `#DDD2C5` light / `line` dark (the profile's `ProfileRule`, promote it to `Palette.lineStrong`), photos at 2pt radius, serif regular for names and headlines, SF for everything else, at most one lacquer element in content. Tab-root screens get an eyebrow (12pt tracked inkSoft) above a serif 40 title.

**M10. Bookings** (`Features/Bookings/BookingsView.swift`)
- Header: eyebrow "2 COMING UP" or "NOTHING ON", then serif 40 "Bookings." (`:16-20` uses `hero` 34 medium).
- Upcoming/Past: `TextTabs`, right-aligned on the title row like List/Map in mockup 07 (`:22-28` are pill chips).
- First upcoming booking: reuse Home's ink `HomeNextUpCard` full width (`HomeView.swift:409-473`), so Home and Bookings share the same object.
- Other bookings: rows like Home's Near you. Pro cover 72x90 at 2pt radius (not `Avatar` `:133`), eyebrow status (dot plus "CONFIRMED"), serif 22 "BIAB overlay with Kiara", SF 15 inkSoft "Thu 23 Oct, 6:15 pm · at yours". Hairline under the text column. Remove the coloured "today" border (`:160-163`).
- Past rows: same, at 70% opacity on the photo only. "Book again" as an ink text link SF 15 medium (not lacquer, `:212`). Price right-aligned SF 15 monospaced inkSoft.
- Rate nudge (`:92-117`): no card and no honey border. A hairline row: serif 22 "How'd Kiara go?", five outline stars in ink at 22pt right under it, tap opens the sheet.
- Empty state: serif 28 "Nothing on. Want to change that?" left-aligned, then the Who's free rail from Home (`HomePortraitTile` at 150) so the empty screen has a photo in it.

**M11. Booking detail** (`Features/Bookings/BookingDetailView.swift`)
- Hide the nav bar; `HDNavHeader` with a bare back glyph over the photo.
- Top: reuse the record from You're booked (`BookingReviewStep.swift:779-825`) as the header: her cover full-bleed at 3:2, then eyebrow status, serif 34 "Kiara M.", serif 19 lines "Thursday 23 October, 6:15 pm / at yours in Fitzroy North / BIAB overlay · $113 held." with the lacquer full stop. She sees the same object she was handed when she booked. Remove the white pro card with initials and green seal (`:97-117`).
- Timeline (`:380-451`): keep vertical, but ink. Reached dots 8pt ink, current dot 8pt ink inside a 16pt `line` ring, future dots 8pt hollow `line`. Connector 1pt `line`. Times SF 13 monospaced inkSoft. No lacquer, no card.
- When/Where/What: receipt rows (label SF 15 inkSoft left, value SF 17 ink right) with `lineStrong` hairlines, like the profile price list. Total SF 28 monospaced. Remove the `.card()` (`:207, 251`).
- Map: 2pt radius, no border, no capsule. "Open in Maps" as an SF 15 ink text link under it with an outline `arrow.up.right` glyph.
- Actions at the bottom: `InkButton` "Message Kiara" (not the lacquer capsule `:305-311`), `OutlineButton` "Reschedule", text button "Cancel booking" in inkSoft (not lacquer `:264`). Rate: `InkButton` "Rate Kiara".
- Cancel sheet (`:489-520`): `ConfirmSheet`, amount in SF 28 monospaced, `InkButton` "Cancel it" or "Cancel and pay $56.50".

**M12. Booking steps 1 to 4** (`Features/Booking/BookingFlowView.swift`, `BookingBits.swift`, `SlotPicker.swift`)
- Chrome (`:115-128`): bare chevron and xmark glyphs in ink (like the ink header), centred eyebrow "2 OF 5", and a 1pt ink progress line across the full width under the header instead of six lacquer segments.
- Footer: carry the profile's ink Book bar through the flow (`ProProfileView.swift:533-580`): ink ground, serif 21 "Kiara" plus SF 15 summary on the left, squared paper button on the right ("Pick a time", "Next", "Review"). The bar is the same object from profile to review, and the ground turns ink on review. Retire the paper `StickyBar` with a lacquer button.
- Services: the profile price list, not cards. Rows: name SF 17 left, duration SF 15 inkSoft and price SF 17 monospaced right, hairlines between, selected = semibold plus a small ink check glyph (the profile already does this, `ProProfileView.swift:757-807`, minus the lacquer check). Detail line SF 13 inkSoft under the name. "Popular" as eyebrow text.
- Time: day strip as plain columns, weekday SF 13 inkSoft over date SF 20 monospaced; selected = ink 6pt square behind with paper text; off days at 35% opacity. No white cells, no 14pt radius (`SlotPicker.swift:370-375`). Slots as `OptionBox` at radius 6, SF 17 monospaced, in a 3-column grid; unavailable at 35% with no border. Period labels as eyebrows. Instant book line in inkSoft with an outline `bolt` glyph (not lacquer, `BookingFlowView.swift:362-368`).
- Where: hairline rows. Leading outline glyph in ink (`location`, `house`), label SF 17, address SF 15 inkSoft, ink check when picked. "Add an address" as an ink text row with an outline `plus`. Getting-in note as an underline field (see M18).
- Notes: underline field, inspo tiles 104x130 at 2pt radius, "Add photos" as an `OutlineButton`-styled 104x130 tile with a 1pt `line` border and an outline `plus` (no dashes, no white fill).
- Out-of-area note (`InlineNote` `BookingBits.swift:57-80`): no tinted box. One SF 15 ink line with a 6pt warn dot.

**M13. Pay with and Add a card sheets** (`BookingReviewStep.swift:515-603`, `AddCardSheet.swift`)
These open over the ink ticket and drop her back onto paper cards with lacquer radios. Make both ink sheets: `.presentationBackground(BookingInk.inkGround)`, rows with `BookingInk.inkLine` hairlines, paper type, ink-on-paper check glyph for the selected method, fields as paper underlines on ink. "Default" as eyebrow text. The add-card button `InkButton` inverted (paper fill, ink text, radius 6) like the profile's Book.

**M14. Inbox** (`Features/Inbox/InboxView.swift`)
- Remove the card wrapper (`:31`). Rows full width with hairlines aligned to the text column.
- Avatar 44 stays (benchmark allows avatars in Inbox), but the avatar should show her cover photo cropped to a circle for pros; initials only for clients.
- Name serif 19 regular (semibold SF when unread is not needed; use ink vs inkSoft for unread). Preview SF 15. Time SF 13 inkSoft always (not lacquer `:84`). Unread = 8pt lacquer dot only (`:97`).
- Header: eyebrow "1 UNREAD", serif 40 "Inbox."
- Pin the Hair Done desk thread first when it exists (benchmark non-negotiable 6).

**M15. Thread** (`Features/Inbox/ThreadView.swift`)
- `HDNavHeader`: bare back glyph, centred avatar 28 plus serif 17 name.
- Booking strip (`:260-286`): paper, not white card. Pro's cover 36x45 at 2pt, SF 15 ink line, SF 13 inkSoft line, status dot, hairline under.
- Bubbles: radius 6 with the tucked corner at 2 (`BubbleShape` `:385` uses 18 and 5). Mine ink, hers paper with a 1pt `line` border (not white card).
- Quick replies: `OptionBox` row, SF 15, radius 6.
- Composer: underline field (1pt ink rule), send as a bare outline `arrow.up` glyph in ink that becomes a 32pt ink square with a paper arrow when there's text. Not a filled lacquer paperplane in a disc (`:350`).

**M16. You** (`Features/Account/AccountView.swift`)
- Header: eyebrow "BOOKING SINCE MARCH 2026", serif 40 "Tash." No initials avatar (`:103`).
- Settings: hairline rows, no card (`:118-131`). Leading glyphs either removed or outline at `.light` weight in inkSoft; value SF 15 inkSoft; bare chevron.
- Favourites: reuse `HomePortraitTile` at 120 in a horizontal rail (retire `ProMiniTile`, `ProCard.swift:79-93`).
- Pro mode (`:171-190`): no lacquerSoft card and no DropMark. A full-width ink row: ink ground, paper serif 22 "Pro mode", SF 15 paper 70% "Kiara M. · 2 requests waiting", paper chevron. It previews the ink signal that pro mode carries (section 4).
- Log out and Delete account as text buttons; Delete in inkSoft, never inkFaint (contrast, see m3).
- Sheets: Details with underline fields and `InkButton` Save; Addresses and Payments as hairline rows with Remove inside each edit view; Notifications with `HDSwitch`; Help as hairline FAQ rows with serif 19 answers.

**M17. Pro mode screens** (`Features/Pro/*`)

*Today* (`ProTodayView.swift`)
- Header: eyebrow "TUESDAY 14 OCTOBER", serif 40 "Afternoon, *Kiara*." (the one italic). The disc gear (`:84`) becomes her cover at 32x40, 2pt radius, top right, opening a pro "You" sheet (profile edit, payout details, "Switch to booking", log out). Remove the lacquer "Back to booking" link (`:80`).
- Next job is the hero, before requests: an ink block like Home's Next up but full width and taller (about 220pt). Time SF 40 light monospaced paper ("6:15 pm"), serif 24 paper "Tash · BIAB overlay", SF 15 paper 70% address, then a paper 6pt button for the one action ("On my way") and a paper text link "Directions". Not a white card with a serif `hero` time (`:195-239`).
- Money: one facts row, not three cards (`:92-111`). Three columns separated by 1pt vertical hairlines: eyebrow label over SF 22 monospaced amount. "Today $230 | This week $1,140 | Pending $410".
- Requests: hairline rows. Eyebrow "REPLY BY 11:40 AM" in inkSoft (not warn text, see m4), serif 22 "Tash wants BIAB overlay", SF 15 inkSoft "Thu 6:15 pm · Fitzroy North", her note in serif italic 17, "$83 to you" SF 17 monospaced. `InkButton` "Accept" and `OutlineButton` "Decline", each 44pt tall, side by side.
- Later today, Tomorrow: rows with time SF 15 monospaced in a fixed column, name serif 19, service SF 13 inkSoft, status dot plus label. Drop the 3pt coloured capsule bar (`ProShared.swift:246`).

*Pro booking detail* (`ProBookingDetailView.swift`): `HDNavHeader`. Header eyebrow status, serif 34 "Tash, 6:15 pm." Map at 2pt, "Directions" as an ink text link under it. Money as receipt rows; "To you" SF 28 monospaced. Accept `InkButton`, Decline `OutlineButton`. Message `OutlineButton` (not the capsule `:151-152`). Cancel as an inkSoft text button opening `ConfirmSheet`.

*Decline sheet* (`ProShared.swift:157-229`): reasons as hairline rows with an ink check; `InkButton` "Decline". No lacquer radio, no lacquer button.

*Calendar* (`ProCalendarView.swift`): serif 40 "Calendar." with `TextTabs` "Week | Hours" on the title row (replace the segmented Picker). Week: bare chevrons either side of SF 15 "Week of 13 Oct"; day strip as plain columns (no card): weekday SF 13 inkSoft, date SF 20 monospaced, selected = ink 6pt square with paper text, today = 1pt ink underline, booking dots 4pt inkSoft. Day detail: serif 28 "Thursday", rows as on Today, free gaps as SF 13 inkSoft "Free 1:00 to 3:30 pm". Hours: one hairline row per weekday ("Monday" SF 17, "9:00 am to 5:00 pm" SF 15 monospaced right, or "Off" inkSoft), tap opens the wheel sheet with an `HDSwitch` for off. Buffer row with `HDStepper`. Days off: hairline rows with "Unblock". Save as an ink bar pinned to the bottom that slides up only when something changed.

*Work* (`ProWorkView.swift`): serif 40 "Work." with SF 15 inkSoft count line. Grid identical to the profile's "Her work" grid (3 columns, 2pt gaps, 2pt radius, `ProProfileView.swift:419`), so she sees what clients see. The cover tile spans two columns and two rows. Pinned photos get a 16pt paper square at the top-right corner with an outline `pin` glyph in ink, no capsule. Filters as `TextTabs` in serif 17 (like Home's category words). "Add photos" as `InkButton`. Photo sheet: photo 4:5 at 2pt on an ink ground like the profile viewer, caption underline field, tag `TextTabs`, Pin and Delete as text rows; Delete in ink.

*Earnings* (`ProEarningsView.swift`): eyebrow "THIS WEEK", the one big number SF 56 light monospaced ("$1,140"), SF 15 inkSoft comparison line. Bars: ink for days with money, `line` for empty days, 2pt radius, no tracks; weekday letters inkSoft, today ink semibold. Pending as one hairline row. Breakdown as receipt rows, tips in ink with a "+" (not green), total SF 28. History as hairline rows with status as dot plus label, not capsules (`:431-433`). Payout details as a hairline row.

*Profile edit* (`ProProfileEditView.swift`): lead with what clients see: her cover full width at 4:5 with her name in paper serif 48 on it (reuse the profile hero), "Change cover" as a paper text button over the bottom right. Remove the initials avatar (`:303`); it isn't shown to clients anywhere. Sections separated by eyebrows and hairlines, not nine cards (`:456-463`). Fields as underlines. Services as the price-list rows with "Edit" in ink. Instant book and Taking bookings with `HDSwitch`. Save as the slide-up ink bar.

*Pro onboarding* (`ProOnboardingFlow.swift`): add a bare xmark on every step including the intro (see m1). Header as in M12 (eyebrow "3 OF 7", 1pt ink line). Titles serif 34 regular. Specialty step: the Home category photo tiles (104x130 at 2pt, serif 16 word under), selected at full opacity with an ink check under the word, unselected at 45%. Not tinted circles with SF symbols (`:175-176`) and no "Main" lacquer tag (`:182`); say "First pick is your main label" in the sub-line. Travel: ink slider and `OptionBox` presets. Work: the Work grid. Done: the bare lacquer check from You're booked and serif 40 "You're on."

**M18. Inputs are boxed 14pt fields.** `HDTextField` (`Components/Bits.swift:105-127`), phone and name fields (`OnboardingFlow.swift:259-270, 514-523`), review text and tip (`ReviewSheet.swift:119-126, 171-181`), composer (`ThreadView.swift:341-348`). Home's search field is the approved input: a 1pt ink rule under SF 17 text (`HomeView.swift:369-405`).
Fix: restyle `HDTextField` as label SF 13 inkSoft above, text SF 17, 1pt `line` rule under, 2pt ink rule when focused, 1pt warn rule plus a SF 13 ink message when invalid. Use it everywhere.

**M19. Lacquer is used as error red.** `OnboardingError` sets the message in lacquer (`OnboardingFlow.swift:114`) and field borders turn lacquer (`:270, 466, 523`). This is the "system red" the founder rejected, and brand rule 3 says never lacquer body text.
Fix: message in ink SF 13 with a 6pt warn dot before it; field rule in warn.

**M20. Pro onboarding traps her.** `ProOnboardingFlow` is a full-screen cover (`AccountView.swift:81-86`) with no close button on any step; the intro has no back either (`ProOnboardingFlow.swift:48`). Once opened she can't leave without finishing.
Fix: bare xmark top right on every step, opening `ConfirmSheet` "Leave pro setup? What you've done so far is kept." This is also a function bug, not only polish.

**M21. Placeholder and stand-in photos show other women's work as hers.** `BundledWork.image` (`Components/Placeholder.swift:145-157`) returns a bundled stock work photo for any `WorkItem` without a URL. New uploads in Work and pro onboarding (`ProShared.swift:279-281`) and inspo picks (`BookingFlowView.swift:536-543`) are given random seeds, so the photo she just picked shows up as someone else's work. With 19 bundled photos (one for makeup, two for lashes) the same picture repeats across pros, which benchmark P2 says reads as fake fastest.
Fix: for anything she picks, keep the picked image (load `PhotosPickerItem` data into the item) or show the procedural art, never a bundled photo. Restrict `BundledWork` to seeded demo pros, and give each demo pro a fixed, distinct set.

**M22. Profile photo change does nothing visible.** `ProProfileEditView.swift:309-313` re-rolls `seed` and toasts "Photo updated", but `Avatar` ignores the seed (`Components/Avatar.swift:12`, same oat fill for everyone). She taps, is told it changed, and nothing changes. Goes away with M17's cover-first layout.

**M23. Dark mode: white on dark lacquer fails contrast.** `Palette.lacquer` dark is `#E2504F` (`Palette.swift:14`); white text on it is about 3.8:1, below AA for 17pt semibold. Every lacquer button in dark mode fails, including Pay.
Fix: keep the fill at `#C8323A` in dark for filled buttons (about 5.3:1 with paper text) via a `Palette.lacquerFill` token, and keep `#E2504F` for dots and strokes only. Also set `onLacquer` to paper `#FBF7F2`, not pure white (`Palette.swift:21`, brand rule 8).

**M24. Dark mode: the ink moments disappear.** Home's Next up card is fixed `#241A16` (`HomeParts.swift:32`) on dark paper `#171210`: about 1.1:1, so the card has no edge. The booking flow "turns to ink" from `#171210` to `#241A16` (`BookingFlowView.swift:61-69`, `BookingReviewStep.swift:9`), which is a step lighter, so the commit ceremony reads as nothing in dark mode.
Fix: add `Palette.inkGround = dyn(light: 0x241A16, dark: 0x0E0A09)` and `Palette.inkRaised = dyn(light: 0x2E231E, dark: 0x1F1815)`, use them for the Next up card, the ticket ground and the Book bar, and add a 0.5pt `onInk` 10% hairline around ink blocks that sit on paper. The profile already does a version of this (`ProProfileView.swift:594`).

### 3.3 Minor: polish

Type and colour
- m2. Two eyebrow styles. Rebuilt screens use `HDFont.eyebrow` medium, tracking 1 (`HomeParts.swift:41-45`, `ProProfileView.swift:623-629`); old screens use `labelStyle()` semibold, tracking 1.2 (`Typography.swift:32-38`). Make `labelStyle()` medium and tracking 1.0, delete `homeEyebrow` and `profileEyebrow`.
- m3. `inkFaint` is used for text and fails contrast (about 2.5:1 light, 3.9:1 dark): "Report or block" `ProProfileView.swift:62`, "Delete account" `AccountView.swift:47`, thread caption `InboxView.swift:93`, bubble times `ThreadView.swift:315`, "Card details go to Stripe" `BookingReviewStep.swift:581`, resend countdown `OnboardingFlow.swift:389`. Use inkSoft for any text. Keep inkFaint for glyphs and disabled fills only.
- m4. `warn` as text fails AA at 13pt (about 3.4:1): `ProTodayView.swift:160`, `ProBookingDetailView.swift:56`, `ProCalendarView.swift:206, 234`, `ProWorkView.swift:208`, `ProOnboardingFlow.swift:298, 310`. Set the text in ink and put a 6pt warn dot before it.
- m5. Ratings: Home rows use a filled honey star (`HomeParts.swift:257`); mockup 07 and the profile use an ink outline star. Use `star` outline in inkSoft at the text size on Home. Honey stays for the rating picker only (brand "the honey star fills").
- m6. `VerifiedBadge` is a green filled seal (`Chips.swift:186-197`), used in booking detail, profile edit and onboarding. The approved profile says "ID checked" in plain inkSoft text. Make the badge text-only.
- m7. Success green for "Free", tips and "Default" (`BookingReviewStep.swift:617`, `ProEarningsView.swift:402, 447`, `ProBookingDetailView.swift:114`, `AccountView.swift:369`). Brand rule 5 keeps success for status. Use ink.
- m8. Category tints still drive chips (`ProShared.swift:384`, `ProWorkView.swift:84, 200`, `ProProfileEditView.swift:502`) and onboarding icons (`ProOnboardingFlow.swift:175-176`). Retired by the benchmark. Remove `Palette.tint` and `tintInk` from UI use once M7 and M17 land.
- m9. Section gap is 36 (`Layout.swift:15`); brief says 32. Pick one and write it into the brief.

Icons
- m10. Mixed SF Symbol weights and fills: tab bar `.light` 21 (`RootView.swift:158`), `IconButton` `.medium` 17 in a disc, `NavRow` `.medium` 16, chevrons `.semibold` 13, and filled glyphs where outline is the rule: `checkmark.circle.fill` (`BookingBits.swift:37`, `BookingReviewStep.swift:634`, `ProOnboardingFlow.swift:183`), `largecircle.fill.circle` (`ProProfileView.swift:1034`, `ProShared.swift:184`), `paperplane.fill`, `bolt.fill`, `location.fill`, `checkmark.seal.fill`, `xmark.circle.fill` (`HomeView.swift:389`). Rule: outline glyphs only, `.light` weight at 17 to 21pt or `.regular` at 13 to 15pt, ink or inkSoft. Selection shown with an ink `checkmark` (no circle).
- m11. Pro tab icons `sun.max`, `photo.on.rectangle`, `dollarsign.circle` (`RootView.swift:82-86`) read as stock and fintech. Benchmark asks for drawn 1.25pt outline glyphs. Until they're drawn, prefer `sun.horizon`, `square.grid.2x2`, `chart.bar` at `.light`.
- m12. `IconButton` (`Buttons.swift:81-101`) is a white disc with a hairline. Used for back, close and week nav on paper. Replace with the bare glyph from `BookingInkIconButton`.

Sheets and states
- m13. `SheetHeader` (`Bits.swift:134-153`) uses serif `title` medium and a disc close. Make it serif 28 regular, bare xmark glyph, and add `.presentationBackground(Palette.paper)` on every sheet.
- m14. Fixed detents clip at larger text: `.height(280)` `ProProfileView.swift:943`, `.height(300)` `:1072`. Use `.medium` or measure content.
- m15. `EmptyState` (`Bits.swift:28-56`) is centred SF symbol at 28 light inkFaint, a serif heading and a lacquer link: the generic "icon, title, link" pattern, and "whitespace next to small things reads empty" (benchmark §3). Redesign: left-aligned at the gutter, serif 28 regular line, SF 15 inkSoft sentence, `OutlineButton` for the action. No SF symbol. Where a rail of photos is relevant (Bookings empty, search no-results), show it under the message.
- m16. Loading states exist only on Home (`HomeView.swift:583-619`), and its blocks don't match the layout: 150x150 squares instead of 150x188 tiles, 132x112 instead of 104x130 category tiles, 230pt cards instead of 120pt rows, 14 and 18pt radii. Match the real shapes at 2pt radius. Bookings, Inbox, Today, Calendar and Earnings have no loading flag, so on the live backend they flash their empty states first. Add `isLoadingBookings`, `isLoadingThreads`, `isLoadingProSide` to `AppState` and a row skeleton (72x90 photo block plus two text bars).
- m17. Slot load error says "Pull down to try again" (`SlotPicker.swift:261`), but the time step has no `.refreshable`. Say "Try again" and rely on the button.
- m18. Toast (`RootView.swift:196-212`) is an ink capsule. Make it a 6pt ink bar inset 20 from the edges, SF 15 paper text, left-aligned.
- m19. Two different "done" checks. You're booked draws a bare lacquer stroke (`BookingReviewStep.swift:681-686`, matches mockup 05). `LacquerCheck` (`Bits.swift:171-194`) draws it inside a lacquerSoft disc with a ring and is used by the rate sheet and pro onboarding. Make `LacquerCheck` the bare stroke and use it in all three places.
- m20. You're booked is missing "Add to Apple Wallet" (mockup 05, benchmark signature moment 2). If PassKit isn't ready, leave the space out rather than fake it, but put it on the list.
- m21. Rate sheet: initials avatar 72 (`ReviewSheet.swift:98`) and a honey blur blob (`:103`, `HoneyGlow`). Use her cover at 120x150, 2pt; drop the glow; let the stars do the honey.
- m22. Home map (`HomeView.swift:515-578`): 18pt card radius with border, initial avatars ringed in lacquer as pins, capsule price labels, a pill Recentre chip. Use 2pt radius with no border, pins as 36x45 cover photos at 2pt with a 1.5pt paper border, price as SF 13 monospaced ink on a 6pt paper label, Recentre as a bare outline `location` glyph in a 36pt paper 6pt square.
- m23. Home category filter (`HomeView.swift:273-280`): the selected category already underlines on its tile; drop the extra "Everything" and category chips and add a "Clear" ink text link at the end of the Near you heading row.
- m24. Profile: the saved heart turns lacquer (`ProProfileView.swift:194`) and selected services get a lacquer check (`:778`). Mockup 03 shows a paper outline heart. Saved = `heart.fill` in paper; service check in ink.
- m25. Profile explainers use a lacquer "Got it" (`ProProfileView.swift:938`). Use `OutlineButton` or just the close glyph.
- m26. Welcome: `SignInWithAppleButton` is clipped to a capsule (`OnboardingFlow.swift:183`) next to a 6pt lacquer button. Clip to `RoundedRectangle(cornerRadius: Radius.button)`.
- m27. Welcome sets `.preferredColorScheme(.dark)` on a child (`OnboardingFlow.swift:202`). That flips the whole window, so the phone screen slides in rendered dark and then snaps to light. Use `.environment(\.colorScheme, .dark)` on the welcome content instead.
- m28. Location screen (`OnboardingFlow.swift:617-642`): initial avatars and a lacquerSoft disc with the glossy `DropMark`. Replace with the concentric hairlines and the `MonogramMark` centred, or three real 36x45 work photos at 2pt on the rings.
- m29. Unused old-style components invite reuse: `ProCard` (`Components/ProCard.swift:4-61`), `BookingSummaryCard` (`BookingReviewStep.swift:845-875`), `FreeRow` (`:606-621`), `FlowErrorCard` (`BookingBits.swift:83-101`), `SecondaryLabel` (`:122-138`), the `WorkTile` caption capsule (`Placeholder.swift:66-71`). Delete them.
- m30. Booked, review and profile each define their own fixed ink and paper colours (`BookingInk`, `ProfileTone`, `HomeInk`). Same values, three names. Move them into `Palette` (`inkGround`, `inkRaised`, `onInk`, `onInkSoft`, `onPhoto`, `lineStrong`) so the next screens use the same ones.

Dark mode details
- m31. Placeholder art is fixed light pastels (`Placeholder.swift:6-15`), so missing photos glow in dark mode. Wrap the swatches in `dyn` with darker pairs, or lay a 25% ink veil over the art in dark.
- m32. Selected cells use ink fill with paper text (`SlotPicker.swift:371`, `Chips.swift:158`, `ProCalendarView.swift:112`), and "my" chat bubbles are ink (`ThreadView.swift:310`). In dark mode ink is cream, so selection and her own messages become bright cream blocks. Acceptable, but softer if dark uses `inkRaised` fill with a 1pt paper border and paper text.
- m33. Tab bar overlay is `Palette.paper` at 78% over `.ultraThinMaterial` (`RootView.swift:187-188`); fine in both modes. The unread dot's 1.5pt paper ring works in dark. No change.

Dynamic Type
- m34. Fixed heights that clip: Near you row `frame(height: 131)` (`HomeParts.swift:242`), Next up card `frame(height: 96)` with `lineLimit(1)` (`HomeView.swift:465`), `DayCell` 48x64 (`SlotPicker.swift:370`), `SlotChip` height 40 (`:436`), `Chip` height 36 (`Chips.swift:156`), code boxes 60 (`OnboardingFlow.swift:462`), every button `frame(height: 52)` or 56 (`Buttons.swift:28, 55`, `BookingReviewStep.swift:389, 422`). Use `minHeight` and let rows grow; on the Near you row put the hairline in an `.overlay(alignment: .bottom)` instead of a fixed frame.
- m35. Fixed widths that wrap or truncate: pro row time column 66 (`ProShared.swift:245`, `ProCalendarView.swift:151`), postcode 112 (`AddressEditor.swift:226`), last initial 96 (`ProProfileEditView.swift:321`), `SummaryRow` label 64 (`BookingBits.swift:150`). Use `ViewThatFits` to stack label over value at accessibility sizes.
- m36. Scale-down instead of reflow on money and actions: Pay and Apple Pay side by side with `minimumScaleFactor(0.8)` (`BookingReviewStep.swift:329-332, 383`), Today's three money tiles (`ProTodayView.swift:104`), profile bar price (`ProProfileView.swift:545`). At accessibility sizes stack the two pay buttons vertically and the money facts as rows.
- m37. Fixed sizes that never scale: tab labels 10pt and icons 21pt (`RootView.swift:158, 169`); add `.accessibilityShowsLargeContentViewer()` on each tab item. Welcome wordmark `size: 40` (`OnboardingFlow.swift:158`) and `MonogramMark` are logos; fine to leave.

## 4. Client and pro: a visual distinction

Today the two modes share the same paper ground, the same paper tab bar and the same type. The only cue is the tab labels. She can lose track of which side she's on, and in Inbox (the same screen in both modes) there is no cue at all.

Proposal: **the pro side is ink chrome on paper content.**

1. **Ink tab bar in Pro mode.** Add `HDTabBar.Style.client | .pro` (`RootView.swift:132`). Pro: ground `Palette.inkGround` (fixed `#241A16`, no blur), inactive icons and labels paper at 55%, active paper at 100%, the same 4pt lacquer dot under the active tab, unread dot lacquer with a 1.5pt ink ring. In dark mode invert it (paper `#F4ECE4` bar, ink icons) so it is always the opposite of the ground and never blends in. This is the one signal that is on every pro screen, including the shared Inbox.
2. **A pro eyebrow on every pro tab root.** Above the serif title: "PRO · KIARA M." in 12pt tracked inkSoft. Client tab roots carry the suburb instead (Home already does).
3. **A switch moment, both ways.** On switching (`AppState.switchMode`), cross-fade through a full-screen ink frame for about 600ms with paper serif 40 "Pro mode." (or "Booking mode." on the way back) and a `.medium` haptic. Under Reduce Motion, a plain cross-fade. This makes the change of side a deliberate event, like the ink booking sheet.
4. **The switch lives in the same place on both sides.** Client: the ink Pro mode row on You (M16), which previews the ink bar. Pro: her cover thumbnail top right on Today opens a pro "You" sheet with "Switch to booking", Profile, Payout details and Log out. Today, pro mode has no log out and the only way back is a lacquer text link on Today (`ProTodayView.swift:80`).
5. **Keep paper as the working ground.** Don't make all of pro mode dark. Ink is reserved for moments that matter (benchmark P6), and a pro uses these screens all day. The ink bar plus the ink next-job block on Today is enough contrast to say "work side" without losing the brand's paper.

## 5. The first ten changes, in order

1. **Fix the tokens and the brief.** Global tint to ink (M1). Serif weights to regular and one shared type scale, money in SF (M2, M3). Radius card 6, photo 2, no chip radius (M4). Fold `HomeInk`, `ProfileTone`, `BookingInk` into `Palette` with dark-aware `inkGround` and `inkRaised` (M24, m30). Update build brief §4 and brand.md colour rules so they describe the luxe system (M5). One PR; it visibly moves every old screen.
2. **Ship the replacement components.** `InkButton`, `OutlineButton` (lacquer `PrimaryButton` only for Pay and Request), `TextTabs`, `OptionBox`, `HDNavHeader`, `ConfirmSheet`, underline `HDTextField`, `HDSwitch`, `HDStepper`, bare-glyph close, text-only tags and badge (M6 to M9, M18, M19). Delete `Chip`, `Tag`, `IconButton`, `ProCard` and the other unused old pieces (m29).
3. **Remove system red and stock chrome.** Swap all seven destructive dialogs, the alert and swipe-to-delete for `ConfirmSheet`; hide the system nav bar on the four pushed screens (M8).
4. **Pro mode signal and the trapped onboarding.** Ink pro tab bar, pro eyebrow, the switch moment, and the pro "You" sheet (section 4). Add a close to every pro onboarding step (M20).
5. **Bookings and booking detail.** Reuse Home's ink Next up card and the You're booked record; hairline rows with cover photos; ink timeline (M10, M11). These are the first screens she reaches from Home.
6. **Booking steps 1 to 4.** Price-list services, plain day strip and squared slots, hairline addresses, and the profile's ink Book bar carried through to the ink review; ink sheets for Pay with and Add a card (M12, M13).
7. **Pro Today and pro booking detail.** Ink next-job hero, one money facts row, hairline requests with ink Accept (M17).
8. **Accessibility and dark mode pass.** Lacquer fill contrast in dark (M23), ink moments in dark (M24), inkFaint and warn text (m3, m4), fixed heights and widths (m34 to m36), welcome colour scheme (m27).
9. **Inbox, Thread and You.** Hairline lists, squared bubbles and replies, underline composer, ink Pro mode row (M14 to M16).
10. **Calendar, Work, Earnings, Profile edit, Pro onboarding, and the states.** Rebuild per M17; real picked photos instead of bundled stand-ins (M21, M22); matching skeletons and loading flags for every list, the new empty state (m15, m16).
