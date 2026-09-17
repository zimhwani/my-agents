# Pamusha Lake House — Brand Identity System

Source facts: `pamusha/research/property-facts.md`. "Pamusha" = "at home" (Shona). Lake Reeve, The Honeysuckles, Gippsland Lakes; walk to Ninety Mile Beach; wood-fired hot tub, fire pit, stargazing deck; sleeps 9.

## 1. Brand foundation

**Essence:** *At home, at the water's edge.*

**Promise:** Every stay feels like arriving somewhere that was already expecting you — a quiet, generous house where the lake does the talking.

**Values**
1. **Welcome** — the Shona idea of pamusha: the door is open, the fire is lit, there is room at the table.
2. **Stillness** — we protect quiet. Design, copy and hosting remove noise rather than add features.
3. **Gathering** — built for nine people to be together and apart: two living areas, a long deck, one hot tub.
4. **Care for place** — we tread lightly on Lake Reeve and the Coastal Park, and ask guests to do the same.

**Personality:** Warm · Unhurried · Assured

**Positioning:** A boutique-hotel-calibre lake house on the Gippsland Lakes, for families and friends who want the water, the fire and the stars — not a resort.

## 2. Name and mark

**Wordmark:** `Pamusha` set in the display serif, sentence case, tracked +0.02em. Never all-caps, never italic in the lockup.
**Descriptor:** `LAKE HOUSE · THE HONEYSUCKLES` in the body sans, 0.6875rem, uppercase, tracked +0.18em, `--ink-soft`. Middle dot, not hyphen.
**Lockups:** horizontal (mark left, wordmark + descriptor stacked right, gap = mark height × 0.5); stacked (mark centred above); mark alone at ≤ 32px. Clear space = height of the "P" on all sides. Minimum wordmark width 96px.

**Mark — "Horizon Ripple."** 64 × 64 viewBox, stroke-only, `stroke-width: 2.5`, `stroke-linecap: round`, currentColor, no fill. Three elements:
1. **Horizon:** straight line from (8, 32) to (56, 32).
2. **Petal (honeysuckle / sun):** an arc above the horizon — half-ellipse from (18, 32) to (46, 32), control point (32, 8) as a quadratic Bézier: `M18 32 Q32 8 46 32`. Reads as a petal, a rising sun and a roofline at once.
3. **Ripples (Lake Reeve):** two shortening cubic waves below the horizon, each 6px apart: `M14 42 C 20 38, 26 46, 32 42 S 44 38, 50 42` and `M20 52 C 24 49, 28 55, 32 52 S 40 49, 44 52`.

Full SVG:
```svg
<svg viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-label="Pamusha">
  <path d="M18 32 Q32 8 46 32"/>
  <path d="M8 32 H56"/>
  <path d="M14 42 C20 38 26 46 32 42 S44 38 50 42"/>
  <path d="M20 52 C24 49 28 55 32 52 S40 49 44 52"/>
</svg>
```
Favicon: same paths at `stroke-width: 3.5` on a `--linen` circle. Do not add gradients, shadows or a second colour to the mark.

## 3. Colour system

```css
:root {
  /* Base */
  --linen:        #F6F1E9;  /* page background */
  --linen-2:      #EDE5D8;  /* cards, alternate sections */
  --ink:          #1C2430;  /* primary text, lake at dusk */
  --ink-soft:     #4A5361;  /* secondary text, descriptors */
  /* Accent — honeysuckle apricot */
  --apricot:      #E5A46E;  /* fills, buttons, decorative rules */
  --apricot-text: #A4541F;  /* links, eyebrows on linen */
  /* Secondary — eucalyptus sage */
  --sage:         #B7C2B1;  /* chips, tints, illustration */
  --sage-deep:    #4F6150;  /* sage as text */
  /* Neutrals (warm) */
  --n-50:  #FBF8F3;  --n-100: #F6F1E9;  --n-200: #E6DFD3;
  --n-300: #CFC7BA;  --n-400: #A8A39B;  --n-500: #7A7F86;
  --n-600: #5A606A;  --n-700: #3E4652;  --n-800: #2A323D;
  --n-900: #1C2430;
  /* Semantic */
  --bg: var(--linen); --surface: var(--linen-2);
  --text: var(--ink); --text-soft: var(--ink-soft);
  --accent: var(--apricot); --accent-text: var(--apricot-text);
  --rule: color-mix(in srgb, var(--ink) 14%, transparent);
  --grain-opacity: 0.035;
}

@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #141A21; --surface: #1C2530;
  --text: #EDE6DA; --text-soft: #B6B0A6;
  --accent: #E5A46E; --accent-text: #E5A46E;
  --sage: #A9B8A3; --sage-deep: #A9B8A3;
  --n-500: #8A9099;
  --rule: color-mix(in srgb, #EDE6DA 14%, transparent);
  --grain-opacity: 0.05;
} }
:root[data-theme="dark"] { /* same values as the block above */ }
body { background: var(--bg); color: var(--text); }
```

**Contrast (WCAG AA, computed):**

| Pair | Ratio | Result |
|---|---|---|
| ink on linen / linen-2 | 13.89 / 12.50 | AAA |
| ink-soft on linen / linen-2 | 6.91 / 6.22 | AAA |
| apricot-text on linen / linen-2 | 4.83 / 4.35 | AA (normal text) |
| sage-deep on linen / linen-2 | 5.91 / 5.32 | AA+ |
| linen on ink (primary button) | 13.89 | AAA |
| ink on apricot (accent button) | 7.34 | AAA |
| ink on sage (chip) | 8.45 | AAA |
| n-500 on linen | 3.59 | large text / icons only |
| dark: text on bg / surface | 14.12 / 12.48 | AAA |
| dark: text-soft on bg / surface | 8.13 / 7.19 | AAA |
| dark: apricot on bg / surface | 8.23 / 7.27 | AAA |
| dark: sage on bg / surface | 8.40 / 7.42 | AAA |
| dark: bg on apricot (button) | 8.23 | AAA |

Rules: apricot fill is never a text colour on linen — use `--apricot-text`. Never place sage text on apricot or vice versa. Colour is used sparingly: one accent moment per screen.

## 4. Typography

**Display:** Fraunces (Google Fonts), weights 300–400, `font-variation-settings: "opsz" 144, "SOFT" 50`. Italic only for single emphasised words.
**Body:** DM Sans (Google Fonts), 400/500.
Fallbacks: `Fraunces, "Iowan Old Style", Georgia, serif` · `"DM Sans", system-ui, sans-serif`.

| Role | Size | Weight | Line-height | Tracking |
|---|---|---|---|---|
| Display | 4.5rem (mobile 2.75rem) | 300 | 1.02 | −0.02em |
| H1 | 3rem (mobile 2.25rem) | 300 | 1.08 | −0.015em |
| H2 | 2rem | 400 | 1.15 | −0.01em |
| H3 | 1.375rem | 400 | 1.3 | 0 |
| Body | 1.0625rem | 400 | 1.65 | 0 |
| Small | 0.875rem | 400 | 1.5 | +0.01em |
| Eyebrow | 0.6875rem | 500, uppercase | 1 | +0.18em |

Measure: 60–68 characters. Headings in `--ink`; eyebrows in `--accent-text` or `--sage-deep`. Numbers (sleeps 9, 4 bedrooms) set in Fraunces at H2 size — the figures are part of the story.

## 5. Visual language

**Photography.** Golden hour and blue hour only; no midday. Lake Reeve as a mirror — reflections, low horizon in the bottom third. Steam lifting from the hot tub at dawn; embers at the fire pit; the deck at night with a long-exposure sky. Interiors: natural light, linen, timber, unmade-then-made beds, a table set for nine. People appear as gestures — a hand on a rail, feet on the deck — never posed to camera. Warm, slightly desaturated grade; blacks lifted to `--ink`, never crushed.

**Motifs.**
- *Horizon rule:* a 1px line in `--rule`, full-bleed, separating sections instead of boxes.
- *Ripple:* the mark's wave path, repeated as a 24px-tall SVG divider or as an animated loader.
- *Contour:* topographic contour lines of the lake edge at 6–8% opacity as a background texture on `--surface` sections — one per page, maximum.
- *Petal arc:* the mark's quadratic arc as an image mask (arched-top photographs) for hero and room cards.

**Texture.** A fixed-position film-grain overlay (SVG `feTurbulence`, baseFrequency 0.8, opacity `--grain-opacity`, `mix-blend-mode: multiply` in light, `overlay` in dark). No drop shadows; depth comes from `--surface` on `--bg`.

**Spacing.** 8px base. Tokens: 0.5 / 1 / 1.5 / 2 / 3 / 5 / 8 / 13rem. Section padding 8rem desktop / 5rem mobile. Generous margins are the luxury signal — when in doubt, add space, not elements. Content max-width 72rem; prose 40rem.

**Motion.** Slow and few. Durations 600–900ms, easing `cubic-bezier(0.22, 1, 0.36, 1)`. Fade-up on scroll (12px, once). Images scale 1.03 → 1.0 on load. Ripple divider drifts 2px horizontally over 8s. Respect `prefers-reduced-motion` fully. No parallax, no bouncing, no auto-playing carousels.

## 6. Voice and tone

**Rules**
1. Speak like a good host, not a listing: first person plural, second person guest.
2. Lead with feeling, then facts. Facts must match the fact sheet.
3. Short sentences. One adjective is plenty.
4. Name the place — Lake Reeve, Ninety Mile Beach, the Coastal Park — not "paradise".
5. Honour the name lightly: explain "pamusha" once, then let the house prove it.

| Do | Don't |
|---|---|
| "The hot tub is wood-fired. Light it after lunch; it's ready by dark." | "Indulge in our luxurious wood-fired spa experience!" |
| "Four bedrooms, two living rooms, room for nine." | "Spacious 4BR/2BA property with ample accommodation." |
| "Bring a jumper. The deck is best after the stars come out." | "Breathtaking 5-star stargazing you won't believe!" |

**Hero**
Headline: *At home on Lake Reeve.*
Subline: A four-bedroom lake house at The Honeysuckles, a short walk from Ninety Mile Beach. Wood-fired hot tub, fire pit, and a deck built for the night sky.

**Section headings:** The house · The water · Fire and stars · Getting here

**Our story (70 words)**
Pamusha means "at home" in Shona. It was the word we reached for the first evening we sat on this deck and watched Lake Reeve go still. We built the house around that feeling: room for nine, two places to gather, one hot tub heated by wood you light yourself. Ninety Mile Beach is a walk away. The stars arrive on their own. Come as you are; leave a little slower.

**CTAs:** Check dates · Book on Airbnb · See the house

**House manual welcome**
Welcome to Pamusha. We're glad you're here. Everything you need is in these pages — the Wi-Fi, the hot tub, the bins, the beach track. If something isn't, message us and we'll sort it. The lake is quiet, the bush is close, and the wildlife lives here too, so please go gently. Light the fire, fill the tub, and make yourself at home. That's what the name means.

**Footer tagline:** Pamusha — at home, at the water's edge.

---
Brand Guardian / Visual Storyteller · 2026-09-17 · Ready for build. Protection: register "Pamusha Lake House" as a business name (ASIC) and secure matching social handles; use the mark and wordmark only as specified above.
