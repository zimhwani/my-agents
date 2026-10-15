# Components and tokens

The catalogue for screen rebuilds. Everything here lives in `HairDone/DesignSystem/` (and the tab bar, mode switch and toast in `App/RootView.swift`). Rules behind it: `docs/build-brief.md` §4 and `docs/brand.md` (Colour, Shape). The look to match is Home, the pro profile and Check it over / You're booked. Each component file has a `#Preview`.

Three rules that decide most calls:

1. **Ink is the action colour.** Lacquer is only `Pay $X` / `Request · $X`, the unread dot, the active-tab dot and the drawn check.
2. **Squared.** Blocks and buttons 6, photos 2. No pills, no capsules, nothing on a photo.
3. **Hairlines over boxes.** Rows on paper, not white cards. Serif regular for words a person would say, SF for everything else, money in SF monospaced.

## Tokens

### Colour (`Palette`)

| Token | Use |
|---|---|
| `paper` | Screen ground. |
| `ink` | Text, actions, selection, checks. The global tint (set in `RootView`). |
| `inkSoft` | Secondary text. The lightest colour any text may use. |
| `inkFaint` | Glyphs (chevrons), hairlines, disabled fills. **Never text** (3.1:1). |
| `line` | Quiet dividers, field rules, `OptionBox` borders. |
| `lineStrong` | Hairlines between data rows (price list, receipts, settings). Replaces `ProfileTone.lineStrong`. |
| `lacquer` | Dots and strokes only: unread, active tab, the check. Brighter in dark. |
| `lacquerFill` | The Pay / Request button fill. Fixed `#C8323A`, so `onLacquer` passes AA in both modes (4.96:1). |
| `onLacquer` | `#FBF7F2` label on `lacquerFill`. |
| `lacquerSoft` | The offline bar only. Ink text on it. |
| `inkGround` | Ink moments: ticket, Next up, Book bar, job hero, ink save bars. Also every ink *fill* on paper: selections, my bubble, toasts, undo bars (never `Palette.ink` as a fill: it's cream in dark), with `onInk` type. `#241A16` light; `#0E0A09` dark, a step *darker* than dark paper. Replaces `BookingInk.inkGround`, `HomeInk.ink`, `ProfileTone.inkGround/inkFixed`. |
| `inkEdge` | The 0.5pt edge round an ink block or bar: the ink itself in light (invisible), `#3A302B` in dark, where the block is darker than the paper. A selection adds a 1pt `Palette.ink` edge instead (cream in dark) so the pick still stands out. |
| `inkRaised` | A surface on ink (a card on the ticket). `#241C18` dark. Replaces `BookingInk.inkCard`. |
| `onInk`, `onInkSoft`, `inkLine` | Type, secondary type and hairlines on ink. Replace `BookingInk.onInk/onInkSoft/inkLine`, `HomeInk.onInk`, `ProfileTone.paperOnInk`. |
| `onPhoto` | Type on a photo (hero name). Replaces `ProfileTone.onPhoto`. |
| `photoGround` | Behind a photo that hasn't loaded. Replaces `HomeInk.photoGround`. |
| `honey` | The rating picker only. |
| `success`, `warn` | Status dots (and `warn` for a field's problem rule). Never text, money or tips. |
| `card`, `tint(_:)`, `tintInk(_:)` | Retired from new screens. Kept so old code compiles. |

Contrast numbers are in the comment at the top of `Palette.swift`.

### Type (`HDFont`)

Serif, New York, **regular**, scales with Dynamic Type:

| Style | Size | When |
|---|---|---|
| `heroName` | 48 (cap 64) | Her name on a full-bleed photo. Replaces `ProfileType.heroName`. |
| `display` | 40 | Tab-root titles ("Bookings."), greetings, "You're booked.". Replaces `HomeFont.greeting`. `hero` is now an alias. |
| `title` | 34 | Step titles, "Kiara at yours.", detail headlines. (Was 28 medium.) |
| `titleSmall` | 28 | Sheet titles, ConfirmSheet question, empty and error lines, day heads. |
| `section` | 26 | Section heads. Replaces `HomeFont.section`. |
| `name` | 22 | Names in rows. Replaces `HomeFont.rowName`. `heading` is now an alias. |
| `nameBar` | 21 | Name in an ink bar. Replaces `HomeFont.nextUp`, `ProfileType.barName`. |
| `nameSmall` | 19 | Names under photos. Replaces `HomeFont.railName`. |
| `quote` | 19 | Bio, review quotes, record lines. Replaces `ProfileType.bio/quote`. |
| `categoryWord` | 16 | Word under a category photo. Replaces `HomeFont.category`. |
| `navTitle` | 17 | `HDNavHeader` title. |
| `serifItalic` / `italicSub` | 19 / 15 | One leaned-on line; her note. |

SF: `body` 17 · `bodyStrong` 17 semibold (buttons) · `sub` 15 · `subStrong` · `subMedium` 15 medium (links, tabs, options) · `caption` 13 · `eyebrow` 12 medium (`label` is an alias).

Money, SF monospaced, never serif: `price` 17 · `priceStrong` 17 semibold · `priceSmall` 15 (replaces `HomeFont.price`) · `priceLarge` 22 (was serif) · `priceTotal` 28 · `priceDisplay` 36 (one per screen, the ticket total) · `priceHero` 56 light (Earnings) · `timeDisplay` 40 light (the job time). `numeral` is an alias of `priceTotal`.

Builders for odd sizes: `HDFont.serif(_ size:, relativeTo:, weight:)` and `HDFont.sans(...)`. Same signature as `BookingInk.serif/sans`, so swapping is a rename.

Eyebrow: `.labelStyle()` (inkSoft) or `.eyebrowStyle(color:)` (any colour, e.g. `Palette.onInkSoft` on ink). 12 medium, caps, tracking 1. Replaces `homeEyebrow()` and `profileEyebrow()`.

### Shape and space

`Radius.card` 6 · `Radius.button` 6 · `Radius.photo` 2 · `Radius.tile` 2 (alias) · `Radius.input` 6 and `Radius.chip` 6 (deprecated). `.photoShape()` clips to 2.

`Space`: xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · gutter 20 · cardPadding 16 · section 32 (was 36).

`.inkBlock(padding:radius:)`: `inkGround`, `onInk` foreground, 6pt corners, 0.5pt `inkEdge` hairline so it keeps an edge in dark. Use for Next up (`HomeNextUpCard` in `Features/Home/HomeParts.swift` is the only Next up), the job hero, the Pro mode row on You.

`.card()` still exists (now 6pt). Don't use it in rebuilt screens.

## Components

### Buttons (`Components/Buttons.swift`)

All squared at 6, SF 17 semibold, `minHeight` 52 (44 with `compact: true`), grow with Dynamic Type.

| Component | When | Signature | Example |
|---|---|---|---|
| `InkButton` | **The default action.** Save, Next, Accept, Message Kiara, Cancel it, Log out. | `InkButton(title:symbol:isLoading:isEnabled:tone: .ink/.onInk, compact:action:)` | `InkButton(title: "Accept", compact: true) { accept() }` |
| `OutlineButton` | The quiet sibling: Reschedule, Decline, Add a service. | `OutlineButton(title:symbol:isLoading:isEnabled:tone: .paper/.onInk, compact:action:)` | `OutlineButton(title: "Decline", compact: true) { declining = b }` |
| `PrimaryButton` | **Money only**: `Pay $X`, `Request · $X`. Lacquer fill. | `PrimaryButton(title:symbol:isLoading:isEnabled:action:)` | `PrimaryButton(title: "Pay $113") { pay() }` |
| `TertiaryButton` | Text link, 44pt tall. inkSoft by default; `tint: Palette.ink` when it is the action. Never lacquer. | `TertiaryButton(title:tint:action:)` | `TertiaryButton(title: "Book again", tint: Palette.ink) { rebook() }` |
| `IconButton` | Bare glyph, 44pt hit area, 19 regular. Back, close, share, week arrows. `filled` is ignored. | `IconButton(symbol:label:filled:tint:action:)` | `IconButton(symbol: "xmark", label: "Close") { dismiss() }` |
| `StickyBar` | Paper bottom bar. Action is an `InkButton`; `isMoney: true` makes it lacquer. | `StickyBar(title:isLoading:isEnabled:isMoney:action:leading:)` | `StickyBar(title: "Save", action: save) { EmptyView() }` |

### Choices

| Component | When | Signature | Example |
|---|---|---|---|
| `TextTabs` | Segments and filters: Upcoming/Past, Week/Hours, Work filters. Underlined text, on the title row. `.serif` style for category words. | `TextTabs(selection: Binding<V>, options: [V], style: .sans/.serif, spacing:, label: (V) -> String)` | `TextTabs(selection: $segment, options: Segment.allCases) { $0.rawValue }` |
| `OptionBox` (label) | A short choice: tips, km presets, time slots, address labels, quick replies. Selected = `inkGround` fill, `onInk` text, 1pt ink edge. | `OptionBox(title:isSelected:action:)` | `OptionBox(title: "$10", isSelected: tip == 10) { tip = 10 }` |
| `OptionBox` (content) | A rich choice. `.box` = 6pt hairline box with ink check; `.row` = hairline row with ink check. Same argument order as `SelectableCard`. | `OptionBox(isSelected:style: .box/.row, action:content:)` | `OptionBox(isSelected: r == reason, style: .row, action: { reason = r }) { Text(r) }` |
| `HDSwitch` | A setting that's on or off. Squared ink track, paper knob. | `HDSwitch(title:subtitle:isOn:)` or `Toggle(...).toggleStyle(.hd)` | `HDSwitch(title: "Instant book", isOn: $instant)` |
| `HDStepper` | A small number. Bare minus/plus, SF monospaced value, VoiceOver adjustable. | `HDStepper(title:value:in:step:format:)` | `HDStepper(title: "Buffer", value: $buffer, in: 0...60, step: 15) { "\($0) min" }` |
| `Chip` | Deprecated. Now a compact `OptionBox`; `symbol` and `tint` ignored. | unchanged | |

### Fields

| Component | When | Signature | Example |
|---|---|---|---|
| `HDTextField` | Every text input. Underline field: label 13 inkSoft above, 1pt `line` rule, 2pt ink when focused, `warn` rule and ink message when `error` is set. | `HDTextField(label:placeholder:text:keyboard:contentType:axis:caption:error:)` | `HDTextField(label: "Postcode", text: $postcode, keyboard: .numberPad, error: postcodeError)` |
| `FieldMessage` | An inline problem under any control: warn dot plus ink SF 13. Replaces lacquer error text. | `FieldMessage(text:)` | `FieldMessage(text: "That code didn't work. Try again.")` |

### Rows, headers, sheets

| Component | When | Signature | Example |
|---|---|---|---|
| `HairlineRow` | Every list row on paper: settings, addresses, payments, hours, history. 0.5pt `lineStrong` hairline. `trailing` is a view value, so the trailing closure is always the action. | `HairlineRow(title:subtitle:value:symbol:chevron:showsHairline:trailing:action:)` | `HairlineRow(title: "Addresses", value: "2") { showAddresses = true }` |
| `ChecklistRow` | A setup step: ink tick when done, `Do it` link when not. | `ChecklistRow(title:subtitle:isDone:actionTitle:action:)` | `ChecklistRow(title: "Payouts", isDone: on) { setUp() }` |
| `ProEyebrow` | Above the serif title on every pro tab root. | `ProEyebrow(name:detail:color:)` | `ProEyebrow(name: pro.displayName)` gives `PRO · KIARA M.` |
| `SectionHeader` | Serif 26 head with an ink text action. | unchanged | `SectionHeader(title: "Near you", actionTitle: "See all") { ... }` |
| `HDNavHeader` / `.hdNavHeader` | Every pushed screen. Hides the stock bar, bare chevron back, serif 17 title, optional trailing, keeps swipe-back. `tone: .ink` on ink grounds; `tone: .onPhoto` over a full-bleed photo (no ground, `onPhoto` glyphs, laid over the content instead of inset). `titleMark:` puts a view (the thread's avatar) beside the title, centred with it. | `.hdNavHeader(_ title:, tone:, showsHairline:, onBack:, trailing:)` or `.hdNavHeader(_ title:)` | `.hdNavHeader("Kiara M.") { IconButton(symbol: "square.and.arrow.up", label: "Share") { share() } }` |
| `SheetHeader` | Top of every sheet: serif 28, bare xmark. Add `.presentationBackground(Palette.paper)`. | unchanged | `SheetHeader(title: "Pay with", onClose: { dismiss() })` |
| `ConfirmSheet` / `.confirmSheet` | Before anything she can't take back. Replaces `confirmationDialog`, `.alert` and swipe-to-delete. Ink action, no red. `onConfirm` runs after the sheet closes. | `.confirmSheet(isPresented:title:message:confirmTitle:cancelTitle:onConfirm:)` | `.confirmSheet(isPresented: $confirmLogout, title: "Log out?", confirmTitle: "Log out", cancelTitle: "Stay") { app.signOut() }` |
| `ConfirmSheet` (by hand) | Extra content (the cancellation amount) or async work with `isWorking`. Put `.confirmSheetPresentation()` on it inside your own `.sheet`. | `ConfirmSheet(title:message:confirmTitle:cancelTitle:isWorking:onConfirm:onCancel:detail:)` | `ConfirmSheet(title: "Cancel this booking?", confirmTitle: "Cancel and pay $56.50", isWorking: busy, onConfirm: cancel, onCancel: nil) { Text("$56.50").font(HDFont.priceTotal) }.confirmSheetPresentation()` |

### States

| Component | When | Signature | Example |
|---|---|---|---|
| `EmptyState` | Nothing here yet. Left-aligned, serif 28, sub-line, `OutlineButton`. Brings its own gutter. `symbol` ignored. | `EmptyState(symbol:title:message:actionTitle:action:)` | `EmptyState(title: "Nothing on. Want to change that?", actionTitle: "See who's free") { app.selectedTab = .home }` |
| `ErrorState` | A load failed. Defaults to "Couldn't load." / "Check your connection." / `Try again`. | `ErrorState(title:message:actionTitle:action:)` | `ErrorState { Task { await app.loadBookings() } }` |
| `OfflineBar` | lacquerSoft bar, 32pt at the default size, wraps at large text: "You're offline. Showing what we've got." | `OfflineBar(text:)` | `if !online { OfflineBar() }` |
| `SkeletonBlock` | A loading shape at the real size, 2pt. `color: Palette.inkLine` on an ink ground. Also stands in for a client's name while it loads (`app.isClientNameKnown`). | `SkeletonBlock(width:height:radius:color:)` | `SkeletonBlock(width: 104, height: 130)` |
| `RowSkeleton`, `ListSkeleton` | A row (72x90 photo and three bars), or a few at the gutter. Only before the first answer, never over what's there. | `ListSkeleton(rows:)` | `if app.showsBookingsSkeleton { ListSkeleton() }` |
| `TileSkeleton` | A 4:5 tile loading. | `TileSkeleton(width:)` | `TileSkeleton(width: 150)` |
| `UploadTile` | A photo she picked: progress line, done, or failed (faded, a retry glyph, and "Didn't upload. Tap to try again." *under* the tile, so it wraps). Always her image, never a stand-in. | `UploadTile(image: UIImage?, state:size:onRetry:onRemove:)` or `UploadTile(state:size:onRetry:onRemove:photo:)` | `UploadTile(image: pick.image, state: pick.state) { retry(pick) }` |
| `LoadingDots` | "She's typing". | unchanged | |
| `LacquerCheck` | The drawn check, now a bare lacquer stroke (no disc). | `LacquerCheck(size:)` | `LacquerCheck(size: 56)` |

### Marks, people, photos

| Component | Now |
|---|---|
| `StatusBadge(status:)` | Eyebrow: 6pt status dot plus tracked caps in ink; cancelled has no dot, inkSoft. |
| `Tag(text:)` | Text eyebrow in inkSoft. `color` and `background` ignored. Never on a photo. |
| `VerifiedBadge(compact:)` | "ID checked" in inkSoft text. No seal, no green. |
| `RatingLine` | Outline star in inkSoft, SF 15. |
| `StarsRow` | Ink filled / inkFaint outline. `StarPicker` keeps honey. |
| `Avatar(name:seed:size:url:photo:)` | Inbox and thread header only. Pass `photo: pro.homeCover` for a pro. Serif regular initials for clients. |
| `HomeProRow` / `HomePortraitTile` (Features/Home/HomeParts.swift) | A pro in a list or rail. (`ProCard`, `ProMiniTile`, `NextUpBlock` and `PortraitTile` are gone.) |
| `WorkTile(showCaption:isIllustration:)` | Caption on a soft scrim, no capsule. Her photo when there is one. On the live backend a pro's work or a client's inspo never borrows a bundled stock photo: no photo shows `photoGround` with a small outline glyph. `isIllustration: true` for art that isn't anyone's work (onboarding's category pictures) keeps the stock photos. `BundledWork.image(for:seed:)` and `Placeholder.gradient(seed:)` stay available for marketing art (`MarketingPhoto`). |
| `PriceRow` | SF prices; `emphasis` total at 22. |
| `Hairline(strong:)` | Default 1pt `line`; `strong: true` is 0.5pt `lineStrong`. |

### Chrome (`App/RootView.swift`)

- `HDTabBar(style: .client/.pro, items:selected:onSelect:)`. Pro: solid ink bar, paper icons 55% / 100%, lacquer active and unread dots; paper bar with ink icons in dark mode. Labels scale to xxxLarge; long press shows the large content viewer. Pro tabs come from `ProTab.allCases`. `Item(dotLabel:)` is what VoiceOver says the dot means ("requests waiting" on Today; default "unread messages").
- Mode switch: when `app.mode` changes in the tabs, a full-screen ink frame says "Pro mode." or "Booking mode." for about 600ms, and VoiceOver hears "Pro mode" / "Booking mode". It only ever fades, so it's the same under Reduce Motion (the words hold a little longer). The haptic comes from `AppState.switchMode`.
- Each tab's stack lives in `AppState` (`clientPaths`, `proPaths`; bind with `NavigationStack(path: app.path(for: .home))`), so a switch and back lands where she was.
- `ToastView`: a squared 6pt `inkGround` bar with an `inkEdge` hairline, `onInk` SF 15, inset 20, left-aligned.
- Global tint is `Palette.ink`.

## Migration

| Old | Replace with | Notes |
|---|---|---|
| `PrimaryButton` for anything that isn't money | `InkButton` | Same arguments. Keep `PrimaryButton` only for `Pay $X` / `Request · $X`. |
| `SecondaryButton` (removed) | `OutlineButton` | Pairs: `InkButton(compact: true)` + `OutlineButton(compact: true)` side by side. |
| `TertiaryButton(tint: Palette.lacquer)` | `TertiaryButton(tint: Palette.ink)` | Destructive text actions ("Cancel booking", "Delete") are inkSoft or ink, then a `ConfirmSheet`. |
| `TertiaryButton(tint: Palette.inkFaint)` | `TertiaryButton()` (inkSoft) | inkFaint fails contrast. |
| `Chip` as a segment (Upcoming/Past, All/Nails) | `TextTabs` | Right-aligned on the title row. |
| `Chip` as a choice (tips, km, address labels, quick replies) | `OptionBox(title:isSelected:action:)` | Drop the symbol and tint. |
| `Chip` as an action ("Recentre", "Open in Maps", "Directions") | `TertiaryButton(tint: Palette.ink)` or a bare `IconButton` | |
| Home's "Everything" / category chips | A "Clear" ink text link on the Near you head | Audit m23. |
| `Tag` on a photo ("Cover", "Pinned") | An eyebrow under the photo, or a 16pt paper square with an outline `pin` | `Tag` is now text-only and unreadable on a photo. |
| `Tag(... color: lacquer/success, background: ...)` | `Tag(text:)` | Colour arguments are ignored now. |
| System segmented `Picker` | `TextTabs` | |
| `IconButton` disc (old look) | `IconButton` (now bare) | No change needed; `BookingInkIconButton` can become `IconButton(tint: Palette.onInk)`. |
| `SelectableCard` (Features/Booking/BookingBits.swift) | `OptionBox(isSelected:style:action:content:)` | Same argument order: rename the call, or make `SelectableCard` a thin wrapper. `.row` for services and addresses as hairline rows. |
| White `.card()` lists, `List(.insetGrouped)` | `VStack(spacing: 0)` of `HairlineRow` at the gutter | |
| Swipe-to-delete | A "Remove" text button in the row's edit view, then `ConfirmSheet` | |
| `confirmationDialog` / `.alert` with `.destructive` | `.confirmSheet(...)` | Ink action, "Keep it" by default. |
| Stock nav bar (`.navigationTitle`, `.navigationBarTitleDisplayMode`) on a pushed screen | `.hdNavHeader("Title")` | Remove the `.navigationTitle` and `.toolbar` items; move a trailing button into `trailing:`. |
| Boxed text fields (`Radius.input` backgrounds) | `HDTextField` | Onboarding's phone/email/code/name boxes, the review text, the composer. |
| Lacquer error text and lacquer field borders | `HDTextField(error:)` or `FieldMessage` | |
| Stock `Toggle` | `HDSwitch` or `.toggleStyle(.hd)` | |
| Stock `Stepper` | `HDStepper` | |
| `Slider` | Keep, add `.tint(Palette.ink)` | Global tint is ink now anyway. |
| `EmptyState(symbol:...)` centred | Same call; it's restyled | Remove an outer `.screenGutter()` (it has its own). Add a photo rail under it where it helps. |
| "Pull down to try again" error copy | `ErrorState` | |
| Private `HomeFont`, `ProfileType`, `BookingInk.serif/sans` | `HDFont` styles and builders (table above) | Delete the private enums once callers move. |
| Private `HomeInk`, `ProfileTone`, `BookingInk` colours | `Palette.inkGround`, `inkRaised`, `onInk`, `onInkSoft`, `inkLine`, `onPhoto`, `lineStrong`, `photoGround` | Fixes the dark-mode ink moments. |
| `homeEyebrow()`, `profileEyebrow()` | `.labelStyle()` / `.eyebrowStyle(color:)` | |
| `HDFont.hero` used for money (Today, Earnings) | `HDFont.priceLarge` / `priceTotal` / `priceHero`, `timeDisplay` for the job time | `hero` is serif 40 now. |
| `VerifiedBadge` seal | Same call; it's text now | |
| Initials `Avatar` outside Inbox | Her cover photo, 2pt (`HomePhoto` or `WorkTile`) | |
| Lacquer `FlowProgress` segments | A 1pt ink line and an eyebrow "2 OF 5" | Screen-owned. |
