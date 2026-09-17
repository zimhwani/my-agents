# Accessibility Audit — Pamusha Lake House

**Scope:** `/`, `/the-house`, `/explore`, `/house-manual`, `/404` at commit `8774571` (served from `http://127.0.0.1:8765`).
**Standard:** WCAG 2.2 AA. **Date:** 2026-09-17. **Auditor:** AccessibilityAuditor.
**Tools:** axe-core 4.13.0 via Playwright/Chromium (light + dark, 390 px + 1440 px, `.reveal` forced `is-in`, CSS transitions disabled so mid-fade colours were not sampled); keyboard-only flows; pixel sampling of screenshots for the hero; token contrast maths; `prefers-reduced-motion` and JS-off emulation; 320 px reflow and text-spacing checks. No live screen reader is available in this environment, so announcement findings are derived from the accessibility tree and live-region markup.

**Conformance: DOES NOT CONFORM (AA).** 0 Critical · 5 Serious · 8 Moderate · 6 Minor.

## Raw axe violations (nodes) per page

| Page | Light 390 | Light 1440 | Dark 390 | Dark 1440 | Rule |
|---|---|---|---|---|---|
| `/` | 2 | 2 | 0 | 0 | color-contrast |
| `/the-house` | 1 | 1 | 0 | 0 | color-contrast |
| `/explore` | 0 | 0 | 0 | 0 | — |
| `/house-manual` | 0 | 0 | 0 | 0 | — |
| `/404` | 1 | 1 | 1 | 1 | heading-order (best practice) |

Automation catches ~30 % of what follows; everything below Moderate-7 was found manually.

## Serious

**S1. Mobile menu is unreachable by forward Tab and Escape drops focus** — 2.4.3 Focus Order, 2.4.7.
`index.html` (all pages) `header .nav__toggle` sits *after* `#nav-links` in the DOM. Tested at 390 px: Enter on Menu opens it (`aria-expanded=true`), but the next Tab lands on the hero "Book on Airbnb" behind the panel; the four menu links are only reachable with Shift+Tab. Escape (`assets/js/main.js` document keydown) closes the panel but leaves focus on whatever page element had it, scrolled off-screen. Note the breakpoint is 56 rem, so desktop users at 200 % zoom get this too.
Fix: on open, `links.querySelector('a').focus()`; on Escape/close, `toggle.focus()`; while open, set `inert` on `main` and `footer` (or move the toggle before `#nav-links`).

**S2. Focus ring fails contrast on all light surfaces** — 1.4.11 Non-text Contrast, 2.4.7.
`assets/css/main.css:23` `:focus-visible { outline: 2px solid var(--accent) }` = `#E5A46E` on `#F6F1E9` **1.89:1**, on `#EDE5D8` **1.70:1** (needs 3:1). Dark mode passes (8.2:1).
Fix: `outline: 2px solid var(--text); outline-offset: 3px; box-shadow: 0 0 0 6px var(--bg);` or use `var(--accent-text)` (4.8:1) in light mode.

**S3. Text inputs remove the focus indicator** — 2.4.7 Focus Visible.
`main.css:269` `.field input:focus { outline: none; border-bottom-color: var(--accent-text) }`. Measured: `outline: none`, only a 1 px underline changes colour; the resting border (`ink@28 %`) is 1.76:1 so the change is barely perceptible.
Fix: delete `outline: none` (inherit the S2 ring) or use `border-bottom-width: 3px` plus an outline.

**S4. Error text unreadable in dark mode** — 1.4.3 Contrast.
`main.css:272` `.field__error { color: #B4462B }` is hard-coded: **3.21:1** on `#141A21` at 14 px (light: 4.85:1, passes).
Fix: add `--error-text` token, dark value e.g. `#F08A6B` (~7:1), and use it for `.field__error` and `:user-invalid`.

**S5. Required "Message" is never validated and no field is marked required** — 3.3.1 Error Identification, 3.3.2 Labels or Instructions.
`index.html #f-msg` has `required` but `validate()` in `main.js` ignores it: with name + email filled and an empty message the form proceeds to `mailto:`/Web3Forms. No `.field__error`, no `aria-describedby`. Labels ("Your name", "Email", "Message") carry no visible required indicator.
Fix: add `<span class="field__error" id="e-msg">` + `aria-describedby`, validate `message`, and append "(required)" to the three labels or add a one-line instruction above the form.

## Moderate

**M1. Premature, unannounced errors** — 3.3.1, 4.1.3. Every `blur` runs the whole `validate()`: tabbing out of an empty Name shows errors on Name *and* the untouched Email field, and neither is announced (errors on unfocused fields are `display` toggles only). Fix: validate only the blurred field before first submit; on submit write "2 fields need attention" to `.form__status` (`role=status`).

**M2. Lightbox changes are silent** — 4.1.3, 1.1.1. `the-house.html #lightbox` has no live region and no `aria-describedby`; with placeholder art the `.art` is `aria-hidden`, so a screen reader hears "Image viewer, dialog, Close" and nothing on Arrow/Next. Fix: `aria-describedby="lightbox-caption"` on the dialog, `aria-live="polite"` on `.lightbox__caption` with "n of 16", and `role="img" aria-label` on the stage art.

**M3. Three buttons named "Copy"** — 2.4.6, 4.1.2. `house-manual.html [data-copy]` (lockbox code, network, password). Fix: `aria-label="Copy Wi-Fi password"` etc.

**M4. Guide search results not announced** — 4.1.3. `#guide-search` hides cards/sections and toggles `#guide-empty` silently. Fix: `role="status"` on `#guide-empty`, plus a visually-hidden status "N cards match", and `aria-controls`.

**M5. Links indistinguishable from text** — 1.4.1 Use of Color. `.tel` (`main.css:259`, `text-decoration:none`, same colour/weight as surrounding `dd`/`p`) and `.site-footer a` (`main.css:287`). Fix: keep the underline on `.tel` inside prose/`.kv`, underline footer links or give them the 3:1 colour difference plus hover/focus underline.

**M6. Header tagline over the hero fails on mobile** — 1.4.3. `.site-header--overlay:not(.is-scrolled) .brand__desc` (`main.css:120`) is 10 px linen at 75 % alpha; sampled **3.8:1** at 390 px (100 % of points), 3.0–4.8:1 at 1440 px. Fix: drop the alpha in the overlay state (≈5.4:1) or raise the top scrim to 0.65.

**M7. Eyebrow contrast on surface panels (axe)** — 1.4.3. `.eyebrow` `#A4541F` on `#EDE5D8` = **4.34:1** at 11 px: `index.html` `#reviews .eyebrow`, `.callout > .eyebrow`; `the-house.html #amenities .eyebrow`. Fix: `--apricot-text: #98491A` (≥5:1 on both linen and surface).

**M8. Checklist completion message will not announce** — 4.1.3. `house-manual.html .checklist__done[aria-live]` text is always in the DOM; only opacity changes, so nothing is announced on completion and it is read while invisible. Fix: keep it `hidden` and set `textContent` when all boxes are checked.

## Minor

- **m1.** 44 `target="_blank"` links (8/5/18/9/4 per page) with no new-tab warning (G201). Add visually-hidden "(opens in new tab)".
- **m2.** `/404` heading order h1 → h3 (footer `.footer-h`). Use `h2` for footer headings or `aria-labelledby` on the lists.
- **m3.** Skip link relies on Chromium's focus-start behaviour; add `tabindex="-1"` to `<main id="main">` for Safari (2.4.1).
- **m4.** `/explore` has 12 links named "Directions" (passes 2.4.4 via preceding `h3`); add `aria-label="Directions to Seaspray"` for link lists.
- **m5.** With JS off and no reduced-motion preference, all 16/18/21 `.reveal` blocks stay at `opacity:0`. Gate the hide rule on an `html.js` class.
- **m6.** Content readiness: 3 links to placeholder `tel:+61400000000`, one link whose text is "TODO: host mobile", and the Wi-Fi password `changeme` is public.

## What is working well (preserve)

- Skip link visible on focus (16 px inset, 2.4.1); landmarks `banner`, `navigation[Primary]`, `navigation[Guide sections]`, `main`, `contentinfo`; unique titles; `lang="en-AU"`; clean h1→h2→h3 on four pages.
- Native `<dialog>` lightbox: Enter/Space open, focus to Close, Tab trapped, arrows wrap, Escape closes, focus returns to the tile.
- Reduced motion honoured everywhere (reveal, ripple, 404 draw, smooth scroll); content visible with JS off under `reduce`.
- Hero text over placeholder art: h1 min **8.7:1**, lede (linen 84 %) min **4.8:1**, eyebrow min **5.3:1**, nav links **6.8:1** after the new top scrim.
- Theme switch: `role="group"` + `aria-pressed`; copy buttons announce "Copied to clipboard"; 320 px reflow has no horizontal scroll; text-spacing causes no clipping; all non-inline targets ≥ 24 px.

## Remediation order

1. S1, S2, S3 (one CSS token + ~10 lines of JS) — unblock keyboard users.
2. S4, S5, M1 — form correctness and dark-mode errors.
3. M2–M8 — announcements and contrast tokens.
4. Minor items during content fill-in; re-audit with NVDA/VoiceOver once photos and real numbers land.
