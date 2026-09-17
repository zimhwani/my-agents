# Pamusha Lake House — Performance Benchmark

**Date:** 2026-09-17 · **Tool:** Lighthouse 13.4.1 mobile (4x CPU slowdown, 1.6 Mbps / 150 ms RTT) + Playwright full-scroll pass · **Target:** local `http-server` (no gzip, 1 h cache). Vercel adds Brotli and the `immutable` header from `vercel.json`, so production will be slightly better; treat this as a conservative baseline.

## Scores (mobile)

| Page | Perf | A11y | BP | SEO | FCP | LCP | TBT | CLS |
|---|---|---|---|---|---|---|---|---|
| `/` | 96 | 98 | 96 | 100 | 1.5 s | 2.6 s | 0 ms | 0 |
| `/the-house` | 96 | 95 | 96 | 100 | 1.7 s | 2.7 s | 50 ms | 0 |
| `/explore` | 96 | 98 | 96 | 100 | 1.7 s | 2.7 s | 20 ms | 0 |
| `/house-manual` | 96 | 100 | 100 | 66* | 1.5 s | 2.7 s | 0 ms | 0 |

Home re-run twice: perf 96/96, LCP 2.6/2.6 s — stable. *SEO 66 is the intentional `noindex` on the guest guide.

**Status: near-miss on LCP.** CLS and TBT are perfect; LCP is 0.1–0.2 s over the 2.5 s "Good" line on every page. The LCP element everywhere is the hero `<p class="lede">` text (the hero image 404s), so LCP is gated by render-blocking CSS + font bytes, not images.

## Payload per page (transfer, uncompressed locally)

| Page | Requests | Total | HTML | CSS (3 files) | JS | Fonts (3) | Images |
|---|---|---|---|---|---|---|---|
| `/` | 13 | 286 KB | 21.8 | 32.4 | 17.8 | 199.7 | 13.4 (2 × 404 HTML, contour.svg, favicon) |
| `/the-house` | 12 | 293 KB | 25.3 | 32.4 | 17.8 | 199.7 | 17.2 (3 × 404 HTML) |
| `/explore` | 12 | 285 KB | 19.0 | 32.4 | 23.1 | 199.7 | 9.7 (1 × 404) |
| `/house-manual` | 10 | 278 KB | 22.1 | 32.4 | 23.1 | 199.7 | 0 |

**Fonts are 70 % of every page**: `fraunces-latin-full-normal.woff2` 121 KB, `fraunces-latin-wght-italic.woff2` 46 KB, `dm-sans-latin-wght-normal.woff2` 37 KB. Lighthouse attributes ~1.05 s of simulated LCP to the font/CSS chain. With Brotli, HTML+CSS+JS shrink from ~75 KB to ~20 KB; woff2 does not, so fonts become ≈200 of ≈225 KB.

## Diagnostics

- **Render-blocking CSS** (all pages): `main.css` 28 KB (600–750 ms sim), `tokens.css` 3 KB (300 ms), `fonts.css` 1.7 KB (150 ms). Three sequential critical requests before first paint.
- **Unused CSS**: 45–63 % of `main.css` per page (12–18 KB raw, ~3 KB Brotli). **Unminified CSS/JS**: ~8 KB raw. Both low.
- **Forced reflow** 33–38 ms in `assets/js/main.js:25-28` (`onScroll` reads `window.innerHeight` after a `classList.toggle` write) on `/the-house` and `/explore`.
- **Main thread** 0.4–0.6 s; "Style & Layout" 134–228 ms. `/the-house` DOM is 1,885 nodes (15 inline SVG scenes). The fixed full-screen `.grain` `feTurbulence` filter with `mix-blend-mode` is a scroll-paint risk on low-end Android that Lighthouse doesn't measure.
- Unthrottled (Playwright, Pixel 7 emulation): LCP 88–144 ms, CLS 0 on all pages after a full scroll.

## Placeholder image 404s (expected)

| Page | 404s in initial viewport (Lighthouse) | 404s after full scroll | Bytes wasted (404.html body, 6.9 KB each) |
|---|---|---|---|
| `/` | 2 (hero, deck) | 10 | 53 KB |
| `/the-house` | 3 (hero, bed-1, bed-2) | 17 | 102 KB |
| `/explore` | 1 (beach) | 2 | 7.5 KB |
| `/house-manual` | 0 | 0 | 0 |

**Do they hurt?** Not Core Web Vitals: CLS is 0 because every `.frame` has `aspect-ratio`, each `<img>` has `width`/`height`, and the `is-missing` fallback swaps in the art cleanly. They do cost: (a) Best Practices 96 not 100 (console errors); (b) 50–100 KB of `404.html` per full scroll on `/` and `/the-house` (Vercel serves the same custom 404); (c) one wasted high-priority request in the hero's critical window. When real photos land the hero becomes the LCP element, so its weight decides whether LCP lands under 2 s or over 3 s — see fix 3.

## Prioritised fixes

1. **Cut font bytes (biggest LCP lever, est. −0.3 to −0.5 s).** `assets/css/fonts.css` + `assets/fonts/`: replace the fontsource "full" Fraunces build (all four axes) with a subset keeping only `wght`, `opsz`, `SOFT` (the site never sets `WONK`), or instance `opsz` 48/144 and `SOFT` 50 to the values actually used. The 46 KB italic serves three short strings (`.serif-i`, `.footer-tagline`); consider dropping it. Target ≤ 100 KB total fonts.
2. **Inline `tokens.css` and `fonts.css` in `<head>`** (5 KB, ~1.2 KB compressed), leaving `main.css` external. Removes two of three render-blocking round-trips (~450 ms simulated). Change `docs/build/build.py` (the template), not the generated HTML.
3. **Prepare the real hero for LCP now** in `docs/build/p_index.py`/`p_house.py`/`p_explore.py`: `<picture>` with AVIF/WebP, `srcset` 800/1200/1600/2400 w, `sizes="100vw"`, plus `<link rel="preload" as="image" imagesrcset=... fetchpriority="high">`. Budget: hero ≤ 150 KB at 1200 w, card images ≤ 80 KB. Note it in `assets/img/README.md`.
4. **Stop emitting `<img>` for missing photos.** In `docs/build/build.py`, render `<img data-fallback>` only when `assets/img/<name>.jpg` exists at build time; otherwise emit just the `.art` scene. Removes all 404s, console errors (BP → 100) and 50–100 KB per scroll.
5. **Fix the scroll reflow** in `assets/js/main.js:24-30`: cache `window.innerHeight` (refresh on `resize`), hoist `querySelector(".book-bar")` out of the handler, toggle only on state change. ~35 ms saved.
6. **Accessibility (95–98 → 100)**: `.brand` `aria-label="Pamusha Lake House — home"` doesn't contain the visible text — drop it or use "Pamusha Lake House · The Honeysuckles, home" (header + footer, via `build.py`). Footer `<h4>` follows `<h2>` — use `<h3>` or a styled `<p>`. One `.eyebrow` on `/the-house` fails contrast; check its colour in `assets/css/tokens.css`.
7. **Minify + purge** `main.css`/`main.js` in `build.py` (csso/esbuild): ~2 KB compressed. Low but free.
8. **Grain filter**: profile scroll on a mid-range Android; if frames exceed 16 ms, swap the SVG `feTurbulence` for a tiled ~2 KB PNG noise texture in `assets/css/main.css:35`.
9. **`assets/img/og.png` 370 KB** — off the load path, but shrink to < 200 KB for social crawlers.
10. **Guardrail**: Lighthouse CI on the Vercel preview with budgets — perf ≥ 95, LCP ≤ 2.5 s, CLS ≤ 0.05, total ≤ 300 KB, fonts ≤ 120 KB, zero 4xx — so the photo drop can't regress LCP silently.

Raw reports: scratchpad `perf/{home,house,explore,manual}.json`.
