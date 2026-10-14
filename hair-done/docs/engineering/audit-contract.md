# Audit fixes: the shared contract

The UX and UI audits (`docs/qa/ux-audit.md`, `docs/qa/ui-audit.md`) are being fixed in one pass by several
people at once. This file is the agreement between them: the models, services and app state the screens
can rely on. The data layer implements exactly this; screens use exactly this. If something is missing,
add it to the "Requests" section at the bottom rather than reaching into a file you don't own.

## Who owns which files

| Owner | Files |
|---|---|
| Design system | `HairDone/DesignSystem/**`, `HairDone/App/RootView.swift`, `docs/design/components.md` |
| Data layer | `HairDone/Models/**`, `HairDone/Services/**` (except `PushNotifications.swift`'s delegate methods, unchanged), `HairDone/App/AppState.swift`, `HairDone/App/Routes.swift`, `HairDone/App/HairDoneApp.swift`, `HairDone/App/AppDelegate.swift` |
| Client: discover and book | `HairDone/Features/Home/**`, `HairDone/Features/ProProfile/**`, `HairDone/Features/Booking/**` |
| Client: bookings, inbox, account, onboarding | `HairDone/Features/Bookings/**`, `HairDone/Features/Inbox/**`, `HairDone/Features/Account/**`, `HairDone/Features/Onboarding/**`, `HairDone/Features/Notifications/**` |
| Pro side | `HairDone/Features/Pro/**` (new files go here too) |

## Server (live now, project `yohqeunmgrxyakviofua`)

- `pros.notice_minutes` (60 to 2880, default 90), `pros.onboarded_at` (null while she's a draft),
  `pros.closed_at` (set by `close_pro_profile()`), `pros.id_submitted_at` (set by `submit_id_check()`).
  She can write `notice_minutes` and `onboarded_at` herself.
- Clients only see and can book pros who are active, verified, payouts on, onboarded and not closed,
  and never themselves (`pro_is_bookable(uuid)`). Lookups by id (`pro_card`, `pro_cards`) still return any
  active pro, so old bookings keep their pro.
- `whos_free(lat, lng, cat, limit_n)` → `[{pro_id, first_free}]`, today in Melbourne, from real slots.
- `pros_search(q, lat, lng, limit_n)` → pro cards, across every bookable pro (not just nearby). `q` ≥ 2 chars.
- `reschedule_booking(b_id, new_start)` → booking. Client only, `requested` or `confirmed`, the booking must be
  24 hours or more away. Errors: `too_late_to_move`, `too_far_to_move` (a placed hold can't stretch past 6 days
  from now), `slot_taken`. Writes "Moved to Saturday 19 October, 2:00 pm." in the thread and pushes the pro.
- `close_pro_profile()` (error `live_booking` while she has a job that isn't finished), `reopen_pro_profile()`.
- `submit_id_check()` (error `id_docs_missing` unless two files are in `id-docs/<uid>/`).
- `save_pro_schedule(p_hours jsonb, p_days_off date[])`: hours as `[{"weekday":0-6 (0 = Sunday),"start":540,"end":1020}]`.
  **Not applied yet** (it's waiting on the founder). Call it; if PostgREST says the function doesn't exist
  (HTTP 404, code `PGRST202`), fall back to the current delete-then-insert.
- Storage buckets: `work` (public, `<uid>/<file>.jpg`), `avatars` (public, `<uid>/<file>.jpg`),
  `inspo` (private, `<uid>/<booking>/<n>.jpg`, readable by both sides once a `booking_inspo` row points at it),
  `id-docs` (private, `<uid>/photo-id.jpg` and `<uid>/selfie.jpg`).
- Pro mode reminders, statuses and messages push through `notify`; the payload has `side`.

## Models

```swift
// Pro
var noticeMinutes: Int = 90
var isOnboarded: Bool = true      // false while she's still in onboarding (onboarded_at is null)
var isClosed: Bool = false        // she closed her pro profile; You shows "Set up Pro mode" with "Welcome back"
var idSubmitted: Bool = false     // she's sent photo ID and a selfie; isVerified is the server's yes
var avatarURL: URL? = nil

// Client
var avatarURL: URL? = nil

// Booking
var inspoURLs: [URL] = []         // signed URLs for her inspo photos; empty means use inspoSeeds as before

// BookingDraft
var inspoPhotos: [Data] = []      // JPEGs picked in step 4, uploaded after the booking is made

// BookingStatus
var proLabel: String              // the pro's words: "Waiting on you", "Confirmed", "On your way", "You're there",
                                  // "In progress", "Done", "Paid", "Client cancelled", "You cancelled",
                                  // "You declined", "No show"

enum IDDocumentKind: String { case photoID = "photo-id", selfie }
enum ProTab { case today, calendar, inbox, earnings, profile }   // Work moves into Profile
enum Route { ... existing ..., case proWork }                    // the Work grid, pushed from Profile
```

`DataError` gains: `tooLateToMove` ("It's under 24 hours away, so it can't move now. Message her, or cancel."),
`tooFarToMove` ("That's too far out to move while your card's on hold. Pick a time in the next six days."),
`idDocsMissing` ("Add your photo ID and a selfie first."), `uploadFailed` ("Didn't upload. Tap to try again."),
`offline` ("You're offline. Try again when you're back.").

## DataService additions

```swift
func uploadWorkPhoto(_ jpeg: Data) async throws -> URL          // public URL; put it in WorkItem.imageURL, then updatePro
func uploadAvatar(_ jpeg: Data) async throws -> URL             // also saves profiles.avatar_url
func uploadIDDocument(_ jpeg: Data, kind: IDDocumentKind) async throws
func submitIDCheck() async throws
func whosFree(near: CLLocationCoordinate2D, category: Category?) async throws -> [String: Date]  // pro id → first free start today
func searchPros(_ query: String, near: CLLocationCoordinate2D) async throws -> [Pro]
func closeProProfile() async throws
func reopenProProfile() async throws
func changePhone(to phone: String) async throws                 // texts a code to the new number
func verifyPhoneChange(phone: String, code: String) async throws -> Client
```

- `reschedule(bookingID:to:)` is real now.
- `updatePro` also saves `profiles.first_name`, `notice_minutes`, `onboarded_at` (set once when `isOnboarded`
  turns true), work `image_path` (from `imageURL` when it's one of ours), and hours and days off through
  `save_pro_schedule` with the fallback.
- `createBooking` uploads `draft.inspoPhotos` after the booking exists and adds `booking_inspo` rows. A photo
  that fails doesn't fail the booking.
- The mock service does all of this in memory (uploads return a `file://` URL in the caches folder, so the
  photo really shows).

## AppState additions

```swift
// Mode
// The mode is remembered per user (UserDefaults "mode.<userID>") and restored at launch and sign-in
// when she has a pro profile that isn't closed. switchMode(_:) saves it. Sign-out resets to client
// and clears proSelf in both builds.

// Offline
var isOffline: Bool                       // NWPathMonitor; screens show OfflineBar and disable network actions

// Load failures: true when the last load failed (not when it was empty). Screens show ErrorState.
var prosLoadFailed: Bool
var bookingsLoadFailed: Bool
var threadsLoadFailed: Bool
var proSideLoadFailed: Bool

// Both sides at once
var otherSideThreads: [MessageThread]     // loaded with threads; the side she isn't on
var otherSideUnreadCount: Int             // unread messages waiting on the other side
var openRequests: [Booking]               // her pro requests waiting for an answer (held), soonest deadline first
func requestDeadline(_ b: Booking) -> Date   // created + 2 hours

// Discovery
var whosFree: [String: Date]              // pro id → first free time today; loaded with pros
func loadWhosFree(category: Category?) async
var searchResults: [Pro]
var isSearching: Bool
func search(_ query: String) async        // server search; clears results under 2 chars

// Photos and ID (each shows its own failure toast and returns nil/false)
func uploadWorkPhoto(_ jpeg: Data) async -> URL?
func uploadAvatar(_ jpeg: Data) async -> URL?
func uploadIDDocument(_ jpeg: Data, kind: IDDocumentKind) async -> Bool
func submitIDCheck() async -> Bool

// Pro profile life
func closeProProfile() async -> Bool      // false with lastError ("Finish or cancel your jobs first.")
func reopenProProfile() async -> Bool

// Money
var pendingEarningsCents: Int             // paid bookings not yet in a payout
var nextPayoutDate: Date?                 // next business day after the last paid booking

// Phone
func changePhone(to phone: String) async -> Bool
func verifyPhoneChange(_ code: String, phone: String) async -> Bool

// Reschedule
func reschedule(_ booking: Booking, to start: Date) async -> Bool   // false with lastError set
```

`saveProSelf(_:)` already returns `Bool`; callers must only say "Saved." when it's true.

## Requests

Screen owners: add what you need here (name, signature, why). The data layer picks these up.
