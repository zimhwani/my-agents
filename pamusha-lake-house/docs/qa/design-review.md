# Pamusha Lake House — Visual polish review

UI Designer + Whimsy Injector · 2026-09-17 · Reviewed against `docs/design/brand.md` and `docs/design/ux-spec.md` at 1440 and 390 px, light and dark. Placeholder art ignored. Overall: the type system, spacing and restraint already read as premium. The items below are the gaps between "good" and "assured".

## Priority 1 — visible on first screen or breaks brand rules

**1. Home hero: nav and wordmark sit on the brightest part of the sky.** `index.html` header over `.hero`. Linen links on the apricot sky top measure ~1.6:1; golden-hour photos will do the same. Fix in `main.css`:
```css
.hero__media::after { background:
  linear-gradient(to bottom, rgba(20,26,33,.55) 0%, rgba(20,26,33,0) 28%),
  linear-gradient(to top, rgba(20,26,33,.78) 0%, rgba(20,26,33,.35) 45%, rgba(20,26,33,.15) 100%); }
```

**2. Sticky header turns muddy grey over dark bands.** All pages, `.site-header.is-scrolled` while over `.hero`, `.section--ink` or the outdoors band. 78–82 % linen over navy renders as flat grey and looks like a bug. Fix:
```css
.site-header.is-scrolled, .site-header--overlay.is-scrolled { background: color-mix(in srgb, var(--bg) 94%, transparent); }
```

**3. Outline chips are invisible in the ink band.** Home "Fire and stars" chips ("8-seater", "Wood-fired"). `.section--ink` overrides `--rule` but not `--rule-strong`, so the border is ink-on-ink and the chips read as loose words. Fix: add `--rule-strong: color-mix(in srgb, #F6F1E9 32%, transparent);` to the `.section--ink` declaration.

**4. Dark mode flattens the hierarchy.** In dark, page bg `#141A21`, `--surface` `#1C2530`, `.section--ink` `#1C2430` and `.mcard--accent` are near-identical navies: the fire band, reviews band and the manual's Address/Wi-Fi/Emergency cards lose their emphasis, and the contour motif (hard-coded `#1C2430` strokes) vanishes. Fix in `tokens.css` and `main.css`:
```css
:root { --ink-band: var(--ink); --contour-filter: none; }
/* both dark blocks */ --ink-band: #0E1319; --contour-filter: invert(1);
.section--ink, .mcard--accent { background: var(--ink-band); }
.contour::before { filter: var(--contour-filter); }
```

## Priority 2 — component consistency

**5. Footer theme toggle has no pressed state and wraps to two rows.** Every footer. Spec says "active option filled"; `Auto` (`aria-pressed="true"`) looks identical to the others, and the three pills break Light/Dark | Auto at 1440. Fix:
```css
[data-theme-set][aria-pressed="true"] { background: var(--btn-bg); color: var(--btn-text); border-color: var(--btn-bg); }
.site-footer [role="group"] { flex-wrap: nowrap; gap: .35rem; }
.site-footer [role="group"] .btn--sm { padding-inline: .8rem; }
```

**6. "Directions" ghost buttons stretch full width.** `explore.html` day-trip, eat-and-drink cards (12×). `.feature` is a grid, so the inline-flex ghost button becomes a centred label over a full-width rule and reads as a form field, not a link. Fix: `.feature .btn--ghost { justify-self: start; }`.

**7. Mobile facts strip orphans "Lake front".** Home and the-house `.facts__list` at ≤36rem: five cells in two columns leave the fifth alone with a stray left border. Fix:
```css
@media (max-width: 36rem) { .facts__list li:nth-child(5) { grid-column: 1 / -1; border-left: 0; } }
```
(Spec's horizontal snap-scroll strip is the fuller answer if the owner prefers.)

**8. Mobile "Fire and stars" buries its headline under two tall images.** Home `[aria-labelledby="fire-title"] .grid--2` collapses to one column at ≤36rem, so ~900 px of imagery precedes the H2. Keep the pair side by side: add class `grid--pair` to that `<div class="grid grid--2 reveal">` and
```css
@media (max-width: 36rem) { .grid--pair { grid-template-columns: 1fr 1fr; gap: .75rem; } }
```

## Priority 3 — refinement

**9. Outdoors grid leaves a dead cell.** `the-house.html#outdoors`: five cards in three columns end with an empty slot bottom-right. Fix:
```css
#outdoors .grid--3 { grid-template-columns: repeat(6, 1fr); }
#outdoors .grid--3 > * { grid-column: span 2; }
#outdoors .grid--3 > :nth-child(n+4) { grid-column: span 3; }
@media (max-width: 56rem) { #outdoors .grid--3 { grid-template-columns: 1fr 1fr; } #outdoors .grid--3 > * { grid-column: auto; } }
```

**10. Gallery mosaic orphans its last tile on mobile.** `the-house.html#gallery`, 16 tiles in two columns. Fix: `@media (max-width: 56rem) { .mosaic > :last-child { grid-column: span 2; } }`.

**11. Brand descriptor is 9 px; multi-line eyebrows are cramped.** All headers: `.brand__desc` is 0.5625rem against the brand's 0.6875rem, and `.eyebrow { line-height: 1 }` crushes the hero eyebrow when it wraps at 390 px. Fix: `.brand__mark { width: 2.5rem; height: 2.5rem; } .brand__desc { font-size: .625rem; } .eyebrow { line-height: 1.5; }`.

**12. Guest guide carries marketing chrome and a marketing-sized hero.** `house-manual.html`: guests have already booked (the book bar is hidden, but "Book on Airbnb" remains in the nav), the hero starts 8–12 rem down, and "Got it" wraps to two lines on mobile. Fix:
```css
.page-manual .nav__cta .btn { display: none; }
.page-manual .page-hero { padding-top: clamp(3rem, 2rem + 3vw, 5rem); }
.copy-btn { white-space: nowrap; }
```

## Delight — slow and few

**13. Images breathe on hover.** Cards and gallery tiles are static; the brand's own motion rule (scale 1.03 → 1.0 on load) suggests the inverse on hover. Place after the `.reveal` rules so specificity resolves:
```css
@media (prefers-reduced-motion: no-preference) {
  .frame .art { transition: transform 1.2s var(--ease); }
  .card:hover .frame img, .card:hover .frame .art, [data-lightbox]:hover img, [data-lightbox]:hover .art { transform: scale(1.03); }
}
```

**14. The horizon draws itself on the 404.** `404.html`: add the mark above the eyebrow (`<span class="brand__mark mark--draw" aria-hidden="true">` + the brand SVG, 4rem wide) and let its strokes draw once:
```css
@media (prefers-reduced-motion: no-preference) {
  .mark--draw path { stroke-dasharray: 80; stroke-dashoffset: 80; animation: draw 1.2s var(--ease) forwards; }
  .mark--draw path:nth-child(2) { animation-delay: .25s; } .mark--draw path:nth-child(3) { animation-delay: .5s; } .mark--draw path:nth-child(4) { animation-delay: .7s; }
  @keyframes draw { to { stroke-dashoffset: 0; } }
}
```
A lost guest gets the lake settling, not a joke.

**15. The checkout list says goodbye.** `house-manual.html#checkout`: after the `<ul class="checklist">`, add `<p class="checklist__done soft serif-i" style="font-size:1.25rem">That's everything. Safe travels — and thank you for looking after the place.</p>`. Pure CSS, fades in only when all six are ticked:
```css
.checklist__done { opacity: 0; margin-top: 1rem; transition: opacity .9s var(--ease); }
.mcard:not(:has(.checklist input:not(:checked))) .checklist__done { opacity: 1; }
```
Host voice, no confetti, reversible if a box is unticked.
