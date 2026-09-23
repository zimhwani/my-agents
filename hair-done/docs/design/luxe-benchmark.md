# Luxe benchmark: what makes a phone app feel expensive, and what Hair Done does next

Answers to `../build-brief.md` §3 and §4 and `../brand.md`. It follows `luxe-pass.md`, which was superseded. This is research for the designer, not a spec. Where it recommends changing a brand rule, it says so and names the rule.

Written by the UX researcher, with the trend researcher as a second reader. Sources are tagged:

- **[W]** confirmed by a web search on 23 Sep 2026 (sources at the end).
- **[K]** from my own knowledge of these apps and sites. That knowledge has a cutoff, and luxury apps redesign often. Point sizes marked "about" are estimates from memory of the screens, not measurements. Check any [K] detail on a device before you copy it.

Method, honestly: web search worked. Every page fetch was blocked by this environment's proxy (apps.apple.com, elsewhen.com, june-h.com), so I couldn't read case studies in full or pull App Store screenshots. I had no device access to any of these apps. What I could see directly: the three TestFlight screenshots of Hair Done and the refined mockup (`scratchpad/refine.png`). The diagnosis in §3 is based on those screens.

---

## 0. What the four Hair Done screens actually show

Before the benchmark, the evidence, so the diagnosis rests on it.

**Build 21, original (Home, "Morning, Mati.").** Every block is a white box on cream: the search field, the "Next up" card, the pastel tiles. "Who's free today" tiles are procedural gradients with an initial in a circle on top. Category tiles are beige, pink and lilac with an SF Symbol (scissors, a hand, a brush). A pink "Confirmed" pill. A system floating tab bar with filled glyphs, a red house and a red "1" badge. The left edge of the greeting, the "Next up" avatar and the tiles is clipped by the screen, so the layout looks broken as well as generic. At no point does a photograph take up more than about a third of the screen width.

**Build 27, editorial pass (Home, "Afternoon, Tash.").** The boxes are gone. What's left: a tracked "CHELTENHAM" eyebrow, a big serif greeting with *Tash.* in italic, a search field that is a single hairline, a *blank band about 100pt tall between two hairlines*, "Next up" as a text row with a green dot and "CONFIRMED", then real photos at about 176pt wide with a small radius, then bare serif category words with one underlined, then "Nails near you" with a "List | Map" pair of underlined text toggles that don't line up with the heading. Each pro in the list gets three square-ish photos in a row, edge to edge, and *every pro shows the same three photos*. Two of the photos are stock: a bride in a white robe in a salon chair, and a threading close-up. The tab bar is unchanged: filled glyphs, a red house, a red badge.

**Refine mockup (build 21 made quieter).** Serif names, a status dot in place of the pill, a tracked "FREE FROM 5 PM" capsule on the photo, desaturated tiles that still have icons, a white card with a three-photo strip and "from $40" in bold serif, an ink-filled "LIST | MAP" segmented control, and an italic name in the greeting. The tab icons are placeholder squares.

What all four share: **the top of Home is a greeting and a search field.** No photograph ever fills the width of the screen, nothing is dark, the tab bar is stock iOS, and the photos are either placeholders, repeats or stock. Those four facts matter more than any radius or tint.

---

## 1. Benchmark: 15 apps and sites

"Phone" means the iOS app where there is one, otherwise the mobile site. The web tag applies to the fact it's attached to, not the whole row.

| # | App | What makes it feel expensive on a phone (concrete) |
|---|---|---|
| 1 | **Net-a-Porter** (app) | • Home is a vertical run of full-width editorial images, most taller than wide, each with a headline of just a few words in small caps and a short line beneath. The image comes first and the words follow it. [K] • Designer name is the heading on a product (bold uppercase sans, about 13pt), product name under it in regular, price under that in plain black at the same size. No strike-through theatre outside sale, and no badges beyond a tracked text word ("Exclusive"). [K] • The chrome is black and white: an outline tab bar, the wordmark centred at the top, no colour anywhere in the UI. All the colour comes from the clothes. [K] • The service layer is where the money shows: EIP (their top-spender tier) gets a named personal shopper, and orders arrive in the black box with ribbon. The expensive part happens away from the screen. [K] |
| 2 | **Mytheresa** (app) | • Campaign imagery full width, product grids 2-up in portrait with a near-white ground, tiny uppercase labels. [K] • Described as balancing a minimal look against function, with loyalty and referral features kept out of the way. [W, AppsFlyer] • Up to 900 new arrivals a week, and the screens still look calm because every product photo follows one standard: same ground, same crop, same light. [W for the number, K for the photo standard] • They built a Vision Pro app with an immersive product carousel. The signal is that they spend on the medium. [W] |
| 3 | **SSENSE** (app) | • The counterexample to "luxury = whitespace". The grid is tight and products sit flush against each other with no gutters. [W, SSENSE-TECH] • Where the air goes is deliberate: they "maximized white space where product recommendations could exist". Space is there to say where something ends. [W] • A neo-grotesk sans only, uppercase for brands, black on white. No serif, no colour, no radius. [K] • Editorial stories sit alongside product in the same grid, with image sizes that change from section to section. [W] • Why it reads as expensive: it is strict. Every edge lines up, every photo is shot the same way, and nothing is decoration. [K] |
| 4 | **Hermès** (site on phone, Jan 2026 relaunch) | • Hand-drawn illustrations by Linda Merad all through the site. A loafer carries a pelican like a boat, and eels circle a watch. [W, Fast Company, Domus] • Paper grain and irregular line are left in on purpose. The press read this as the opposite of AI imagery, and as expensive for that reason. [W, Highsnobiety] • Hermès orange is used as a signal, not a surface. Most screens are cream or white. [K] • Lesson: one crafted thing that no template can produce is worth more than any amount of polish. [synthesis] |
| 5 | **Chanel** (site; Lipscanner app for beauty) | • Two colours only: black and white. The wordmark is centred in its own typeface, and even buttons are black rectangles. [K] • Opens on full-bleed video or photography that fills the first screen, with no text on it apart from the wordmark and one line. [K] • Beauty shades are shown as photographed product texture (a real smear of lipstick), never as a flat colour circle. [K] • Lipscanner (2021) lets you point the camera at any colour and try on the closest Chanel lipstick in AR. It's a single-purpose tool with a single signature trick. [K] |
| 6 | **Aesop** (site on phone; Aesop Reader app) | • Product photographed as a single amber bottle on a flat, muted ground (olive, oat, dark brown), and the ground colour changes from section to section. [K] • Type does a lot of the work: long product descriptions set well in one sans (Suisse), with generous line height and literary quotes as section breaks. Paragraphs, not bullets. [K] • Aesop Reader is a separate app for literature. It sells no product. [W] • The in-store ritual (the basin, the hand massage, the samples in the bag) is the brand, and the digital side mostly points you there. [W, Wallpaper, PURVEYR] |
| 7 | **Le Labo** (site; in store) | • Every bottle's label is printed while you wait, with your name, the date and the city it was made in. The personalised object is the luxury. [K] • A typewriter face and plain kraft-and-white labels. It looks like a lab, not a boudoir. [K] • Digital is sparse and product-led. The site points you to the in-person moment. [K] • Lesson for us: what's expensive is the booking record that has her name on it, not the booking button. [synthesis] |
| 8 | **Rhode** (site on phone), with **Glossier** as the contrast | • Rhode: a lowercase sans wordmark (we have a lowercase mark too), milky neutrals, product shot huge on flat grounds, very few words per screen. [W for minimal lowercase identity, K for layout] • The product and the founder's face carry every screen, and there is almost no UI on top. [K] • Glossier: one owned pink everywhere (pink pouch, pink UI). It works because it's friendly and cool, and that is exactly why it isn't luxe. **Pastel pink UI reads as approachable, not expensive.** That's our pink "Confirmed" pill and our nails tile. [K, synthesis] |
| 9 | **Aman** (site; Aman Club app for members) | • Landscape photography fills the screen, and the text is tiny: about 11 to 13pt uppercase sans, stone and grey. The image does almost all the talking. [K] • Very little UI at all: no cards, no chips, and hardly any buttons until you book. Whitespace is always framed by a big image. [K] • Aman Club is a separate app for founding members, with private accounts and statements. Exclusivity comes from what you can see and who you are. [W] • Grounds are dark and warm (charcoal, stone). There is no pure white, the palette lets the photography glow, and nothing in it is decorative. [K] |
| 10 | **Soho House** (app) | • The 2022 redesign by Elsewhen put real House photography and the clubs' physical design into the app, so it feels like each House. [W] • Modules adapt to each member by interests, booking history and location ("What's On", "Where to Eat"). [W] • The digital membership card at the door is the moment the app pays for itself: you show your face, and you're in. [K] • Cowshed spa treatments are booked in the same app. Service booking inside a club feels like being looked after, not like a transaction. [K] • Warning: members still complain about performance. Slow and buggy cancels out the look. [W] |
| 11 | **Four Seasons** (app and Chat) | • Four Seasons Chat is staffed 100% by people, with no chatbots, in 100+ languages, answering in about 90 seconds. [W] • You can ask for anything, from a table to a late checkout to a private jet. The chat is the concierge desk. [W] • When you have a stay, the app leads with that property: its photo first, then your dates. When you don't, it shows the brand's places. [K] • Lesson: a named person replying fast reads as more expensive than any visual detail. [synthesis] |
| 12 | **Airbnb Luxe** (tier inside Airbnb) | • Same company, same app, but the luxury tier changed three things: vetting (a 300-point home inspection, stated as a promise), a named human (a trip designer with every booking, 24/7), and presentation (larger photo tours, fewer facts per screen). [W for the first two, K for presentation] • The trip designer arranges chefs, childcare and in-house massage. The booking includes a person, not only a place. [W] • Lesson: when a mass-market app wants to feel expensive, it adds a person and a standard, not a font. [synthesis] |
| 13 | **Blade** (app) | • Black ground, white type, landscape photography of helicopters and destinations. Dark UI with big photos is the whole look. [K] • Price stated plainly and early (seats from $195), and booking takes a few taps with Apple Pay. [W] • The rebuilt app (Flutter, Very Good Ventures) was pitched on "rich visuals and polished interactions". [W] • The physical ceremony is the brand: lounges with rosé in their own sippy cups and staff in black jumpsuits by Cynthia Rowley and Sarah Jessica Parker. The app is the ticket to that moment. [W] • The boarding pass works as an object: full screen, dark, big type, in Apple Wallet. [K] |
| 14 | **Glamsquad and Priv** (US at-home beauty, our closest peers) | • Priv: a "clean, minimalist" grey-and-white palette with pale blue accents. Booking is location, then service, then time, then pro, with chat to the pro. [W, DesignRush and gopriv.com] • Glamsquad's 2023 redesign put booking into one flow, let members pick a preferred pro and added a design system. [W] • Both read as tidy utilities: service menus, lists and forms. They're competent, and they are the "nice marketplace" we already built. [K, synthesis] • Lesson: the category's default look is a utility, so matching the peers means looking like the thing we're trying not to look like. [synthesis] |
| 15 | **Boulevard** (booking software behind upscale US salons), plus **Blys and Purely Polished** (AU) | • Boulevard: the booking layer slides over the salon's own site and brand. Categories, then services with prices and durations, then time, then contact. It handles a colour-then-cut booking and plans the processing gap between the two. [W] • Its lesson is legibility in the booking flow: every service has a price and a duration on one line, and nothing is hidden. [W] • Blys: "Australia's largest network" of mobile massage and beauty pros, open 6am to midnight, hair from $99. Purely Polished sends vans with salon kit. [W] • Both AU players sell convenience with utility layouts: service first, and the pro is often assigned rather than chosen. [K, lower confidence] **No one in Australia owns the luxury tier of at-home beauty on a phone.** [synthesis] |

---

## 2. The 12 patterns that recur

Each one has the mechanism, which is why it reads as expensive, and a do and a don't for Hair Done.

### P1. The photograph is the layout, not a thing placed inside it
**Mechanism:** a large image is costly to make and risky to show, so a screen that gives most of itself to one picture says "we're sure this is good". Small images inside boxes say "here is a list of options". Net-a-Porter, Chanel, Aman and Blade all give the first screen 60 to 100% of its height to one image.
**Do:** give the first viewport of Home and of a profile to one photo, edge to edge, 4:5 or taller.
**Don't:** make the first thing on a screen a text greeting and a search field, or show photos only as tiles or thumbnails 150 to 180pt wide.

### P2. One image standard across the set
**Mechanism:** a set that matches (same crop, same light, same distance) looks art-directed, and art direction costs money. Mytheresa's 900 new arrivals a week look calm for this reason. A mixed set looks user-generated, and user-generated reads as a marketplace.
**Do:** one crop rule (4:5, the work fills the frame), one light rule (window light), and one cover per pro chosen by Hair Done, not the pro. Real photos by the pro, as the brand says, but held to a standard.
**Don't:** stock (the bride in a salon chair breaks the brand's own "no salons" rule), and never the same three photos on every pro. A repeat tells a tester it's fake faster than any other flaw.

### P3. Big jumps in scale, and few sizes
**Mechanism:** a confident layout has one huge thing and a lot of small things, with not much in between. The contrast is what says "edited". When everything is between 15 and 20pt, the screen looks like a form.
**Do:** per screen, one display line (40 to 56pt serif) or one image, then body at 17 and captions at 12 to 13. Three steps you can see.
**Don't:** step by 34, 20, 17, 15, 13, or set pro names, prices and ratings all at 17 semibold.

### P4. The chrome is custom or it disappears
**Mechanism:** default system controls (filled SF Symbols, red badges, standard segmented controls, a search bar) say "template" in the part of the screen people see most. Luxury apps take control of the chrome (NAP's centred wordmark, Chanel's black rectangle buttons) or hide it under the image.
**Do:** the wordmark at the top of Home, thin custom outline tab icons in ink, a lacquer dot for unread instead of a counter, and search as an icon that opens its own full screen.
**Don't:** a filled red house, a red "1" badge, underlined text toggles (they look like unstyled HTML), or placeholder-square icons.

### P5. Colour comes from the photos. The UI stays neutral.
**Mechanism:** when the interface has no colour of its own, everything with colour in it is the work: red nails, copper hair. Pastel UI tints compete with the photos and look like a children's app (Glossier's pink is charming, not expensive).
**Do:** paper, ink and one lacquer. Category and status colour go away, and the photo of a red French tip carries the red.
**Don't:** six pastel tiles, pink pills, a honey star, a green seal and a lilac avatar all on one screen.

### P6. A dark ground marks the moments that matter
**Mechanism:** a whole screen in a dark tone reads as night, evening, a theatre, a boarding pass: something scheduled and special. Blade, Aman and Chanel all use dark grounds. Switching from light for browsing to dark for committing tells you something important has started, without any words.
**Do:** ink ground (#241A16) with paper type for the booking sheet, the confirmation, the "on her way" screen and a pro's full-screen work viewer.
**Don't:** leave the whole app on one flat plane of paper with no change of tone anywhere (build 27), or go dark everywhere and lose the warm paper that is the brand.

### P7. Structure through alignment, not boxes, but the structure has to be visible
**Mechanism:** SSENSE has no cards and still looks rigorous because every edge lines up and the photos fill the grid. Taking boxes away only works when big images and a strict grid take over the job of holding the page together. Hairlines at 1.06:1 contrast with gaps of air between them look like missing content.
**Do:** full-bleed or strict-gutter images, text aligned to one left edge, data rows (a receipt, booking details) with hairlines you can actually see.
**Don't:** empty bands between hairlines, toggles that don't line up with their heading, content clipped at the screen edge (build 21).

### P8. The price is a fact, set quietly and never hidden
**Mechanism:** luxury states the price once, in plain type at fact size. Not in bold, not in a badge, not with "from" doing a lot of work. Blade and Boulevard show it early, because hiding it reads as upselling.
**Do:** "$95" in SF with monospaced digits at the size of the facts around it, and the total in the booking sheet as the one big number.
**Don't:** "from $40" in bold serif at the size of the name, or a price that only appears on the review screen.

### P9. A named person answers
**Mechanism:** Four Seasons Chat (people only, about 90 seconds), Airbnb Luxe's trip designer and NAP's personal shopper all sell *attention*, which is the scarcest thing money buys. A name and a reply time on screen cost almost nothing to design, and testers value them highly.
**Do:** the pro's own voice on her profile and in her messages. A Hair Done desk thread with a real first name and an honest reply time, for changes and problems.
**Don't:** a help centre tree, "Our team", or anything that reads like a bot.

### P10. The transaction gets a ceremony, and the record is something she keeps
**Mechanism:** Blade's boarding pass, Le Labo's label printed with your name and Soho House's card at the door turn a receipt into something you'd keep. Luxury slows down exactly once: when she commits, and just after.
**Do:** a dark booking sheet laid out like a ticket, the lacquer check, and a record with her name, the pro's name, the date and the suburb, which she can add to Apple Wallet.
**Don't:** a grey summary list, confetti, or a toast that says "Success".

### P11. Motion is weighted and serves the image
**Mechanism:** expensive motion is slow where the eye rests (a hero that settles over a few seconds, a photo that grows from the list into the profile) and instant everywhere else. Cheap motion is uniform: everything scales to 0.97 and everything springs the same way.
**Do:** a matched-geometry transition from the list photo to the profile hero, a slow 1.03-to-1.0 settle on the Home hero, and haptics on three moments only.
**Don't:** fade in every section on launch or bounce every button.

### P12. One crafted signature no template can produce
**Mechanism:** Hermès's drawings, Le Labo's label and Aesop's amber bottle on olive are things a competitor can't copy out of a UI kit. One of them is enough.
**Do:** our lacquer full stop, the "done." in the wordmark, used as the mark that closes a booking, and nowhere as decoration.
**Don't:** five small delights spread across the app.

---

## 3. Why each of our three attempts failed

### Attempt 1, "a nice generic marketplace": it used marketplace grammar
Every unit was a white box of the same weight (P7 done backwards). Colour went on the navigation, with pastel tiles and a pink pill, instead of the work (P5). Avatar circles sat on photos, which is Instagram and Uber Eats grammar, and they repeated what the photo already said. The photos were procedural placeholders, so no image carried any screen (P1). The chrome was stock (P4). On the device, content was clipped at the left edge (P7). **Everything was the same size and weight, so it read as a list of options, and a list of options is a marketplace.**

### Attempt 2, "editorial minimal": it took away the structure and put nothing in its place
Luxury restraint is two moves: take away chrome, and add scale (big photos, big type, a change of ground). Build 27 made only the first move. The photos stayed at thumbnail size and were stock or repeated (P1, P2). The type steps stayed small (P3). The one plane of paper never changed tone (P6). Hairlines at 1.06:1 with empty bands between them, underlined text toggles and bare words as links are the actual vocabulary of a wireframe, so a tester's eye read "not built yet" (P7). And the most-seen chrome, the tab bar with its filled red house and red badge, stayed stock, so it looked like unfinished content inside a finished template (P4). **Whitespace next to small things doesn't read as luxe. It reads as empty.** It only reads as luxe when it frames something large.

### Attempt 3, "restrained refinement": it turned the marketplace down instead of changing it
The refine mockup keeps every marketplace object (the search field first, the white card, the initial avatar, the icon tile, the segmented control, the capsule on the photo, the three-photo strip) and makes each one quieter. Serif names and an italic greeting are type details applied to a utility layout. Luxury isn't a quieter marketplace. It's a different arrangement: **one thing per screen, shown large, then the facts.** The mockup still has about 14 separate objects above the fold and no object bigger than about 300pt, so nothing on it says "this one" (P1, P3). The search field is still the first thing she can do, which frames Hair Done as a search tool rather than a friend with someone in mind (P9).

### What's common to all three, and a caution
None of them changed the information architecture of Home, the photos, or the chrome, and those are the three things that set the first impression on a phone. Radius, tint, dots and italics are second-order. **A caution for the next pass:** this direction depends on the photos more than any other. If covers stay stock, repeated or inconsistent, a full-bleed hero will make them *more* visible, not less. Sort the photo standard (P2) before the layout, or at least alongside it.

---

## 4. Direction for Hair Done (one page)

**The idea in one line:** paper for browsing, ink for committing, and one large photo of one woman's work at the top of every screen that matters.

### Non-negotiables

1. **Home opens on one full-bleed 4:5 photo, not a greeting and a search field.** Edge to edge, running under the status bar, about 490pt tall on a 393pt-wide phone. If she has a booking today, it's her pro's cover with "Kiara, 6:15 tonight." in paper New York at about 40pt, bottom left over a bottom-third ink scrim at 45%, and one 13pt paper line under it: "BIAB overlay · at yours in Cheltenham". If she doesn't, it's the nearest pro who's free tonight: "Kiara is free from 5." and "Nails · Brunswick · $95". The eyebrow above it in 12pt tracked paper: "AFTERNOON, TASH · CHELTENHAM". The wordmark `hair done.` sits top centre over the photo in paper serif 17. Search becomes a magnifier icon at top right that opens a full-screen search.
   *This changes a brand rule:* brand.md says "no overlays" on photos. Keep that rule everywhere except this hero and the profile hero. The rule was written to stop captions burned into photos and capsules sitting on them, not a typographic cover line.

2. **Photos come large, and never small in rows.** Below the hero, "Who's free today" is a horizontal pager of 4:5 photos at 300pt wide (not 176), 2pt radius, with the name under each in serif 24 and one 13pt fact line. "Near you" is one pro per screen width: a full-bleed 4:5 photo you can swipe through her work (small page dots), then name in serif 28, a fact line "Nail tech · St Kilda · 13 km · ★ 4.8 (121)" in 15 inkSoft, and the price "$60" right-aligned in 17 SF monospaced ink. No three-photo strips, no card, no avatar and no capsules on photos. Categories are photo tiles (3:4, about 120pt wide, a real photo of that kind of work) with the word in serif 17 beneath. No tints, no icons.

3. **A pro's profile is her work first, then her words.** The top is a full-bleed hero (the cover, 4:5, stretching on pull). Her name sits on it in paper serif about 48pt, with the one-line headline in serif italic 20 under it ("Does a *very* good French tip."). Tap the photo and it opens a full-screen ink viewer with her work, swiped horizontally, with a caption in 13pt paper. Below: facts as one quiet line, then services as a price list (name on the left, duration and price on the right, visible hairlines at about #DDD2C5), then three reviews set as serif pull quotes with hairlines between them. The sticky bar at the bottom is ink with paper text, "Kiara · from $60" on the left and a `Book` button on the right.

4. **Booking turns to ink.** From `Book` onwards, the sheet is an ink ground with paper type. At the top, her cover as a square with a 2pt radius, then "Kiara at yours." in serif 34. The rows (service, day and time, address, travel fee, total) are SF 17 with paper hairlines at 12% opacity. The total is the one large number, "$180" at 34 in SF monospaced. The hold is explained in one sentence above the button, as the brand says. `Pay $180` in lacquer, 56pt tall, radius 4, and Apple Pay as the default. Price, time and suburb are on every step.

5. **Custom chrome, and no system red.** Four tab icons drawn for us as 1.25pt outline glyphs in ink, with labels. The active tab is ink with a 4pt lacquer dot beneath. There is no counter: unread is a lacquer dot on Inbox. Keep the system's floating glass bar material, which looks right. What reads as stock is the filled glyphs and the red. Buttons go from pills to squared (radius 4). The pill is the single most "consumer app" shape we have, and the welcome button can go squared too.

6. **A named person on the desk.** The first thread in Inbox is from Hair Done: a real first name, a real reply time ("Usually replies in about 10 minutes, 8am to 10pm"), for changes, lateness and anything that goes wrong. It's Four Seasons Chat at our size. If ops can't staff it at launch, don't fake it with a bot. Show the pro's own reply time instead, and add the desk later.

**The photo standard goes with these (P2), and none of it works without it.** Hair Done chooses each pro's cover and crops it 4:5 with the work filling the frame. The long edge is at least 1,600px, and the light is daylight. No stock anywhere, including TestFlight: shoot or commission 20 real covers before judging any of this on a device. Placeholders keep the brief's warm grain, but at full size, with no initials on them.

### Keep from the current brand
Paper #F8F3EC, ink #241A16 and one lacquer #C8323A (lacquer now appears even less: the pay button, the unread dot, the check). New York for the words a person would say and SF for everything else. The voice and copy, which are already the most luxe thing in the app. The wordmark and the `hd. nd.` mark with its lacquer full stops. The welcome screen with video. The lacquer check that draws itself. Dark mode tokens as they are.

### Retire
The white `card` on Home and profile, the category tints, `lacquerSoft` as a pill fill, status pills and capsules on photos, initial avatars (except in Inbox, where you're talking to a person), the three-photo strip, the segmented List/Map control (Map becomes an icon in the "Near you" header), and the search field as the first thing on Home.

---

## 5. Three signature moments

These are the three places to make a tester say "this feels expensive". Each is built from something the product already has.

### 1. "Tonight" (Home, first open of the day)
The app opens straight onto a full-bleed photo of the pro who's coming to her, or the one who's free tonight. The image settles slowly from 1.03 to 1.0 over about 4 seconds, the cover line fades in 300ms after it, and there's nothing else above the fold. Tap the photo and it grows into her profile with a matched-geometry transition, so the photo becomes the profile hero and never jumps. Under Reduce Motion, it's a plain cross-fade. This is P1, P3 and P11 in one gesture, and it's the first thing a tester sees.

### 2. The ink ticket (Pay, then "You're booked.")
She taps `Pay $180` and double-clicks for Apple Pay. The sheet stays ink. "You're booked." appears on its own line in paper serif 40, the lacquer check draws itself, and there's a `.success` haptic. Then the booking settles below it like a Le Labo label: her first name, "Kiara M.", "Thursday 25 September, 6:15 pm", "at yours in Cheltenham", "BIAB overlay · $180 paid", and a lacquer full stop at the end of the last line. Under it: `Add to Apple Wallet`. The pass is ink, with Kiara's cover as a strip image, the time in big numerals and the address. It shows on her lock screen on the day. This is P6, P10 and P12, and it's the moment people screenshot.

### 3. "She's on her way," then her note the next morning
When Kiara taps "leaving", a Live Activity starts on Tash's lock screen and in the Dynamic Island: Kiara's cover in a small circle (the one place an avatar earns its keep), "12 min" in serif numerals, and a lacquer dot that pulses once when she's 2 minutes away. In the app, the booking shows full-screen on ink: her photo, "Kiara's 12 minutes away.", and "Message her". The next morning comes a message *from Kiara*, not from Hair Done. It's her own template, prompted by us: care notes ("No hot water on them for a day.") and one line offering a date for the next visit ("Your infill's due in three weeks. I'm free Thursday 16 October at 6.") with a `Book again` button. The rating comes after that, and the honey star fills. This is P9 and P10. It's aftercare done by a person, and it gets the next booking.

---

## 6. How to test this before anyone builds it

Rule from last time: judge on a device, never on a mockup.

- Build the Home hero, one profile and the ink booking sheet as a clickable prototype, **with real photos**, and run it on an iPhone.
- Show it to 8 Melbourne women aged 25 to 45 who have booked a mobile or salon pro in the last three months. Put it side by side with build 21 and build 27, with the order shuffled.
- Ask three questions: "Which of these would you trust with $180?", "Which feels most expensive?" and "What's missing?". Give each screen 5 seconds first, then let them use it freely. Note which of them read "unfinished" before prompting.
- Pass mark: at least 6 of 8 choose the new direction for both the trust and the expensive questions, and none of them call it unfinished.

---

## Sources (web, searched 23 Sep 2026)

- [Mytheresa's app: Luxury UX with room to grow, AppsFlyer](https://www.appsflyer.com/blog/measurement-analytics/mytheresa-luxury-app-strategy/)
- [Mytheresa launches immersive Vision Pro app, PRWeb](https://www.prweb.com/releases/mytheresa-launches-an-immersive-shopping-experience-for-apple-vision-pro-as-one-of-the-first-luxury-platforms-to-underline-digital-leadership-302051415.html)
- [Behind the SSENSE app homepage, SSENSE-TECH](https://medium.com/ssense-tech/behind-the-ssense-app-homepage-building-a-dynamic-uicollectionview-layout-system-962fa7ddd9ec)
- [Designing with ambiguity, SSENSE-TECH](https://medium.com/ssense-tech/designing-with-ambiguity-part-i-establishing-an-experience-and-design-principles-8a93a4157fe9)
- [Design critique: SSENSE, IXD@Pratt](https://ixd.prattsi.org/2023/09/design-critique-ssense/)
- [Hermès's hand-illustrated website, Fast Company](https://www.fastcompany.com/91471305/hermes-hand-illustrated-website-is-the-ultimate-luxury)
- [Hermès launches a different kind of website, Domus](https://www.domusweb.it/en/news/2026/01/07/herms-new-website.html)
- [In the age of AI, Hermès goes all-in on illustration, Highsnobiety](https://www.highsnobiety.com/p/hermes-ai-illustration/)
- [Aesop store design, Wallpaper](https://www.wallpaper.com/fashion-beauty/aesop-store-design)
- [How Aesop uses design in its stores, PURVEYR](https://purveyr.com/2021/01/07/how-aesop-builds-compelling-customer-experiences-through-thoughtful-design/)
- [Aesop Reader, App Store](https://apps.apple.com/us/app/aesop-reader/id6476888615)
- [Rhode skin, a graphic designer's perspective](https://heyudesign.substack.com/p/rhode-skin-as-a-graphic-designers)
- [Aman Club, App Store](https://apps.apple.com/us/app/aman-club/id6443803190)
- [Redesigning Soho House's app, Elsewhen](https://www.elsewhen.com/work/customer-centric-app/)
- [Soho House app reviews, App Store](https://apps.apple.com/us/app/soho-house/id670256744?see-all=reviews&platform=iphone)
- [Four Seasons launches Chat in 100+ languages, Hospitality Technology](https://hospitalitytech.com/four-seasons-launches-four-seasons-chat-100-languages)
- [Four Seasons Chat, press release](https://press.fourseasons.com/content/fourseasons_pressroom/printView.html?pageToPrint=/content/fourseasons_pressroom/en/news/corporate/2017/four_seasons_chat)
- [Airbnb Luxe reimagines luxury travel, Airbnb Newsroom](https://news.airbnb.com/airbnb-luxe-reimagines-luxury-travel)
- [Airbnb Luxe launch with concierge services, PhocusWire](https://www.phocuswire.com/Airbnb-Luxe-launch-with-concierge-services)
- [BLADE, App Store](https://apps.apple.com/us/app/blade/id871972482)
- [Blade mobile app in Flutter, Very Good Ventures](https://verygood.ventures/success-stories/blade-mobile-flutter-app/)
- [Blade's lounges and uniforms, TheDesignAir](https://thedesignair.net/2017/06/23/blades-lounges-and-new-uniforms-celebrate-the-jetset-era/)
- [Glamsquad redesign, June Hongkiatkhajorn](https://june-h.com/work/glamsquad)
- [PRIV app design, DesignRush](https://www.designrush.com/best-designs/apps/priv)
- [How Priv works](https://gopriv.com/how-it-works/)
- [Boulevard self-booking](https://www.joinblvd.com/features/self-booking)
- [Boulevard client booking flow, support centre](https://support.boulevard.io/en/articles/5941525-the-client-booking-experience)
- [Blys mobile hair, Melbourne](https://getblys.com.au/locations/hair-melbourne/)
- [Purely Polished](https://www.purelypolished.com.au)
