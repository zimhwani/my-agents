# Target State Product & Proposition — Executive Deck

An executive/leadership slide deck articulating a member-owned (mutual) bank's
target state across two elements:

1. **The retail product suite** — what we look like as a product house
   (on-sale catalogue → member-type coverage → target-state ambition).
2. **How we show up in the market** — moving from vanilla, basic banking to a
   distinctive, member-owned proposition (the "second view").

## Files

- `Target-State-Product-and-Proposition.pptx` — the deck (16 slides, 16:9).
- `build.js` — the generator (pptxgenjs) used to produce it.

## Narrative flow

| # | Slide |
|---|-------|
| 1 | Title |
| 2 | Executive summary — where we are / where we're headed |
| 3 | The framework — two elements, two lenses |
| 4 | Divider: Element 01 — The retail product suite |
| 5 | On-sale product catalogue today |
| 6 | Strong on the basics, thin at the edges |
| 7 | The member types we serve |
| 8 | Suite × members coverage matrix |
| 9 | What a complete suite looks like |
| 10 | Divider: Element 02 — How we show up in the market |
| 11 | Today we show up as vanilla banking |
| 12 | Two views — vanilla vs. differentiated |
| 13 | The proposition that is unmistakably ours |
| 14 | The target state on a page |
| 15 | Three horizons to get there |
| 16 | What we're asking of leaders |

## Placeholders to replace

The content is a strategic **framework with illustrative content**. Before
presenting, swap in your specifics:

- `[Bank Name]` and `[Month Year]` throughout.
- Slide 5 — the on-sale product list per category.
- Slide 7 — member segment taxonomy.
- Slide 8 — the product-to-segment coverage assessment.
- Slide 15 — horizon scope and timing.

## Regenerate

```bash
npm install pptxgenjs react-icons react react-dom sharp
node build.js
```
