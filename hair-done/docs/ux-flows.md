# Hair Done — UX flows

Screen-by-screen spec for v1. Answers to `build-brief.md` (names, voice, palette, scope, money, tech) and `product-spec.md` (rules, states, timers). Copy in this document is final unless it contradicts the brief, in which case the brief wins and this file is wrong.

Contents

1. How to read this
2. Navigation map
3. Shared components
4. Client onboarding
5. Client — Home tab
6. Booking flow (sheet)
7. Client — Bookings tab
8. Client — Inbox tab
9. Client — You tab
10. Pro onboarding
11. Pro — Today tab
12. Pro — Calendar tab
13. Pro — Inbox tab
14. Pro — Work tab
15. Pro — Earnings tab
16. Pro — Profile edit
17. Interaction details
18. Accessibility
19. State rules that apply everywhere

---

## 1. How to read this

Every screen has the same seven parts:

- Purpose: one sentence, why the screen exists.
- On it, top to bottom: every element, in order, with copy where copy is fixed.
- Primary action: the one thing the screen is for. There is one, and it is the only `lacquer` thing on the screen.
- Secondary actions: everything else you can do.
- States: loading, empty, error, offline. If a state is not listed the general rules in section 19 apply.
- Transition out: what happens when the primary action succeeds, and how it moves.

Naming: type sizes are the brief's scale (`hero`, `title`, `heading`, `body`, `sub`, `caption`, `label`). Colours are the brief's tokens. "Sheet" means a SwiftUI `.sheet` with detents unless it says "full-screen cover". "Push" means a `NavigationStack` push. Times are shown as `2:00 pm`, dates as `Sat 27 Sep`; within a sentence that already says the day, the time alone is fine ("Kiara's coming Saturday at 2:00 pm").

Where a button label depends on data it is written with the example data from the product spec: Ruby (client, 8 Glenlyon Rd, Brunswick East) books Kiara (nail tech, Coburg) for a $150 gel set with a $15 travel fee, total $168.

---

## 2. Navigation map

```
App
├── Splash
├── Client onboarding
│   ├── Welcome
│   ├── Sign in (phone)
│   │   └── Code
│   ├── Your name
│   └── Location
├── Client (TabView)
│   ├── Home
│   │   ├── Search
│   │   │   └── Pro profile
│   │   ├── Category results (list / map)
│   │   │   └── Pro profile
│   │   ├── Near you (list / map)
│   │   │   └── Pro profile
│   │   ├── Who's free → Pro profile
│   │   ├── Book again → Pro profile (services preselected)
│   │   └── Pro profile
│   │       ├── Her work (viewer)
│   │       ├── Reviews
│   │       ├── Verified sheet
│   │       ├── Report or block sheet
│   │       └── Booking flow (sheet)
│   │           ├── Services
│   │           ├── Time
│   │           ├── Where
│   │           │   └── New address
│   │           ├── Notes
│   │           ├── Review
│   │           ├── Pay
│   │           └── Booked
│   ├── Bookings
│   │   └── Booking detail
│   │       ├── Thread
│   │       ├── Reschedule (sheet)
│   │       ├── Cancel (sheet)
│   │       ├── Pay and tip (sheet, at done)
│   │       ├── Rate (sheet)
│   │       ├── Receipt
│   │       ├── Share with a friend (system share)
│   │       ├── Something wrong (sheet)
│   │       └── Pro profile
│   ├── Inbox
│   │   ├── Thread
│   │   └── Update → Booking detail
│   └── You
│       ├── Profile
│       ├── Addresses
│       │   └── New address
│       ├── Payment methods
│       │   └── Add card
│       ├── Favourites → Pro profile
│       ├── Notifications
│       ├── Help
│       ├── About
│       ├── Pro mode (switch, or Pro onboarding if not a pro)
│       └── Log out
├── Pro onboarding
│   ├── Start
│   ├── Specialty
│   ├── Services and prices
│   ├── Travel area
│   ├── Availability
│   ├── Work photos
│   ├── ID and ABN
│   ├── Payouts
│   ├── Check and send
│   └── Pending
└── Pro (TabView)
    ├── Today
    │   ├── Job detail
    │   │   ├── Thread
    │   │   ├── Cancel job (sheet)
    │   │   ├── No show (sheet)
    │   │   └── Report or block (sheet)
    │   ├── Request detail
    │   │   └── Decline reason (sheet)
    │   └── Profile (via avatar)
    ├── Calendar
    │   ├── Day
    │   │   └── Job detail
    │   ├── Availability
    │   └── Block time off (sheet)
    ├── Inbox
    │   └── Thread
    ├── Work
    │   ├── Add photos (picker)
    │   └── Photo detail (sheet)
    └── Earnings
        ├── Booking earnings
        ├── Payout detail
        └── Fee breakdown
```

---

## 3. Shared components

Built once, used everywhere. Engineers build these first.

### Tab bar

Standard `TabView`. Client tabs: Home, Bookings, Inbox, You. Pro tabs: Today, Calendar, Inbox, Work, Earnings. SF Symbols: `house`, `calendar`, `tray`, `person.crop.circle` for client; `sun.max`, `calendar`, `tray`, `photo.on.rectangle.angled`, `dollarsign.circle` for pro. Selected tab is `lacquer`, unselected `inkSoft`. Inbox shows a badge with the unread count (messages + updates). Today shows a badge with the count of open requests. Tab bar background is `paper` with a `line` hairline on top.

### Pro card

Used on Home (Who's free, Near you), search, category results, favourites. Two sizes.

Large (list): a photo 4:3 at the top with corner radius 20, then 12pt of air, then name at `heading` serif, then a line at `sub`: "Nail tech · 4.9 · 212 reviews · 1.8 km". Then one line of `caption` `inkSoft`: "From $90 · Free from 5:00 pm" (the earliest slot today if there is one, otherwise "Next free Thu"). Chips row when applicable: `Instant book` (lacquer text on lacquerSoft), `Reliable` (ink on line), `Insured`. Heart button top-right of the photo, 44pt target, `card` circle, filled heart is `lacquer`. Whole card is tappable. On press it lifts (section 17).

Small (horizontal strip): photo 1:1 at 132pt, radius 16, name at `body` semibold, one line `caption` "Free from 5:00 pm". Same heart.

Stars are `honey`. The number and count are text, not five stars; five stars appear only in the rate sheet and the review list.

### Booking card

Used on Bookings, Today, Calendar, Inbox updates. Left: the pro's (or client's) photo 56pt round. Right: first line `body` semibold "Gel set with Kiara" (pro side: "Gel set for Ruby"), second line `sub` "Sat 27 Sep · 2:00–3:30 pm · Brunswick East", third line: status chip. Right edge: chevron. Active bookings (requested through inProgress) sit above a hairline; past ones below.

### Status chip

Pill, height 24, `caption` semibold, dot 6pt before the text. Text and dot colour by state:

| State | Text | Colour |
|---|---|---|
| requested | Waiting on Kiara | warn |
| confirmed | Confirmed | success |
| onHerWay | On her way | success |
| arrived | She's here | success |
| inProgress | In progress | success |
| done | Done, paying | success |
| paid | Paid | success |
| cancelledByClient | Cancelled | inkSoft |
| cancelledByPro | Kiara cancelled | inkSoft |
| declined | Declined | inkSoft |
| noShow | Missed | inkSoft |

The pro-side text differs where the subject differs: "Waiting on you", "Cancelled by client", "You cancelled", "You declined", "No show".

### Buttons

Primary: pill, height 52, `lacquer` fill, `paper` text at `body` semibold, full width inside the gutter. Disabled: `lacquer` at 40% with `paper` text. Loading: text replaced by a 20pt `paper` spinner, width unchanged. Floating primary (sticky bars): same button on a `paper` bar with a `line` hairline on top and the one allowed shadow.

Secondary: pill, height 52, `card` fill with a `line` hairline, `ink` text.

Text button: `body` `lacquer` text, no fill, 44pt tall hit area.

Destructive confirmations (cancel booking, log out, delete photo) use the primary style with the amount or the consequence in the label ("Cancel and pay $82.50"). Never red text on a plain button; the confirm sheet carries the weight.

### Chips

Pill, height 36, `sub` text. Unselected: `card` fill, `line` hairline, `ink` text. Selected: `lacquer` fill, `paper` text. Disabled: `paper` fill, `line` hairline, `inkSoft` text, and a small `inkSoft` slash icon before the text so disabled is not colour-only. Category chips use the category tint as fill with `ink` text; selected category chip adds a `lacquer` 2pt border.

### Placeholder image

Any image that has not loaded, or that does not exist, is a warm procedural gradient (two colours from the category tint, one angle from a hash of the id) with a grain overlay at 6% opacity. Never a grey box, never a system photo icon. Loaded images cross-fade in over 0.25s.

### Section eyebrow

`label` size, uppercase, tracked 0.08em, `inkSoft`, 20pt gutter, 8pt below to content. Only used for section headers on Home, Earnings and Today (WHO'S FREE, NEAR YOU, BOOK AGAIN, THIS WEEK, NEXT UP).

### Toast

Bottom, above the tab bar, `ink` fill at 92%, `paper` text at `sub`, radius 14, one line, 3 seconds, swipe down to dismiss. Used for "Saved", "Added to favourites", "Message sent" when the sender is not on the thread screen, "Copied". Never for errors that need action.

### Empty state

Centred in the available space: an optional small line drawing (24pt, `inkSoft`, SF Symbol), a `heading` serif line, one `sub` `inkSoft` line, and at most one secondary button. Copy is specific to the screen (below). No illustrations of women laughing.

### Error and offline

Inline error: `sub` text in `ink` (not red) under the element it belongs to, with a small `exclamationmark.circle` in `warn`. Full-screen error: same layout as empty state with a `Try again` secondary button. Offline: a 32pt bar under the navigation bar, `lacquerSoft` fill, `ink` `caption` text "You're offline. Showing what we've got." It appears and disappears with the default spring. Actions that need the network are disabled with their normal disabled style plus the bar; nothing pops an alert for being offline.

### Sheet chrome

Sheets use `.presentationDetents`, `.presentationDragIndicator(.visible)`, `card` background, corner radius 20. A sheet with steps (booking flow, pro onboarding is not a sheet) has a top row: `Back` chevron on the left (44pt), a `caption` step label centred ("Step 2 of 6 · Time"), close `xmark` on the right (44pt). Closing a sheet with progress asks "Leave without booking?" with `Keep going` (primary) and `Leave` (text).

---

## 4. Client onboarding

Five screens, one thing per screen, say why we ask. Progress is not shown as a bar; there is nothing to save the user from.

### Splash

Purpose: cover the cold start and draw the mark once.

On it: `paper` background. The drop mark at 64pt centred, filled `lacquer`, drawing itself with `trim` over 0.6s (brand doc). Below it, 24pt down, the stacked wordmark in serif medium at `title`: "hair done." / "nails done." / "everything done." fading in over 0.3s after the drop finishes.

Primary action: none.

States: shows for at least 0.9s and until the mock data service is ready. If a signed-in session exists, goes straight to Home or Today (whichever mode was last used). Offline: same.

Transition out: cross-fade 0.3s to Welcome or the tab view.

### Welcome

Purpose: say what this is and get her to sign in.

On it, top to bottom: full-bleed `lacquer` hero occupying the top 55% with the stacked wordmark in `paper` serif at `hero`, bottom-left with the 20pt gutter and 32pt from the bottom of the hero. Below on `paper`: `sub` `inkSoft` line "A vetted pro comes to you. Hair, nails, makeup, lashes, brows. You see the price and the time before you book." Then two buttons stacked with 12pt gap: `Sign in with Apple` (black Apple button per Apple's rules, height 52, full pill), `Sign in with phone` (secondary). Below, `caption` `inkSoft`: "By signing in you agree to the terms and privacy policy." with both words as `lacquer` links opening a plain text sheet.

Primary action: `Sign in with phone` is the primary path in v1 because Apple sign-in is mocked; both buttons are styled as given because Apple's button rules apply. Decision: neither button is `lacquer` because the hero already is; the hero is the one lacquer thing on this screen.

Secondary: terms, privacy.

States: none needed; static. Offline: buttons work (mock).

Transition out: push to Sign in (phone) or, for Apple, straight to Your name with the name prefilled if Apple gives one (mock gives "Ruby").

### Sign in (phone)

Purpose: get a phone number, explain why.

On it: back chevron. `title` serif "Your number." `sub` `inkSoft`: "We text you a code. It's also how she reaches you once you're booked, never before." Phone field: `+61` prefix fixed, input for the rest, numeric keypad, input height 52, radius 14, `line` border, `lacquer` border when focused. Keyboard is up on appear. Primary button pinned above the keyboard: `Text me a code`.

Primary action: `Text me a code`. Enabled when 9 digits are entered (Australian mobile without the leading 0, or accept a leading 0 and strip it).

Secondary: back.

States: loading: button spinner. Error: "That doesn't look like an Australian mobile. Check it and try again." under the field. Offline: the mock still works; with the real service, the button is disabled with the offline bar.

Transition out: push to Code.

### Code

Purpose: verify the number.

On it: back. `title` serif "Code's on its way." `sub`: "Sent to 04xx xxx 123. Not you? [Change number]" with the link in `lacquer`. Six-box code input, auto-advances, one-time-code content type so iOS autofills. `caption` `inkSoft` under it: "Resend in 0:30" counting down, becoming a `lacquer` text button "Resend code". Mock accepts `000000` and shows a `caption` hint "Demo code: 000000" only in mock builds.

Primary action: none as a button; entering the sixth digit submits.

Secondary: change number, resend.

States: verifying: boxes dim to 60% and a spinner appears under. Wrong code: boxes shake once horizontally (8pt, three cycles, 0.3s) with `.error` haptic and "That's not it. Try again or resend." Offline: same as Sign in.

Transition out: existing account with a name → cross-fade to Home. New account → push Your name.

### Your name

Purpose: first name only, so the pro knows who she's meeting.

On it: `title` serif "What do we call you?" `sub`: "First name's fine. It's what she'll see when you book." One text field, given-name content type, keyboard up. Primary button pinned: `That's me`.

Primary action: `That's me`, enabled when at least one character.

States: none. Trims whitespace; caps the first letter if all lowercase.

Transition out: push to Location.

### Location

Purpose: get the location permission with a real reason.

On it: `title` serif "Where are you?" `sub`: "So we can show who's free near you and how far away she is. Only used while you're in the app." A small static map thumbnail of inner Melbourne as a `paper`-tinted image, 160pt tall, radius 20, decorative (hidden from VoiceOver). Primary: `Allow location`. Text button: `Not now`.

Primary action: `Allow location` triggers the system prompt (when-in-use).

Secondary: `Not now`, which sets Home to ask for a suburb.

States: denied at the system prompt: same as Not now, no nagging. Offline: n/a.

Transition out: cross-fade to Home. If allowed and the location is outside the launch area, Home shows the out-of-area state.

---

## 5. Client — Home tab

### Home

Purpose: get her from "I want my nails done" to a pro profile in one tap.

On it, top to bottom, all in a scroll view:

1. Header (not a navigation bar): `hero` serif greeting on the left. Copy by local time: 5:00–10:59 "Morning, Ruby."; 11:00–16:59 "Afternoon, Ruby."; 17:00–22:59 "Who's free tonight."; 23:00–4:59 "Up late, Ruby." Right of it, a 40pt round avatar button that jumps to the You tab. Below the greeting, `sub` `inkSoft`: "Brunswick East" with a chevron, tapping opens the address picker (same one as the Where step) to change where "near you" is measured from.
2. Search field: height 44, radius 14, `card` fill, `line` hairline, magnifier, placeholder "Gel set, blow-dry, Kiara…". Tapping pushes Search.
3. Eyebrow WHO'S FREE with a `sub` `inkSoft` right-aligned "Today near you". Horizontal strip of small pro cards (up to 10), 16pt gap, 20pt leading inset, snapping off. Pros with a free slot in the next 8 hours, ordered per the spec.
4. Categories: a 3×2 grid of tiles, gap 12, each tile 16 radius, category tint fill, `heading` serif `ink` name bottom-left, 96pt tall. Order: Hair, Nails, Makeup, Lashes, Brows, The lot. No eyebrow above it.
5. Eyebrow BOOK AGAIN, only if she has a paid booking. Horizontal strip of small pro cards from her paid bookings, most recent first, each with `caption` "Gel set · 3 weeks ago". Tapping opens the profile with those services preselected in the booking sheet.
6. Eyebrow NEAR YOU with a segmented control on the right: List | Map (44pt tall, `line` background, `card` selected segment). List: large pro cards, 20pt gap, paged 10 at a time, sorted by distance then rating. Map: 320pt tall map with `lacquer` drop pins (the brand mark at 24pt, no highlight), tapping a pin shows a small pro card above it; a text button "See all on map" pushes Near you in map mode full-height.
7. 32pt of air at the bottom.

Primary action: none as a button; the primary path is tapping a pro card.

Secondary: search, category, change address, avatar, list/map.

States. Loading: the whole scroll view renders with placeholder gradients in place of images and `line`-coloured blocks in place of text, no shimmer in reduce-motion, a slow 1.2s opacity pulse otherwise; the greeting renders immediately. Empty (nobody free today): the WHO'S FREE section shows a one-line `sub` "Nobody's free right now. Next free is Thu." and nothing else. Empty (out of launch area): header stays; a `card` block replaces sections 3–6: `heading` serif "We're not in Glen Waverley yet." `sub`: "Melbourne inner north and inner south for now. We'll text you when we get to you." Secondary button `Tell me when`, which stores the suburb and shows a toast "Noted." Error: full-screen error under the header with `Try again`. Offline: offline bar; cached data shown; Who's free is hidden (it's time-sensitive) with "Who's free needs a connection." in its place.

Transition out: push to Pro profile (from any card), Search, Near you, Category results.

### Search

Purpose: find a pro or a service by name.

On it: the search field becomes the navigation bar title area, focused, keyboard up, with `Cancel` text button on the right. Under it, before typing: eyebrow RECENT with up to 5 recent queries as plain rows (swipe to delete), then eyebrow CATEGORIES with the six category chips. After typing (debounced 250ms): results as large pro cards in a list, with a `caption` `inkSoft` header "12 pros for 'gel set'". A service match shows the matching service under the name as `sub` "Gel set · $150 · 90 min". Filter row above results: chips `Instant book`, `Free today`, and the category chips; multi-select on category.

Primary action: tapping a result.

Secondary: filters, clear recent, cancel.

States. Loading: previous results dim to 60% until new ones land; no spinner. Empty: "Nothing for 'acrylics in Werribee'. Try a service, or a name." with the category chips below. Error: inline error line under the header with `Try again`. Offline: searches the cached pro list; offline bar shows.

Transition out: push to Pro profile.

### Category results and Near you

Purpose: browse one category, or everything near her, in a list or a map.

On it: navigation title is the category name ("Nails") or "Near you". Right bar item: List | Map segmented control (44pt). Below the title, the filter chip row (`Instant book`, `Free today`; in Near you also the category chips). List: large pro cards, 20pt gap, sorted instant-book first then rating then distance. Map: full-height map, the pins as above, a bottom horizontal strip of small pro cards synced to the visible pins; tapping a pin scrolls the strip to that card and vice versa.

Primary action: tapping a card or pin card.

Secondary: filters, list/map.

States. Loading: placeholder cards. Empty: "No nail techs near Brunswick East today. [Try another day]" where the link opens a date picker that re-runs the query for that date. Error: full-screen error. Offline: cached list; map still renders with pins from cache; offline bar.

Transition out: push to Pro profile. Map mode remembers itself per tab session.

### Pro profile

Purpose: decide whether to book her, then book her.

On it, top to bottom, in a scroll view with a sticky Book bar over the bottom:

1. Cover: her pinned work photo, full width, 4:5, edges to the screen sides, no radius. Back chevron and heart (favourite) and `ellipsis` (report/block, share profile) as 44pt `card` circles overlaid top-left and top-right.
2. Name block on `paper`, 20pt gutter, 20pt from the cover: `title` serif "Kiara", `Verified` chip inline after the name (tap → Verified sheet). Next line `sub`: "Nail tech · 4.9 · 212 reviews" where the number and count are one tappable unit that scrolls to the reviews section. Next line `sub` `inkSoft`: "1.8 km away · About 15 min from you". Chips row: `Instant book`, `Reliable`, `Insured`, `Founding pro`, whichever apply.
3. "She'll come to" line: `sub` "10 km from Coburg. Travel fee $15." as one line, a small `map` icon before it.
4. About: `body` `ink`, up to 6 lines then "More" text button that expands inline. Her own words, emoji allowed here.
5. Eyebrow SERVICES. Rows: left `body` service name and `caption` `inkSoft` "90 min", right `body` monospaced price. Rows are tappable and toggle a checkmark on the right, which preselects them in the booking sheet; the sticky Book bar's label updates ("Book · $150"). Grouped by category if she lists more than one, with `sub` semibold group headers. Bundles under "The lot" show the included items in the caption.
6. Eyebrow HER WORK. 3-column grid, 2pt gaps, square crops, up to 9 then "See all 34" text button that opens the viewer at index 9. Tapping a photo opens the viewer at that index.
7. Eyebrow REVIEWS with "4.9 · 212 reviews" as the header line. The three most recent reviews: five `honey` stars at 14pt, `body` text (up to 4 lines, "More" expands), `caption` `inkSoft` "Ruby M. · Gel set · August", review photos as 64pt thumbnails, and her reply indented with a `line` left rule and "Kiara replied" `caption`. Text button "All 212 reviews" pushes Reviews.
8. Eyebrow NEXT FREE. A compact version of the day strip (section 6, Time step): the next 7 days as chips, days with slots show the earliest time as `caption` ("Thu · 10:00 am"), days without are disabled. Tapping a day opens the booking sheet on the Time step with that day selected.
9. 96pt of air so the last content clears the sticky bar.

Sticky Book bar: pinned to the bottom, `paper` background, hairline on top, the one shadow. Left: `sub` `inkSoft` "From $90" or, with services selected, `body` "Gel set" and `caption` "90 min". Right: primary button `Book` (or `Book · $150` when services are selected), 160pt wide minimum. The bar appears when the name block scrolls past the top (so the cover is uninterrupted on first view) and stays. Slides up from below with the default spring.

Primary action: `Book`. Opens the booking flow sheet on the Services step (with any preselected services) or, if the pro has exactly one service, on the Time step.

Secondary: favourite, share profile (system share of "Kiara does a very good French tip. hairdone://pro/kiara" — the URL scheme is the app's; without the app it does nothing, which is acceptable in v1), report or block, service rows, work grid, reviews, next free.

States. Loading: cover placeholder, name block renders as soon as the pro summary is in cache, sections below use placeholder blocks. Empty reviews: the section shows `New` where the number would be and "No reviews yet. She's verified, and her first booking was with us." Empty work (cannot happen for a verified pro; if it does, the grid shows three placeholder tiles). Error: the cover and name block from cache, then a full-screen error below with `Try again`. Offline: everything from cache; the Book button is disabled with `caption` under the bar "Booking needs a connection."; heart works and syncs later.

Transition out: booking sheet presents from the bottom at the `.large` detent.

### Her work (viewer)

Purpose: look at the photos properly.

On it: full-screen cover, `ink` background at 96%. Horizontal paging of photos, pinch to zoom, double-tap to zoom 2×. Top: close `xmark` (44pt, `paper`) left, "4 of 34" `caption` `paper` centred. Bottom: `caption` `paper` category tag ("Nails") and date month ("August"). Swipe down to dismiss (interactive, the photo follows the finger, background fades).

Primary: none.

States: loading a photo shows the gradient placeholder and cross-fades. Offline: shows what is cached; uncached pages show the placeholder with "Needs a connection" `caption`.

Transition out: dismiss back to the profile at the same scroll position.

### Reviews

Purpose: read all of them.

On it: navigation title "Reviews". Header block: `hero` serif "4.9" with five `honey` stars beside at 20pt and `sub` "212 reviews". Distribution as five thin bars (5 to 1) with counts, `line` track, `honey` fill. Sort chips: `Newest`, `Highest`, `Lowest`. Then the review list as on the profile, paged.

Primary: none.

States. Loading: header immediate from the summary, list placeholders. Empty: as profile. Error: inline. Offline: cached.

Transition out: back.

### Verified sheet

Purpose: say what verified means.

On it: `.medium` detent. `heading` serif "Verified". Four rows with a `checkmark.circle.fill` in `success` and `body` text: "ID checked", "ABN checked", "Insured" (only if she is), "First booking done with the Hair Done team". `sub` `inkSoft` "Every pro on Hair Done has done these before you can see her." Primary button `Got it`.

Transition out: dismiss.

### Report or block (sheet)

Purpose: get help, or make her go away.

On it: `.medium` detent. `heading` serif "What's happened?" Rows (radio): "Didn't show", "Not who was on the profile", "Made me uncomfortable", "Unsafe", "Work wasn't as shown", "Something else". A text field appears when a row is selected, placeholder "Anything else we should know", optional except for Something else. Toggle row: "Also block Kiara" with `caption` "You won't see each other again. Any booking with her is cancelled, no charge." Primary: `Send report` (or `Send and block`).

Primary action: sends, shows toast "We've got it. Someone from Hair Done will be in touch." and dismisses.

States. Error: inline "That didn't send. Try again." Offline: queued, toast says "We'll send it when you're back online."

Transition out: dismiss; if blocked, pop to the previous screen and remove the pro from any lists.

---

## 6. Booking flow (sheet)

One sheet, seven steps, presented from the pro profile at `.large` detent. State is held in a single `BookingDraft` observable so back and forth loses nothing. Steps slide horizontally inside the sheet (forward: new step enters from the right, old exits left, default spring; back is the reverse). The sheet's top row shows Back, "Step n of 6 · Name", Close. The Booked screen is not numbered.

Every step has a persistent bottom bar inside the sheet: left, a running `body` monospaced price (services only until Review) and `caption` duration; right, the step's primary button. The button says what it does, never "Continue".

### Step 1 — Services

Purpose: pick what she's getting done.

On it: `heading` serif "What are you getting done?" Service rows grouped by category (as on the profile) with a checkbox on the right (24pt, `line` circle unchecked, `lacquer` circle with `paper` tick checked). Bundle rows under The lot show what's included and, when selected, deselect their component services to avoid double-booking. Bottom bar: "$150 · 90 min" and primary `Pick a time`.

Primary action: `Pick a time`, enabled when at least one service is selected.

States: none beyond the general. Selection persists if she goes back.

Transition out: slide to Time.

### Step 2 — Time

Purpose: pick a real slot.

On it, top to bottom:

1. `heading` serif "When?" with `sub` `inkSoft` under it: "Kiara needs 2 hours' notice. Slots fit around her other jobs."
2. Day strip: horizontal scroll of 60 day chips starting today, each 56pt wide, 64pt tall, radius 16, showing weekday `caption` ("SAT") over the date `body` semibold ("27"). Today shows "TODAY". Selected day: `lacquer` fill, `paper` text. Days with no windows: disabled style with the slash and VoiceOver "Saturday 27 September, Kiara's off". Month `label` eyebrow appears above the strip and updates as it scrolls ("SEPTEMBER"). The strip snaps to chip boundaries. Selecting a day scrolls it to the leading edge with 20pt inset.
3. Under the strip, three groups with `sub` semibold headers "Morning", "Afternoon", "Evening" (a group is omitted if the day has no candidates in it). Each group is a wrapping flow of time chips (36pt tall, `body` text, "2:00 pm"). Available: normal chip. Selected: `lacquer`. Unavailable: disabled chip. Tapping a disabled chip shows a popover anchored to the chip (`card`, radius 14, `sub` text, 8pt arrow) with the reason from the product spec ("Kiara's booked then", "Not enough time before her next job", "She finishes at 5, this would run over", "Too soon. Kiara needs 2 hours' notice", "She's off then"); it auto-dismisses after 2.5s or on the next tap. `.light` haptic on selecting an available chip; `.rigid` (a short, firm one) on tapping a disabled one.
4. When a chip is selected, a summary line appears above the bottom bar with the spring: `sub` "Sat 27 Sep, 2:00–3:30 pm".

Bottom bar: "$150 · 90 min" and primary `Set the address`.

Primary action: `Set the address`, enabled once a slot is selected.

States. Loading slots for a day (they are computed against the client's address; before the Where step, the address is her saved default or current location, and slots are recomputed if the address changes later): the chip groups render as placeholder chips for up to 0.5s, then real. Empty: a day with windows but no available slots: "Nothing free on Saturday. Closest is Sun 11:00 am." with the closest as a `lacquer` text button that selects it. Error: inline under the strip, `Try again`. Offline: the step is disabled: "Times need a connection." and the primary button disabled. (Mock builds compute locally and never hit this.)

Transition out: slide to Where. If the address chosen later is outside her area or changes the travel estimate such that the chosen slot no longer fits, the Where step says so and sends her back to Time with the slot cleared.

### Step 3 — Where

Purpose: say where she's coming to.

On it: `heading` serif "Where's she coming to?" Rows (radio, 56pt tall): saved addresses (label `body` "Home", `sub` `inkSoft` "8 Glenlyon Rd, Brunswick East"), "Use my location" with a `location` icon and the resolved address under it once it resolves, and "Somewhere else" which pushes New address inside the sheet. Under the list, when a row is selected and inside her area: `sub` `success` "Kiara comes to Brunswick East. Travel fee $15." Outside: `sub` `ink` with `warn` icon "Kiara doesn't come to Elwood. Her area is 10 km from Coburg." and the primary button disabled; secondary text buttons `Change address` and `Message her` (opens a thread with no booking attached, allowed in v1 for exactly this case).

Bottom bar: "$165 · 90 min" (travel fee added now) and primary `Add notes`.

Primary action: `Add notes`, enabled when an in-area address is selected.

States. Loading current location: the row shows a small spinner and "Finding you…". Location denied: the row says "Location's off. Turn it on in Settings, or type an address." with a `Settings` link. Error resolving: "Couldn't find that address. Try the street and suburb." Offline: saved addresses work; new address lookup is disabled with the offline bar.

Transition out: slide to Notes.

### New address (inside the sheet)

Purpose: type an address once.

On it: `heading` serif "New address." Search field "Street and suburb", autocomplete rows from the geocoder (mock: a seeded list of 30 Melbourne addresses). Once chosen: fields for unit/flat (optional), a "Label" chip row (`Home`, `Work`, `Mum's`, `Other`), a text field "Notes for the pro (buzzer, parking)" optional, and a toggle "Save this address" default on. Primary `Use this address`.

Transition out: pops back to Where with the new row selected.

### Step 4 — Notes

Purpose: tell her what you want; show her a photo.

On it: `heading` serif "Anything she should know?" Multiline text field, 4 lines minimum, radius 14, placeholder "Short almond, milky white, no chrome. Buzzer's broken, call when you're here." Counter `caption` "0/500". Below: eyebrow INSPO with three 96pt square tiles, radius 16: filled tiles show the photo with a 24pt `xmark.circle.fill` `card` remove button; empty tiles show a `plus` in `inkSoft` on a `line`-dashed border. Tapping an empty tile opens the photo picker (PhotosPicker, up to the remaining count). `caption` `inkSoft`: "Only Kiara sees these."

Bottom bar: "$165 · 90 min" and primary `Review booking`. Notes and photos are optional, so the button is always enabled.

States. Photo loading: the tile shows the gradient placeholder and a spinner until the thumbnail is ready. A photo over 10 MB is downscaled silently. Error picking: toast "Couldn't add that photo." Offline: works; photos upload when the booking is submitted.

Transition out: slide to Review.

### Step 5 — Review

Purpose: see everything, especially the money, before paying.

On it, top to bottom:

1. `heading` serif "Check it over."
2. Pro row: 48pt photo, `body` "Kiara", `sub` "Nail tech · Verified".
3. When and where card (`card`, radius 20, padding 16): `body` "Sat 27 Sep, 2:00–3:30 pm", `sub` "8 Glenlyon Rd, Brunswick East", each with a text button `Change` on the right that jumps back to that step.
4. Price card:
   ```
   Gel set (90 min)              $150
   Travel fee                     $15
   Hair Done booking fee           $3
   ───────────────────────────────────
   Total                         $168
   ```
   Line items `body`, the fee line's label has a small `info.circle` that shows a popover "Goes to Hair Done, not Kiara. It's always shown, never hidden in the price." Total at `title` monospaced.
5. Notes preview (if any) and inspo thumbnails (if any), `sub`.
6. Payment row: Apple Pay mark, or the saved card "Visa ···· 4242", with `Change` on the right that opens a small picker (Apple Pay, saved cards, `Add card`). Default is Apple Pay if available on the device.
7. Cancellation policy, in full, `sub` `ink`: "Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. If you're not there when she arrives, you pay the full amount."
8. Hold sentence, `sub` `ink`, directly above the bar: "We hold $168 on your card now and charge it when she's done." For request-to-book, followed by: "If Kiara doesn't say yes within 2 hours, nothing's charged."

Bottom bar: total "$168" at `body` semibold monospaced and primary `Pay $168` (instant book) or `Request for $168` (request-to-book). With Apple Pay selected, the button is the Apple Pay button per Apple's rules (black, "Pay with Apple Pay" mark) and the same width and height; the plain primary is used for saved cards.

Primary action: pay. `.medium` haptic on tap.

States. Loading: button spinner; the whole step is non-interactive. Error (hold failed): inline above the bar in the brand's error shape: "That card didn't go through. Nothing's been charged. Try another, or Apple Pay." with the payment row highlighted. Error (slot taken in the meantime): "Someone just booked that time. Pick another." and back to Time with the strip on the same day. Offline: button disabled, offline bar.

Transition out: to Pay (Apple Pay sheet or the card confirmation moment), then Booked.

### Step 6 — Pay

Purpose: the system payment moment.

On it: for Apple Pay, the system `PKPaymentAuthorizationController` sheet over the booking sheet; for a saved card, nothing separate: the Review button shows its spinner for the hold call (mock: 1.2s). This step exists in the state machine so the analytics and the error handling have somewhere to live; it has no chrome of its own.

States: Apple Pay cancelled by the user returns to Review with no message. Hold failure returns to Review with the error above.

Transition out: on success, the sheet's content cross-fades to Booked and the sheet's Back and Close controls are removed (the only way out is the Booked screen's buttons).

### Booked

Purpose: one clean moment, then the detail.

On it: `paper` background. Centred vertically in the top half: a 72pt circle in `lacquerSoft` with a `lacquer` check stroke that draws itself (section 17). Below, `hero` serif "You're booked." on its own line. Then `sub` `ink`: "Sit tight, she's on her way at 2:00 pm Saturday." — for request-to-book the heading is "Sent." and the line is "Kiara usually replies within an hour. We'll tell you the moment she says yes." Then the booking card (section 3) as a summary. Then two buttons stacked: primary `See booking`, text button `Share with a friend`. Below, `caption` `inkSoft`: "Receipt's in your inbox once she's done."

Primary action: `See booking` dismisses the sheet and switches to the Bookings tab with the detail pushed.

Secondary: share (system share sheet with the text from the product spec).

States: none; this screen only appears on success.

Transition out: sheet dismisses downward; the tab switches underneath with no animation so the detail is already there when the sheet is gone. `.success` haptic fires when the check finishes drawing.

---

## 7. Client — Bookings tab

### Bookings

Purpose: what's coming up and what happened.

On it: navigation title "Bookings" (large title, serif). Segmented control under it: `Upcoming` | `Past` (44pt). Upcoming: booking cards sorted by start time ascending; active ones (onHerWay, arrived, inProgress, done) pinned at the top with a `success` left rule 3pt wide. Past: paid, cancelled, declined, missed, newest first; paid ones without a review show a `Rate Kiara` text button on the card's third line instead of the chip.

Primary action: tapping a card.

Secondary: segment switch, pull to refresh.

States. Loading: three placeholder cards. Empty (Upcoming): `heading` serif "Nothing on." `sub` "Want to change that?" secondary button `Who's free` which switches to Home. Empty (Past): "Nothing yet. Your first booking will land here." Error: full-screen with `Try again`. Offline: cached list, offline bar.

Transition out: push to Booking detail.

### Booking detail

Purpose: everything about one booking, and the actions that make sense right now.

On it, top to bottom:

1. Navigation bar: back, title is the service ("Gel set"), right bar `ellipsis` menu: "Share with a friend", "Something wrong?", "Report or block Kiara".
2. Status block: the status chip, then a `title` serif line that says the concrete thing (by state, from the product spec table: "Kiara's coming Saturday at 2:00 pm." / "Kiara's on her way, about 20 minutes." / "Kiara's at your door." / "Done. Pay $168 to Kiara?" and so on). For requested: "Kiara usually replies within an hour." and `caption` `inkSoft` "She's got until 4:12 pm before it goes to someone else."
3. Timeline: a vertical list of five steps: Requested, Confirmed, On her way, Done, Paid. Each has a 12pt dot and a 2pt line to the next; completed steps `success` dot with a tick, the current step a `success` ring, future steps `line`. Each completed step shows `caption` `inkSoft` time ("Booked Thu 3:41 pm"). Arrived and in progress are shown as sub-lines under On her way rather than separate steps so the timeline stays five long. Cancelled, declined and missed replace the remaining steps with one `inkSoft` step "Cancelled Sat 9:02 am" plus the charge line.
4. Pro row: 56pt photo, `body` "Kiara", `sub` "Nail tech · 4.9 · 212 reviews", chevron to the profile. Two buttons side by side under it: secondary `Message` (opens the thread) and, from confirmed until 24h after terminal, secondary `Call`. Before confirmed, `Call` is absent and `caption` reads "You'll swap numbers once she confirms."
5. When and where card: `body` "Sat 27 Sep · 2:00–3:30 pm", `sub` "8 Glenlyon Rd, Brunswick East", the address notes if any, a `Directions` text button is not shown to the client (she is already there); instead a small static map thumbnail.
6. What's booked: the service lines and the price card exactly as on Review, with the total and, once paid, the tip line and "Paid Sat 3:34 pm" and a `Receipt` text button.
7. Notes and inspo, if any.
8. Friend row: "Sharing with Jess" if a friend number was added, with `Change`; otherwise a text button `Share with a friend`.
9. Actions block (which buttons appear depends on state):
   - requested: secondary `Cancel booking` (free, says "Free to cancel while she hasn't said yes").
   - confirmed (≥24h): secondary `Reschedule`, text `Cancel booking` with `caption` "Free until Fri 2:00 pm".
   - confirmed (<24h) and onHerWay: secondary `Reschedule` (as a request), text `Cancel booking` with `caption` "Less than 24 hours' notice: you'll pay $82.50".
   - arrived: text `Cancel booking` with `caption` "She's here, so this is the full $168."
   - inProgress: no cancel; `caption` "Kiara's working. Say hi."
   - done: primary `Pay $168` (opens the pay and tip sheet), text `Something wrong?`.
   - paid, no review: primary `Rate Kiara`. paid, reviewed: secondary `Book again` (opens the booking sheet with the same services).
   - cancelledByPro, declined: a Who's free strip filtered to the same category and day under the heading "Who else is free Saturday".
   - noShow: text `Something wrong?` with `caption` "You've got until 3:34 am to tell us."

Primary action: varies by state, as above. At most one lacquer button on the screen.

States. Loading: from cache instantly; the timeline updates live via the data service's async stream. Error: the cached booking shows with an inline error at the top. Offline: shown from cache; Cancel, Reschedule, Pay, Rate disabled with the offline bar; Message opens the thread and queues.

Transition out: sheets present from the bottom; Message pushes the thread; pro row pushes the profile.

### Reschedule (sheet)

Purpose: move it without cancelling.

On it: `.large` detent. The Time step from the booking flow, reused, with heading "Move it to when?" and the current slot shown as a `sub` line at the top "Now: Sat 27 Sep, 2:00 pm". Bottom bar: primary `Move to Sun 11:00 am` (label updates with the selection). Under 24h, the heading gets a `sub` line: "Less than 24 hours out, so Kiara has to say yes. Your Saturday slot stays until she does."

Primary action: move. `.medium` haptic.

States: as Time. Error (slot gone): as Time.

Transition out: dismiss; the detail's status line updates ("Moved. Kiara's now coming Sunday at 11:00 am." or "Sent. Kiara needs to say yes to Sunday 11:00 am.").

### Cancel (sheet)

Purpose: make the consequence unmistakable before she confirms.

On it: `.medium` detent. `heading` serif "Cancel Saturday with Kiara?" Then the exact consequence as `body`:

- Free: "More than 24 hours' notice, so it's free. Nothing's charged."
- Under 24h: "Less than 24 hours' notice, so Kiara keeps half. You'll pay $82.50. She's already turned down other work for you."
- Arrived: "Kiara's at your door, so this counts as a no-show. You'll pay the full $168."

Then two buttons: primary `Cancel booking` / `Cancel and pay $82.50` / `Cancel and pay $168`, and text `Keep booking`.

Primary action: confirm cancel. `.medium` haptic.

States. Loading: spinner in the button. Error: "That didn't go through. Your booking's still on. Try again." Offline: primary disabled; `caption` "Cancelling needs a connection."

Transition out: dismiss; the detail re-renders as cancelled with the charge line.

### Pay and tip (sheet, at done)

Purpose: close it out and tip if she wants to.

On it: `.medium` detent, growing to `.large` when custom tip is chosen. `heading` serif "Done. Pay $168 to Kiara?" Tip chips in a row: `No tip`, `$10`, `$15`, `$20`, `Custom`; Custom reveals a numeric field. Selected chip is `lacquer`. Under the chips `caption` `inkSoft`: "Tips go straight to her, all of it." Price lines: total $168, tip line when non-zero, and a `title` "Total $183" when a tip is selected. Payment row as on Review. `caption` `inkSoft`: "If you do nothing, we charge $168 at 3:34 am tomorrow, no tip."

Primary action: `Pay $168` / `Pay $183`. `.medium` haptic; `.success` haptic and the toast "Paid. $183 to Kiara, receipt in your inbox." on success.

Secondary: text `Something wrong?` which dismisses this and opens the Something wrong sheet.

States. Error: brand error shape ("That card didn't go through. Nothing's been charged. Try another, or Apple Pay."). Offline: disabled with the caption "Paying needs a connection. We'll charge automatically at 3:34 am if you can't get back."

Transition out: dismiss; the detail becomes paid and the Rate sheet presents automatically after 0.6s.

### Rate (sheet)

Purpose: two taps to say how it was.

On it: `.medium` detent, `.large` when text is being typed. Pro photo 64pt round centred. `heading` serif "How was Kiara?" Five stars at 44pt each, `line` outline unfilled, `honey` filled; tapping star n fills 1…n. Under the stars a `sub` word that changes with the count: 1 "Not good", 2 "Meh", 3 "Fine", 4 "Good", 5 "Very good". Optional text field "Say what she did well, or didn't" 600 max. Optional photos: three 72pt tiles as on Notes. `caption` `inkSoft`: "Shows as Ruby M. with the service and month. Kiara can reply once."

Primary action: `Rate` (disabled until a star is chosen), label becomes `Rate 5 stars` once chosen. `.medium` haptic; on success the sheet shows a brief "Thanks." at `heading` and dismisses after 0.8s.

Secondary: text `Not now` which leaves the prompt on the card for 14 days.

States. Error: "Didn't save. Try again." Offline: saves locally and syncs; the button works and says "Saved. We'll send it when you're online." in a toast.

Transition out: dismiss.

### Receipt

Purpose: a receipt she can screenshot or share.

On it: push. `card` block with the wordmark in one line at the top (`hair done, nails done, everything done.` in serif `heading`), then "Receipt" `label`, booking number, date, pro name and ABN, address, the price lines, tip, total, payment method, "Hair Done booking fee $3 (includes GST)", and `caption` "Hair Done Pty Ltd · ABN shown in mock as 00 000 000 000". Bottom: secondary `Share receipt` (share sheet, PDF rendered from the view via `ImageRenderer`).

States: from cache. Offline: works.

### Share with a friend (system share)

The `ellipsis` menu item and text buttons call the system share sheet with the text from the product spec. Before it opens, a small `.medium` sheet asks once per booking: "Want Jess to get a text when Kiara arrives and when you're done?" with a contact picker button `Pick a number` and text `Just share`. Picking a number stores it on the booking and then opens the share sheet.

### Something wrong (sheet)

Purpose: pause the money and get a human.

On it: `.medium` detent. `heading` serif "What's happened?" Rows: "She didn't do everything I booked", "The work isn't right", "She was late", "She didn't show" (only from noShow, contesting it), "Something else". Text field, required. `sub` `ink`: "We'll pause the charge for up to 48 hours while someone from Hair Done looks. Kiara sees that there's a question, not what you wrote." Primary `Send`.

Transition out: dismiss; the detail's status line changes to "On hold while we look. Someone will message you today." and the Pay button disappears.

---

## 8. Client — Inbox tab

### Inbox

Purpose: every conversation and every update in one place.

On it: navigation title "Inbox". Segmented control `Messages` | `Updates`. Messages: thread rows, 72pt tall: 48pt pro photo, `body` semibold name, `sub` `inkSoft` last message truncated to one line, right side `caption` time and a `lacquer` 8pt unread dot. Under the name, `caption` "Gel set · Sat 2:00 pm" tying the thread to its booking. Sorted by last activity. Updates: rows of status changes (the in-app column of the notifications matrix), 56pt tall, `sub` text, `caption` time, tapping opens the booking detail; unread ones have the dot.

Primary action: tapping a row.

Secondary: segment, pull to refresh, swipe a thread row to `Mute`.

States. Loading: placeholder rows. Empty (Messages): `heading` serif "Quiet in here." `sub` "Your messages with pros show up once you've booked." Empty (Updates): "Nothing yet." Error: full-screen. Offline: cached; sending queues.

Transition out: push to Thread or Booking detail.

### Thread

Purpose: talk to her about this booking.

On it, top to bottom: navigation bar with the pro's 32pt photo and name as the title, tapping it opens the profile; right bar item `Call` (phone icon, only from confirmed until 24h after terminal) and `ellipsis` (report or block, mute). Pinned under the bar: a compact booking card (one line: "Gel set · Sat 27 Sep, 2:00 pm · Confirmed" with the status chip), tappable to the detail. Message list: bubbles, hers on the left in `card` with a hairline, yours on the right in `lacquerSoft` with `ink` text (never lacquer bubbles: brand rule 3), `caption` timestamps every 10 minutes gap, day separators. System lines centred in `caption` `inkSoft` for status changes ("Kiara confirmed · 3:52 pm"). Photos in messages: 200pt max, radius 14, tap to view. Above the composer, a horizontal row of quick reply chips (36pt): client side "Running 5 min late", "Buzzer's broken, call me", "Park out the front", "Thank you!" (the one allowed exclamation mark on this screen); pro side in section 13. Composer: text field radius 14, camera button (44pt) left, send button (44pt, `lacquer` circle with `paper` arrow) right, disabled until there is text or a photo.

Primary action: send. `.light` haptic; the bubble animates in with the spring from the composer's position.

Secondary: quick replies, camera, call, booking card.

States. Loading: from cache instantly. Sending: the bubble shows at 60% opacity with a `caption` "Sending…"; on failure it stays with "Didn't send. Tap to retry." Blocked contact details before confirmed: the composer shows `sub` under itself "You'll swap numbers once she confirms." and the send button stays disabled while the text matches a phone or address pattern. Offline: composer works, messages queue with "Sending when you're back online."; the pinned card shows the cached state.

Transition out: back; profile push; booking detail push.

---

## 9. Client — You tab

### You

Purpose: her stuff, and the door to Pro mode.

On it: navigation title "You". Header: 72pt avatar, `title` serif "Ruby", `sub` `inkSoft` phone number, text button `Edit`. Then grouped rows (56pt, `body`, chevron): Addresses, Payment methods, Favourites, Notifications. A gap. Help, About. A gap. A `card` block: `heading` serif "Pro mode" with `sub` "Do hair, nails, makeup, lashes or brows? Get bookings here." and a secondary button `Set up Pro mode` — or, if she is a pro, `Switch to Pro mode` and `caption` "3 requests waiting" when relevant. A gap. Text button `Log out` in `ink` (not lacquer, not red).

Primary action: none; navigation.

States: static from cache. Offline: all rows work from cache.

Transition out: pushes. `Switch to Pro mode` cross-fades the whole tab view to the pro tab view (0.3s) with a `.medium` haptic. Log out asks "Log out?" with `Log out` and `Stay`.

### Profile

On it: avatar with `Change photo`, First name field, Phone (read-only, `Change` pushes Sign in), `caption` "She sees your first name and your photo once you've booked." Primary `Save` in the navigation bar, enabled on change. Toast "Saved."

### Addresses

On it: rows: label `body` "Home", `sub` address, notes `caption`; `Default` chip on the default one. Swipe to delete, tap to edit. Bottom primary `Add address` which pushes New address (same screen as in the booking flow, not in a sheet). Empty: "No saved addresses. You can add one when you book, too." Long-press a row for "Make default".

### Payment methods

On it: Apple Pay row (present if available on the device, not editable, `Default` chip if chosen), card rows "Visa ···· 4242 · 09/28", swipe to delete, tap for `Make default`. Bottom primary `Add card`. Add card: a mock card form (number, expiry, CVC, name) with formatting as you type; in a Stripe build this is the PaymentSheet. `caption` "Cards are stored with Stripe, not on our servers." Empty: "No cards yet. Apple Pay works without one."

### Favourites

On it: large pro cards for hearted pros, most recently added first. Empty: `heading` "Nobody yet." `sub` "Tap the heart on a pro and she'll turn up here." secondary `Who's free`.

### Notifications

On it: toggle rows: "Reminders before a booking" (24h and 2h), "Rate reminders", "Kiara replied to your review", "Tips from Hair Done" (off by default; product news, at most fortnightly). `caption` under the list: "Booking updates and messages always come through while you've got something on." Quiet hours are fixed and stated: "No pushes 10 pm to 7 am unless she's on her way."

### Help

On it: search field, then plain rows for the top questions ("How does the hold work?", "Cancelling and what it costs", "She didn't show", "Something's wrong with a booking", "Becoming a pro"), each pushing a plain text screen. Bottom: secondary `Message Hair Done` which opens a support thread in the Inbox. `caption` "We reply within a day, usually a lot faster."

### About

On it: the wordmark in one line, version and build, `Terms`, `Privacy`, `Licences`. Nothing else.

---

## 10. Pro onboarding

A full-screen `NavigationStack` flow, not a sheet. Nine steps, each a screen, each with one thing on it and a reason. A thin progress bar (2pt, `lacquer` on `line`) under the navigation bar, fraction = step/9. Every step saves on leaving, so she can quit and come back; `Start` shows "Pick up where you left off" when there is a draft. Step buttons name the next step, never "Continue".

### Start

On it: `hero` serif "Get booked." `body`: "Set up takes about ten minutes. You'll need your ABN, a photo of your ID and three photos of your work. Then someone from Hair Done books you for a first job, and you're live." Primary `Start`. Text `Not now`.

### Specialty

On it: `title` serif "What do you do?" `sub` "Pick everything you offer." Six category tiles as on Home, multi-select, selected ones get the `lacquer` 2pt border and a tick. Choosing The lot requires at least two others (the tile explains: "Bundles need two or more of the others"). Primary `Add services`.

### Services and prices

On it: `title` serif "Services and prices." `sub` "Clients see these before they book. Say the real price." Grouped by chosen category. Each group starts with suggested rows from a seeded list (Nails: Gel set, Acrylic full set, Infill, Removal, Pedicure; Hair: Blow-dry, Event updo, Bridal hair, Cut, Colour touch-up; and so on) as unfilled rows the pro completes or deletes, plus `Add a service` per group. Each row: name field, price field (numeric, `$` prefix), duration picker (15-minute steps from 15 to 240). Bundles under The lot: name, the included services as chips, one price, duration auto-summed but editable. Validation: at least one complete row overall. Primary `Set travel area`.

### Travel area

On it: `title` serif "Where will you go?" A map centred on her base suburb (search field above it: "Your base suburb", autocomplete), a radius picker as chips `2 km`, `5 km`, `10 km`, `15 km` that draws a `lacquer` 20%-opacity circle on the map. Under it: "Travel fee" numeric field with `$` prefix and `caption` "One flat fee, added to every booking. Clients see it on your profile." Primary `Set availability`.

### Availability

On it: the Availability editor from section 12, with a `sub` intro "When can clients book you? You can change this any time from Calendar." Also the "Buffer between jobs" chip row (0, 15, 30, 45, 60) and "Notice you need" chip row (1h, 2h, 3h, 6h, 12h, 24h). Primary `Add photos`.

### Work photos

On it: `title` serif "Show your work." `sub` "At least three. Your own photos of your own work, close and in daylight if you can. No screenshots." A 3-column grid with a `plus` tile first, then the added photos; each photo tile has a category chip picker underneath (defaults to her first category) and a remove button. Counter `caption` "2 of 3 minimum". Primary `Add ID and ABN`, enabled at 3 photos.

### ID and ABN

On it: `title` serif "Who you are." `sub` "Clients only book verified pros. Someone from Hair Done checks this by hand; nothing is automatic." Rows: "Photo ID" with a `Take photo` button (camera or picker) and a thumbnail once added; "Selfie" the same; "ABN" numeric field, 11 digits, formatted 12 345 678 901 with `caption` "Sole trader is fine"; "Public liability insurance (optional)" file/photo upload with `caption` "Shows an Insured tag on your profile". Primary `Set up payouts`, enabled with ID, selfie and a well-formed ABN.

### Payouts

On it: `title` serif "Getting paid." `body` "Payouts go to your bank daily through Stripe. Stripe asks for your details on its own page; we never see your bank login." Fee summary card: "Hair Done takes 12% of what you charge. Clients pay a $3 booking fee on top, which doesn't come out of yours." A worked line: "A $150 set with a $15 travel fee pays you $145.20." Primary `Set up with Stripe` opens a mock Stripe Connect Express page (a full-screen cover with a `Done` button in mock builds; the real link in Stripe builds). On return: the row shows `success` "Connected". Primary becomes `Check it over`.

### Check and send

On it: `title` serif "Check it over." A preview of her profile as clients will see it (the Pro profile screen rendered read-only with a `caption` banner "This is what clients see"), with `Edit` text buttons per section that pop back to that step. Toggle row "Instant book" default off with `caption` "Clients book straight in, no accepting. You can turn it on later." Primary `Send for review`.

Transition out: `.success` haptic; push to Pending.

### Pending

On it: `hero` serif "Sent." `body`: "Someone from Hair Done will check your ID and ABN and book your first job with you, usually within two days. You'll get a push. Until then you can add photos and fix prices, but clients can't see you yet." A checklist with `success` ticks as each item is cleared by the team (ID checked, ABN checked, Photos checked, First booking done). Primary `Go to Today`. This screen is also reachable from Today while pending.

States (whole flow). Loading: rare; saves are local-first. Error on send: "Didn't send. Everything's saved. Try again." Offline: every step works; Send for review queues.

---

## 11. Pro — Today tab

### Today

Purpose: what's next, what's waiting, what I've made.

On it, top to bottom, in a scroll view:

1. Header: `hero` serif greeting by time of day ("Morning, Kiara." / "Afternoon, Kiara." / "Evening, Kiara."), 40pt avatar top-right that pushes Profile edit. `sub` `inkSoft` under the greeting: "3 jobs today · $412 booked" (or "Nothing on today." if none).
2. Pending banner (only while not verified): `card` block "You're not live yet. 2 of 4 checks done." with `See what's left` text button to Pending.
3. Eyebrow REQUESTS with a `warn` count badge. Request cards, one per open request, `card` radius 20: client photo 48pt, `body` "Ruby · gel set", `sub` "Sat 27 Sep, 2:00–3:30 pm · Brunswick East", `body` monospaced "$145.20 to you", `caption` `warn` "1h 12m left". Two buttons side by side: primary `Accept`, secondary `Decline`. Tapping the card body pushes Request detail. Section is omitted when there are none.
4. Eyebrow NEXT UP. The next job card, larger: client photo 56pt, `title` serif "Ruby, 2:00 pm", `sub` "Gel set · 90 min", `sub` "8 Glenlyon Rd, Brunswick East" with a `Directions` text button (opens Apple Maps), notes preview if any, inspo thumbnails if any. Status controls at the bottom of the card, by state: confirmed within 3h of start → primary `On my way`; onHerWay → primary `I'm here`; arrived → primary `Start` and, after 15 minutes, a text button `No show`; inProgress → primary `Done` with `caption` timer "42 min of 90"; done → `sub` "Done. Paying you $145.20." Cards for later jobs today follow as booking cards (section 3).
5. Eyebrow THIS WEEK. A compact earnings block: `title` monospaced "$1,240" `caption` "so far this week", and `sub` "$412 today · $318 pending payout". Tapping pushes Earnings.
6. Eyebrow TOMORROW, then booking cards for tomorrow (max 3, "See calendar" text button).

Primary action: whichever status control is live on the next job; the Accept on a request otherwise. Only one lacquer control is visible at once: requests use the primary style only when there is no live status control; otherwise Accept is secondary.

States. Loading: greeting immediate, cards as placeholders. Empty: NEXT UP shows `heading` serif "Nothing on today." `sub` "Your availability's set for Tue, Thu, Sat. Open more days?" with text button `Edit availability`. Error: full-screen under header. Offline: cached; status controls are disabled with the offline bar and `caption` "Updates need a connection, we'll send it when you're back."

Transition out: push to Job detail, Request detail, Earnings, Profile.

### Job detail

Purpose: everything about the job and the controls to move it.

On it: same layout as the client Booking detail, from the pro's side: status block with the concrete line ("Ruby, Saturday 2:00 pm, Brunswick East."), timeline (Requested, Confirmed, On my way, Done, Paid), client row (photo, "Ruby", `caption` "3rd booking with you" or "First booking with you", `Message` and `Call` from confirmed), when and where card with `Directions`, what's booked with her earnings breakdown (services, travel, Hair Done fee −12%, "Your payout $145.20"), notes and inspo (full size), the status control for the current state as a sticky bottom bar (primary), and an actions block: `Cancel job` (text, with `caption` "Ruby's refunded in full and your reliability drops 20 points."), `Report or block Ruby`.

Status controls: `On my way` (`.medium` haptic, asks nothing), `I'm here` (`.medium`), `Start`, `Done` (a `.medium` sheet "Mark done? Ruby's charged $168 and you're paid $145.20 by tomorrow." with primary `Mark done`), `No show` (see sheet below; disabled with `caption` "Message Ruby first, then wait 15 minutes" until both are true).

States: as Booking detail. Offline: controls disabled with the bar.

### No show (sheet)

On it: `.medium`. `heading` serif "Mark Ruby as a no-show?" `body` "You've been here since 2:01 pm and messaged twice. Ruby's charged the full $168 and you're paid $145.20. She can question it for 12 hours." Primary `Mark no-show`, text `Wait a bit longer`.

### Cancel job (sheet)

On it: `.medium`. `heading` serif "Cancel Ruby's Saturday?" `body` "She's refunded in full and finds someone else. Your reliability drops 20 points; under 70 turns off instant book." Reason chips (required): `Sick`, `Car trouble`, `Family`, `Something else`. Primary `Cancel job`, text `Keep it`.

### Request detail

On it: push. Same as Job detail but the address is the suburb only ("Brunswick East, address after you accept"), the client row has no Call, and the sticky bottom bar has primary `Accept` and secondary `Decline` side by side. `caption` above the bar: "1h 12m left. After that it goes to someone else and counts against you."

Accept: `.medium` haptic; the card flips to confirmed in place with the spring; toast "Booked. Ruby's Saturday at 2:00 pm."

### Decline reason (sheet)

On it: `.medium`. `heading` serif "Why not?" `sub` "Ruby sees this." Rows (radio): "I'm not free then", "I don't travel to Brunswick East", "I can't do that service at the moment". Primary `Decline`. The chosen reason is shown to the client exactly as the product spec's copy.

---

## 12. Pro — Calendar tab

### Calendar

Purpose: see the week, spot the gaps, fix the availability.

On it: navigation title is the month ("September") with `‹` `›` 44pt buttons and a `Today` text button. Right bar `ellipsis`: "Edit availability", "Block time off". A week strip of seven day chips (as the booking day strip, `line` dot under days with jobs). Below, a vertical day timeline for the selected day, 6:00 am to 11:00 pm, 44pt per hour, hour labels in `caption` `inkSoft` on the left. Availability windows render as `lacquerSoft` bands; jobs render as `card` blocks with a `line` hairline and a 3pt left rule in `success` (confirmed and later) or `warn` (requested), showing `sub` semibold "Ruby · gel set" and `caption` "2:00–3:30 pm · Brunswick East"; buffer and travel render as `line`-hatched bands before and after each job so she can see why a gap is not bookable. Blocked exceptions render as `paper` bands with a diagonal `line` hatch and `caption` "Off".

Primary action: none as a button; tapping a job pushes Job detail; long-pressing a day (`.medium` haptic) opens Block time off for that day; tapping an empty area of the timeline opens Block time off with that hour preselected.

Secondary: week navigation, Today, edit availability, block time off, swipe left/right on the strip to move weeks.

States. Loading: the bands render from the template immediately; jobs from cache. Empty week: the timeline shows availability bands only and a `sub` `inkSoft` line at the top "Nothing booked this week." Error: inline. Offline: cached, edits queue.

Transition out: pushes and sheets.

### Availability

Purpose: set the weekly template.

On it: push. `title` serif "When can clients book you?" Seven rows, Monday to Sunday, each with a toggle and, when on, one or more window rows "9:00 am – 5:00 pm" (each end is a wheel-style time picker in a popover, 15-minute steps) and `Add another window` text button. Below the days: "Buffer between jobs" chips and "Notice you need" chips (as in onboarding). A `sub` `inkSoft` preview line updates live: "Clients can book you 32 hours a week." Primary `Save` in the navigation bar, enabled on change. Validation: windows on a day cannot overlap; an overlapping window shows an inline error and Save is disabled.

Transition out: pop with a toast "Saved."

### Block time off (sheet)

Purpose: a one-off exception.

On it: `.medium` detent. `heading` serif "Block time off." Date row (a date picker, defaults to the day tapped). Segmented: `All day` | `Some of it`. With Some of it: from and to time pickers. Optional note "Why" (only she sees it). Also a third segment `Extra hours` to add a window on a day that is normally off. `sub` `inkSoft` warning if the block overlaps a booked job: "You've got Ruby at 2:00 pm that day. Blocking won't cancel it; cancel the job first if you need to." Primary `Block Sat 27 Sep` (label updates).

Transition out: dismiss; the timeline redraws with the spring.

---

## 13. Pro — Inbox tab

Identical to the client Inbox and Thread with these differences: threads show the client's name and "3rd booking with you" under it; the pinned booking card shows the payout instead of the total ("$145.20 to you"); quick replies are "On my way, about 15 min", "Running 10 late, sorry", "Here, which door?", "Send me a photo of what you're after"; the request-stage rule hides the client's address in the pinned card until confirmed; the pro's bubbles are on the right in `lacquerSoft`.

---

## 14. Pro — Work tab

### Work

Purpose: her photos, in the order she wants, tagged so clients find them.

On it: navigation title "Work", right bar `Select` text button and a `plus` (44pt) that opens the picker. Filter chips under the bar: `All`, then her categories. A 3-column grid, 2pt gaps, square crops. Pinned photos show a small `pin.fill` badge in `card` top-left. Long-press on a tile (`.medium` haptic) lifts it and starts drag-to-reorder; the grid animates with the spring. Tap opens Photo detail. `caption` `inkSoft` under the bar: "34 photos · 3 pinned. Pinned ones show first on your profile and one is your cover."

Primary action: `plus` add photos.

Secondary: reorder, select (multi-select for delete and tag), filter.

States. Empty: `heading` serif "Nothing here yet." `sub` "Three photos minimum to go live. Your own work, close, in daylight." primary `Add photos`. Uploading: new tiles appear with a placeholder and a thin progress line at the bottom of the tile; failures show a `warn` icon and tap to retry. Offline: viewing works; adding queues with the progress line paused and a `caption` "Uploads when you're back online."

Transition out: picker sheet; Photo detail sheet.

### Add photos (picker)

PhotosPicker, up to 10 at once. After picking, a `.large` sheet "Tag these" shows each photo at 96pt with a category chip row underneath (defaults to the current filter or her first category) and primary `Add 4 photos`.

### Photo detail (sheet)

On it: `.large` detent. The photo full width, 4:5. Below: category chip row (editable), toggle "Pinned" with `caption` "Pinned photos show first", toggle "Cover photo" (only one; turning it on turns the other off), `caption` "Added August 2026". Text button `Delete photo` in `ink`, confirms with "Delete this photo?" `Delete` / `Keep`. Changes save on dismiss; toast "Saved."

---

## 15. Pro — Earnings tab

### Earnings

Purpose: what she's made, what's coming, and where the 12% went.

On it, top to bottom:

1. Navigation title "Earnings".
2. Period segmented control: `This week` | `This month` | `All time`.
3. Hero number: `hero` serif monospaced "$1,240" with `sub` `inkSoft` "paid to you this week" and, on the right, a small `caption` "+18% on last week" in `success` (or `inkSoft` when down; never red).
4. A simple bar strip of the last 7 days (or 4 weeks, or 12 months), 88pt tall, `lacquer` bars on `line` baseline, no axis labels beyond first and last day `caption`. Tapping a bar shows the day's total in a popover.
5. Eyebrow PENDING. A `card` block: `body` "$318 on its way", `sub` "Lands tomorrow, Tue 30 Sep", `caption` "From 2 jobs done yesterday". If nothing pending: "Nothing pending."
6. Eyebrow TIPS. `body` "$45 this week" `caption` "From 3 clients. Tips are all yours."
7. Eyebrow FEES. `body` "$148.80 to Hair Done this week" `caption` "12% of $1,240. Clients paid $24 in booking fees on top." Text button `How fees work` pushes Fee breakdown.
8. Eyebrow HISTORY. Rows per paid booking: `body` "Ruby · gel set", `sub` "Sat 27 Sep", right side `body` monospaced "$145.20" and `caption` "+$15 tip". Tap pushes Booking earnings. Then payout rows in `card` blocks between bookings: "Payout $312.40 · Mon 29 Sep · Sent" with a chevron to Payout detail. Paged.

Primary action: none; reading.

States. Loading: hero from cache, list placeholders. Empty: `heading` serif "Nothing yet." `sub` "Your first payout shows up here the day after your first job." Error: inline. Offline: cached.

### Booking earnings

On it: push. Title is the service. Client, date, and the breakdown card exactly as on the job detail (services, travel, fee, payout, tip on its own line), then `caption` "Paid out Mon 29 Sep in payout #1042". Text button `See booking`.

### Payout detail

On it: push. `title` monospaced "$312.40", `sub` "Sent Mon 29 Sep to ···· 8821", status chip `Sent` (`success`) / `On its way` (`warn`) / `Failed` (`inkSoft`, with `caption` "Check your bank details with Stripe" and a `Fix with Stripe` secondary button). Rows for each booking in the payout. `caption` "Stripe payout ID po_…" for support.

### Fee breakdown

On it: push, plain text screen. `title` serif "How fees work." Then in `body`: the rules from the product spec in her words: "Hair Done takes 12% of what you charge, including your travel fee. The client pays a $3 booking fee on top; that's theirs, not yours. Tips are yours, all of it. Late cancellations pay you half your price less 12%. No-shows pay you in full." Then the $150 + $15 worked example as a card. Then "Payouts go out daily and land the next business day."

---

## 16. Pro — Profile edit

Reached from the Today avatar. Push, navigation title "Profile", right bar `Preview` text button that shows the client-facing Pro profile read-only.

On it, top to bottom, grouped rows:

1. Header: cover photo (the pinned cover, `Change` pushes Work), avatar with `Change photo`, `title` serif "Kiara", `Verified` chip, `sub` "4.9 shown · 4.92 raw · 212 reviews" with an `info.circle` popover: "The shown number starts near 4.6 and moves as reviews come in, so one bad day doesn't sink a new pro."
2. Reliability block (`card`): `heading` "Reliability 94" with `success` text "Reliable badge is on" or `warn` "Reliable badge needs 90". The last five changes as `caption` rows ("+1 On time, Sat 27 Sep", "−3 Late, Thu 18 Sep"). `caption` "Not shown to clients. Under 70 turns off instant book; under 50 pauses your profile until we've talked."
3. Rows: Bio (pushes a multiline editor, 400 chars, emoji allowed), Services and prices (pushes the onboarding Services screen), Travel area and fee (pushes the onboarding Travel area screen), Availability (pushes Availability), Buffer and notice (inline chips).
4. Instant book toggle row with `caption` "Clients book straight in, no accepting. Needs reliability 70 or more." Disabled with the reason when below 70.
5. Insurance row: `Insured` chip if checked; otherwise `Add insurance` with `caption` "Optional. Shows an Insured tag."
6. Payouts row: "Stripe · connected" or `Fix with Stripe`.
7. Notifications row (pro version: reminders, payout pushes, review pushes; requests and status pushes fixed on).
8. A gap. Secondary button `Switch to client mode`. Text `Log out`.

Changes save per screen with a toast "Saved." The toggle saves immediately with `.light` haptic.

---

## 17. Interaction details

All motion uses the brief's default spring `.spring(response: 0.35, dampingFraction: 0.85)` unless a duration is given. All durations below drop to a 0.15s cross-fade or nothing under reduce motion (section 18).

### Haptics

| Moment | Haptic |
|---|---|
| Selecting a chip, a service row, a star, a tab, a segment | `.light` (`UIImpactFeedbackGenerator(style: .light)`) |
| Tapping a disabled slot chip | `.rigid` |
| Primary actions: Pay, Request, Accept, On my way, I'm here, Start, Done, Cancel booking, Send report, Move to | `.medium` |
| Booked (check finishes drawing), Paid (capture succeeds), Verified push opened, Rate submitted | `.success` (`UINotificationFeedbackGenerator`) |
| Wrong code, failed hold | `.error` |
| Long-press begins (reorder photo, calendar day) | `.medium` |
| Pull to refresh reaches the threshold | `.light` |

No haptic on scroll, on sheet open, on navigation, or on toast.

### Sheets

Booking flow, reschedule and rate open at `.large`; cancel, decline reason, no show, pay and tip, verified, report open at `.medium`. All have the drag indicator. The booking flow's steps move horizontally inside the sheet with the spring: incoming step from +100% x, outgoing to −30% x with opacity to 0 (asymmetric so it reads as a stack). Back reverses. The sheet height does not change between steps.

### The lacquer check on Booked

A 72pt `lacquerSoft` circle scales from 0.6 to 1.0 with the spring over 0.35s. 0.1s in, a check path (two segments, stroke 5pt, round caps, `lacquer`) draws with `trim(from: 0, to: p)` where `p` animates 0 → 1 over 0.45s with `.easeOut`. When it reaches 1, `.success` haptic. Then the heading "You're booked." fades and rises 8pt over 0.25s, then the subline 0.1s later, then the rest 0.1s after that. Total about 1.1s before the buttons are interactive. This is the one delightful moment in the booking flow; nothing else in the flow animates beyond the standard transitions. Under reduce motion: circle and check appear, no trim, everything fades in over 0.2s, haptic still fires.

### The star that fills with honey

In the Rate sheet, tapping star n: stars 1…n fill in sequence, 40ms apart, each scaling 1.0 → 1.25 → 1.0 with the spring as it fills `honey`. `.light` haptic on the tap only, not per star. Under reduce motion: instant fill, no scale.

### The pro card that lifts on press

On press-down (`.onLongPressGesture(minimumDuration: 0)` pattern or a custom `ButtonStyle`): the card scales to 0.98 and its hairline darkens to `inkSoft` at 30% with the spring. On release inside: returns to 1.0 and navigates. On drag-out or cancel: returns to 1.0 without navigating. Under reduce motion: the hairline change only.

### Sticky Book bar

Hidden at scroll offset 0; slides up (from +64pt y, opacity 0 → 1) with the spring once the name block's top passes the safe area top. Does not hide again on scroll down. When services are toggled on the profile, the bar's label cross-fades (0.2s) and the price uses `.contentTransition(.numericText())`.

### Slot picker

Day strip snaps per chip (`scrollTargetBehavior(.viewAligned)`). Selecting a day: the chip's fill animates with the spring; the time groups below cross-fade (0.2s) to the new day's chips; the layout height change is animated. Selecting a time chip: fill animates; the summary line above the bar slides in from below (16pt) with the spring. The reason popover on a disabled chip fades in over 0.15s and out over 0.15s.

### Lists

Pull to refresh on Home, Bookings, Inbox, Today, Calendar, Work and Earnings with the system control tinted `lacquer`. Rows insert and remove with the spring (`.animation(.default, value:)` on the collection). Skeleton placeholders pulse opacity 0.6 → 1.0 over 1.2s, looping, `line` colour; under reduce motion they are static.

### Status changes arriving live

When a booking's state changes while its card or detail is on screen (via the data service's async sequence), the status chip cross-fades, the timeline's next dot fills with the spring, the status line's text cross-fades, and the actions block re-lays out with the spring. No toast for a change the user is already looking at.

### Keyboard

Fields that are the only thing on a screen focus on appear. Primary buttons that sit above the keyboard use `safeAreaInset(edge: .bottom)` so they ride up with it. Tapping outside a field dismisses the keyboard on every screen with a scroll view (`.scrollDismissesKeyboard(.interactively)`).

### Toasts

Slide up from below the tab bar 12pt with the spring, hold 3s, slide down. Only one at a time; a new one replaces the current.

### Images

Cross-fade from the gradient placeholder over 0.25s when loaded. Grid tiles load thumbnails first. The viewer's swipe-to-dismiss follows the finger with the background opacity mapped to the drag distance (0–160pt → 96% → 0%).

---

## 18. Accessibility

This is part of the definition of done for every screen, not a pass at the end.

### Dynamic Type

Every text style is a system text style with the serif design applied, so it scales. Layouts are tested at the default size, at `xxxLarge` and at the accessibility size `accessibility3`. Rules: horizontal rows (a label and a value, two side-by-side buttons, the sticky bar's two halves) switch to vertical stacks when the size category is an accessibility size (`@Environment(\.dynamicTypeSize)` `.isAccessibilitySize`). Chips wrap rather than truncate; the day strip's chips grow in height, not width, and the date stays. The tab bar uses the system's large-content viewer on long press. Nothing clamps a font size; the serif headings are given room (`.fixedSize(horizontal: false, vertical: true)`). The one exception is the wordmark on the Welcome hero, which may be clipped by the hero's height at the largest sizes; the hero grows to fit up to 70% of the screen.

### VoiceOver

- Stars and ratings: the "4.9 · 212 reviews" unit reads "4.9 stars, 212 reviews". In the rate sheet, each star is a button with the label "n stars" and the group has an `accessibilityValue` of "3 of 5 stars selected". The distribution bars read "5 stars, 180 reviews".
- Status: the status chip reads its text plus the concrete line, e.g. "Confirmed. Kiara's coming Saturday at 2:00 pm." The timeline reads as a list: "Requested, done, Thursday 3:41 pm. Confirmed, done. On her way, current step."
- Pro cards are one element: "Kiara, nail tech, 4.9 stars, 212 reviews, 1.8 kilometres away, free from 5 pm, instant book. Button." The heart is a separate element after it: "Add Kiara to favourites" / "Remove Kiara from favourites", with `.isSelected` trait when favourited.
- Slot chips: "2:00 pm, available" or "2:00 pm, unavailable, Kiara's booked then". The reason is in the label so a VoiceOver user does not need to tap to hear it. Day chips: "Saturday 27 September, 4 times free" or "…, Kiara's off".
- Prices: "$145.20" reads as "one hundred and forty-five dollars twenty". Line items are grouped so a row reads "Travel fee, fifteen dollars".
- Decorative images (placeholder gradients, the map thumbnail on Location, the drop mark) are hidden. Work photos have the label "Kiara's work, photo 4 of 34, nails".
- Buttons whose label is only an amount get the action in the accessibility label: `Pay $168` reads "Pay one hundred and sixty-eight dollars"; the `plus` in Work reads "Add photos"; `ellipsis` reads "More options".
- Headings use `.accessibilityAddTraits(.isHeader)` so the rotor can jump between sections; the eyebrows are headers.
- Sheets announce their heading on open (`AccessibilityNotification.ScreenChanged`). Toasts announce with `.Announcement`. Live status changes announce once: "Kiara's on her way."
- The offline bar is announced when it appears and disappears.
- Focus order in the booking flow: heading, then content, then the bottom bar; the Back and Close controls come last so a swipe-right from the top does not land on Close.

### Targets

Every tappable element is at least 44×44pt. Chips are 36pt tall visually but carry a 44pt hit area via `.contentShape` with vertical padding. Time chips in the slot picker have 8pt vertical spacing so hit areas do not overlap. Photo grid tiles are larger than 44pt at any width. The heart on a pro card, the close on a sheet, the `ellipsis`, the strip arrows are all 44pt.

### Reduce motion

`@Environment(\.accessibilityReduceMotion)` is read at the root and passed down as `motion` (`.full` or `.reduced`). Under reduced: springs become 0.15s cross-fades; the lacquer check, the star fill, the card lift, the shake and the splash trim are replaced as described in section 17; skeletons are static; the sticky bar appears without sliding; step transitions in the booking sheet are cross-fades; parallax or scale on scroll is never used anyway. Haptics still fire.

### Colour is never the only signal

- Status: chip text says the state; the dot is decoration.
- Disabled slot chips: the slash icon plus the reason, not just the greyed fill.
- Selected chips: the fill change plus a checkmark when the chip is in a multi-select group (categories on Specialty), and the `.isSelected` trait.
- Errors: the `warn` icon plus text, never a red border alone.
- Stars: the count in text next to them.
- Success and pending: the word is always there ("Confirmed", "Waiting on Kiara").
- The lacquer primary button is also the only pill with a filled background at full opacity in its region, and it carries the verb.

### Contrast

Token pairs and their ratios are in the brand doc. Text on category tints is `ink` (all pass). `inkSoft` is never placed on `lacquerSoft`. Disabled primary buttons (lacquer at 40%) are not required to meet contrast, per WCAG's inactive-control exception, but their label still reads "dimmed" to VoiceOver.

### Other

- Bold Text setting is respected (system handles it).
- Increased Contrast: hairlines become 2pt and `inkSoft` steps to `ink` at 80%.
- Differentiate Without Colour: no change needed; the design already does.
- Voice Control: every button has a spoken label that matches its visible text.
- Larger accessibility sizes stack the sticky bar vertically (price above button, full-width button).

---

## 19. State rules that apply everywhere

- Loading never shows a spinner with a slogan. Skeletons where layout is known, a plain 20pt `inkSoft` spinner centred where it is not. Anything from cache renders immediately; the network fills in around it.
- Empty states say what is missing and give one way forward, in the screen's own words. Never "No data".
- Errors say what happened, what we did, what she can do. Three sentences at most. Never "Oops", never "Something went wrong" on its own. Inline where the error belongs to one element; full-screen only when there is nothing else to show.
- Offline shows the bar, keeps everything readable from cache, disables only the actions that genuinely need the network, and says so under the disabled control in one `caption` line. Anything that can queue (messages, reviews, photo uploads, reports, availability edits) queues and says "when you're back online".
- Nothing modal for a failure that the user did not initiate. Live changes arrive in place.
- Every screen has a `<title>`-equivalent: a navigation title or a `hero`/`title` serif line, so VoiceOver has something to land on.
- Every list is paged at 10–20 items with a plain `inkSoft` spinner row at the bottom while the next page loads.
