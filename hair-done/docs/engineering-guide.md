# Hair Done — engineering guide

How the SwiftUI app is put together, and the rules for adding to it.

## Layout

```
hair-done/
├── HairDone.xcodeproj        Xcode 16 project (synchronised folder: every file under HairDone/ is in the target)
├── project.yml               XcodeGen fallback (not needed if the .xcodeproj opens)
├── HairDone/
│   ├── App/                  HairDoneApp (entry), AppState (the shared model), RootView (shells + tabs), Routes
│   ├── DesignSystem/         Palette, HDFont, Space/Radius/Motion, Haptics, Formatting, Components/
│   ├── Models/               Category, Pro/Service/WorkItem/Review, Availability, Booking/Address/Client/etc
│   ├── Services/             DataService protocol, MockDataService + MockData, PaymentService, LocationService
│   ├── Features/             One folder per area: Onboarding, Home, ProProfile, Booking, Bookings, Inbox, Account, Pro
│   └── Resources/            Assets.xcassets (AccentColor, AppIcon)
├── supabase/                 Postgres schema, RLS, edge functions
└── docs/                     build-brief, brand, copy-deck, product-spec, ux-flows, this file
```

## Rules

1. **iOS 17, Swift 5 language mode, no packages.** `@Observable`, `NavigationStack`, `TabView`. No Combine, no UIKit views unless wrapped for a reason.
2. **Read `AppState` from the environment**: `@Environment(AppState.self) private var app`. For bindings: `@Bindable var app = app` at the top of `body`.
3. **Never hard-code a colour, font or spacing.** `Palette.*`, `HDFont.*`, `Space.*`, `Radius.*`, `Motion.*`. Category tints: `category.tint` / `category.tintInk`.
4. **Copy comes from `docs/copy-deck.md`.** Look the screen up before writing a string. If a line isn't there, write one in the brief's voice and check it against the banned list in `docs/build-brief.md` §3.
5. **Money is Int cents.** Show with `Money.format(_:)`. Dates with `Date.friendlyDay`, `.clock`, `.friendlyDayTime`.
6. **Navigation**: each tab owns a `NavigationStack` and calls `.hdDestinations()` on its root. Push with `NavigationLink(value: Route.pro(pro))`. Sheets and full-screen covers are local `@State`.
7. **Components first.** `PrimaryButton`, `SecondaryButton`, `TertiaryButton`, `IconButton`, `Chip`, `StatusBadge`, `VerifiedBadge`, `Tag`, `RatingLine`, `StarsRow`, `StarPicker`, `Avatar`, `WorkTile`, `ProCard`, `ProMiniTile`, `SectionHeader`, `EmptyState`, `PriceRow`, `NavRow`, `HDTextField`, `Hairline`, `SheetHeader`, `LoadingDots`, `LacquerCheck`, `DropMark`, `Wordmark`, `StickyBar`. `.card()`, `.screenGutter()`, `.paperBackground()`, `.floating()`.
8. **Haptics** through `Haptics.*`. Buttons already fire them; don't double up.
9. **Every list has an empty state and every async call has a loading state.** Use `EmptyState` and `ProgressView`/`LoadingDots`.
10. **Accessibility**: labels on icon-only buttons, `accessibilityElement(children: .combine)` on cards, 44pt targets, respect `accessibilityReduceMotion` for anything that moves for fun.
11. **Previews**: add `#Preview` blocks using `AppState()` with the mock service, e.g.
    ```swift
    #Preview { HomeView().environment(previewApp()) }
    ```
    `previewApp()` lives in `App/Preview.swift`.
12. **Data flow**: views call `app.book(_:)`, `app.update(_:to:)`, `app.send(_:in:)`, `app.review(...)`, `app.reschedule(...)`, `app.saveProSelf(_:)`. Don't call `app.data` directly from a view except for `slots(for:on:minutes:)`.
13. **No banned words anywhere**, including comments and preview data.
