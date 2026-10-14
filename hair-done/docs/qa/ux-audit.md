# Hair Done UX audit, 14 Oct 2026

Written by a senior product designer for the founder. Read with `docs/build-brief.md`, `docs/product-spec.md`, `docs/ux-flows.md`, `docs/copy-deck.md` and `docs/design/luxe-benchmark.md`.

How this was done: I read the five docs above, then every Swift file under `HairDone/App/` and `HairDone/Features/`, and the parts of `HairDone/Services/`, `HairDone/Models/` and `supabase/` that decide what a screen shows. I traced each flow screen by screen as a tester would meet it. I could not run the app, so nothing here was seen on a device. Where a finding depends on the live backend, I say so and point at the SQL or edge function. Paths are relative to `hair-done/`.

Line numbers are from the last commit, `607c35a`. While I was writing, an uncommitted change set appeared on disk that starts on some of this: push registration and tap routing (`App/AppDelegate.swift`, `Services/PushNotifications.swift`, `AppState.route(to:)`, `0008_push.sql`, `functions/notify`), email-code sign-in in the services (no screen yet), `saveProSelf` and `send` now reporting failure, and payout-return alerts. None of the views have changed yet. Where that work touches a finding, the finding says so. Line numbers in `AppState.swift` and `SupabaseDataService.swift` will have moved in the working tree.

Severity:

- **Blocker**: a tester gets stuck, or loses money or data.
- **Major**: confusing, or likely to cause a support request.
- **Minor**: polish.

---

## 1. Verdict

The client side is close. Home, the pro profile, the booking flow and the ink "You're booked." moment read well, and the copy is still the best thing in the app. The pro side and the join between the two sides are not ready for real testers. A woman who is both a client and a pro has no way out of pro onboarding once she opens it, gets listed to clients before she can take a payment, can find and try to book herself, lands back in client mode every time she opens the app, and never hears about a new request unless she happens to pull to refresh inside Pro mode. Requests lapse after two hours, so on the live backend that last point costs pros real jobs and reliability points. Underneath that sit several money and data problems a tester will notice fast: paying at "done" is hidden behind a star rating, Reschedule is a dead end on the live backend, every photo a pro or client picks is thrown away and replaced by a gradient, and several "Saved." toasts show even when the save failed. None of this needs a redesign. It needs one clear model for the two sides (section 2) and about twenty focused fixes (sections 3 and 4).

---

## 2. Client and pro: the switch

### 2.1 What happens today, traced

#### Becoming a pro

1. **Entry points.** There is exactly one: the "Pro mode" card on the You tab (`Features/Account/AccountView.swift:171-190`). It sits at the very bottom of the screen, below Favourites and below "Terms and privacy", just above Log out (`AccountView.swift:34-40`). Nothing on Welcome, Home, Help or the sign-in steps mentions it. A pro recruited by the founder downloads the app, sees "A vetted pro comes to you. Melbourne, for now.", is asked for her location so "Pros near you" works, and lands on a client Home full of other pros. She has to know to scroll to the bottom of You. The Help sheet has no "Becoming a pro" answer, although `ux-flows.md` §9 lists one.
2. **The card.** Copy is "Pro mode" / "For hair stylists, nail techs, makeup artists, lash and brow artists." with a secondary button `Set up Pro mode`. It never says what she gets ("Get booked. Get paid daily.").
3. **Onboarding.** `Set up Pro mode` opens `ProOnboardingFlow` as a full-screen cover (`AccountView.swift:81-86`). Seven steps: specialty, services and prices (pre-filled with three suggested services and prices per specialty), travel area (base suburb as free text, radius slider, travel fee), availability, work photos (three minimum), ID and ABN, payouts. Then "You're on." and `Go to Today`.
4. **No way out.** Step 0 shows only `Start`. Steps 1 to 7 show a Back chevron and the step count, and nothing else. There is no close button, no "Not now", and a full-screen cover cannot be swiped away (`ProOnboardingFlow.swift:95-123`). Once she taps `Set up Pro mode` the only exits are finishing all seven steps or force-quitting the app.
5. **Quitting halfway.** Every answer lives in `@State` on the view (`ProOnboardingFlow.swift:13-29`). Force-quit and it is gone; she starts again from step 0. The intro promises the opposite: "Seven short steps. You can come back to any of them" (`ProOnboardingFlow.swift:149`).
6. **Quitting at the payout step is worse.** On the live backend, tapping `Set up payouts` first saves her as a pro (`ProOnboardingFlow.swift:385`). That inserts a `pros` row with `is_active` defaulting to true (`supabase/migrations/0001_init.sql:89`), and `pros_near` lists any active pro (`0003_operational.sql:156`). If she then leaves Stripe and never comes back, she is live in search with suggested prices she may not have read, placeholder photos and no payouts.
7. **The ID step is theatre.** `Verify ID` waits 1.4 seconds and shows "Checked" with the "ID checked" badge (`ProOnboardingFlow.swift:374-379`). Nothing is uploaded and the server does not let the app set `is_verified` (`0003_operational.sql:496-499`). Later, Profile edit tells her "ID not checked yet" (`ProProfileEditView.swift:161`). ABN can be left blank and the step still says `Next`, next to a `Do this later` that does the same thing (`ProOnboardingFlow.swift:41, 113-114`).
8. **The finish line overpromises.** "You're on. Your profile's live in Fitzroy. The first request could be today." (`ProOnboardingFlow.swift:355-356`), even if she skipped payouts and ID. If the final save fails, `onFinished()` still runs and switches her into Pro mode with a profile that only exists on the phone (`ProOnboardingFlow.swift:396-402`, `AppState.swift:484-487`).

#### Switching sides, and back

- **Client to pro:** You tab, scroll to the bottom, `Switch to Pro mode` (`AccountView.swift:182`). This calls `app.switchMode(.pro)` (`AppState.swift:184-188`), which swaps the whole shell (`RootView.swift:19`).
- **Pro to client:** a small lacquer text link `Back to booking` under the greeting on Today only (`ProTodayView.swift:80`). It is not on Calendar, Inbox, Work, Earnings or Profile edit. "Back to booking" reads like "go back to a booking", not "switch to your own bookings". `ux-flows.md` §16 asked for `Switch to client mode` and `Log out` in Profile edit; neither exists.
- **Pro mode has no account screen.** No log out, no delete account, no Help, no notification settings, no "Your details". To do any of those she has to switch back first.
- **Mode is forgotten.** `mode` starts as `.client` and `restoreSession()` never restores it (`AppState.swift:36, 111-117`). A working pro opens the app between jobs and lands on client Home every single time.

#### Knowing which mode she is in

- The only signals are the tab set (four tabs or five) and the Today header. Both shells use the same paper ground, the same tab bar, the same ink and lacquer, and the same `Inbox` tab with the same icon (`RootView.swift:46-51, 81-87`). There is no "Pro mode" label anywhere in Pro mode.
- The shell change is a slide-up spring with a haptic (`RootView.swift:21`), with no words. A tester who taps the button by accident sees the tabs change and does not know why.
- Status chips use the client's words on both sides (`DesignSystem/Components/Chips.swift:39`, `Models/Booking.swift:64-78`). In Pro mode, when the client cancels, the chip says **YOU CANCELLED**. When the pro herself cancels, it says **SHE CANCELLED**. "On her way" and "She's here" show on jobs where she is the one driving. For a woman who uses both sides, "you" now means opposite things on the same booking.
- "Hair Done fee" is the client's $3 booking fee on the client side (`BookingDetailView.swift:202`) and the 12% on the pro side (`ProBookingDetailView.swift:105`). Same name, two different charges. Brief rule 13 says one name per thing.

#### What carries over and what resets on a switch

| Thing | What happens | Problem |
|---|---|---|
| Selected tab | Kept per side in `AppState` (`selectedTab`, `selectedProTab`) | Fine |
| Navigation stacks | Lost. Each tab's `NavigationStack` path is view state and the shell is rebuilt | A pro profile or thread she had open is gone when she comes back |
| Open sheets and covers | Closed with the shell | Only matters for the onboarding cover, which has its own problem |
| Unsaved drafts | Lost with no warning: Calendar availability edits and blocked days (`ProCalendarView.swift:28-35`), the Profile edit draft | She taps `Block it`, never sees `Save` further down, switches, and the day is not blocked |
| Threads | `threads` is filtered to the current side (`AppState.swift:218-226`) but only reloaded after the switch, in a background task | For a moment the new side's Inbox shows the old side's threads, labelled with the new side's logic. In Pro mode that labels each client thread with her own first name (`AppState.swift:293-294`) |
| Unread badge | Counts the current side only (`AppState.swift:317-319`) | A client message waiting on her pro side is invisible in client mode, and the other way round |
| Requests waiting | Never counted outside Today. `ux-flows.md` §9 asked for "3 requests waiting" on the Pro mode card; it isn't built. Today has no badge either, though §3 asks for one | A request can sit unseen until it lapses |
| Data freshness | `switchMode` calls `refreshAll()`, which is the only time pro bookings load outside a pull to refresh. There is no refresh when the app comes back to the foreground (no `scenePhase` anywhere) | Today goes stale while she's working |

#### Notifications and deep links

- **In the last commit the app has no push at all.** No permission prompt, no device registration, no notification handling. The server side (`0008_push.sql`, `functions/notify`) and an app side (`PushNotifications.swift`, `AppDelegate.swift`, `AppState.open(_:)` and `route(to:)`) are being written now, uncommitted. That work already does the most important thing right: a tapped push looks up the booking or thread, switches to the side it belongs to and opens it. Three gaps remain in it:
  - It switches sides on any tap (`enter(_:)`), even if she's halfway through the booking cover or pro onboarding. Both covers live inside the shell, so a switch tears them down and loses her picks.
  - In the foreground it shows the system banner and refreshes data, but nothing in the app marks that the other side has something waiting (no dot, no count, no line on the Pro mode card).
  - It works out the side by fetching the booking first, which is a network round trip before anything happens on a tap. The payload should just say.
- **The push payload doesn't say which side it is for.** `notify` sends `kind`, `booking_id` and `thread_id` (`supabase/functions/notify/index.ts:49-53`). Add `side`.
- **The only deep links handled** are the Stripe returns (`HairDoneApp.swift:20-24`). The share link `https://hairdone.app/pro/<id>` (`ProProfileView.swift:212`) opens a website, not the profile.
- **What should happen** (built into the change list below):
  - A pro request arrives while she's in client mode and the app is closed: tapping the push opens Pro mode on that request.
  - It arrives while she's in the app in client mode: don't yank her out of what she's doing. Show a banner at the top: "Ruby wants a gel set, Sat 2:00 pm. 1h 58m to answer." with `Open`. Put a lacquer dot on You and a line on the Pro mode card.
  - She's mid-booking (the booking cover is open): banner only, never a switch.
  - A client message arrives while she's in Pro mode: same banner, "Kiara: 'French tip or plain?'", `Open` switches to client mode and opens the thread. Dot on Profile.

#### Edge cases

- **A pro booking herself.** `pros_near` doesn't exclude the person asking (`0003_operational.sql:142-166`) and Home doesn't filter her out (`HomeView.swift:126-128`). She sees her own card in Who's free and Near you, opens it, picks services, a time, an address and notes, and only at Pay is told "That's your own profile. Nothing's been charged. Book someone else." (server `own_booking` at `0003_operational.sql:260`, copy at `Services/DataService.swift:107`). "See it as a client" in Profile edit (`ProProfileEditView.swift:76-84`) opens the same profile with a working `Book` bar, heart and "Report or block".
- **A pro with no payouts, shown to clients.** Onboarding lets her skip payouts ("You can take bookings now", `ProOnboardingFlow.swift:343`) and she is listed. The payment function refuses her (`supabase/functions/create-payment-intent/index.ts:27`). A client gets through all five steps and is told at Pay "She can't take bookings through the app just yet. Nothing's been charged. Try someone else for now." (`PaymentService.swift:29`). The pro never learns that a client tried.
- **A pro who wants to stop.** The only control is a `Taking bookings` toggle halfway down Profile edit, which also needs `Save` at the bottom (`ProProfileEditView.swift:176-184, 196`). There is no "close my pro profile". Once she's a pro, You says `Switch to Pro mode` forever. When paused, Today still says "No new requests. Your profile's live." (`ProTodayView.swift:120`).
- **Sign out.** Only reachable from client mode. On the sample data, `proSelf` survives sign-out (`AppState.swift:166`), so the next person to sign in on that phone sees `Switch to Pro mode` for someone else's pro profile. Sign-out doesn't unregister the device for push (there's nothing to unregister yet; there will be).
- **Delete account.** Only from client mode. The confirmation says "Profile, addresses and cards go. Past receipts stay in your email." (`AccountView.swift:64-69`). It says nothing about her pro profile, work, payouts or Stripe account. The server refuses while any booking is live on either side (`0003_operational.sql:475-488`), and the app says "You've still got a booking that isn't finished." She's in client mode looking at an empty Bookings tab, because the live booking is a job on her pro side. She has no idea which one.
- **The same inbox mixing both sides.** It doesn't mix today: each mode shows only its own threads. That's the right call (see 2.3), but nothing tells her the other side has unread messages.

### 2.2 How other two-sided apps handle it

From my own knowledge of these apps; they redesign often, so check details on a device before copying them.

| App | Model | Where the switch is | What it teaches us |
|---|---|---|---|
| **Airbnb** | One app, one account, two modes with their own tab bars | Guest side: `Switch to hosting` on the Profile tab. Host side: `Switch to travelling` in the Menu tab. A short full-screen interstitial while it changes. The app reopens in the last mode. Host and guest messages are kept apart. Tapping a host notification while travelling switches modes | The closest fit. Same person, both roles, one identity, one payment profile, clear separation of tools |
| **Uber / Uber Driver** | Two apps, two sign-ups | None; you open the other app | Works when the provider side is a heavy, all-day work tool with its own regulation. Wrong for us: the founder walks pros through on their own phone, and a second app doubles review, sign-in and push work for a two-person team |
| **Airtasker** | One app, no modes | Nothing to switch. "My tasks" filters Posted and Assigned. One inbox for both | Works because both roles are light and asynchronous. Our pro side is time-critical (2-hour request timer, `On my way`, `I'm here`) and our copy flips "you" and "she" by side, so mixing breaks the words |
| **Fresha / Fresha for business** | Two apps | None | Business side is salon software (staff, rosters, till). Our pros are sole traders; they don't need that weight |
| **Etsy** | Buyer app links out to a separate Etsy Seller app | `Sell on Etsy` in the buyer app sends you to the seller app or web | Good at one thing we lack: the entry point to selling is visible in the buyer app's main menu, not at the bottom of settings |

### 2.3 Recommended model: one app, two modes, the Airbnb way

**One app, one account, two clearly separate modes: Booking mode (the client side, as now) and Pro mode.** Each mode has its own tab bar, inbox and badges. Pro mode always shows that it is Pro mode. The app reopens in the mode she last used. The switch lives in the same place in both modes, the last tab. Each side can see that something is waiting on the other side, and one tap gets her there.

Why this model:

1. **She is one person.** One name, one phone number, one card, one inbox address. The live backend already treats her as one id for both roles (`ProOnboardingFlow.swift:411`, "a pro's id is her account's id"). Two apps would split that for no gain.
2. **The two sides do different jobs at different speeds.** As a pro she's racing a two-hour timer and tapping `On my way` from the car. As a client she's browsing on the couch. Separate tab bars keep each side fast. Mixing them, Airtasker-style, would put "You cancelled" and "Ruby cancelled" in the same list with "you" meaning two different people.
3. **The words already depend on the side.** Status lines, money lines ("$168 total" or "$145.20 to you") and quick replies all change by side. A mode keeps every screen speaking to one role at a time.
4. **Recruitment stays one install.** The founder sets a pro up on her own phone in one sitting. A second app would add an App Store detour to every onboarding call.
5. **It matches the brief.** `build-brief.md` §2 names it "Pro mode", and the tab sets are already defined.

What we borrow from the others: Etsy's visible entry point to selling, and Airtasker's habit of showing you what's waiting for you whichever role you're in.

### 2.4 Change list for the switch

Numbered in build order. Copy is in the app's voice.

1. **Let her leave onboarding, and keep what she's done.** Add a close button (`xmark`, 44pt) to every step of `ProOnboardingFlow`, step 0 included. On close with any answers, ask "Finish later?" / "Everything so far is saved. Clients can't see you until it's done." with `Finish later` and `Keep going`. Save each step as she leaves it to a draft pro row with `is_active = false`. On return, the You card reads "Pick up where you left off. Step 4 of 7." with `Keep going`. Make the intro line true.
2. **Never list a pro who can't be booked.** Server: `pro_cards_where` adds `and p.payouts_connected and p.is_verified` (or, if the founder wants unverified pros visible during the trial, at least `payouts_connected`, three photos, one service and some hours). App: the last onboarding step becomes `Send for review`, then a "Not live yet" checklist (step 6).
3. **Hide her from herself.** Server: `pro_cards_where` adds `and p.id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000')` for `pros_near`. App: filter `proSelf?.id` out of `app.pros` in `loadPros` too. On her own profile (from "See it as a client"), replace the Book bar with an ink bar: "This is you. It's what clients see." and `Edit`. Hide the heart and "Report or block".
4. **Remember the mode.** Store the last mode per user id (`@AppStorage("mode.<userID>")`) and restore it in `restoreSession()` when `proSelf` exists. Reset to client mode on sign-out.
5. **Give Pro mode a last tab, "Profile", and put the switch at the top of the last tab in both modes.** Pro tabs become Today · Calendar · Inbox · Earnings · Profile. Profile holds, in order: a header card (photo, name, "See it as a client"), `Switch to booking` with the sub line "Book your own hair, nails and the rest.", Work (the current Work grid moves here, it's how clients see her), Services and prices, Travel area and fee, Hours, Payouts, Taking bookings, Notifications, Help, Log out. On You, move the Pro mode card to sit right under the profile header, above the settings rows. Rename the client-side button `Switch to Pro mode` (keep) and drop "Back to booking".
6. **Show the mode.** In Pro mode: an ink tab bar with paper icons and labels (luxe-benchmark "ink for committing" applies to work), and a small tracked `PRO MODE` eyebrow above every Pro tab's title. On every switch, a 0.6 s full-screen interstitial on the destination ground with the mode name in serif ("Pro mode." or "Booking."), then the shell. Under Reduce Motion, a cross-fade with the same words. VoiceOver announces "Pro mode" or "Booking mode".
7. **Show what's waiting on the other side.** Keep per-side unread counts for both sides in `AppState` (load both sides' threads; filter at display time). Client mode: lacquer dot on You when the pro side has unread messages or open requests; the Pro mode card shows "2 requests waiting · 1 message" in `warn`; Home shows a banner above Who's free for any request with under an hour left: "Ruby wants a gel set, Sat 2:00 pm. 48 min to answer." `Open`. Pro mode: dot on Profile and a line under `Switch to booking`: "1 message from Kiara".
8. **Badge requests.** Today tab gets the lacquer dot while any request is open, as `ux-flows.md` §3 asks.
9. **Wire push, with the side in the payload.** Ask for permission after her first booking or when she finishes pro onboarding (not at launch), register the token with `register_device`, unregister on sign-out. Add `"side": "pro"` or `"client"` to every `notify` payload. On tap: switch to that side if needed (with the interstitial), select the tab, push the booking or thread. In the foreground: show the banner from item 7 instead of switching. Never switch while the booking cover or onboarding cover is open.
10. **Refresh when she comes back.** On `scenePhase == .active`, refresh the current side's bookings and threads, and the other side's counts. Poll Today every 60 seconds while it is on screen and a request is open (until push is live).
11. **Keep each side's place.** Hold each tab's navigation path in `AppState` (or keep both shells alive and hide one), so switching back returns her to the profile or thread she left. If a draft is dirty (Calendar, Profile edit), ask before switching: "Save your changes first?" `Save` / `Discard`.
12. **Load both sides' threads; show one side at a time.** Keep the Inbox per mode (Airbnb does the same). At the top of each Inbox, if the other side has unread threads: "1 unread in Pro mode" with `Switch`. Never render the old side's threads under the new side's labels.
13. **Fix the side-dependent words.** Give `BookingStatus` a `proLabel` and use it in `StatusBadge` on the pro side: "Waiting on you", "Confirmed", "On your way", "You're there", "In progress", "Done", "Paid", "Client cancelled", "You cancelled", "You declined", "No show". On the pro side, call the 12% "Hair Done's 12%"; keep "Booking fee" for the client's $3 (rename it from "Hair Done fee" on the client side to match the review step and brief rule 13).
14. **Let her stop being a pro, two ways.** In Profile: `Taking bookings` (pause) saves instantly and Today says "Paused. Clients can't find you. Jobs you've got still stand." And a quiet `Close my pro profile` at the bottom: refused while a job is live ("Finish or cancel your 2 jobs first."), otherwise "Close your pro profile? Clients can't find or book you. Money on its way still lands. Your work and reviews are kept if you come back." On close, the You card returns to `Set up Pro mode` with "Welcome back. We kept your work and prices."
15. **Make delete account cover both sides.** Copy when she's a pro: "Delete your account? Your bookings, your pro profile, your work photos and your payout link all go. Money already on its way still lands. Can't be undone." When refused, say which booking and which side: "You've got Ruby on Saturday in Pro mode. Finish or cancel it, then try again." with `Open it`.
16. **A visible way in.** Welcome: a quiet text link under the sign-in buttons, "Do hair, nails or makeup? Get booked here." which sets an intent flag so that after sign-in she skips location and goes straight to pro onboarding. Help: add "Becoming a pro". The You card copy: "Get booked." / "Do hair, nails, makeup, lashes or brows? Set up takes about ten minutes."
17. **Self-booked bookings.** Keep the server's `own_booking` refusal. With item 3 she can't reach it, so the old error only shows for a race; leave the copy as is.
18. **Tell her what's missing on Today.** While she isn't live: a card at the top of Today, "You're not live yet. 2 of 4 done." rows `Payouts`, `ID check (we do this)`, `Three photos`, `Your hours`, each with a tick or a `Do it` link. Replace "No new requests. Your profile's live." with that card when it isn't true.

---

## 3. Findings

### Blockers

**B1. Pro onboarding has no exit.**
- Where: `Features/Pro/ProOnboardingFlow.swift:95-123`, presented by `AccountView.swift:81-86`. Screen: Your pro side, steps 0 to 7.
- What happens: no close, no `Not now`, and a full-screen cover can't be swiped down. The only way out is to finish or force-quit.
- Why it matters: a curious client who taps `Set up Pro mode` to look is trapped. Force-quitting is the most common way a tester "gives up" on an app.
- Fix: change list item 1.

**B2. A half-finished pro goes live; an unbookable pro is listed.**
- Where: `ProOnboardingFlow.swift:385` (saves her at the payout step), `0001_init.sql:89` (`is_active` default true), `0003_operational.sql:156` (listing filter), `functions/create-payment-intent/index.ts:27` (refuses payment), `Services/PaymentService.swift:29` (client copy). Screens: Home, Pro profile, Booking flow step "Check it over".
- What happens: a pro who skips or abandons payouts is shown to clients. A client fills in five steps, taps Pay, and is told to try someone else.
- Why it matters: both testers lose: the client wasted her time, the pro never knows she was wanted.
- Fix: change list items 1, 2 and 18.

**B3. New requests are invisible until they lapse.**
- Where: `AppState.swift:184-200` (only load points), `ProTodayView.swift:57` (pull to refresh), no push registration anywhere, `ProShared.swift:79-84` ("Reply by 11:40 am or it lapses."). Screens: Today, You, all client tabs.
- What happens: a request arrives while she's in client mode, or has the app in the background, or has Today already open. Nothing changes on screen. After two hours the server declines it and her reliability drops.
- Why it matters: the pro loses the job and the points; the client gets "didn't answer in time".
- Fix: change list items 7 to 10. The uncommitted push work covers the tap and the server side; it still needs the foreground refresh, the Today badge, the cross-side dot and a guard against switching mid-booking.

**B4. Reschedule is a dead end on the live backend.**
- Where: `Services/SupabaseDataService.swift:638-640` (`reschedule` always throws `cantReschedule`), `BookingDetailView.swift:263`, `Features/Booking/RescheduleSheet.swift`. Screen: Booking detail → `Reschedule`.
- What happens: she picks a day and time, taps `Move it`, and is told "The time didn't change. Your hold's the same as before. Message her to sort a new one."
- Why it matters: a dead end after real effort, on a button the screen offers as a main action.
- Fix: until the server function exists, hide `Reschedule` on the live backend and show `Need another time? Message Kiara` that opens the thread. Then build it per `product-spec.md` §5.

**B5. Every photo a pro or client picks is thrown away.**
- Where: `ProOnboardingFlow.swift:77-82`, `Features/Pro/ProWorkView.swift:124-130`, `ProProfileEditView.swift:62-67`, `Features/Booking/BookingFlowView.swift:536-543`; `SupabaseDataService.swift:352` says "Photos themselves aren't uploaded yet". Screens: onboarding Your work, Work, Profile photo, Booking Notes and photos.
- What happens: she picks her best three sets from her camera roll and gets three random gradients. "Change photo" re-rolls the avatar colour and toasts "Photo updated. Save to keep it." Inspo photos reach the pro as gradients.
- Why it matters: for a pro, her work is the product (brief §1, luxe benchmark P1). A real pro will stop here. For a client, her inspo never reaches the pro.
- Fix: upload to Supabase Storage (`work/<pro_id>/<id>.jpg`, `inspo/<booking_id>/<n>.jpg`), show an upload progress line on the tile and "Didn't upload. Tap to try again." on failure. Until then, say so honestly on each picker: "Photos are coming soon. For now we'll show a placeholder."

**B6. "Saved." when it wasn't.**
- Where: `AppState.swift:484-487` (`saveProSelf` sets local state first, toasts the error, returns normally), then `ProProfileEditView.swift:237-240`, `ProCalendarView.swift:270-271`, `ProWorkView.swift:136, 145, 150` each toast "Saved." straight after. `AccountView.swift:245-250` (`try?` then dismiss). Screens: Profile edit, Calendar availability, Work, Your details.
- What happens: on a failed save the error toast is replaced at once by "Saved." and the screen shows her change. On the next refresh it's gone. On the live backend `updatePro` deletes all her hours and days off, then re-inserts them (`SupabaseDataService.swift:372-388`); a failure between the two leaves her with no hours and no slots.
- Why it matters: lost data she believes is saved, and on the pro side a profile that silently stops taking bookings.
- Fix: make `saveProSelf` return a Bool and keep the old value on failure (the uncommitted `AppState` now does this, but every caller above still toasts "Saved." without looking at the result). Show "Didn't save. Your changes are still here. Try again." inline by the Save button and keep the form dirty. Replace hours and days off in one server function so it's all or nothing.

### Major

**M1. The app forgets Pro mode on every launch.** `AppState.swift:36, 111-117`. Screen: launch. A working pro lands on client Home every time and has to dig for the switch. Fix: change list item 4.

**M2. The way back from Pro mode is hidden and badly named.** `ProTodayView.swift:80`. Screen: Today. `Back to booking` is a small link on one tab only, and reads like "back to a booking". Fix: change list item 5.

**M3. Pro mode has no account, Help or log out.** `RootView.swift:67-99`, `ProProfileEditView.swift`. A pro with a payout problem can't find Help without switching sides. Fix: the Profile tab in change list item 5.

**M4. Nothing says which mode she's in.** `RootView.swift:19-21, 46-87`. Same ground, same tab bar, same Inbox. Fix: change list item 6.

**M5. Pro-side status chips say the opposite of what happened.** `Chips.swift:39`, `Booking.swift:73-74`. Screens: Today, Calendar, Job detail, Earnings history. "YOU CANCELLED" when the client cancelled. Fix: change list item 13.

**M6. Switching loses her place and unsaved edits.** `RootView.swift:19`, `ProCalendarView.swift:28-35, 230, 255`. Fix: change list item 11.

**M7. Her own profile is listed to her and bookable until Pay.** `HomeView.swift:126-128`, `ProProfileEditView.swift:76-84`, `0003_operational.sql:260`. Fix: change list item 3.

**M8. Fake ID check.** `ProOnboardingFlow.swift:304-321, 374-379, 425`. Screen: onboarding ID and ABN. Shows "Checked" and the "ID checked" badge after a 1.4 s pause; Profile edit later says "ID not checked yet". Brief rule 14 calls it "ID checked" because it means a person looked. Fix: replace `Verify ID` with `Add photo ID` and `Add a selfie` (camera or library, uploaded), then show "Sent. Someone from Hair Done checks it by hand, usually within a day." Only the server sets the badge.

**M9. "You're on." when she isn't.** `ProOnboardingFlow.swift:352-362`. Fix: when anything's missing, the last screen reads "Sent." / "You're not live yet. Finish payouts and we'll check your ID, then clients can book you." with `Go to Today`, and Today shows the checklist (change list item 18).

**M10. Her travel area is centred on wherever she was standing.** `ProOnboardingFlow.swift:407-420` uses `app.location.coordinate` (or the Fitzroy fallback if location is off, `LocationService.swift:8`); "Your base" is free text that only changes the label, here and in `ProProfileEditView.swift:121`. Screens: onboarding Where you'll go, Profile edit. A Coburg pro onboarding in the CBD gets a CBD-centred radius. Fix: geocode the base suburb (the `AddressEditor` already uses `CLGeocoder`) and show a small map with the radius circle, as `ux-flows.md` §10 describes. Caption: "Clients inside the circle can book you."

**M11. Pro first-name edits don't save on the live backend.** `ProProfileEditView.swift:69` edits `firstName`; `SupabaseDataService.swift:309-323` never writes it (the name lives on `profiles`). It then shows "Saved." Fix: either write `profiles.first_name`, or remove the field and say "Your name comes from your account. Change it in You → Your details." Remember it's shared: changing it changes her name on both sides; say that in the caption.

**M12. Paying at "done" is hidden behind a star rating.** `BookingDetailView.swift:274-277` (only button is `Rate Kiara`), `ReviewSheet.swift:63-69, 143` (`Pay $X` disabled until she taps a star), `BookingDetailView.swift:469` and `Booking.swift:88` ("Charging $168 now."). Screens: Booking detail at done, Rate sheet. A client who wants to pay and tip without reviewing can't. A client who reads "Charging now" thinks it's handled and doesn't open the sheet. Reviews collected as the price of paying aren't the reviews brief §5 wants. Fix: at `done`, the primary button on Booking detail is `Pay $168`. It opens "Pay Kiara" with the tip chips and `Pay $168` (updating with the tip), and "Something wrong?" under it. After paying, the sheet turns into "Paid. $168 to Kiara, receipt in your inbox." with the stars underneath as optional: "How was she? Two taps." Status line at done: "Done. Pay Kiara now, or we'll charge your card at 9:40 pm." Server already supports pay without review (`pay-booking`). The uncommitted `ReviewOutcome.paidOnly` handles a review failing after payment, but she still can't pay without picking a star first.

**M13. Quick replies send the moment she taps.** `Features/Inbox/ThreadView.swift:209`. Screen: Thread. A mis-tap sends "Thank you, it was lovely" before the job. The pro chip "On my way, there in 10" sends text but doesn't move the booking to On her way, so the client's status and the message disagree. Fix: tapping a chip puts the words in the field, ready to edit and send. Drop "On my way" from the pro chips while the job is confirmed and show the real `On my way` button in the pinned booking strip instead.

**M14. A failed message loses what she typed.** `ThreadView.swift:243-251` clears the draft before sending; `AppState.swift:421-428` only toasts on failure. (The uncommitted `send` now returns false on failure; the composer doesn't use it yet.) Fix: show the bubble at 60% with "Sending…", keep it on failure with "Didn't send. Tap to try again." (`ux-flows.md` §8).

**M15. Booking detail never updates by itself.** `BookingDetailView.swift` has no `.refreshable` and nothing polls. On the day, the client stares at "Confirmed" while the pro has tapped `On my way`. Fix: pull to refresh on the detail, refresh on foreground, and poll every 30 seconds while the booking is today and between confirmed and done. Push (change list item 9) replaces most of this.

**M16. Home shows "No pros in Fitzroy yet." when the network failed.** `HomeView.swift:282-291`; `AppState.swift:202-210` puts the error in `lastError`, which Home never shows. Same pattern on Bookings, Inbox, Today and Earnings: an error looks like an empty state. Fix: an error state per screen: "Couldn't load who's near. Check your connection." with `Try again`. Keep the empty-state copy for real emptiness.

**M17. No offline handling anywhere.** No path monitor, no offline bar, no queued sends (`ux-flows.md` §3 "Error and offline"). Fix: one `NWPathMonitor` in `AppState`, the 32pt `lacquerSoft` bar "You're offline. Showing what we've got." under each screen's title, and network actions disabled with that bar instead of failing one by one.

**M18. Who's free shows pros who aren't free.** `HomeView.swift:139-150` reads only her weekly hours, not bookings or days off. Tap "Free from 5 pm", get "Nothing free" on the time step. Fix: use the same slots the time step uses (`pro_slots`), one call per visible pro, or a server `whos_free` RPC as `product-spec.md` §10 describes.

**M19. "Use my location" sends the pro to a GPS point with no street.** `BookingFlowView.swift:470-479` builds `line1: "Where you are now"`. The pro's job card shows "Where you are now, Fitzroy VIC" (`ProTodayView.swift:213`). Fix: reverse-geocode to a street address and show it for her to confirm ("12 Smith St, Fitzroy. Right?"), and require a unit or door note when there's no street number.

**M20. Notification settings do nothing, and one contradicts the rules.** `AccountView.swift:450-503`. Toggles are local `@AppStorage`, the app never asks for permission, and "Messages" can be switched off although `product-spec.md` §12 says messages can't be. Fix: when push lands, ask for permission with a reason first ("We'll tell you when she confirms, when she's on her way, and when she messages. Nothing else without asking."), show "Notifications are off in Settings" with `Open Settings` if denied, and lock the Messages row like Booking updates.

**M21. Delete account doesn't mention the pro side.** `AccountView.swift:64-69`, `DataService.swift:110`. Fix: change list item 15.

**M22. Changing your mobile in Your details doesn't change how you sign in.** `AccountView.swift:216, 238-251`. She edits the number, it saves to `profile_contacts`, and next time she signs in with the new number she gets a brand-new empty account. Save errors are swallowed. Fix: make Mobile read-only with `Change` that runs the code flow for the new number ("We'll text the new number a code."). Show save errors inline.

**M23. Reschedule inside 24 hours doesn't say what it costs.** `RescheduleSheet.swift:30` ("Inside that, it counts as a cancel."), CTA `Move it`. (Once B4 is fixed.) Fix: when the booking is under 24 hours away, show the amount like the cancel sheet does: "It's under 24 hours, so this counts as a cancel. You'll pay $82.50 and can book a new time." with `Cancel and pay $82.50`, or block it and point to Message.

**M24. The client can't cancel once the pro is on her way.** `BookingDetailView.swift:261-272`. The spec allows it (50% from on her way, 100% from arrived). A client with an emergency has only Message. Fix: offer `Cancel booking` in those states with the charge shown, using `cancelBody`; fix `cancellationChargeCents` for `arrived` first (it returns 50%, see `docs/qa/reality-check.md` §3).

**M25. No "No show" for the pro.** `ProShared.swift:60-68` stops at `Mark done`. A pro who waits at a locked door has no recourse but cancelling, which costs her reliability. Fix: from 15 minutes after `I'm here`, with at least one message sent, show `No show` under the status button, with the sheet from `ux-flows.md` §11.

**M26. "Mark done" says it charges the client now.** `ProShared.swift:126` ("This charges Ruby $168."). The client is charged when she pays or 12 hours later. The done state then shows a spinner forever next to "Done. $145.20 to you tomorrow." (`ProShared.swift:128-136`), which looks like it's stuck. Fix: "Mark it done? Ruby's asked to pay $168 now. If she doesn't, we charge her card in 12 hours. $145.20 comes to you." Replace the spinner with a static `warn` dot and "Waiting for Ruby to pay."

**M27. Earnings "Pending" and Today's "Pending" stay at nothing on the live backend.** `ProEarningsView.swift:17, 107-122`, `ProTodayView.swift:38, 96` read `payouts`, which nothing fills yet (`docs/qa/reality-check.md` §3). After a paid job she sees "Nothing waiting". Fix: compute pending from paid bookings not yet in a payout ("$145.20 on its way. Lands Tue 15 Oct."), and hide History until payouts exist.

**M28. Payout setup is buried.** Only at the bottom of Earnings (`ProEarningsView.swift:34-37`). Fix: the Today checklist (change list item 18) and a Payouts row in Profile.

**M29. Calendar's "Block it" isn't saved until a second button.** `ProCalendarView.swift:225-255`. `Block it` adds the day to a list; `Save` is further down. A clash shows a warning but blocks anyway. Fix: `Block it` saves at once with a toast "Blocked Sat 19 Oct." and an `Undo`. With a clash, the button reads `Block anyway` and the line stays: "You've got Ruby at 2:00 pm. Blocking won't cancel her."

**M30. Paused and not-live states say "Your profile's live."** `ProTodayView.swift:120`. Fix: change list items 14 and 18.

**M31. Tab bar labels don't grow with Dynamic Type and have no large-content viewer.** `RootView.swift:157-176` (fixed 10pt label, 21pt icon, fixed 49pt height). The system bar it replaced did both. Fix: `.accessibilityShowsLargeContentViewer()` on each item, with `.accessibilityLargeContentTitle(item.title)` and the symbol; scale the label with `UIFontMetrics` up to `xxxLarge`.

**M32. Faint text fails contrast.** `Palette.swift:11` `inkFaint` `#A69B93` on paper `#F8F3EC` is about 2.5:1 (needs 4.5:1 for text). It's used for text on `Delete account` (`AccountView.swift:47`), Inbox captions (`InboxView.swift:93`), "Send again in 30s", "Free" bands in Calendar, `Report or block` on the profile. Fix: keep `inkFaint` for hairlines and icons only; use `inkSoft` (`#6F625B`, about 5.6:1) for any text.

**M33. Help's "Message us" opens Mail, or nothing.** `AccountView.swift:533-535`. With no Mail account set up, the tap does nothing. The copy promises "A person replies, usually the same day." Fix: open a support thread in Inbox (as `ux-flows.md` §9 says). Until then, fall back to copying the address with a toast "Copied hello@hairdone.app."

### Minor

**m1. Next up on Home goes to the Bookings list, not the booking.** `HomeView.swift:29-31`. Fix: switch tab and push `Route.booking(id)`.

**m2. "Message Kiara" on You're booked lands on the Inbox list.** `BookingFlowView.swift:272-275`. Fix: open the thread.

**m3. "Requested." gets the same lacquer check as "You're booked."** `BookingReviewStep.swift:664`. A tick says "done". Fix: for a request, use an outline clock that draws itself, and keep the check for confirmed.

**m4. "Sit tight, she's on her way at 6:15."** `BookingReviewStep.swift:670` for any booking today, hours before she leaves. Fix: "Sit tight. Kiara's coming at 6:15."

**m5. Inbox empty state is client copy in Pro mode.** `InboxView.swift:23` "Threads show up here once you've booked." Fix: Pro mode: "Quiet in here. Messages with clients show up once someone books you."

**m6. Two lacquer buttons at once on Today.** `ProTodayView.swift:154, 236`. `Accept` and the status button are both primary. `ux-flows.md` §11 says only one. Fix: `Accept` drops to secondary while a status button is live.

**m7. Addresses: no way to change the default, and delete has no undo.** `AccountView.swift:267, 302`. "First one's your default." but there's no reorder. Fix: swipe action `Make default`, and a toast "Removed. Undo".

**m8. Apple sign-in leaves a blank line under her name.** `AccountView.swift:106` shows `client.phone`, empty for Apple users. Fix: show the email, or "Add your mobile" as a link.

**m9. Email code sign-in has no screen.** Welcome offers only `Continue with phone` and Apple (`OnboardingFlow.swift:170-184`). The uncommitted services add `sendEmailCode` and `verifyEmailCode`. Add `Continue with email` as a text button under Apple, reusing the code screen with "We sent a 6-digit code to ruby@example.com." Testers without an Australian mobile need it.

**m10. The slot picker's error says "Pull down to try again" next to a Try again button.** `Features/Booking/SlotPicker.swift:43`. Fix: "Couldn't load her times." with `Try again` only.

**m11. Small icon buttons.** `DesignSystem/Components/Buttons.swift:94` draws `IconButton` at 40 by 40. Fix: keep the 40pt circle, make the hit area 44 with `.contentShape` and a frame.

**m12. Share links open the website.** `ProProfileView.swift:212`. Fix: universal link for `/pro/<id>` to open the profile in the app.

**m13. Availability allows one window a day and no notice setting.** `ProShared.swift:461-528`. A pro who works 9 to 12 and 4 to 8 can't say so. Fix: `Add another window` per day, and the "Notice you need" chips from `ux-flows.md` §10.

**m14. Search only looks through the pros already loaded near you.** `HomeView.swift:176-185`. Searching a suburb across town finds nobody. Fix: search on the server, or say "Searching near Fitzroy" in the field's caption.

**m15. The category filter doesn't apply to Who's free.** `HomeView.swift:152-154`. Pick Nails, and the top strip still shows hair stylists. Fix: filter `freePros` by category too.

**m16. Profile edit loses changes on Back with no warning, and Save sits at the very bottom.** `ProProfileEditView.swift:196`. Fix: `Save` in the navigation bar, enabled when dirty, and "Leave without saving?" on Back.

**m17. Sample data keeps the last person's pro profile after sign-out.** `AppState.swift:166`. Demo only, but a demo on a shared phone shows someone else's Pro mode. Fix: clear `proSelf` on sign-out in both builds.

**m18. Pro Inbox and job detail show "Client" until names load.** `AppState.swift:293-297`. Fix: a short placeholder shimmer instead of the word "Client", and load names before rendering rows.

---

## 4. The ten changes I'd make first, in order

1. **Let her out of pro onboarding and save each step as a draft** (B1, change list 1). Without this a curious client is trapped, and every pro who stops halfway starts again.
2. **List only bookable pros, and never list her to herself** (B2, M7, change list 2 and 3). This stops clients wasting five steps on a pro who can't take payment, and stops the founder booking herself.
3. **Make new requests impossible to miss** (B3, change list 7 to 10): refresh on foreground, poll Today while a request is open, badge Today, show waiting requests on You and Home in client mode, then register for push with the side in the payload and route taps to the right mode.
4. **Remember the mode and put the switch in the last tab of both sides** (M1, M2, M3, change list 4 and 5): Pro tabs Today · Calendar · Inbox · Earnings · Profile, with `Switch to booking`, Help and Log out in Profile, and the Pro mode card moved to the top of You.
5. **Make Pro mode look like Pro mode** (M4, M5, change list 6 and 13): ink tab bar, `PRO MODE` eyebrow, a one-word interstitial on switch, and pro-side status words.
6. **Stop saying "Saved." when it wasn't** (B6): `saveProSelf` returns success, failures stay on screen with the edit kept, and hours and days off save in one server call.
7. **Put `Pay $168` on the booking at done, with rating after and optional** (M12). It's the moment money moves; it should not be behind a star.
8. **Upload photos for real, or say plainly that they're placeholders** (B5). A pro judges the whole app by whether her work shows up.
9. **Hide Reschedule on the live backend until it works, and send her to Message instead** (B4, then M23 when it's built).
10. **Replace silent failures with real error and offline states** (M16, M17, M14): "Couldn't load. Try again." where the network failed, the offline bar, and messages that keep her words when they don't send.
