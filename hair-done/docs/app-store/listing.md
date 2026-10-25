# App Store listing

What to paste into App Store Connect for version 1.0, field by field. Character limits are Apple's;
everything here fits. Voice: warm, direct, a little cheeky (docs/brand.md). Australian spelling.

## App information (set once)

| Field | Value |
|---|---|
| Name (30) | **Hair Done** (9). If App Store Connect says it's taken: **Hair Done: Beauty at Home** (25) |
| Subtitle (30) | **Hair, nails and makeup at home** (30) |
| Primary category | Lifestyle |
| Secondary category | Health & Fitness (optional; leave blank if unsure) |
| Content rights | No third-party content you don't have rights to: **No** |
| Privacy policy URL | https://hairdonenailsdone.app/privacy/ |
| Price | Free |
| Availability | Australia only (Melbourne for now; the app only shows pros within their travel areas) |

## This version (1.0)

**Support URL:** https://hairdonenailsdone.app/support/ (publish site/support first)
**Marketing URL:** https://hairdonenailsdone.app
**Copyright:** 2026 Hair Done
**Version:** 1.0

### Promotional text (170; can change any time without review)

```
A vetted pro at your door for hair, nails, makeup, lashes and brows. See the price, the time and who's coming before you book. Melbourne, for now.
```

### Description (4,000)

```
hair done, nails done, everything done.

Hair Done brings a vetted beauty pro to you. Blow-dries, braids, gel nails, lashes, brows, makeup for the big night: booked in a minute, done at home.

KNOW IT ALL BEFORE YOU BOOK
Every pro shows her prices, her travel fee and photos of her own work. You see the full total, the time and who's coming before you tap Book. No quotes, no back-and-forth in the DMs.

PROS WE'VE CHECKED
Every pro sends photo ID and a selfie, and we check her details before she's listed. Reviews come only from people who've actually booked her.

PAY WHEN IT'S DONE
We hold the total on your card when you book, and nothing's charged until she's finished. Pay in the app with a tip if you like (tips go to her in full), or we'll charge your card 12 hours later. Something not right? Tap "Something wrong?" and we hold off while a person looks.

ON THE DAY
See when she's on her way, when she's at the door and when she's started. Message her in the app. Your receipt is on the booking and in your inbox.

FAIR CANCELLING
Cancel 24 hours or more before and it's free. If she cancels, every dollar comes back.

FOR PROS
Set up Pro mode in the same app: your services and prices, your travel area, your hours. Take requests or turn on instant book. Get paid to your bank through Stripe. Our fee is 12% of a booking, and tips are yours.

Melbourne, for now. Questions? hello@hairdonenailsdone.app
```

### Keywords (100, commas, no spaces)

```
mobile beauty,nails,hairdresser,blowdry,makeup artist,lashes,brows,braids,manicure,at home,melbourne
```

(100 characters. Apple already indexes the name, subtitle and category, so "hair" and "done" aren't repeated.)

### What's New (first version)

```
Hello, Melbourne.
```

## Screenshots

6.9-inch iPhone (1320 × 2868), 3 to 10 of them. See docs/app-store/screenshots (mockup for approval first).

## App Review Information

| Field | Value |
|---|---|
| Sign-in required | Yes |
| User name / password | From `tools/setup-review.sh`: the review email and the six-digit code it prints |
| Contact | Your name, phone and email (Apple only, not shown publicly) |

**Notes** (paste, then fill in the email and code):

```
Hair Done is a marketplace for mobile beauty pros in Melbourne, Australia: clients book a vetted pro to come to their home.

Sign in: tap "Continue with email", enter [REVIEW EMAIL], tap Send code, then enter [CODE] as the six-digit code. It's a fixed code for review; no email needed.

To see a booking: choose any pro on Home, pick a service and a time, and book. [While sample pros are live: they accept and run the job by themselves, a step every couple of minutes. Payments are in Stripe test mode, so use card 4242 4242 4242 4242, any future date, any CVC.]

Pro mode: You > Set up Pro mode shows the pro side (identity check, ABN, payouts through Stripe Connect).

Payments are for services performed in person at the client's home, so they're processed by Stripe rather than in-app purchase (App Review Guideline 3.1.3(e)).

Account deletion: You > Delete account.
```

**Before you submit, decide what Apple's reviewer will see.** If the sample pros are gone and you
have no real pros listed yet, the reviewer sees an empty app and will likely reject it ("app
incomplete"). Either keep the sample pros (and test-mode Stripe) until you're approved and then
switch to live, or have a few real pros live first. If you switch to live Stripe before review, take
out the test-card line above: a reviewer's booking would then be a real charge.

## Age rating

Answer **None** to every content question (violence, sexual content, profanity, drugs, gambling,
horror, medical, etc.). Then:
- Unrestricted web access: **No**
- User-generated content / messaging between users: **Yes** (in-app messages and reviews; users can
  report and block, which the app has)
- Contests: **No**

Expected result: 12+ (because people can message each other). Apple sets the number.

## App Privacy (the "nutrition label")

Tracking: **No**, nothing is used to track you across other companies' apps or websites.

For each of these, answer **Collected**, **Linked to the user**, **Not used for tracking**, purpose
**App Functionality**:

| Apple's category | What it is in Hair Done |
|---|---|
| Contact Info → Name | Your first and last name |
| Contact Info → Email Address | Sign-in and receipts |
| Contact Info → Phone Number | Shared with your pro once a booking's confirmed |
| Contact Info → Physical Address | Where the pro comes to |
| Location → Precise Location | Finding pros near you, and saved addresses |
| Financial Info → Payment Info | Card brand and last four digits (Stripe holds the card) |
| User Content → Photos or Videos | Inspiration photos; pros' work, ID and selfie |
| User Content → Other User Content | Messages and reviews |
| Purchases → Purchase History | Your bookings |
| Identifiers → User ID | Your account ID |

These match the privacy manifest in the app (HairDone/Resources/PrivacyInfo.xcprivacy). Stripe's
SDK declares its own.

## Encryption

Already answered in the app (ITSAppUsesNonExemptEncryption = NO): standard HTTPS only.
