# Caddie ⛳

A mobile-first, offline-friendly on-course golf caddie. First course: **Mt Derrimut Golf & Community Club** (Derrimut, VIC).

It's a single self-contained `index.html` — no build step, no server, no dependencies. Open it in a browser, or add it to your phone's home screen and use it walking the course. All state (scores, your club distances, tee choice, theme) is saved in the browser's `localStorage` on that device.

## Features

- **Hole-by-hole caddie** — big rangefinder-style distance readout per selected tee, par, stroke index, and a written strategy note for every hole. Signature holes (the par-3 9th between two stone walls, the short par-4 11th with lake + wall) and back-nine water are flagged.
- **Distance → club matcher** — enter the distance to the pin and it suggests the club from *your* bag, telling you whether you're dialled in, need to club up, or should ease off. Par 3s pre-fill with the hole distance.
- **My bag** — set your realistic carry distances (metres) for each club; add/remove clubs. These drive the matcher.
- **Live scorecard** — tap the score stepper on each hole; a full 18-hole card shows running totals, front/back nines, and score-to-par with birdie/bogey markers.
- **Tee selector** — Blue (Championship), White (Men's), Red (Women's).
- **Light / dark / auto** themes, tuned for reading a phone in bright sun or at dusk.

## Course data

Blue-tee distances, par and stroke index are the official scorecard (par 72, 6,776 m from the blue tees; designed by Craig Parry & Pacific Coast Design, opened 2007). White and red per-hole distances are **estimated** by scaling the tee totals (shown with a `≈` in the app) until exact per-hole figures are added. Confirm hazards and pin positions on the day.

## Adding another course

Course content lives in the `COURSES` array near the top of the `<script>` in `index.html`. Append an object with the same shape:

```js
{
  id: "unique-slug",
  name: "Course Name",
  location: "Suburb, STATE",
  par: 72,
  designer: "…",
  address: "…",
  tees: [
    { id: "blue",  name: "Blue",  label: "Championship", total: 6776, rating: 73.0, slope: 127, factor: 1 },
    { id: "white", name: "White", label: "Men's",        total: 6275, rating: 70.0, slope: 124, factor: 6275/6776 },
    // …
  ],
  holes: [
    { par: 4, si: 4, blue: 406, play: "Caddie strategy note…",
      feature: { type: "water", tag: "Water carry", text: "…" } /* optional */ },
    // …18 holes
  ]
}
```

- `blue` is the exact metres from the reference (blue) tee; other tees are derived from `factor` (`total / blueTotal`). Swap to exact per-hole distances any time.
- `si` is the stroke index (hole handicap).
- `feature` is optional; `type` is `"water"` or `"sand"` and controls the icon/colour.

The course picker in the header appears automatically once more than one course is present.
