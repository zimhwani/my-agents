# Mati Chinyanda — Brand System

**Prepared by:** Design strategy team (Brand Guardian · UI Designer · UX Architect) — 2026-09-22
**Inputs:** `competitive-research.md`, `research-brief.md` (fact confidence).
**Scope:** personal-brand website (static HTML/CSS/vanilla JS). Tokens below are the single source of truth for `css/design-system.css`.

---

## 1. Brand strategy

### Brand essence
**"The room changes when Mati walks in."**
Mati is the warm centre of gravity in any space — a host who makes a ballroom feel like a living room, a speaker who makes culture and ambition feel like one conversation, and a producer who puts emerging creatives on a runway.

### Purpose · Vision · Mission
- **Purpose:** to make people feel seen, celebrated and switched-on — on stage, on mic and on the runway.
- **Vision:** the go-to Black woman host and cultural producer in Australia for brands and organisations that want their events to feel alive.
- **Mission:** hosting, speaking and producing events that are joyful, editorial and culturally rooted, for corporate, community and fashion audiences.

### Three personality words
1. **Magnetic** — presence you cannot look away from; big laugh, bigger warmth.
2. **Editorial** — high-fashion polish, considered composition, nothing accidental.
3. **Rooted** — Zimbabwean heritage, Melbourne community, the group chat; culture is the source, not the garnish.

### Brand values (behavioural)
- **Joy is professional.** Warmth and rigour are not opposites; every touchpoint should feel both.
- **Platform others.** FreekÀ Runway exists to put emerging creatives on stage. The site gives credit generously.
- **Say the real thing.** Group-chat honesty — direct, human, no corporate filler.

### Positioning statement
For event organisers, brands and conference producers who want more than a competent MC, Mati Chinyanda is the speaker, host and creative producer whose energy is joyful, editorial and culturally rooted — because she has built the rooms herself (FreekÀ Runway, *What Left The Group Chat*), not just walked into them.

### Brand pillars (mirror the site IA)
1. **Speaking & MC** — keynotes, panel moderation, hosting, award nights, conferences.
2. **Podcast** — *What Left The Group Chat*: three Black women on life in Australia, ambition, womanhood, culture.
3. **FreekÀ Runway & Event Production** — creative direction and production of runway shows and cultural events.

### Brand protection notes
- Word marks to consider registering (AU, class 41): **MATI CHINYANDA**, **FREEKÀ RUNWAY**, **WHAT LEFT THE GROUP CHAT**. Check existing FreekÀ/podcast co-founder ownership before filing.
- Always spell **FreekÀ** with the grave-accented À in display type; `Freeka` only in URLs/slugs (`/freeka-runway`).
- Podcast co-hosts are credited by name wherever the podcast appears; never present it as Mati-only.
- Photography of runway talent requires model/designer release; credit designers in captions.

---

## 2. Colour system

### Rationale
Luxe editorial = a near-black warm ink, a warm ivory (not clinical white), and **burnished gold** as the single accent — it echoes her gold nose ring, warms dark skin tones, and sits harmoniously against foliage green. A deep **forest green** secondary is drawn straight from the reference photo's plants and is reserved for large surfaces (section backgrounds, the podcast block), never for small text. Colour otherwise lives in photography.

### Palette (hex)

**Ink neutrals (warm)**
| Token | Hex | Use |
|---|---|---|
| `--ink-950` | `#0B0A0A` | Primary dark background, primary text on light |
| `--ink-900` | `#141212` | Dark cards / nav on dark |
| `--ink-800` | `#221F1E` | Dark elevated surfaces, borders on dark |
| `--ink-700` | `#3A3634` | Secondary text on light (AAA) |
| `--ink-600` | `#5A5451` | Muted text on light (AA 6.5:1) |
| `--ink-500` | `#7A736F` | Large-text-only muted (4.07:1 — captions ≥ 24px or decorative) |
| `--ink-400` | `#9B938E` | Muted text on dark (AA 6.55:1) |
| `--ink-300` | `#BDB5AE` | Secondary text on dark (AAA 9.78:1), rules on dark |
| `--ink-200` | `#DDD5CC` | Borders on light |

**Ivory neutrals**
| Token | Hex | Use |
|---|---|---|
| `--ivory-100` | `#EDE6DB` | Light alt-section background |
| `--ivory-50` | `#F5EFE6` | Primary light background |
| `--ivory-0` | `#FBF8F3` | Light cards, form fields |

**Gold accent (primary brand accent)**
| Token | Hex | Use |
|---|---|---|
| `--gold-300` | `#E3C77E` | Highlight/hover on dark (AAA 11.99:1) |
| `--gold-400` | `#D4AE5A` | Accent text and rules on dark (AAA 9.42:1) |
| `--gold-500` | `#C39A3E` | **Hero accent** — buttons on dark (ink text 7.54:1), large display words, marquee |
| `--gold-600` | `#9C7A2B` | Accent rules/icons on light (3.51:1 — non-text only) |
| `--gold-700` | `#7A5D1C` | Accent text/links on light (AA 5.39:1) |
| `--gold-800` | `#5E4712` | Accent text on light, AAA (7.70:1) |

**Forest secondary**
| Token | Hex | Use |
|---|---|---|
| `--forest-800` | `#12281E` | Deep green section background |
| `--forest-700` | `#1B3A2C` | Podcast/FreekÀ block background (ivory text 10.88:1, gold-300 7.54:1) |
| `--forest-600` | `#24503C` | Hover on forest surfaces |
| `--forest-500` | `#2E6B4E` | Green text on light (AA 5.52:1) |
| `--forest-300` | `#8FBFA3` | Green text on forest-800 (AAA 7.53:1) |

**Semantic**
| Token | Light | Dark | Ratio |
|---|---|---|---|
| `--success` | `#276B43` | `#8FD1A8` | 5.62 / 11.16 |
| `--warning` | `#8A5A00` | `#F0C060` | 5.19 / 11.69 |
| `--error` | `#B3261E` | `#F2A39C` | 5.72 / 9.88 |
| `--info` | `--forest-500` | `--forest-300` | — |

### Semantic tokens (light = default, dark = hero/footer/podcast)
```css
:root {
  --bg: var(--ivory-50);
  --bg-alt: var(--ivory-100);
  --surface: var(--ivory-0);
  --text: var(--ink-950);
  --text-2: var(--ink-700);
  --text-muted: var(--ink-600);
  --accent: var(--gold-500);        /* fills, large display */
  --accent-text: var(--gold-700);   /* links, small accent text */
  --accent-strong: var(--gold-800);
  --line: var(--ink-200);
  --line-strong: var(--ink-950);
  --focus: var(--gold-700);
  --btn-bg: var(--ink-950); --btn-fg: var(--ivory-50);
}
[data-theme="dark"], .theme-dark {
  --bg: var(--ink-950);
  --bg-alt: var(--ink-900);
  --surface: var(--ink-800);
  --text: var(--ivory-50);
  --text-2: var(--ink-300);
  --text-muted: var(--ink-400);
  --accent: var(--gold-500);
  --accent-text: var(--gold-400);
  --accent-strong: var(--gold-300);
  --line: var(--ink-800);
  --line-strong: var(--ivory-50);
  --focus: var(--gold-400);
  --btn-bg: var(--gold-500); --btn-fg: var(--ink-950);
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { /* same as dark block */ } }
```
The site ships a **light/dark/system toggle** (UX Architect default). Editorial sections (hero, podcast, footer) are always dark via `.theme-dark` regardless of global theme; the toggle affects content sections.

### Verified contrast (WCAG 2.1 AA, computed)
| Foreground on background | Ratio | Result |
|---|---|---|
| ivory-50 on ink-950 | 17.30 | AAA |
| ink-950 on ivory-50 | 17.30 | AAA |
| ink-600 on ivory-50 | 6.51 | AA |
| ink-400 on ink-950 | 6.55 | AA |
| gold-700 on ivory-50 | 5.39 | AA (accent text on light) |
| gold-400 on ink-950 | 9.42 | AAA (accent text on dark) |
| ink-950 on gold-500 (button) | 7.54 | AAA |
| ivory-50 on forest-700 | 10.88 | AAA |
| gold-300 on forest-700 | 7.54 | AAA |
| ivory-50 on gold-700 (light-mode gold button) | 5.39 | AA |
| **Do not use:** gold-500 text on ivory-50 | 2.29 | FAIL — fills/large decorative only |

Rule: gold-500 is never used for text on light backgrounds; use gold-700/800. ink-500 is never used for body text.

---

## 3. Typography

### Pairing (Google Fonts)
- **Display / headings: Fraunces** — variable, optical sizes 9–144, `wght` 300–900, `opsz`, plus the `SOFT` and `WONK` axes. At 96px+ with `opsz` 144 and `SOFT` 30 it has the high-contrast, slightly wonky warmth that reads "editorial with a laugh" — Mati, not a law firm. Italic used for emphasis words ("*joy*", "*the room*").
- **Body / UI: Figtree** — friendly geometric-humanist sans, tight and even at 16–18px, excellent numerals for stats, weights 300–900. Figtree + Fraunces is a documented premium pairing ("warm, contemporary, human voice").
- **Alternative if Fraunces feels too playful in review:** Instrument Serif (display) + Figtree. Keep sizes identical.

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght,SOFT,WONK@0,9..144,300..700,0..100,0..1;1,9..144,300..700,0..100,0..1&family=Figtree:ital,wght@0,300..800;1,300..800&display=swap" rel="stylesheet">
```
Self-host the two `woff2` files in production (`/assets/fonts/`) with `font-display: swap` and `size-adjust` fallbacks (`Georgia` for Fraunces, `system-ui` for Figtree) to limit CLS.

### Tokens
```css
:root {
  --font-display: "Fraunces", Georgia, "Times New Roman", serif;
  --font-body: "Figtree", system-ui, -apple-system, "Segoe UI", sans-serif;

  /* fluid scale, ratio ~1.25 at 360px → ~1.333 at 1440px */
  --text-xs:   0.75rem;                                   /* 12  eyebrow, legal */
  --text-sm:   0.875rem;                                  /* 14  captions, meta */
  --text-base: clamp(1rem, 0.95rem + 0.25vw, 1.125rem);   /* 16→18 body */
  --text-lg:   clamp(1.125rem, 1rem + 0.5vw, 1.375rem);   /* 18→22 lead */
  --text-xl:   clamp(1.375rem, 1.2rem + 0.9vw, 1.75rem);  /* 22→28 h4 */
  --text-2xl:  clamp(1.75rem, 1.4rem + 1.6vw, 2.5rem);    /* 28→40 h3 */
  --text-3xl:  clamp(2.25rem, 1.6rem + 3vw, 3.5rem);      /* 36→56 h2 */
  --text-4xl:  clamp(3rem, 1.8rem + 5.5vw, 5.5rem);       /* 48→88 h1 */
  --text-hero: clamp(3.5rem, 1.5rem + 9vw, 9rem);         /* 56→144 hero name */

  --lh-tight: 0.95;  /* hero */
  --lh-snug:  1.05;  /* h1–h2 */
  --lh-head:  1.15;  /* h3–h4 */
  --lh-body:  1.6;
  --lh-loose: 1.75;  /* long-form about page */

  --ls-hero: -0.03em; --ls-head: -0.02em; --ls-body: 0;
  --ls-eyebrow: 0.14em; --ls-button: 0.06em;
}
```

### Hierarchy
| Role | Font | Size | Weight | LH | Tracking | Notes |
|---|---|---|---|---|---|---|
| Hero name | Fraunces `opsz` 144 | `--text-hero` | 400 (SOFT 40) | 0.95 | -0.03em | Italic on one word max |
| H1 | Fraunces | `--text-4xl` | 400 | 1.05 | -0.02em | One per page |
| H2 | Fraunces | `--text-3xl` | 400 | 1.05 | -0.02em | Section titles |
| H3 | Fraunces | `--text-2xl` | 500 | 1.15 | -0.01em | Card titles |
| H4 | Figtree | `--text-xl` | 600 | 1.2 | 0 | Sub-cards, form legends |
| Lead | Figtree | `--text-lg` | 400 | 1.5 | 0 | Intros, max 60ch |
| Body | Figtree | `--text-base` | 400 | 1.6 | 0 | Max 68ch |
| Eyebrow | Figtree | `--text-xs` | 600 | 1 | 0.14em | UPPERCASE, gold accent-text |
| Button | Figtree | 0.9375rem | 600 | 1 | 0.06em | UPPERCASE |
| Caption/meta | Figtree | `--text-sm` | 400 | 1.4 | 0.02em | ink-600 / ink-400 |
| Stat numeral | Fraunces | `--text-3xl` | 300 | 1 | -0.02em | `font-variant-numeric: lining-nums tabular-nums` |
| Pull-quote | Fraunces italic | `--text-2xl` | 300 | 1.25 | 0 | Testimonials |

Body text never below 16px. Headline max-width 18ch, body 68ch.

---

## 4. Spacing, layout, radii, lines

```css
:root {
  --space-1: 0.25rem;  --space-2: 0.5rem;  --space-3: 0.75rem; --space-4: 1rem;
  --space-5: 1.5rem;   --space-6: 2rem;    --space-7: 3rem;    --space-8: 4rem;
  --space-9: 6rem;     --space-10: 8rem;   --space-11: 12rem;
  --section-y: clamp(4rem, 3rem + 6vw, 9rem);   /* vertical rhythm between sections */
  --gutter: clamp(1rem, 0.5rem + 2.5vw, 3rem);  /* 16px phone → 48px desktop */
  --container: 1360px; --container-narrow: 760px; --container-wide: 1600px;

  --radius-0: 0;       /* default — editorial, sharp */
  --radius-sm: 4px;    /* form fields, tags */
  --radius-md: 8px;    /* cards on light theme only */
  --radius-pill: 999px;/* buttons, pills */
  --radius-img: 2px;   /* images — near-sharp */

  --line-hair: 1px solid var(--line);
  --line-strong: 1px solid var(--line-strong);
  --shadow-sm: 0 1px 2px rgb(11 10 10 / .06);
  --shadow-md: 0 12px 32px -12px rgb(11 10 10 / .25);
}
```
- **Grid:** 12-column CSS Grid, gap `--space-5` (mobile) / `--space-6` (desktop). Editorial asymmetry: text columns 5/12, image 7/12; offset image blocks by one column on desktop.
- **Rules, not boxes:** sections divide with 1px hairlines and generous whitespace; cards are borderless on dark, hairline-bordered on light. Shadows are rare (lightbox, sticky nav on scroll only).
- **Radii:** sharp by default (editorial); pill buttons are the one soft element — they echo the hoop earrings.
- **Breakpoints:** 480 / 768 / 1024 / 1280 / 1600 (mobile-first).

---

## 5. Imagery treatment

- **Hero portrait:** the reference photo (laughing, mic, fur coat, foliage, mural) is the brand. Crop tall (4:5) on mobile, wide (3:2) or bleeding off the right edge on desktop. Do **not** duotone the hero — her skin tone, the gold ring and green plants are the palette's proof.
- **Secondary photography:** full-colour, editorial crops (tight on hands/mic/earrings), consistent warm grade: +5 warmth, slight lift of blacks to `#0B0A0A`, contrast curve gentle. Apply a **2–3% film grain overlay** (CSS `background-image` SVG turbulence at `opacity: .04`, `mix-blend-mode: overlay`) on hero and section backgrounds only — never on body-text areas.
- **Gallery (FreekÀ / events):** colour images, `object-fit: cover`, mixed aspect ratios (4:5, 1:1, 3:2) in an editorial masonry. Hover: image scales 1.03 with a **gold-500 at 12% tint** overlay and caption reveal. Press/logos: monochrome ivory on dark, ink on light (`filter: grayscale(1)` with opacity .8; full colour on hover is optional).
- **Video posters:** desaturated 20% with a centred pill play button (gold-500, ink glyph).
- **Alt text:** descriptive and specific ("Mati laughing into a Shure SM7B microphone in a black faux-fur coat, green plants and a Harlem mural behind her"). Decorative grain/texture images use `alt=""`.
- Image formats: AVIF with WebP fallback, `srcset` 480/800/1200/1800, `loading="lazy"` below the fold, hero `fetchpriority="high"`.

---

## 6. Motion principles

1. **Editorial, not theatrical.** Motion supports reading order; nothing loops except the marquee.
2. **Durations:** micro 150ms, standard 300ms, reveal 600–800ms. Easing `cubic-bezier(.2,.7,.2,1)` (out-expo feel).
3. **Reveal on scroll:** `IntersectionObserver` adds `.is-in`; elements translate 24px→0 and fade; stagger children by 60ms, max 6 per group. Headlines can reveal by line via `clip-path` (no per-letter splitting).
4. **Marquee:** "As seen at / Trusted by" strip scrolls continuously at ~40s per loop, pauses on hover/focus, duplicates content for seamlessness; `aria-hidden` on the duplicate.
5. **Hover:** buttons — background/colour swap + 2px translateY(-1px); links — gold underline grows from left (`background-size` trick); cards — image scale 1.03, caption slides up; nav items — hairline underline.
6. **Hero:** portrait fades/scales 1.04→1 over 1.2s on load; name reveals by line. No parallax beyond a subtle 4% on desktop.
7. **Reduced motion:** `@media (prefers-reduced-motion: reduce)` — all transitions 0ms, reveals render in final state, marquee stops and wraps to a static two-row logo grid, video does not autoplay.
8. **Performance:** animate only `transform`, `opacity`, `clip-path`; `will-change` sparingly; no animation libraries.

---

## 7. Iconography

- **Set:** Lucide (MIT) inline SVGs, 1.5px stroke, 20/24px, `stroke="currentColor"`. Used only where they aid scanning: play, arrow-up-right (external), arrow-right (CTA), mic, calendar, map-pin, mail, chevron (accordion), x (close), sun/moon/monitor (theme).
- **Social:** Instagram, TikTok, LinkedIn, YouTube, Spotify, Apple Podcasts — simple-icons glyphs, monochrome, 20px, labelled with visually-hidden text.
- **Brand mark:** a wordmark set in Fraunces — `Mati Chinyanda` with the `À`-style accent motif borrowed for a monogram **MC** (Fraunces italic, gold on ink) used as favicon and footer stamp. No illustrated icon system.

---

## 8. Voice & tone

### Voice characteristics
- **Warm and direct** — like a friend who happens to run the room. Second person, contractions, short sentences.
- **Confident, not boastful** — proof does the bragging (names, numbers, logos).
- **Culturally fluent** — Zimbabwean heritage, Melbourne, the group chat; specific references over generic "diversity" language.

### Tone by context
| Context | Tone | Example |
|---|---|---|
| Hero / headlines | Bold, playful, editorial | "Your event, but make it *unforgettable*." |
| Speaking pages | Assured, planner-focused | "Keynotes and hosting for rooms that need energy and a safe pair of hands." |
| Booking form | Clear, reassuring, quick | "Tell me about the room. I reply within two business days." |
| Podcast | Conversational, cheeky | "Three women. One group chat. No filter." |
| FreekÀ / events | Visionary, generous | "A runway built for the creatives Melbourne hasn't met yet." |
| Errors / validation | Kind, specific | "Add an email so I can reply to you." |

### Messaging architecture
- **Tagline:** *Bring the room to life.*
- **Roles line:** Speaker · MC & Event Host · Podcaster · Founder, FreekÀ Runway
- **Value proposition:** Joyful, editorial hosting and speaking — with the production instinct of someone who builds her own shows.
- **Key messages:** (1) Hosting with real energy, not a run-sheet voice. (2) Speaking on culture, ambition and belonging from lived experience. (3) Creative direction and production for fashion and cultural events, proven with FreekÀ Runway.

### Microcopy library
| Element | Copy |
|---|---|
| Primary CTA | **Book Mati** |
| Secondary CTA (proof) | **Watch the reel** |
| Tertiary / soft | **Start a conversation** · **Enquire about an event** |
| Events pillar CTA | **Produce with Mati** |
| Podcast CTA | **Listen to the latest** · **Follow the show** |
| Speaker kit | **Download the speaker kit (PDF)** |
| Nav | Speaking · Podcast · FreekÀ Runway · About · **Book** |
| Form submit | **Send enquiry** |
| Form success | "Got it — thank you. I'll be in touch within two business days." |
| Form error (required) | "Please add [field] so I can get back to you." |
| Marquee eyebrow | "As seen at · Trusted by" |
| Stats labels | "Events hosted" · "Podcast episodes" · "Runway shows produced" · "Countries" |
| Footer CTA | "Got a room that needs *energy*?" → Book Mati |
| 404 | "That left the group chat." → Back home |

### Writing rules
- Australian English (organise, colour, programme for events, program for software).
- Numerals for stats (120+ events), words for one–nine in prose.
- Never "diverse voices", "empower", "synergy". Prefer specific nouns: designers, models, communities, ballrooms.
- Always "FreekÀ Runway" on first mention, "FreekÀ" thereafter; podcast in italics: *What Left The Group Chat*.
