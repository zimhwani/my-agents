# Hair done, nails done, everything done.

An iOS app for women in Melbourne who want their hair, nails, makeup, lashes or brows done wherever they are, by a vetted mobile pro who comes to them. Built by women, for women. Two sides in one app: clients book, pros get a calendar that fills itself.

```
hair-done/
├── project.yml           xcodegen generate → HairDone.xcodeproj (gitignored)
├── HairDone/             SwiftUI source (iOS 17+, no packages)
├── supabase/             Postgres schema, row-level security, Stripe edge functions
├── docs/                 Brief, brand, copy deck, product spec, UX flows, engineering guide
├── tools/                release.sh, testflight-ship.py, asc-status.py, set_team.sh
└── store/                TestFlight test information
```

## Run it

```bash
brew install xcodegen        # once; the golf-caddy repo uses the same tool
cd hair-done
xcodegen generate            # after adding any source file
open HairDone.xcodeproj
```

Pick an iPhone simulator and press Run. No accounts, keys or network needed:
the app runs on seeded mock data so every screen works on first launch. The
`.xcodeproj` is generated from `project.yml` and gitignored, same as Caddy.

On a real phone: `tools/set_team.sh` writes your Team ID into
`HairDone.xcconfig`, then Run.

## Ship to TestFlight

Same pipeline as the Caddy app. One-time setup:

1. **App record.** App Store Connect → My Apps → + → New App. Platform iOS,
   name `Hair Done`, bundle ID `com.keithchinyanda.hairdone` (register it under
   Certificates, Identifiers & Profiles first if it isn't offered), SKU
   `hairdone`. Apple has no API for this step.
2. **Signing config.** Copy the three values across from the Caddy repo; it's
   the same account and the same API key:
   ```bash
   sed 's/^CADDY_/HAIRDONE_/' ../../golf-caddy/Caddy.xcconfig > HairDone.xcconfig
   ```
   The `AuthKey_<id>.p8` is already in `~/.appstoreconnect/private_keys` if
   Caddy has ever shipped from this Mac.
3. **Testers.** App Store Connect → TestFlight → Internal Testing → + →
   name the group, tick the people. Internal testers need no review.

Then, every time:

```bash
tools/release.sh                  # archive, validate, upload (build number = commit count)
tools/testflight-ship.py 14 --internal   # wait for processing, add build 14 to the internal group
tools/asc-status.py               # what's where
```

`tools/release.sh --validate` stops before the upload. Paste
`store/testflight-beta-description.md` into Test Information the first time.

## What to try

**Client side**
- Sign in with any phone number and any 6-digit code. Say yes or no to location; either way you'll land in Fitzroy.
- Home: who's free tonight, the six categories, pros near you as a list or a map. Tap Kiara.
- Her profile: her work, her prices, her reviews. Pick BIAB overlay, tap Book.
- The booking flow: day, time (try a greyed-out slot to see why), where, notes, then the review screen with every fee on it. Pay with Apple Pay. Watch the check draw itself.
- Bookings: tonight's booking with Kiara is already there. Open it, then use the Simulate menu (top right, debug builds only) to walk it through on her way → here → done → paid, then rate her and tip.
- Inbox: Kiara's last message. Quick replies along the top.
- You: addresses, cards, favourites, then **Pro mode** at the bottom.

**Pro mode (you're Kiara)**
- Today: two requests waiting, one for Zoe who wants something chrome. Accept one, decline the other and pick a reason.
- The next job card, and the On my way / I'm here / Done buttons.
- Calendar: this week, then Availability to change hours or block a day.
- Work: her photos, pin a few, add more.
- Earnings: this week, what's pending, the 12% shown plainly.

## How it's built

- SwiftUI, iOS 17, Swift 5 language mode, `@Observable`. Zero third-party packages, so it builds the moment it's cloned.
- `AppState` is the one shared model. `DataService` is a protocol: `MockDataService` ships; `SupabaseDataService` is the stub for the real backend in `supabase/`.
- `PaymentService` is the same shape: `MockPaymentService` ships; `StripePaymentService` compiles when the `stripe-ios` package is added.
- The look is in `DesignSystem/`: warm paper, one lacquer red, serif headlines, hairlines instead of boxes. Category tints and procedural placeholder art stand in for photos until pros upload their own.
- Every string was written against `docs/copy-deck.md` and the voice rules in `docs/build-brief.md` §3.

## Going live: the short list

1. **Backend**: `supabase link`, `supabase db push`, `supabase functions deploy`. See `supabase/README.md`.
2. **Data**: implement `SupabaseDataService` with the `supabase-swift` package (each method maps to a table or RPC; the README says which).
3. **Money**: add `stripe-ios`, set the publishable key in `StripePaymentService`, add the Apple Pay merchant ID and entitlement in Xcode.
4. **Sign-in**: turn on phone auth (Twilio) and Sign in with Apple in the Supabase dashboard; add the capability in Xcode.
5. **Photos**: work and inspo photos upload to the `work` and `inspo` storage buckets; `WorkItem.imageURL` already renders them.
6. **Push**: APNs key in Supabase, tokens into the `devices` table, the notification copy is in the copy deck.
7. **Legal**: terms, privacy, and the pro agreement (ABN, insurance, cancellation terms) before the first real booking.

## Docs

| File | What it's for |
|---|---|
| `docs/build-brief.md` | The one page everything answers to: names, voice, banned words, palette, scope, money, tech |
| `docs/brand.md` | Essence, portraits, wordmark, the drop mark, colour and type rules, photography direction |
| `docs/copy-deck.md` | Every string in the app, by screen, with keys |
| `docs/product-spec.md` | State machine, fees with worked examples, cancellation rules, reviews, availability, trust and safety, metrics |
| `docs/ux-flows.md` | Every screen top to bottom, states, motion, accessibility |
| `docs/engineering-guide.md` | Folder layout and the rules for adding code |
