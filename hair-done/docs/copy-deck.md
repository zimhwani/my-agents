# Hair Done copy deck

Every string in the app, by screen. Voice rules and the banned list are in `build-brief.md`, section 3. Read that before adding a line here.

Conventions:

- Keys are camelCase, dotted by screen: `home.greeting.morning`.
- Labels and buttons have no full stop. Sentences do.
- Substitutions in braces: `{name}` the client's first name, `{pro}` the pro's first name, `{client}` the client's first name on pro screens, `{price}` a formatted amount, `{payout}` the pro's amount after the 12%, `{time}` a clock time, `{day}` a short day and date, `{suburb}`, `{distance}`, `{service}`, `{n}` a count.
- Formats: money `$180` and `$47.50`, never `$180.00`. Times `6:15 pm`, lowercase with a space. Days `Thu 12 Mar`; use `Today` and `Tomorrow` where they apply. Distances `1.2 km` and `800 m`. Durations `45 min` and `1 h 30`.
- Plurals: `1 review`, `2 reviews`; `1 booking`, `2 bookings`; `1 photo`, `2 photos`. Never `review(s)`.
- One exclamation mark per screen at most. Most screens have none. This deck has none.

## Shared

| Key | Copy | Notes |
|---|---|---|
| common.back | Back | |
| common.next | Next | Only on flow steps where nothing more specific fits |
| common.done | Done | |
| common.save | Save | |
| common.cancel | Cancel | Dismisses a sheet. Not for cancelling a booking, see `detail.cancel` |
| common.skip | Skip for now | |
| common.notNow | Not now | |
| common.gotIt | Got it | Dismisses an explainer |
| common.tryAgain | Try again | |
| common.edit | Edit | |
| common.change | Change | |
| common.delete | Delete | |
| common.remove | Remove | |
| common.close | Close | |
| common.seeAll | See all | |
| common.today | Today | |
| common.tomorrow | Tomorrow | |
| common.free | Free | Used for $0 fees and free cancellation |
| common.optional | Optional | Field hint |
| common.loading | | Empty on purpose. A `ProgressView` with no caption |

## Client side

### Welcome and sign-in

| Key | Copy | Notes |
|---|---|---|
| welcome.wordmark | hair done.<br>nails done.<br>everything done. | Stacked form. See brand.md |
| welcome.sub | A vetted pro comes to you. Melbourne, for now. | |
| welcome.phone | Continue with phone | |
| welcome.apple | Continue with Apple | Apple's required string. Use `SignInWithAppleButton(.continue)` |
| welcome.legal | By continuing you agree to the terms and privacy policy. | "terms" and "privacy policy" are links |
| welcome.legal.terms | Terms | |
| welcome.legal.privacy | Privacy policy | |
| welcome.error.apple | Apple didn't come back to us. Try again, or use your phone. | |
| phone.title | Your number | |
| phone.sub | We'll text you a code. No calls, no spam. | |
| phone.placeholder | 04xx xxx xxx | |
| phone.countryCode | +61 | Fixed for v1 |
| phone.cta | Text me a code | |
| phone.error.invalid | That doesn't look like an Australian mobile. | |
| code.title | Check your texts | |
| code.sub | We sent a 6-digit code to {phone}. | `{phone}` formatted `0412 345 678` |
| code.resend | Send it again | |
| code.resend.wait | Send again in {seconds}s | Countdown from 30 |
| code.changeNumber | Wrong number | Goes back |
| code.error.wrong | That code's not right. Have another look. | |
| code.error.expired | That code's expired. We've sent a new one. | |
| code.error.tooMany | Too many goes. Wait a couple of minutes and try again. | |
| name.title | And you are | Serif. No question mark, no full stop |
| name.sub | First name's fine. It's what she'll see when you book. | |
| name.placeholder | Your first name | |
| name.cta | That's me | |
| name.error.empty | She'll need something to call you. | |

### Location permission

| Key | Copy | Notes |
|---|---|---|
| location.pre.title | Pros near you | Pre-permission screen, ours |
| location.pre.body | We use your location to show who's close and what her travel fee comes to. Only while you're in the app. | |
| location.pre.cta | Use my location | Triggers the system prompt |
| location.pre.skip | I'll type a suburb | |
| location.system | Hair Done shows pros near you and works out travel fees. Only while you're in the app. | `NSLocationWhenInUseUsageDescription`. The system dialog wraps this |
| location.suburb.title | Your suburb | |
| location.suburb.placeholder | Brunswick, or 3056 | |
| location.suburb.cta | Show me who's near | |
| location.denied.banner | Location's off. Showing {suburb}. | Tap to change |
| location.denied.change | Change | |
| location.failed | Couldn't find you. Type a suburb instead. | |

### Home

| Key | Copy | Notes |
|---|---|---|
| home.greeting.morning | Morning, {name}. | 5:00 to 11:59 |
| home.greeting.afternoon | Afternoon, {name}. | 12:00 to 16:59 |
| home.greeting.evening | Who's free tonight. | 17:00 to 21:59. No name, no question mark. From the brief |
| home.greeting.late | Late one. Here's tomorrow. | 22:00 to 4:59. Lists default to tomorrow |
| home.greeting.noName | Morning. | Fallback if name is missing, same time-of-day pattern |
| home.search.placeholder | French tip, blow-dry, a suburb | |
| home.search.recent | Recent | |
| home.search.clear | Clear | |
| home.search.empty | Nothing for "{query}". Try a service or a suburb. | |
| home.whosFree.title | Who's free today | Serif heading. After 22:00 reads "Who's free tomorrow" |
| home.whosFree.card | {distance} away, free from {time} | e.g. "1.2 km away, free from 5" |
| home.whosFree.empty | No one's free today. Tomorrow's looking better. | |
| home.whosFree.empty.cta | See tomorrow | |
| home.categories.title | | No header. The chips speak for themselves |
| category.hair | Hair | Exact names and order from the brief |
| category.nails | Nails | |
| category.makeup | Makeup | |
| category.lashes | Lashes | |
| category.brows | Brows | |
| category.theLot | The lot | |
| category.theLot.sub | Hair, makeup, nails. For events. | Shown on the tile only |
| home.nearYou.title | Near you | Serif heading |
| home.nearYou.sub | Closest first | `label` style eyebrow, optional |
| home.nearYou.toggle.list | List | Segmented, with map |
| home.nearYou.toggle.map | Map | |
| home.nearYou.empty | No pros in {suburb} yet. We're new here and adding more every week. | |
| home.nearYou.empty.cta | Look 15 km out | |
| home.nearYou.filter.category | {category} near you | Title when a category chip is selected |
| home.map.recentre | Recentre | |
| home.map.pin | {pro} · {price} | Map callout. Price is her cheapest service |
| home.bookAgain.title | Book again | Hidden until there's a completed booking |
| home.bookAgain.card | {service} with {pro} | Second line: `{day}` of the last booking |
| home.bookAgain.cta | Book | |
| home.card.instant | Instant book | Chip, `lacquerSoft` |
| home.card.distance | {distance} away | |
| home.card.stars | {stars} · {n} reviews | e.g. "4.9 · 212 reviews". Singular "1 review" |
| home.card.new | New | Fewer than 3 reviews. Replaces stars |
| home.card.from | From {price} | Cheapest service |
| home.card.freeFrom | Free from {time} | Only when free today |
| home.card.favourite | Save | Heart. Becomes "Saved" |

### Pro profile

| Key | Copy | Notes |
|---|---|---|
| profile.specialty | {specialty} | e.g. "Nail tech" |
| profile.verified | ID checked | Badge with tick, `success` |
| profile.verified.explainer | Hair Done has seen her ID and ABN. Reviews only come from completed bookings. | Sheet when the badge is tapped |
| profile.stars | {stars} · {n} reviews | Tap scrolls to reviews |
| profile.distance | {distance} from you | |
| profile.comesTo | Comes to {area} | e.g. "Comes to Coburg and 10 km around" |
| profile.comesTo.fee | Travel fee {price}, flat | |
| profile.comesTo.noFee | No travel fee | |
| profile.instantBook | Instant book | Chip |
| profile.instantBook.explainer | Book a free slot and it's confirmed straight away. No waiting on a reply. | |
| profile.request.explainer | {pro} confirms each booking herself. She usually replies within {time}. | `{time}` like "an hour" |
| profile.about | About | |
| profile.about.more | More | Expands the bio |
| profile.services | Services | |
| profile.services.row | {service} · {duration} | Price right-aligned, monospaced digits |
| profile.services.more | All {n} services | |
| profile.work | Her work | Serif heading |
| profile.work.count | {n} photos | |
| profile.reviews | Reviews | |
| profile.reviews.summary | {stars} · {n} reviews | |
| profile.reviews.row | {service}, {day} | Under the reviewer's first name |
| profile.reviews.empty | No reviews yet. Someone has to go first. | |
| profile.reviews.seeAll | All {n} reviews | |
| profile.availability | Next free | |
| profile.availability.row | {day} from {time} | e.g. "Thu from 5:00 pm" |
| profile.availability.none | Nothing free this week. Message her. | |
| profile.book | Book | Sticky, full pill, `lacquer` |
| profile.book.from | Book from {price} | Variant when there's room |
| profile.message | Message | |
| profile.favourite | Save | Becomes "Saved" |
| profile.share | Share | |
| profile.share.text | {pro}, {specialty} in {suburb}, on Hair Done. | Share sheet text with link |
| profile.more | More | Opens the report/block sheet |
| profile.report.title | Report or block | Sheet title |
| profile.report.report | Report {pro} | |
| profile.report.block | Block {pro} | |
| profile.report.why | Tell us what happened | |
| profile.report.reason.notHerWork | Photos aren't her work | |
| profile.report.reason.offApp | Asked me to pay outside the app | |
| profile.report.reason.noShow | Didn't show up | |
| profile.report.reason.uncomfortable | Made me uncomfortable | |
| profile.report.reason.other | Something else | |
| profile.report.placeholder | Only we see this. | |
| profile.report.cta | Send report | |
| profile.report.done | Sent. A person reads every one, and we'll get back to you within two days. | |
| profile.block.confirm.title | Block {pro}? | |
| profile.block.confirm.body | She won't show up for you and can't message you. She won't be told. | |
| profile.block.confirm.cta | Block | |
| profile.block.confirm.keep | Leave it | |
| profile.block.done | Blocked. | Toast |

### Booking: services

| Key | Copy | Notes |
|---|---|---|
| booking.services.title | Services | Serif |
| booking.services.sub | Pick as many as you like. She'll do them in one visit. | |
| booking.services.row | {service} · {duration} | Price right-aligned |
| booking.services.addOns | Add-ons | Section header, if the pro has any |
| booking.services.summary | {n} services · {duration} · {price} | Above the button. Singular "1 service" |
| booking.services.cta | Pick a time | |
| booking.services.error.none | Pick at least one. | |

### Booking: time

| Key | Copy | Notes |
|---|---|---|
| booking.time.title | When | Serif |
| booking.time.sub | These are her real free slots. | |
| booking.time.day | {day} | Horizontal day strip: "Today", "Tomorrow", then "Thu 12" |
| booking.time.morning | Morning | Slot group |
| booking.time.afternoon | Afternoon | |
| booking.time.evening | Evening | |
| booking.time.slot | {time} | Chip, e.g. "6:15 pm" |
| booking.time.instant | Confirmed as soon as you pay | Under the strip when instant book is on |
| booking.time.request | {pro} confirms, usually within {time} | When instant book is off |
| booking.time.noSlots.day | Nothing free on {day}. | |
| booking.time.noSlots.week | She's booked out this week. Next free is {day}. | |
| booking.time.noSlots.week.cta | Jump to {day} | |
| booking.time.noSlots.all | Nothing free in the next four weeks. Message her, or see who else is close. | |
| booking.time.noSlots.message | Message {pro} | |
| booking.time.noSlots.others | See who's free | |
| booking.time.summary | {day}, {time} · {duration} | Above the button |
| booking.time.cta | Next | |

### Booking: where

| Key | Copy | Notes |
|---|---|---|
| booking.where.title | Where | Serif |
| booking.where.sub | She'll come to you. Somewhere with a power point and decent light is ideal. | |
| booking.where.current | Use my location | |
| booking.where.saved | Saved | Section header |
| booking.where.type | Type an address | |
| booking.where.placeholder | Street and suburb | |
| booking.where.unit.placeholder | Unit, floor, gate code | |
| booking.where.label.placeholder | Call it something. Home, Mum's, the hotel. | |
| booking.where.access.placeholder | Parking, buzzer, dogs. Anything she should know getting in. | |
| booking.where.saveToggle | Save this address | |
| booking.where.outside | That's outside where {pro} travels. She comes to {area}. | |
| booking.where.outside.others | Pick someone closer | |
| booking.where.outside.message | Message her anyway | |
| booking.where.cta | Next | |

### Booking: notes and inspo

| Key | Copy | Notes |
|---|---|---|
| booking.notes.title | Notes and photos | Serif |
| booking.notes.sub | Optional, but she'll thank you. | |
| booking.notes.placeholder | What you're after. Hair length, colours you like, what the event is. | |
| booking.inspo.title | Inspo | |
| booking.inspo.add | Add photos | |
| booking.inspo.count | {n} of 3 | |
| booking.inspo.limit | Three's the limit. Keep your favourites. | |
| booking.notes.cta | Review | |

### Booking: review

| Key | Copy | Notes |
|---|---|---|
| booking.review.title | Check it over | Serif |
| booking.review.pro | {pro} · {specialty} | With her photo |
| booking.review.when | {day}, {time} | e.g. "Thu 12 Mar, 6:15 pm" |
| booking.review.where | {address} | With the label if saved, e.g. "Home · 14 Union St, Brunswick" |
| booking.review.change | Change | On each row |
| booking.review.services | Services | Section header |
| booking.review.line.service | {service} | Price right, monospaced |
| booking.review.line.travel | Travel fee | `{price}`. "Free" when $0 |
| booking.review.line.travel.note | Set by {pro}. Flat, wherever you are in her area. | Caption under the line |
| booking.review.line.fee | Hair Done fee | Always `$3`. Always its own line. Never folded into services or the total label |
| booking.review.line.fee.note | Covers payments and support. Her prices are all-in apart from this. | Caption |
| booking.review.total | Total | `{price}`, `title` size |
| booking.review.total.note | Held now, charged when she's done. | |
| booking.review.notes | Your notes | Collapsed row |
| booking.review.policy | Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Not there when she arrives and it's the full amount. | Full text, above the button. The first three sentences are the brief's |
| booking.review.cta.instant | Pay {price} | |
| booking.review.cta.request | Request · {price} | The hold is placed on request too |

### Booking: payment sheet

| Key | Copy | Notes |
|---|---|---|
| payment.title | Pay | Sheet title |
| payment.applePay | | Apple's own button, `PayWithApplePayButton`. No custom label |
| payment.or | or a card | Divider |
| payment.card | {brand} ending {last4} | e.g. "Visa ending 4242" |
| payment.card.default | Default | |
| payment.addCard | Add a card | |
| payment.hold.title | Holding, not charging | |
| payment.hold.body | We hold {price} on your card now. It's charged when {pro} marks you done, or 12 hours after your booking, whichever's first. Cancel in time and the hold just drops off. | |
| payment.secure | Card details go to Stripe, not to us. | Caption |
| payment.cta | Pay {price} | |
| payment.cta.request | Request · {price} | |
| payment.processing | Sorting it. | Shown while the hold is placed |

### Booking: confirmation

| Key | Copy | Notes |
|---|---|---|
| booked.title | You're booked. | Serif `hero`. The check draws itself above |
| booked.sub.today | Sit tight, she's on her way at {time}. | Booking is today. From the brief |
| booked.sub.later | {pro}, {day} at {time}. We'll remind you the day before. | |
| booked.title.request | Requested. | When the pro has to confirm |
| booked.sub.request | {pro} usually replies within {time}. We'll ping you. Nothing's charged until she says yes. | |
| booked.share | Share with a friend | |
| booked.share.sub | So someone knows who's coming and when. | |
| booked.share.text | I've got {pro} coming {day} at {time}, {address}. Booked on Hair Done. | Share sheet text |
| booked.calendar | Add to calendar | |
| booked.message | Message {pro} | |
| booked.done | Done | Returns home |

### Bookings list

| Key | Copy | Notes |
|---|---|---|
| bookings.title | Bookings | Tab and screen title |
| bookings.upcoming | Upcoming | Segment |
| bookings.past | Past | |
| bookings.card.title | {service} with {pro} | Multiple services: "{service} and {n} more" |
| bookings.card.sub | {day}, {time} · {suburb} | |
| bookings.empty.upcoming | Nothing on. Want to change that? | From the brief |
| bookings.empty.upcoming.cta | See who's free | |
| bookings.empty.past | Nothing yet. Your first one goes here. | |
| status.requested | Waiting on {pro} | `warn` |
| status.confirmed | Confirmed for {day} | `success`. "Confirmed for today" when today |
| status.onHerWay | On her way | `success`, pulsing dot |
| status.here | She's here | `success` |
| status.done | Done | `success` |
| status.paid | Paid {price} | `success` |
| status.cancelled.byYou | You cancelled | `inkSoft` |
| status.cancelled.byHer | {pro} cancelled. Refunded in full. | `inkSoft` |
| status.declined | {pro} couldn't do it | `inkSoft`. Reason on the detail screen |
| status.noShow | Missed. Charged in full. | `inkSoft`. Client didn't answer the door |
| bookings.rateNudge | Rate {pro} | Small chip on past cards without a rating |

### Booking detail

| Key | Copy | Notes |
|---|---|---|
| detail.title | {service} with {pro} | |
| detail.timeline.requested | Requested | Each step shows `{time}` beside it once reached |
| detail.timeline.requested.sub | She usually replies within {time}. | |
| detail.timeline.confirmed | Confirmed | |
| detail.timeline.confirmed.sub | See you {day} at {time}. | |
| detail.timeline.onHerWay | On her way | |
| detail.timeline.onHerWay.sub | About {minutes} minutes out. | |
| detail.timeline.here | Here | |
| detail.timeline.here.sub | Put the kettle on. | |
| detail.timeline.done | Done | |
| detail.timeline.done.sub | Charging {price} now. | |
| detail.timeline.paid | Paid | |
| detail.timeline.paid.sub | {price} to {pro}. Receipt's in your inbox. | |
| detail.timeline.declined.sub | {reason} | The pro's chosen reason, see `today.requests.decline.*` |
| detail.when | When | Row label |
| detail.where | Where | |
| detail.notes | Notes | |
| detail.inspo | Your photos | |
| detail.price | Price | Opens the same breakdown as review |
| detail.receipt | Receipt | Past bookings |
| detail.message | Message {pro} | |
| detail.call | Call {pro} | Only after confirmed |
| detail.share | Share with a friend | |
| detail.reschedule | Reschedule | |
| detail.reschedule.title | Pick a new time | |
| detail.reschedule.sub | Free with more than 24 hours' notice. Inside that, it counts as a cancel. | |
| detail.reschedule.cta.instant | Move to {day}, {time} | |
| detail.reschedule.cta.request | Ask {pro} to move it | |
| detail.reschedule.done | Moved to {day} at {time}. | Toast |
| detail.reschedule.requested | Asked. {pro} usually replies within {time}. | Toast |
| detail.cancel | Cancel booking | Text button, `inkSoft` |
| detail.cancel.title | Cancel this booking? | |
| detail.cancel.body.free | More than 24 hours out, so it's free. The hold drops off your card in a few days. | |
| detail.cancel.body.half | Under 24 hours. {pro} keeps half, {price}. She's already turned down other work for you. | |
| detail.cancel.body.requested | She hasn't confirmed yet, so nothing's charged. | |
| detail.cancel.cta | Cancel it | |
| detail.cancel.keep | Keep it | |
| detail.cancel.done.free | Cancelled. Nothing charged. | Toast |
| detail.cancel.done.half | Cancelled. {price} to {pro}, the rest drops off your card. | |
| detail.help | Something's not right | Opens help with the booking attached |

### Tip and rate

| Key | Copy | Notes |
|---|---|---|
| rate.title | How'd {pro} go? | Serif. Appears after done |
| rate.stars.1 | Not good. | Prompt under the stars as each fills with `honey` |
| rate.stars.2 | Not great. | |
| rate.stars.3 | Fine. | |
| rate.stars.4 | Good. | |
| rate.stars.5 | Very good. | |
| rate.review.placeholder | What was she like? The next woman deciding will read this. | 3 stars and up |
| rate.review.placeholder.low | What went wrong? We read these too. | 1 or 2 stars |
| rate.photo | Add a photo of the work | Optional |
| rate.tip.title | Tip {pro} | |
| rate.tip.sub | Optional. All of it goes to her. | |
| rate.tip.none | No tip | Chip |
| rate.tip.amount | {price} | Chips: $10, $20, $30 |
| rate.tip.other | Other | |
| rate.tip.other.placeholder | Amount | |
| rate.cta | Send | |
| rate.cta.tip | Send and tip {price} | |
| rate.skip | Not now | |
| rate.thanks | Thanks. {pro} will see it, and so will the next woman deciding. | |
| rate.thanks.tip | Thanks. {price} to {pro}, on top of the rest. | |
| rate.thanks.low | Thanks for telling us. A person will look at this. | 1 or 2 stars |

### Inbox

| Key | Copy | Notes |
|---|---|---|
| inbox.title | Inbox | |
| inbox.empty | No messages yet. Threads show up here once you've booked. | |
| inbox.thread.sub | {service} · {day} | Under the pro's name |
| inbox.composer.placeholder | Message {pro} | |
| inbox.send | Send | |
| inbox.quick.late | Running 5 minutes late, sorry | Quick replies, six, in this order |
| inbox.quick.buzzer | Come on up, buzzer's {unit} | Falls back to "Come on up" without a unit |
| inbox.quick.parking | Parking's on the street out front | |
| inbox.quick.earlier | Any chance a bit earlier? | |
| inbox.quick.thanks | Thank you, love it | |
| inbox.quick.again | Same again next time? | |
| inbox.system.requested | You asked for {day} at {time}. | System line, `inkSoft`, centred |
| inbox.system.confirmed | Confirmed for {day} at {time}. | |
| inbox.system.paid | Paid. {price} to {pro}, receipt attached. | |
| inbox.phone.hidden | Phone numbers are shared once she's confirmed. | Caption at the top of a requested thread |
| inbox.photo | Photo | |
| inbox.report | Report this conversation | Menu |

### You

| Key | Copy | Notes |
|---|---|---|
| you.title | You | Tab and screen title |
| you.profile.edit | Edit | |
| you.profile.name | Name | |
| you.profile.phone | Mobile | |
| you.profile.email | Email | For receipts |
| you.profile.email.hint | Receipts go here. | |
| you.addresses | Addresses | |
| you.addresses.add | Add an address | |
| you.addresses.default | Default | |
| you.addresses.empty | No saved addresses. Add one and booking's two taps quicker. | |
| you.payment | Payment methods | |
| you.payment.add | Add a card | |
| you.payment.applePay | Apple Pay | Row, if available |
| you.payment.default | Default | |
| you.payment.remove | Remove | |
| you.payment.remove.confirm | Remove {brand} ending {last4}? | |
| you.payment.empty | No cards yet. Apple Pay works without one. | |
| you.favourites | Favourites | |
| you.favourites.empty | No favourites yet. Tap Save on a pro you'd book again. | |
| you.notifications | Notifications | |
| you.notifications.bookings | Booking updates | Toggle, always on |
| you.notifications.bookings.sub | Can't turn these off, sorry. They're the useful ones. | |
| you.notifications.messages | Messages | |
| you.notifications.reminders | Day-before reminders | |
| you.notifications.whosFree | Who's free near you | |
| you.notifications.whosFree.sub | Now and then. Never before 9 am. | |
| you.help | Help | |
| you.help.sub | A person replies, usually the same day. | |
| you.help.contact | Message us | |
| you.help.faq.holds | How holds and charges work | FAQ rows |
| you.help.faq.cancel | Cancelling and rescheduling | |
| you.help.faq.report | Reporting a pro | |
| you.help.faq.delete | Deleting your account | |
| you.proMode | Pro mode | |
| you.proMode.sub | For hair stylists, nail techs, makeup artists, lash and brow artists. | |
| you.proMode.switch | Switch to Pro mode | Becomes "Set up Pro mode" if not onboarded |
| you.proMode.back | Back to booking | Shown on the pro side |
| you.legal | Terms and privacy | |
| you.version | Hair Done {version} | Caption |
| you.logout | Log out | |
| you.logout.title | Log out? | |
| you.logout.body | Your bookings stay put. You'll need a new code to get back in. | |
| you.logout.cta | Log out | |
| you.logout.keep | Stay | |
| you.delete | Delete account | Under help |
| you.delete.title | Delete your account? | |
| you.delete.body | Profile, addresses and cards go. Past receipts stay in your email. Can't be undone. | |
| you.delete.cta | Delete | |

### Errors and offline

| Key | Copy | Notes |
|---|---|---|
| error.generic.1 | That didn't work. Try again. | Default |
| error.generic.2 | Something's up on our end. Give it a minute. | Server 5xx |
| error.generic.3 | Couldn't load that. Pull down to try again. | A list failed to load |
| error.generic.4 | We lost that one. Have another go. | Timeout |
| error.generic.5 | Still stuck? Message us from Help and a person will look. | After a second failure |
| offline.banner | You're offline. Showing what we had. | Top banner, `warn` tint |
| offline.action | Needs a connection. Try again when you're back on. | When an action is attempted offline |
| payment.declined | That card didn't go through. Nothing's been charged. Try another, or Apple Pay. | |
| payment.hold.failed | Couldn't place the hold. Nothing's been charged. Try again. | |
| slot.taken | Someone just took {time}. Here's what's still free. | Returns to the time picker |
| slot.taken.cta | Pick another | |
| pro.cancelled.title | {pro} had to cancel. | |
| pro.cancelled.body | Full refund, back on your card in 3 to 5 days. Sorry. Here's who's free near you. | |
| pro.cancelled.cta | See who's free | |
| session.expired | You've been logged out. Text yourself a new code. | |
| photo.failed | That photo didn't upload. Try again. | |
| photo.tooMany | Three's the limit. | |
| update.required | This version's too old to book. Update from the App Store. | |

## Pro side

### Pro onboarding

| Key | Copy | Notes |
|---|---|---|
| pro.onboarding.progress | {step} of 7 | `label` style |
| pro.onboarding.intro.title | Your pro side | Serif |
| pro.onboarding.intro.body | Seven short steps. You can come back to any of them, and take bookings before the last two are done. | |
| pro.onboarding.intro.cta | Start | |
| pro.onboarding.specialty.title | Your specialty | Step 1 |
| pro.onboarding.specialty.sub | Pick everything you do. The first one's your main label. | Multi-select |
| pro.onboarding.specialty.hair | Hair stylist | |
| pro.onboarding.specialty.nails | Nail tech | |
| pro.onboarding.specialty.makeup | Makeup artist | |
| pro.onboarding.specialty.lashes | Lash tech | |
| pro.onboarding.specialty.brows | Brow artist | |
| pro.onboarding.services.title | Services and prices | Step 2 |
| pro.onboarding.services.sub | Your price is what she sees. Our 12% comes out of your side, and she pays a $3 booking fee on top. | |
| pro.onboarding.services.add | Add a service | |
| pro.onboarding.services.name | Service | Field |
| pro.onboarding.services.name.placeholder | Full set, French tip | |
| pro.onboarding.services.price | Price | |
| pro.onboarding.services.duration | How long | Picker in 15 min steps |
| pro.onboarding.services.suggested | Common ones for {specialty} | Tappable list to prefill |
| pro.onboarding.services.empty | Nothing yet. Your top three is enough to start. | |
| pro.onboarding.services.youGet | You get {payout} | Caption under each price, after the 12% |
| pro.onboarding.travel.title | Where you'll go | Step 3 |
| pro.onboarding.travel.sub | Your base and how far from it you'll travel. Clients outside this won't see you. | |
| pro.onboarding.travel.base | Your base | |
| pro.onboarding.travel.base.placeholder | Suburb or postcode | |
| pro.onboarding.travel.radius | How far | |
| pro.onboarding.travel.radius.option | {n} km | 5, 10, 15, 25 |
| pro.onboarding.travel.radius.all | Anywhere in Melbourne | |
| pro.onboarding.travel.fee | Travel fee | |
| pro.onboarding.travel.fee.sub | Flat, per booking, shown on your profile. $0 is fine. | |
| pro.onboarding.availability.title | When you work | Step 4 |
| pro.onboarding.availability.sub | Your usual week. Change any day later from Calendar. | |
| pro.onboarding.availability.day | {weekday} | Mon to Sun |
| pro.onboarding.availability.off | Off | Toggle |
| pro.onboarding.availability.hours | {start} to {end} | |
| pro.onboarding.availability.addBlock | Add a second block | Split shifts |
| pro.onboarding.availability.copy | Copy to every day | |
| pro.onboarding.work.title | Your work | Step 5 |
| pro.onboarding.work.sub | At least three. Your photos, your clients, natural light if you can get it. This is what gets you booked. | |
| pro.onboarding.work.add | Add photos | |
| pro.onboarding.work.tag | Tag it | Category chips per photo |
| pro.onboarding.work.min | {n} of 3 | Until three are in |
| pro.onboarding.work.ownWork | Your own work only. Anyone else's and your profile comes down. | Caption |
| pro.onboarding.id.title | ID and ABN | Step 6 |
| pro.onboarding.id.sub | Once, and you get the ID checked badge. Clients look for it. | |
| pro.onboarding.id.abn | ABN | Field, 11 digits |
| pro.onboarding.id.abn.error | An ABN is 11 digits. Have another look. | |
| pro.onboarding.id.photoId | Photo ID | Licence or passport |
| pro.onboarding.id.selfie | A quick selfie | |
| pro.onboarding.id.privacy | Your ID is checked, then deleted. Only the tick stays. | |
| pro.onboarding.id.status.checking | Checking. Usually within a day. | `warn` |
| pro.onboarding.id.status.checked | Checked | `success` |
| pro.onboarding.id.status.failed | We couldn't match that. Try a clearer photo of both. | |
| pro.onboarding.id.later | Do this later | |
| pro.onboarding.payouts.title | Getting paid | Step 7 |
| pro.onboarding.payouts.sub | Payouts go to your bank daily through Stripe. About two minutes to set up. | |
| pro.onboarding.payouts.cta | Set up payouts | Opens Stripe Connect Express |
| pro.onboarding.payouts.done | Payouts on. Daily, to {bank} ending {last4}. | |
| pro.onboarding.payouts.later | Do this later | |
| pro.onboarding.payouts.later.note | You can take bookings now. You'll need this before your first payout lands. | |
| pro.onboarding.done.title | You're on. | Serif `hero` |
| pro.onboarding.done.sub | Your profile's live in {suburb}. The first request could be today. | |
| pro.onboarding.done.cta | Go to Today | |

### Today

| Key | Copy | Notes |
|---|---|---|
| today.title | Today | Tab and screen title, with `{day}` beside it |
| today.greeting | Morning, {name}. | Same time-of-day set as `home.greeting.*`, except evening reads "Evening, {name}." and late reads "Late one, {name}." |
| today.next.title | Next up | Serif heading |
| today.next.client | {client} · {service} | Multiple: "{service} and {n} more" |
| today.next.when | {time} · {duration} | |
| today.next.where | {address} | Full address, only after confirmed |
| today.next.notes | Her notes | Expands notes and inspo photos |
| today.next.directions | Directions | Opens Maps |
| today.next.message | Message {client} | |
| today.next.late | Tell her you're late | Sends a quick reply |
| today.next.onMyWay | On my way | Primary. Client gets `push.client.onHerWay` |
| today.next.here | I'm here | Replaces "On my way" once sent |
| today.next.done | Mark done | Replaces "I'm here" |
| today.next.done.title | Mark it done? | |
| today.next.done.body | This charges {client} {price}. {payout} comes to you after the 12%. | |
| today.next.done.cta | Yes, done | |
| today.next.done.toast | Done. {payout} to you tomorrow. | Haptic `.success` |
| today.next.empty | Nothing on today. | |
| today.next.empty.sub | Tomorrow: {n} bookings. | "Nothing tomorrow either. Check Calendar's got you on." when 0 |
| today.next.later | Later today | Header for bookings after the next one |
| today.earnings.today | Today | Tile, `{price}` |
| today.earnings.week | This week | Tile |
| today.earnings.pending | Pending | Tile, `{price}`, sub "{n} to pay out" |
| today.requests.title | New requests | With count |
| today.requests.card | {client} wants {service} | |
| today.requests.when | {day}, {time} · {suburb} · {distance} from base | |
| today.requests.price | {price} · {payout} to you | |
| today.requests.notes | Her notes | |
| today.requests.expires | Reply by {time} or it lapses. | Caption |
| today.requests.accept | Accept | `lacquer` |
| today.requests.decline | Decline | |
| today.requests.accept.done | Confirmed. She's been told. | Toast |
| today.requests.decline.title | Reason | Sheet |
| today.requests.decline.sub | She'll see this. Keep it kind. | |
| today.requests.decline.reason.time | That time doesn't work for me | Five reasons, this order |
| today.requests.decline.reason.far | Too far for me to travel | |
| today.requests.decline.reason.service | I don't do that service | |
| today.requests.decline.reason.booked | I'm fully booked that day | |
| today.requests.decline.reason.other | Something else | Reveals a text field |
| today.requests.decline.other.placeholder | One line. She'll read it. | |
| today.requests.decline.offer | Offer another time | Optional, opens the picker |
| today.requests.decline.cta | Decline | |
| today.requests.decline.done | Declined. She's been told and her hold's released. | Toast |
| today.requests.empty | No new requests. Your profile's live. | |
| today.reliability | {n}% of bookings kept | Small, only if under 100 |

### Calendar

| Key | Copy | Notes |
|---|---|---|
| calendar.title | Calendar | |
| calendar.week | Week of {day} | |
| calendar.today | Today | Jump button |
| calendar.booking | {time} · {client} · {service} | Event block |
| calendar.empty.day | Free all day. | |
| calendar.off.day | Off | |
| calendar.availability | Availability | Section |
| calendar.availability.edit | Edit usual week | Reuses onboarding step 4 |
| calendar.availability.thisDay | Just {day} | Edit one day without changing the usual week |
| calendar.availability.hours | {start} to {end} | |
| calendar.availability.addHours | Add hours | |
| calendar.availability.instantNote | Instant book is on. Anything you leave open can be booked without asking you. | Caption |
| calendar.block | Block time | |
| calendar.block.title | Block time off | Sheet |
| calendar.block.from | From | |
| calendar.block.to | To | |
| calendar.block.allDay | All day | Toggle |
| calendar.block.repeat | Every week | Toggle |
| calendar.block.note.placeholder | Just for you. Clients don't see it. | |
| calendar.block.cta | Block it | |
| calendar.block.conflict | You've got {client} at {time} in there. Move her first. | |
| calendar.block.done | Blocked. | Toast |
| calendar.unblock | Unblock | |

### Work

| Key | Copy | Notes |
|---|---|---|
| work.title | Work | Tab and screen title |
| work.count | {n} photos | |
| work.add | Add photos | |
| work.empty | No photos yet. Three good ones beat thirty average ones. | |
| work.uploading | Uploading {n} of {total} | |
| work.cover | Cover | Badge on the first photo |
| work.reorder | Reorder | |
| work.reorder.hint | Hold and drag. The first one's your cover, the first six show on your card. | |
| work.tag | Tag | |
| work.tag.title | Tag this photo | Sheet, category chips |
| work.tag.service | Which service | Optional picker |
| work.pin | Pin | Becomes "Unpin" |
| work.pin.note | Pinned photos stay at the top. Up to four. | |
| work.pin.limit | Four's the limit. Unpin one first. | |
| work.delete | Delete | |
| work.delete.title | Delete this photo? | |
| work.delete.body | Gone from your profile, not from your camera roll. | |
| work.delete.cta | Delete | |
| work.ownWork | Your own work only. | Caption on the add sheet |

### Earnings

| Key | Copy | Notes |
|---|---|---|
| earnings.title | Earnings | |
| earnings.thisWeek | This week | Tile, `{price}` |
| earnings.thisWeek.sub | {n} bookings | |
| earnings.month | This month | Tile |
| earnings.pending | Pending | Tile |
| earnings.pending.sub | Paid out daily. Lands the next business day. | |
| earnings.tips | Tips | Tile |
| earnings.tips.sub | All yours, no fee. | |
| earnings.history | History | Section |
| earnings.history.row | {client} · {service} | `{day}` under, `{payout}` right |
| earnings.history.tip | Tip {price} | Caption on the row |
| earnings.status.paid | Paid out {day} | |
| earnings.status.tomorrow | Paying out tomorrow | |
| earnings.status.held | Held. Booking not done yet. | |
| earnings.status.refunded | Refunded. You cancelled. | |
| earnings.status.kept | Client cancelled late. You keep {price}. | |
| earnings.breakdown.title | How it breaks down | Sheet per booking |
| earnings.breakdown.services | Services | `{price}` |
| earnings.breakdown.travel | Travel fee | `{price}` |
| earnings.breakdown.fee | Hair Done fee, 12% | `−{price}` |
| earnings.breakdown.tip | Tip | `+{price}`, hidden if none |
| earnings.breakdown.total | To you | `{payout}`, `title` size |
| earnings.breakdown.note | The $3 booking fee is paid by the client, not you. | |
| earnings.empty | Nothing yet. It'll be here the day after your first booking. | |
| earnings.summary | Email me a summary | Tax-time export |
| earnings.stripe | Manage payouts in Stripe | |

### Profile edit

| Key | Copy | Notes |
|---|---|---|
| proProfile.title | Your profile | |
| proProfile.preview | See it as a client | |
| proProfile.photo | Profile photo | |
| proProfile.name | Name | |
| proProfile.specialty | Specialty | |
| proProfile.bio | About you | |
| proProfile.bio.placeholder | A few lines in your own words. How long you've been doing this, what you're known for. Emoji are fine here. | Pros may use emoji in bios; the app doesn't |
| proProfile.bio.count | {n}/300 | |
| proProfile.services | Services and prices | Reuses onboarding step 2 |
| proProfile.services.add | Add a service | |
| proProfile.services.remove | Remove | |
| proProfile.travelFee | Travel fee | |
| proProfile.radius | How far you'll go | |
| proProfile.base | Your base | |
| proProfile.instantBook | Instant book | Toggle |
| proProfile.instantBook.sub | On, and clients book your open slots without asking. Off, and you accept each one. | |
| proProfile.pause | Pause my profile | |
| proProfile.pause.sub | Hidden from searches. Bookings you already have still stand. | |
| proProfile.unpause | Unpause | |
| proProfile.reliability | Reliability | |
| proProfile.reliability.sub | {n}% of bookings kept. Cancelling on a client drops it. | |
| proProfile.save | Save | |
| proProfile.saved | Saved. | Toast |
| proProfile.discard.title | Leave without saving? | |
| proProfile.discard.cta | Leave | |
| proProfile.discard.keep | Keep editing | |

### Push notifications, pro side

| Key | Copy | Notes |
|---|---|---|
| push.pro.newRequest | {client} wants {service}, {day} {time} in {suburb}. {price}. | Body. Title is "New request" |
| push.pro.newRequest.expires | Reply by {time}. | Appended if under 2 hours left |
| push.pro.instantBooked | New booking. {client}, {service}, {day} {time}, {suburb}. | |
| push.pro.clientMessage | {client}: {message} | Truncated by iOS |
| push.pro.clientOnHerWay | {client}: On my way home, there by {time}. | The client's quick reply, surfaced as a push |
| push.pro.headsUp | {client} at {time} in {suburb}. Tap when you're on your way. | 45 min before |
| push.pro.paid | Paid. {payout} from {client} lands tomorrow. | |
| push.pro.paid.tip | Paid. {payout} from {client}, plus a {tip} tip. | |
| push.pro.cancelled.free | {client} cancelled {day}. More than 24 hours out, so no charge. | |
| push.pro.cancelled.late | {client} cancelled {day}. Under 24 hours, so you keep {price}. | |
| push.pro.rescheduleAsk | {client} wants to move {day} to {newDay} {time}. | |
| push.pro.review | {client} gave you {stars} stars. | |
| push.pro.tomorrow | Tomorrow: {n} bookings, first at {time} in {suburb}. | 7 pm the night before |
| push.pro.idChecked | ID checked. The badge is on your profile. | |
| push.pro.payoutSent | {payout} is on its way to your bank. | |

### Push notifications, client side

| Key | Copy | Notes |
|---|---|---|
| push.client.confirmed | {pro} confirmed. {day} at {time}, at {addressLabel}. | `{addressLabel}` is "home", "Mum's", or the suburb |
| push.client.declined | {pro} can't do {day}. Her reason's inside, and so are a few others who are free. | |
| push.client.onHerWay | {pro}'s on her way. About {minutes} minutes. | |
| push.client.here | {pro}'s here. | |
| push.client.done | Done. {price} charged, receipt on its way. | |
| push.client.receipt | Paid. {price} to {pro}, receipt in your inbox. | From the brief |
| push.client.rate | How'd {pro} go? Two taps. | 2 hours after paid |
| push.client.reminder | Tomorrow: {pro}, {time}, at {addressLabel}. Cancel free until {cutoff}. | Day before, 6 pm |
| push.client.reminder.dayOf | {pro} at {time} today. | Morning of |
| push.client.message | {pro}: {message} | |
| push.client.proCancelled | {pro} had to cancel {day}. Full refund's on its way. Tap for who else is free. | |
| push.client.rescheduled | Moved. {pro}, {day} at {time}. | |
| push.client.whosFree | Free this arvo: {pro}, {distance} away, from {time}. | Opt-in only. "Arvo" is allowed in pushes |

### System permissions

Pre-permission screens are ours and come first. The system string is what iOS shows in its own dialog; keep it to the point.

| Key | Copy | Notes |
|---|---|---|
| perm.location.pre.title | Pros near you | |
| perm.location.pre.body | We use your location to show who's close and what her travel fee comes to. Only while you're in the app. | |
| perm.location.pre.cta | Use my location | |
| perm.location.pre.skip | I'll type a suburb | |
| perm.location.system | Hair Done shows pros near you and works out travel fees. Only while you're in the app. | `NSLocationWhenInUseUsageDescription` |
| perm.camera.pre.title | Your camera | |
| perm.camera.pre.body | For inspo photos, and on the pro side, photos of your work. | |
| perm.camera.pre.cta | Allow camera | |
| perm.camera.pre.skip | Not now | |
| perm.camera.system | Hair Done uses your camera for inspo photos and, on the pro side, photos of your work. | `NSCameraUsageDescription` |
| perm.photos.pre.title | Your photos | |
| perm.photos.pre.body | Pick up to three inspo photos for a booking. We only see the ones you pick. | Pro side: "Pick the photos of your work you want on your profile. We only see the ones you pick." |
| perm.photos.pre.cta | Pick photos | |
| perm.photos.pre.skip | Not now | |
| perm.photos.system | Hair Done needs your photos so you can add inspo shots, and pros can add their work. Only the ones you pick. | `NSPhotoLibraryUsageDescription`. Use the limited picker |
| perm.notifications.pre.title | We'll tell you when she's on her way | Client side |
| perm.notifications.pre.body | Confirmed, on her way, here, done, receipt. That's the lot. Nothing else unless you turn it on. | |
| perm.notifications.pre.title.pro | New requests and messages | Pro side |
| perm.notifications.pre.body.pro | A request lapses if you don't reply in time. You'll want these on. | |
| perm.notifications.pre.cta | Turn on | |
| perm.notifications.pre.skip | Not now | |
| perm.notifications.system | | iOS has no custom string for notifications. Everything we want to say is on the pre-permission screen |
