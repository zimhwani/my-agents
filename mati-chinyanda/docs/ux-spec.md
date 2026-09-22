# Mati Chinyanda — UX Specification

**Prepared by:** Design strategy team (UX Architect lead · UI Designer · Brand Guardian) — 2026-09-22
**Stack:** static HTML/CSS/vanilla JS, no framework, no build step required (optional: a tiny script to minify). Tokens from `brand-system.md`.
**Primary conversion:** enquiry submitted on `/book` (or the home enquiry section). **Secondary:** reel watched, speaker kit downloaded, podcast play.

---

## 1. Sitemap

```
/                      Home (long-form landing; every pillar summarised, enquiry form at end)
/speaking/             Speaking & MC — talks, hosting formats, reel, testimonials, logistics
/podcast/              What Left The Group Chat — about, latest episodes, platforms, guest enquiries
/freeka-runway/        FreekÀ Runway & Event Production — story, gallery, production services, case studies
/about/                Bio (3 lengths), story, values, press, downloadable kit
/book/                 Booking / enquiry form (canonical CTA target)
/404.html              "That left the group chat."
/speaker-kit.pdf       Downloadable one-sheet (bio lengths, headshots, topics, AV rider)
/sitemap.xml  /robots.txt  /manifest.webmanifest  /favicon.svg
```
File structure:
```
/index.html  /speaking/index.html  /podcast/index.html  /freeka-runway/index.html  /about/index.html  /book/index.html  /404.html
/css/design-system.css  /css/layout.css  /css/components.css  /css/utilities.css  /css/main.css
/js/theme-manager.js  /js/main.js (nav, reveal, marquee, accordion, lightbox, form)
/assets/img/  /assets/video/  /assets/fonts/  /assets/logos/
```
Navigation (global, max 5 + CTA): **Speaking · Podcast · FreekÀ Runway · About · [Book Mati]**. Logo/wordmark left, theme toggle in the footer and inside the mobile menu (kept out of the desktop header to preserve the luxe silhouette; still "always accessible").

---

## 2. Information hierarchy and user flows

**Primary persona:** event/conference producer or brand marketing manager (Melbourne/Sydney, often on mobile), evaluating 3–5 hosts. Needs in <60 seconds: what she does, proof she's done it at scale, what she's like on stage (reel), how to book.
**Secondary persona:** community/fashion organiser seeking a producer or creative director.
**Tertiary:** podcast listener / press.

Flow A (booker): Home hero → marquee proof → reel → talks → testimonials → **Book**. Every section end has a contextual CTA to `/book`.
Flow B (producer client): Home pillars → `/freeka-runway/` gallery → services → **Produce with Mati** → `/book/?type=production` (pre-selects event type).
Flow C (listener): Home podcast block → `/podcast/` → platform buttons (external).

Hierarchy rule: one H1 per page; H2 per section with an uppercase gold eyebrow above it; body limited to 68ch; CTAs appear at hero, after proof, and at page end. Sticky header shows **Book Mati** on all pages after 200px scroll.

---

## 3. Page-by-page section spec

### 3.1 Home `/`
| # | Section | Content & layout | CTA(s) |
|---|---|---|---|
| 0 | Skip link + header | `<a class="skip" href="#main">Skip to content</a>`; header transparent over hero, becomes ink-950 with hairline on scroll | Book Mati (pill) |
| 1 | **Hero** (dark, full-viewport min 88svh) | 12-col grid: left 6 cols — eyebrow "Speaker · MC & Event Host · Founder, FreekÀ Runway", H1 `Mati Chinyanda` (`--text-hero`, line reveal), tagline "Bring the room to life." in Fraunces italic, 1-sentence lead; right 6 cols — portrait bleeding off right edge, grain overlay. Mobile: portrait first (4:5, 60svh), text below. | Primary **Book Mati** → `/book/`; secondary **Watch the reel** (opens video modal, `aria-haspopup="dialog"`) |
| 2 | **Marquee** "As seen at · Trusted by" | Single row of 8–14 monochrome logos/venue names (fallback: text names in Fraunces if logos unavailable). Pauses on hover/focus; static wrapped grid under reduced motion. | — |
| 3 | **About intro** (light) | 5/12 text: eyebrow "Meet Mati", H2 "Warm on the mic, sharp on the run-sheet." 2 short paragraphs; 7/12 secondary portrait offset by one column. | Text link **More about Mati** → `/about/` |
| 4 | **Three pillars** | 3 cards (1 col mobile, 3 col ≥768): image 4:5, H3, 2-line description, arrow link. Cards: Speaking & MC → `/speaking/`; What Left The Group Chat → `/podcast/`; FreekÀ Runway & Events → `/freeka-runway/`. | Card links |
| 5 | **Signature talks / topics** | Eyebrow "Signature talks & hosting formats", H2; 4 topic cards in 2×2 (1 col mobile): title (Fraunces), one-line promise, "Best for: conferences / award nights / panels" meta, expand accordion for 3 takeaways. | **Book this talk** on each card → `/book/?topic=<slug>`; section CTA **See all speaking** |
| 6 | **Showreel** (dark) | 16:9 video block, poster image, pill play; opens inline (not autoplay). Below: three 20-second "moments" thumbnails (optional phase 2). Hosted on YouTube/Vimeo via facade (lite-embed) to protect performance. | **Book Mati** (secondary pill on dark) |
| 7 | **Testimonials** | Carousel-free: 3 pull-quotes in a 3-col grid (stack on mobile), Fraunces italic quote, name, role, organisation, optional logo. | — |
| 8 | **Stats row** | 4 numerals: Events hosted · Podcast episodes · Runway shows produced · Cities/Countries (values TBC with client; never fabricate). Count-up animation on reveal (disabled under reduced motion). | — |
| 9 | **Podcast latest** (forest-700) | Left: cover art 1:1, show title, one-liner, co-host credit; right: 3 latest episodes (title, date, duration, play → platform link). Static JSON `/data/episodes.json` fetched by JS; server-side fallback = hard-coded 3 in HTML. | **Listen to the latest** · platform buttons |
| 10 | **FreekÀ Runway gallery** | Eyebrow "FreekÀ Runway", H2 "A runway for the creatives Melbourne hasn't met yet.", 6-image editorial masonry (2 col mobile, 3–4 col desktop), lightbox on click. | **Explore FreekÀ** → `/freeka-runway/`; **Produce with Mati** |
| 11 | **Press & features** | Logo/name strip + 3 feature cards (outlet, headline, date, external arrow). | — |
| 12 | **Enquiry section** | Same form as `/book/` (shared partial), 2-col: left copy "Tell me about the room." + response promise + direct email; right form. | **Send enquiry** |
| 13 | **Footer** (dark) | Big-type CTA "Got a room that needs *energy*?" + Book Mati; nav columns (Pages / Ventures / Connect), socials, email, Melbourne/Naarm acknowledgement of Country line, theme toggle, © and privacy link. | Book Mati |

### 3.2 Speaking `/speaking/`
1. Hero (dark, 60svh): eyebrow "Speaking & MC", H1 "Keynotes and hosting with real energy.", lead, portrait on stage. CTAs Book Mati / Watch the reel.
2. Formats grid: Keynote · MC / Event Host · Panel Moderation · Fireside / Interview · Awards Night · Workshop facilitation — each with duration, audience size, virtual/in-person tags.
3. Signature talks (full detail): 4–6 cards, accordion for abstract, audience takeaways, formats (20/45/60 min).
4. Showreel + 3 clips.
5. Testimonials (6) + client logo wall.
6. Past stages (list/timeline: event, city, year) — Sorensen-style proof.
7. Planner logistics accordion: travel base (Melbourne), AV/tech rider, headshots & bio → speaker kit download, fees "on enquiry, budget ranges on the form".
8. CTA band → `/book/`.

### 3.3 Podcast `/podcast/`
1. Hero (forest-700): cover art, title, "Three women. One group chat. No filter.", co-hosts named with roles/heritage per their consent, platform buttons.
2. About the show (topics: life in Australia, ambition, womanhood, culture/identity).
3. Episodes list (latest 8 from `/data/episodes.json`; "Load more"), each with platform link and optional embedded player (lazy).
4. Guest/partnership enquiry: short text + **Start a conversation** → `/book/?type=podcast`.
5. Social/community strip (Instagram embed as static images, no third-party script).

### 3.4 FreekÀ Runway & Event Production `/freeka-runway/`
1. Hero (dark): H1 "FreekÀ Runway", tagline "Express : Your : Self", founding story line (co-founded, Melbourne, multicultural runway platform).
2. Manifesto paragraph + 3 value cards (Platform emerging creatives / Fashion, dance, art, music / Community first).
3. Gallery: 12–24 images, filter chips by year/show (vanilla JS, `aria-pressed`), lightbox with captions crediting designers/photographers.
4. Event production services: Creative direction · Runway production · Casting & talent · Show calling / stage management · Brand activations. Each a card with 2-line scope.
5. Case studies (2–3): image, challenge, role, outcome, credits.
6. Testimonials from designers/partners.
7. CTA band **Produce with Mati** → `/book/?type=production`.

### 3.5 About `/about/`
1. Hero (light, editorial): oversized H1 "Mati", portrait 4:5 offset, eyebrow.
2. Story (long-form, `--container-narrow`, 68ch, Fraunces pull-quotes): heritage, Melbourne, FashionOne era, founding FreekÀ, the podcast, what she's like on stage.
3. Values / "how I work" — 3 items.
4. Bio in three lengths (copyable): 25 words, 75 words, 200 words; each with a **Copy** button (clipboard API, "Copied" live-region confirmation).
5. Press & features (full list).
6. Speaker kit download + headshot pack link.
7. CTA band → `/book/`.

### 3.6 Book `/book/`
1. Compact hero: H1 "Let's make it happen.", reassurance: "Reply within two business days. Melbourne-based, travels Australia-wide and internationally."
2. Form (see §4), 2-col ≥1024 (left: what to expect, direct email `hello@…`, speaker kit link; right: form).
3. FAQ accordion: fees, travel, virtual events, lead time, AV needs.

### 3.7 404
Dark page, Fraunces H1 "That left the group chat.", link home, link to Book.

---

## 4. Booking form — fields, validation, behaviour

Static site: submit via a form backend (Formspree / Netlify Forms / Basin — `action` URL configurable in one place) with JS-enhanced inline validation and a no-JS fallback (native `required`, server redirect to `/book/thanks/` or an inline success message).

| Field | Type | Required | Validation / notes |
|---|---|---|---|
| Full name | text, `autocomplete="name"` | yes | 2–80 chars |
| Email | email, `autocomplete="email"` | yes | RFC-ish pattern; error "Add an email so I can reply to you." |
| Organisation | text, `autocomplete="organization"` | no | |
| Phone | tel, `autocomplete="tel"` | no | AU/intl free format, 8–20 chars |
| Enquiry type | select | yes | Speaking / keynote · MC / event host · Panel or fireside · Event production / creative direction · Podcast guest or partnership · Other. Pre-filled from `?type=` param |
| Event name | text | no | |
| Event date | date (+ "Date TBC" checkbox that disables the input) | yes unless TBC | Must be ≥ today; warn (not block) if < 21 days |
| Location | text + radio: In person / Virtual / Hybrid | yes | City/venue; radio required |
| Audience size | select | no | <50 · 50–200 · 200–500 · 500–1000 · 1000+ |
| Budget range (AUD) | select | no (strongly encouraged, helper text "helps me tailor the proposal") | <$2k · $2–5k · $5–10k · $10–20k · $20k+ · Not sure yet |
| Message | textarea | yes | 20–2000 chars, live counter, placeholder "Tell me about the room, the audience and the vibe you're after." |
| How did you hear about Mati? | select | no | |
| Consent | checkbox | yes | "I'm happy for Mati to contact me about this enquiry." Link to privacy |
| Honeypot | hidden text `website` | — | Reject if filled; plus timestamp check (>3s) |

Behaviour: labels always visible (no placeholder-only), errors inline below field with `aria-describedby` and `aria-invalid`, summary at top on submit with links to fields, first invalid field focused. Submit button shows "Sending…" with `aria-busy`; success replaces the form with a confirmation (`role="status"`) and offers the speaker kit. Analytics event `enquiry_submitted` with type only (no PII).

---

## 5. Mobile behaviour

- Mobile-first; breakpoints 480 / 768 / 1024 / 1280 / 1600. Gutter 16px at phone width; no horizontal scroll (test at 320px).
- Header: wordmark + **Book** pill + hamburger. Menu is a full-screen ink-950 overlay `<dialog>`-style panel: large Fraunces links, socials, theme toggle; focus trapped, `Esc` closes, body scroll locked.
- Hero: portrait first, 60svh, then text; hero name wraps to two lines at ≤480px (`--text-hero` clamps to 56px).
- Marquee speed halves on mobile; sticky CTA bar (Book Mati) appears at bottom on mobile after scrolling past the hero, hidden when the form is in view.
- Cards stack; galleries 2-col; testimonials stack; stats 2×2.
- Video opens inline (no modal) on mobile; lightbox supports swipe and pinch (native), close button 44px.
- Touch targets ≥ 44×44px; form inputs 48px tall, 16px font (prevents iOS zoom).

---

## 6. Accessibility requirements (WCAG 2.1 AA)

- Skip link first in DOM, visible on focus. Landmarks: `header`, `nav[aria-label="Primary"]`, `main#main`, `footer`; one `h1` per page; heading levels never skip.
- Focus: `:focus-visible` 2px `--focus` outline + 3px offset on every interactive element; never `outline: none` without replacement.
- Contrast per brand-system table; gold-500 never as small text on ivory.
- Reduced motion: `prefers-reduced-motion` disables reveals, count-ups, marquee (becomes static grid), hero scale, video autoplay.
- Alt text: descriptive for portraits and gallery (credit designer where relevant); `alt=""` for decorative textures; logos "Logo: <org>".
- Marquee: content duplicated once with `aria-hidden="true"`; pause on hover/focus; `role="region" aria-label="Clients and appearances"`.
- Accordion: `<button aria-expanded aria-controls>` inside `h3`; content `hidden` toggled; arrow keys optional.
- Lightbox: `role="dialog" aria-modal="true"`, labelled by caption, focus trap, `Esc`/close, returns focus to trigger, arrow keys navigate.
- Video: poster, visible controls, captions (`<track kind="captions">`) for self-hosted; YouTube facade with title attribute.
- Forms: per §4; `autocomplete` attributes; error text not colour-only (icon + text).
- Theme toggle: `role="radiogroup"` with three radios; persists in `localStorage` (try/catch).
- Language: `<html lang="en-AU">`. Text resizes to 200% without loss; no fixed heights on text containers.
- Keyboard: full site operable; visible order matches DOM order; sticky header does not obscure focused elements (`scroll-padding-top`).

---

## 7. SEO

Global: canonical URLs with trailing slash, `robots.txt`, `sitemap.xml`, `theme-color` meta (`#0B0A0A`), OG image 1200×630 per page (portrait crop with name overlay), Twitter `summary_large_image`, favicon SVG + 180px apple-touch-icon, `manifest.webmanifest`.

| Page | `<title>` (≤60) | Meta description (≤155) |
|---|---|---|
| / | Mati Chinyanda — Speaker, MC & Event Host, Melbourne | Book Mati Chinyanda: keynote speaker, MC and event host, co-host of What Left The Group Chat and founder of FreekÀ Runway. Joyful, editorial, culturally rooted. |
| /speaking/ | Speaking & MC — Mati Chinyanda | Keynotes, panel moderation and event hosting with real energy. Signature talks, showreel, testimonials and booking for conferences and award nights. |
| /podcast/ | What Left The Group Chat — Podcast co-hosted by Mati Chinyanda | Three Black women on life in Australia, ambition, womanhood and culture. Latest episodes and where to listen. |
| /freeka-runway/ | FreekÀ Runway & Event Production — Mati Chinyanda | Melbourne's multicultural runway platform for emerging creatives, plus creative direction and production for fashion and cultural events. |
| /about/ | About Mati Chinyanda | Zimbabwean-born, Melbourne-based speaker, host and producer. Story, bios in three lengths, press and speaker kit. |
| /book/ | Book Mati Chinyanda — Speaking, MC & Event Enquiries | Enquire to book Mati as a speaker, MC or event producer. Replies within two business days. |

JSON-LD on every page (site-wide `Person` + page `WebPage`; `PodcastSeries` on /podcast; `Organization` for FreekÀ on /freeka-runway; `BreadcrumbList` on subpages):
```json
{
  "@context": "https://schema.org",
  "@type": "Person",
  "name": "Mati Chinyanda",
  "url": "https://www.matichinyanda.com/",
  "image": "https://www.matichinyanda.com/assets/img/mati-portrait-1200.jpg",
  "jobTitle": ["Speaker", "MC & Event Host", "Podcast Host", "Event Producer"],
  "description": "Melbourne-based speaker, MC and event host; co-host of What Left The Group Chat; founder of FreekÀ Runway.",
  "address": { "@type": "PostalAddress", "addressLocality": "Melbourne", "addressRegion": "VIC", "addressCountry": "AU" },
  "nationality": "Zimbabwean",
  "knowsAbout": ["Event hosting", "Public speaking", "Fashion runway production", "Podcasting", "Culture and identity"],
  "founder": { "@type": "Organization", "name": "FreekÀ Runway", "url": "http://freekarunway.com/" },
  "sameAs": ["https://www.instagram.com/…", "https://www.linkedin.com/in/…", "https://podcasts.apple.com/…/id1847614435", "https://open.spotify.com/show/…"]
}
```
Verify all facts (nationality wording, URLs, handles) with the client before publishing; see `research-brief.md` for confidence labels. Drop the `founder.url` if freekarunway.com remains offline.

---

## 8. Performance budgets

| Metric | Budget |
|---|---|
| LCP (hero portrait, mobile 4G) | ≤ 2.5s |
| CLS | ≤ 0.05 (fonts with `size-adjust`, images with `width/height`) |
| INP | ≤ 200ms |
| Total transfer, home (first view) | ≤ 1.2 MB (hero image ≤ 180 KB AVIF/WebP, fonts ≤ 120 KB total for 2 variable files, CSS ≤ 40 KB, JS ≤ 25 KB) |
| Requests, home | ≤ 30 |
| Third-party scripts | 0 on load (video via facade, podcast via static JSON, analytics deferred/consented) |
| Lighthouse (mobile) | Performance ≥ 90, Accessibility 100, Best Practices ≥ 95, SEO 100 |
Techniques: preload hero image and the two font files, critical CSS inline (≤ 10 KB), `content-visibility: auto` on below-fold sections, lazy images with `srcset`/`sizes`, `loading="lazy"` iframes, no CSS framework, no JS libraries.

---

## 9. Component inventory

| Component | Variants / states | Notes |
|---|---|---|
| **Header / nav** | transparent → solid on scroll; mobile overlay menu | Sticky; logo, 4 links, Book pill; `aria-current="page"` |
| **Button** | primary (ink on light / gold on dark), secondary (outline pill), tertiary (text + arrow), sizes md/lg; hover, focus, active, loading, disabled | Pill radius, uppercase Figtree 600, min 44px |
| **Eyebrow + heading** | light/dark | Gold uppercase eyebrow, Fraunces H2 |
| **Marquee** | logos / text; paused; reduced-motion grid | Duplicate `aria-hidden` |
| **Pillar card** | image 4:5, title, text, arrow | Whole card clickable via pseudo-element |
| **Topic card** | with accordion abstract; "Book this talk" | Grid 2×2 |
| **Video block / facade** | poster + play; inline; modal on desktop | YouTube/Vimeo lite embed |
| **Testimonial** | quote / quote+logo / quote+headshot | Fraunces italic |
| **Stat** | numeral + label; count-up | tabular nums |
| **Episode row** | title, date, duration, platform play | From JSON |
| **Gallery + lightbox** | masonry 2/3/4 col; filter chips; dialog with prev/next, caption | Focus trap |
| **Press card / logo strip** | monochrome, hover colour optional | |
| **Accordion** | FAQ, talk details, logistics | `aria-expanded` button |
| **Form** | inputs, select, textarea, radio group, checkbox, error, success, honeypot | Labels always visible |
| **CTA band** | dark / forest; big type + button | Page ends |
| **Footer** | with big-type CTA, columns, socials, theme toggle | Acknowledgement of Country |
| **Theme toggle** | light / dark / system radiogroup | `theme-manager.js`, localStorage try/catch |
| **Skip link, visually-hidden, container, grid, section** | utilities | `layout.css` / `utilities.css` |

---

## 10. Implementation priority

1. `design-system.css` tokens + theme manager → 2. layout/grid + header/footer + skip link → 3. Home hero, marquee, pillars → 4. shared form partial + `/book/` → 5. `/speaking/` (highest-value subpage) → 6. testimonials, stats, showreel → 7. `/freeka-runway/` gallery + lightbox → 8. `/podcast/` + JSON → 9. `/about/` + speaker kit → 10. SEO/JSON-LD, OG images, Lighthouse pass.

Open items for the client: verified stats, client/venue logos with permission, testimonials with names, showreel link, episode feed URL, social handles, headshot pack, speaker kit PDF, preferred email/form backend, acknowledgement of Country wording.
