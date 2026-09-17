# Pamusha Lake House — UX Spec (IA, wireframes, components)

v1 · 2026-09-17 · ArchitectUX + UI Designer. Source of truth: `pamusha/research/property-facts.md`. Stack: static HTML/CSS/vanilla JS, no build, Vercel, Web3Forms.

## 1. Sitemap

| File | Nav label | Role |
|---|---|---|
| `index.html` | Home | Sell the stay, route to Airbnb, enquiries (`#enquire`) |
| `the-house.html` | The house | Rooms, bathrooms, kitchen, outdoors, gallery (`#gallery`), amenities |
| `explore.html` | Explore | Getting here, beach, lakes, day trips, eat & drink, seasons |
| `house-manual.html` | Guest guide | Post-booking manual; footer link only; `noindex` |
| `404.html` | — | Branded not-found |

Shared: `css/tokens.css`, `css/base.css`, `css/components.css`; `js/main.js` (nav, lightbox, form), `js/manual.js` (pills, search, copy). Header/footer pasted per page.

Decisions:
- **Gallery is a section.** ~25 photos is one scroll; a separate page divorces photos from the room copy that sells them. Home carries a 3-image teaser to `the-house.html#gallery`.
- **Enquire is a section** on Home; every nav links to `index.html#enquire`. A contact page is an extra hop with no extra content.
- **Guest guide is off the primary nav** (nav stays 3 links + CTA), footer-linked, sent by URL in the Airbnb check-in message. Owner should run a dedicated guest SSID since the password sits on a public URL.
- **Theme toggle** (light/dark/system, ArchitectUX default) sits in the footer on marketing pages and in the manual's sticky header, because the manual is read at night beside the hot tub.

## 2. Primary journeys

**(a) Deciding to book.** Entry: Google, Airbnb listing, Instagram. Screens: hero → fact strip → rooms → hot tub → reviews → gallery → Airbnb. Decision points: "Will 9 of us fit?" (fact strip, bed config on cards); "Really lakefront?" (hero, map); "Is the hot tub private?" (feature); "Dates and price?" (only Airbnb answers, so the primary CTA is one tap away on every screen). Success: click on any `[data-cta="airbnb"]` link (UTM-tagged) or an enquiry sent.

**(b) Arriving.** Entry: Airbnb message link, on a phone, maybe in the car on one bar of signal. Screens: manual header (call host) → Arrival card (open by default: address, directions, lockbox) → Wi-Fi card (tap-to-copy) → later Hot tub, Kitchen, Bins. Decision points: "Which card?" (sticky pills, search); "How do I find this again?" (save-to-home-screen hint, page < 150 KB). Success: on Wi-Fi within 60 s, no call to host.

**(c) What to do nearby.** Entry: manual "Local picks" card or Home teaser. Screens: Explore hero → category pills → place cards. Decision points: "How far? Kid-friendly? Whole day?" — every card carries distance/time, best-for tag, Directions link. Success: taps Directions or a venue link.

## 3. Page wireframes

Conventions: mobile (M) ≤ 767px single column, 16px gutters; tablet (T) 768–1023; desktop (D) ≥ 1024, 12-col grid, 1200px max / 720px prose; section padding 64px M / 96px D. Photo slot = `<picture>` with fixed aspect ratio.

### index.html

1. **Skip link + sticky nav** (§5). Transparent over hero, solid after 80px scroll.
2. **Hero** — prove "lakefront" at a glance. Photo slot 4:5 M / 16:9 D (deck and lake at dusk); eyebrow "The Honeysuckles · Gippsland Lakes"; H1 ≤ 8 words; sub ≤ 25 words; primary "Book on Airbnb" + secondary "Explore the house". M: text over gradient scrim, CTAs stacked full-width. D: text in left 6 cols, CTAs inline. No video or parallax; LCP element.
3. **Key-facts strip** — qualify in two seconds. Chips: Sleeps 9 · 4 bedrooms · 2 bathrooms · Wood-fired hot tub · Lake front (+ Walk to Ninety Mile Beach on D). M horizontal snap-scroll; D one centred row. Static.
4. **Story** — the name and the feeling. H2, ≤ 120 words ("Pamusha means 'at home' in Shona…"), one 4:5 portrait. M image then text; D 5/7 cols.
5. **Rooms & spaces showcase** — "will we fit?". H2; 4 room cards (Primary king + ensuite · Queen · Bunk sleeps 3 · Queen) + 2 space cards (Kitchen & living · Second living); ghost "See every room →". M snap-scroll cards 85vw; T 2 cols; D 3 cols. Card links to `the-house.html#<room>`.
6. **Hot tub & fire pit** — emotional close. H2, 60 words, hot tub at dusk 3:4 + fire pit 1:1, mini-facts (8-seater · wood-fired · beside Lake Reeve), stargazing line. M photos then text; D full-bleed dark band, 7/5 cols, offset images.
7. **Location & explore teaser** — H2, 40 words, self-hosted static map image with "Open in Maps" link, distance chips (Beach [TODO] min walk · Sale ~40 min · Melbourne ~3 h) [verify], 3 explore cards, secondary "Plan your days". M stacked; D map 6 / text 6.
8. **Reviews** — H2 with "10/10 Exceptional" badge, 2–3 testimonials (paraphrased until owner supplies verbatim [TODO]), link to Airbnb reviews. M stack; D 3 cols. No carousel.
9. **Enquiry (`#enquire`)** — H2 "Ask us anything", 20-word note ("Booking is on Airbnb; ask here about dates or groups"); fields name, email, check-in, check-out, guests, message; primary "Send enquiry", secondary "Book on Airbnb". M stacked; D form 7 / aside 5 (host photo, response time [TODO]). Behaviour §5.
10. **Footer** (§5).

### the-house.html

1. Nav.
2. **Page hero** — 21:9 photo, H1 "The house", 20-word sub, fact strip.
3. **At a glance** — definition list: Bedrooms 4 · Bathrooms 2 · Sleeps 9 (2+2+3+2) · Living areas 2 · Parking · Laundry · Wi-Fi. M 1 col; D 3 cols.
4. **Bedrooms** — anchored rows `#primary`, `#queen-one`, `#bunk`, `#queen-two`: 3:2 photo, H3, bed spec, two-line notes. M stacked; D 6/6 alternating.
5. **Bathrooms & kitchen** — two cards (bath 4:5, kitchen 3:2) with bullets from the fact sheet. D 2 cols.
6. **Outdoors** — five feature cards: hot tub, fire pit, deck, swings, garden. D 3 + 2.
7. **Gallery (`#gallery`)** — ~20 images, mixed 3:2/4:5/1:1, CSS grid `grid-auto-flow: dense`; M 2 cols, D 4. Tap opens native `<dialog>` lightbox: prev/next buttons, Esc closes, focus trapped and returned. No library.
8. **Amenities** — checklist grouped Kitchen / Comfort / Outdoors / Family; D 3 cols.
9. **CTA band** — "Ready for lake time?", primary Airbnb, ghost Enquire.
10. Footer.

### explore.html

1. Nav.
2. **Hero** — 21:9 beach photo, H1 "Lakes, beach, slow days".
3. **Getting here** — chips (Melbourne ~3 h · Sale ~40 min · Bairnsdale [TODO]) [verify], 60-word note, "Open in Maps".
4. **Category pills** — anchors Beach · Lakes · Day trips · Eat & drink · Seasons; sticky under nav.
5. **Ninety Mile Beach** — 3:2 photo, 80 words, tip chips [TODO]. D 6/6.
6. **Lake Reeve & Gippsland Lakes** — photo, 80 words, activity cards (paddling, birdwatching, fishing) [TODO confirm].
7. **Day trips** — 4–6 place cards: name, distance/time, best-for tag, 25 words, Directions link [TODO]. M 1; T 2; D 3 cols.
8. **Eat & drink** — same card shape, 4–6 entries [TODO].
9. **Seasons** — four small cards; D 4 cols.
10. **CTA band + Footer**.

### house-manual.html — §4.

## 4. House manual UX

Single column, 680px max, 17px body, no marketing imagery, transfer < 150 KB, `noindex`.

**Sticky header (56px):** "Pamusha · Guest guide", "Call host" (`tel:`), theme toggle. **Sticky pill row** beneath (horizontal snap-scroll; active pill via IntersectionObserver): Arrival · Wi-Fi · The house · Hot tub & fire pit · Kitchen · Bins & recycling · Wildlife & safety · Local picks · Emergency · Checkout.

**Search:** filters cards by title + body (toggles `hidden`), auto-expands matches, debounced 150 ms; empty state "No match — call [host]".

**Save hint:** dismissible banner: "Add this guide to your home screen: Share → Add to Home Screen" (iOS/Android copy by UA); dismissal in localStorage.

**Cards:** native `<details>`; Arrival and Wi-Fi `open` by default; inline SVG icon, H2, one-line summary visible when collapsed; URL hash opens the matching card. Fields:

1. **Arrival** — check-in [ASSUMED 3:00 pm]; street address [TODO]; Directions maps link [TODO]; parking [TODO]; lockbox location [TODO] and code [TODO] (tap-to-copy; note it changes per stay); door quirk [TODO]; front-door photo 3:2 [TODO]; host name + mobile (click-to-call) [TODO].
2. **Wi-Fi** — network name [TODO] (copy); password [TODO] (copy, monospace, 22px); coverage note [TODO]; mobile signal note [TODO].
3. **The house** — heating/cooling [TODO]; TV/streaming [TODO]; laundry [TODO]; water source (tank?) [TODO]; hot water [TODO]; fuse box [TODO]; spare linen [TODO]; quiet hours [ASSUMED 10 pm].
4. **Hot tub & fire pit** — lighting steps [ASSUMED]; heat time ~2–3 h [ASSUMED]; target temp [TODO]; wood location [TODO]; cover on when unused; no glass; supervise children; drain/refill rule [TODO]. Fire pit: extinguish before bed; check CFA Total Fire Ban (link cfa.vic.gov.au), no fires on TFB days [ASSUMED]; stargazing note.
5. **Kitchen** — gas cooktop lighting [TODO]; dishwasher tablets [TODO]; fridge ice/filtered water; coffee machine [TODO]; BBQ [TODO]; pantry basics [TODO].
6. **Bins & recycling** — bin colours and contents [TODO]; collection day [TODO]; where to wheel them [TODO]; "out the night before".
7. **Wildlife & safety** — snakes (paths, doors closed, snake catcher [TODO]); no feeding wildlife; kangaroos on the road at dusk; lake edge and kids; UV; first-aid kit [TODO]; extinguisher/fire blanket [TODO]; smoke alarms.
8. **Local picks** — 5–8 favourites (name, line, distance, link) [TODO]; "Full guide →" `explore.html`.
9. **Emergency** — 000 (large click-to-call); Central Gippsland Health, Sale ~40 min [verify] (call + directions); Nurse-on-Call 1300 60 60 24; Poisons 13 11 26; SES 132 500; VicEmergency app; address restated for 000; host mobile.
10. **Checkout** — time [ASSUMED 10:00 am]; checklist with checkboxes persisted in localStorage (dishes, bins, hot tub cover, fire out, windows locked, heating off, key in lockbox); late-checkout policy [TODO]; "Review on Airbnb" link.

**Interactions:** copy buttons use `navigator.clipboard` with select-text fallback, 1.5 s "Copied", `aria-live="polite"`. Numbers are `tel:` links with digits visible. Pills `scrollIntoView`, instant under reduced motion.

## 5. Component inventory

Tokens: 4px spacing scale (4–96), type scale 14/16/18/22/28/36/48/64, radius 4/12/999, motion 150/250 ms (0 and no transforms under `prefers-reduced-motion: reduce`). Focus: 2px accent ring, 2px offset, `:focus-visible` everywhere. Touch targets ≥ 44px.

| Component | Spec | States |
|---|---|---|
| Nav | Logo; The house · Explore · Enquire; primary "Book on Airbnb" (external icon, `rel="noopener"`). D inline; M hamburger → `<dialog>` overlay | Transparent → solid after 80px; `aria-current="page"` underlined; hover underline grows; overlay traps focus, Esc closes |
| Button primary | Filled accent, 48px, 16px text | Hover darken 8% + 1px lift; active no lift; disabled 50%; loading spinner + `aria-busy` |
| Button secondary | 1px outline | Hover 8% tint |
| Button ghost | Text + arrow | Hover arrow +4px |
| Fact chip | Pill, 1px border, icon + text, non-interactive | Snap in strip |
| Feature card | 3:2 or 4:5 image, eyebrow, H3, ≤ 40 words | Hover image scale 1.03 in clipped frame; one stretched `<a>` |
| Room card | 3:2 image, name, bed line, "Sleeps n" chip | As feature card; focus ring on card |
| Image frame | `aspect-ratio` per slot (hero 16:9 D / 4:5 M, page hero 21:9, cards 3:2, portrait 4:5, gallery 1:1); `object-fit: cover`; `width`/`height`; AVIF/WebP/JPEG `<picture>` + `sizes` | Placeholder tint |
| Accordion | `<details>/<summary>`, summary 56px, chevron rotates 180° | Open/closed; focus ring; multiple open |
| Pill tabs | Anchor links, 40px, sticky `top: 56px` | Default / hover tint / active filled `aria-current="true"` / focus |
| Testimonial | Quote glyph, ≤ 60 words, name + month, source | None |
| Form field | Label above, 48px input, helper, error via `aria-describedby` + `aria-invalid` | Default / focus / error (border + text) / disabled |
| Form | Validate on blur + submit (required, email, check-out after check-in, guests 1–9); honeypot `botcheck`; JSON POST to `api.web3forms.com/submit` with `access_key` const in `js/main.js` (as `geo-engine/web/index.html`) | Loading → success panel replaces form (`role="status"`, "Thanks [name], we reply within [TODO] hours", Airbnb CTA) / failure: inline error + `mailto:` fallback |
| Copy button | 44px icon button beside value | Default / hover / "Copied" 1.5 s |
| Theme toggle | Radiogroup light/dark/system; localStorage; inline `<head>` script sets `data-theme` pre-paint | Active option filled |
| Footer | D 3 cols: brand + 20 words; links (The house, Explore, Guest guide, Enquire, Airbnb); contact [TODO] + toggle. M 1 col. © + Gunaikurnai Country acknowledgement [confirm wording] | Hover underline |

## 6. Accessibility & performance checklist

- WCAG 2.2 AA: 4.5:1 text, 3:1 large text/UI; hero text on scrim measured; targets 44px; `scroll-padding-top` so sticky bars never hide focus; no drag-only interaction.
- Structure: one H1 per page; `header/nav/main/footer` landmarks; `aria-label` on both navs; skip link first in DOM, visible on focus; tab order = visual order; `lang="en-AU"`.
- Alt policy: descriptive alt on every content photo ("Wood-fired hot tub beside Lake Reeve at dusk"); `alt=""` for decorative/repeated; gallery alts per photo [TODO].
- Motion: all transitions/transforms inside `@media (prefers-reduced-motion: no-preference)`; smooth scroll likewise.
- Forms: visible labels; errors as text, not colour alone; success in a live region.
- Images: `loading="lazy"` + `decoding="async"` below fold; hero `fetchpriority="high"` + preload; explicit dimensions everywhere (CLS 0); ≤ 1600px, AVIF/WebP, ≤ 200 KB each.
- Fonts: two families max (display serif + text sans), self-hosted subset WOFF2, `font-display: swap` with `size-adjust` fallback metrics; preload display font only.
- Code: CSS ≤ 40 KB, JS ≤ 15 KB, `defer`, no frameworks.
- Vercel: immutable cache for `/img /css /js` (versioned filenames), short cache for HTML.
- Targets (Lighthouse mobile): Performance ≥ 95, Accessibility 100, Best Practices 100, SEO ≥ 95; LCP < 2.0 s, CLS < 0.02, INP < 200 ms; manual usable on 3G.
- SEO: unique title/description per page, OpenGraph hero, `LodgingBusiness` JSON-LD on Home (locality only), canonicals, `sitemap.xml`, `robots.txt` disallowing the manual.
