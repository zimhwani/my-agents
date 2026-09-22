# App icon: the three-dot proposal, three alternatives, a ranking

Answers to `../build-brief.md` (§2 names, §4 look) and `../brand.md` (the mark, the wordmark). Where this file and those disagree, they win, except where this file proposes changing them, which it says out loud in §7.

Written by the UI designer with the brand guardian reading over the shoulder. Opinionated on purpose. The founder is free to disagree with §6.

## 1. What we're actually designing

The name is the Drake line from "Fancy": *nails done, hair done, everything did.* The brand is the woman who is completely put together, every single thing ticked off, and the pro who comes to her to make that happen. The wordmark is three lines that each end in a full stop:

```
hair done.
nails done.
everything done.
```

Four marks have been on the table:

| | What | Why it went |
|---|---|---|
| v1 | Lacquer nail-polish teardrop | Read as a drop of blood, worst on dark |
| v2 | One lacquer full stop (the "." from *done.*) | Too abstract; says nothing on a home screen of forty icons |
| — | "hd" monogram | Reads as hair only |
| v3 (proposed) | Three stacked lacquer full stops, one per line of the wordmark | This document |

The founder also floated using Apple's emoji for hair, nails and lashes. Apple's emoji artwork is Apple's copyright and App Review will not take it in an icon; two of the three contain a face or an eye, which the brand bans; and three emoji is three ideas in one square. But the instinct under it is right and it drives this whole document: the nail-polish emoji is the internet's shorthand for the lyric. That is why one of the concepts below is a nail-polish bottle, drawn by us.

### What an icon has to do here

An icon is seen at 60 pt among forty others, with the label `Hair Done` under it. Five jobs, in order:

1. **Be nameable.** A stranger glancing at it should say what kind of app it is. (This is the criterion v2 failed.)
2. **Not say the wrong thing.** Not blood, not medical, not a menu, not a checklist. (This is the criterion v1 failed.) A wrong reading is worse than a null reading: a null reading is rescued by the label, a wrong reading fights it.
3. **Survive 60 pt and 29 pt** as a shape, and, better, as a meaning.
4. **Be ours.** Paper, ink, one lacquer red, the DropMark highlight, lowercase serif. No gradients, no faces, no emoji.
5. **Pair with the label.** The unit is icon + `Hair Done`, not the icon alone.

**On "she comes to you":** none of the four marks carries the mobile promise, and none should try. Everything that says "comes to you" in a 60 pt square is a map pin, a car, a door or a doorbell, which is Uber, Airtasker, a real-estate app or a smart-home camera. That is "marketplace", and the brief says "magazine, not marketplace". The icon carries one idea; the App Store subtitle, the first screenshot and the label carry the rest. I am not scoring any concept on this and neither should the founder.

## 2. The three stacked full stops, honestly

Geometry as proposed: three lacquer circles, diameter 0.16 of the canvas, 0.10 gap, in a column at the centre, each with the DropMark highlight.

**Does it carry "everything done"?** Only to someone who already has the wordmark in their head. The full stops mean "done" because they end the words *done.* three times. Take the words away and three full stops are three circles. The meaning was borrowed from the type and the icon has no type. This is exactly v2's failure, with the abstraction multiplied by three, not divided.

**Does it carry "come to you"?** No. Nothing in a column of dots moves, arrives or knocks.

**Does it survive 60 pt?** As shapes, perfectly: at 60 pt each dot is about 10 px, at 29 pt about 5 px, highlights gone but circles crisp. As a meaning, no, because at every size it reads as the thing below.

**What a stranger thinks it is**, in the order I'd expect from a five-second test:

1. The overflow menu. Three vertical dots is the "more" button on every Android phone, every Google product, every web app since 2014. In red, on cream, it is a red kebab menu. This is not a risk, it is the reading.
2. A traffic light with the colours taken off.
3. A loading indicator.
4. A domino or a die.
5. Three drops. Three red dots in a line on skin-coloured paper are spots. The blood worry that killed v1 is not gone here; it is one dot away from a rash.

Not one of those five is "beauty". Under the label it reads as `Hair Done ⋮`, an app with more options.

**It also breaks the brand's own rule.** `brand.md`, the mark: "Never … pair it with a second dot, use it as a bullet." Three dots is two extra dots and, arranged in a column, they are bullets. The brand guardian would bounce this on the rule before getting to taste.

**What it does have.** It is honest to the wordmark's structure; nobody in beauty owns it; it scales; it is quiet. Those are the virtues of a mark that already means something. On a home screen it has to earn meaning, and it can't.

**If the founder keeps it anyway**, the one repair worth trying: don't stack them in a column. The wordmark is left-aligned and ragged right, so the three full stops sit at three different x positions. In New York Medium the lines measure roughly 4.55 em, 4.95 em and 7.4 em, so with the block spanning x 0.30 to 0.70 the dots land at about x 0.545, 0.568 and 0.70, on rows y 0.32, 0.50, 0.68. That breaks the kebab reading and tells the truth about the words. It is also lopsided: two dots nearly aligned and one far right, which reads as a broken ellipsis. I would test it and I would not ship it.

## 3. Concept A: the bottle

**Name:** *Lacquer.* (Working name; nobody outside this doc needs to know it.)

**Rationale.** The lyric's shorthand is the nail-polish emoji; the emoji's object is the bottle; the brand's accent colour is literally called lacquer. A polish bottle is the one beauty silhouette a stranger names correctly at 29 px, and it is a container, not a drop, so the blood reading that killed v1 has nowhere to start. Under the label it reads `Hair Done` + nails, which is the first two lines of the wordmark; "everything" is implied by the pair and stated by the subtitle. We make it ours by proportion (squat body, tall plain cap, no brush, no label, no ridges), by the DropMark highlight, which makes the bottle and the in-app full stop one family, and by the palette.

**Geometry.** Canvas 1024 × 1024 filled `paper`. Square corners in the source; Apple applies the mask. Everything is a fill; there are no strokes. All fractions are of 1024, pixels in brackets.

| Part | Shape | x | y | Radius | Fill |
|---|---|---|---|---|---|
| Cap | Rounded rect, w 0.24 (246), h 0.28 (287) | 0.38–0.62 (389–635) | 0.10–0.38 (102–389) | 0.05 (51), all corners | `ink` |
| Neck | Rect, w 0.16 (164), h 0.10 (102) | 0.42–0.58 (430–594) | 0.36–0.46 (369–471) | 0 | `ink` |
| Body | Rounded rect, w 0.44 (451), h 0.40 (410) | 0.28–0.72 (287–737) | 0.44–0.84 (451–860) | 0.10 (102), all corners | `lacquer` |
| Highlight | Ellipse, w 0.088 (90), h 0.132 (135), rotated 22° | centre 0.425 (435) | centre 0.552 (565) | — | white at 0.85 opacity |

Draw order: cap, neck, body, highlight. The neck overlaps the cap by 0.02 and the body by 0.02 so there is no seam. The highlight is the DropMark rule applied to the body: ellipse 0.2 × 0.3 of the body width, rotated 22°, offset (−0.17, −0.20) of the body width from the body centre (0.50, 0.64).

Group bounds: y 0.10 to 0.84, x 0.28 to 0.72. The visual centre sits at about y 0.47, slightly high, which is right for a top-heavy object.

**Light:** paper `#F8F3EC`, cap and neck `#241A16`, body `#C8323A`.
**Dark:** paper `#171210`, cap and neck `#F4ECE4`, body `#E2504F`.
**Tinted (iOS 18):** one layer, the union of cap, neck and body, as the mask. No highlight.
**Below 40 px:** drop the highlight. Nothing else changes.

**At 60 pt and 29 pt.** Rendered and checked: the cap-over-body silhouette holds at 29 pt on white and on black wallpaper. It is the only one of the four that a stranger names at that size.

**Weakness.** Three, and the founder should weigh them. It says nails, not hair, and it is the same objection that sank "hd", answered only by the label. It is a product, and the brand's photography rule says "Product. There isn't one." (that rule is about photos, but the guardian will raise it: Hair Done sells a woman, not a bottle). And it is the category cliché: half the nail-salon booking apps in the App Store use a bottle. Ours is distinguishable by the proportions and the highlight, not by the idea. A fourth, smaller: a squat body with a tall cap can read as perfume, which is at least still beauty.

## 4. Concept B: "d."

**Name:** *done.*

**Rationale.** The promise is the word "done" and the brand already owns the full stop. A single lowercase serif "d" followed by the lacquer full stop is the wordmark reduced to two marks: the first letter of the word every line ends with, and the stop. It is the only concept that says "done" to a stranger rather than "nails", and it is the most on-system: the serif, the lowercase, `ink` on `paper`, the lacquer stop with its highlight, exactly as the wordmark sets it. It looks like the magazine the brief asks for.

**Geometry.** Canvas 1024 × 1024 filled `paper`.

| Part | Spec |
|---|---|
| Glyph | Lowercase "d", New York Medium (`Font.system(size: 740, weight: .medium, design: .serif)`), converted to outlines. Do not ship live text; Apple's serif changes between OS versions. |
| Glyph box | Scale so the ascender top sits at y 0.22 (225) and the baseline at y 0.76 (778): glyph height 0.54 (553). In New York Medium that is about 740 pt; measure the rendered glyph, don't trust the number. Leftmost ink at x 0.24 (246). Fill `ink`. |
| Full stop | Circle, diameter 0.12 (123). Left edge 0.03 (31) to the right of the glyph's rightmost ink. Bottom tangent to the baseline, so centre y 0.70 (717). With New York Medium the glyph's right edge lands near x 0.64, putting the dot centre at about (0.73, 0.70) (748, 717). Fill `lacquer`. |
| Highlight | DropMark rule on the dot: ellipse 0.024 × 0.036 (25 × 37), rotated 22°, centre offset (−0.021, −0.024) from the dot centre, about (727, 692). White at 0.85. |

Check the group's optical centre lands between x 0.49 and 0.52; nudge the whole group, never the gap.

**Light:** `ink #241A16`, `lacquer #C8323A` on `#F8F3EC`.
**Dark:** `#F4ECE4`, `#E2504F` on `#171210`.
**Tinted:** glyph and dot as one mask.
**Below 40 px:** drop the highlight; keep the dot, it is the point.

**At 60 pt and 29 pt.** Rendered and checked: "d." is legible at both, though at 29 pt the stop is a 3 px fleck and the icon is mostly a letter.

**Weakness.** It is a letter. Letter icons are the busiest genre on a home screen, and to a stranger it says nothing about beauty; it is a null reading rescued only by the label, which is the failure the founder named for v2. A red-and-cream "d" has a faint DoorDash echo. Lowercase "d" on its own also reads draft, delete, dictionary. And it adds a second typographic asset to police: kerning, weight, the glyph's shape across OS versions.

## 5. Concept C: the nail

**Name:** *Nails done.*

**Rationale.** The only object in the lyric that is a *done state* rather than a tool: a painted nail is the result. It is the full stop stretched into the shape it belongs on, wearing the same highlight, in the same lacquer, so mark and icon are visibly one thing. No hand, because a hand forces a skin-tone choice, which is why Apple ships the emoji in six, and an icon can only ship one.

**Geometry.** Canvas 1024 × 1024 filled `paper`.

| Part | Spec |
|---|---|
| Plate | One path: rounded rect w 0.48 (492), h 0.62 (635), x 0.26–0.74 (266–758), y 0.19–0.81 (195–829). Top corner radii 0.24 (246), i.e. half the width, a fully round tip. Bottom corner radii 0.11 (113), a soft square base. Fill `lacquer`. Build it as a single `UnevenRoundedRectangle`, not a circle on a rectangle, or there is a seam at the shoulders. |
| Lunula | Ellipse w 0.34 (348), h 0.16 (164), centre (0.50, 0.81) (512, 829), clipped to the plate so only the upper half shows. Fill white at 0.60. |
| Highlight | Ellipse 0.096 × 0.144 (98 × 147), rotated 22°, centre (0.418, 0.326) (428, 334). White at 0.85. |

Upright. I rendered a version tilted −10° for a hand-held-up feel; it reads as a capsule falling over. Don't.

**Light / dark:** as the bottle. **Tinted:** the plate as the mask. **Below 40 px:** drop the highlight, keep the lunula.

**At 60 pt and 29 pt.** Rendered and checked, and this is where it falls down. At 180 px, with the lunula, it is a nail. At 60 pt it is a red glossy rounded shape with a pale base, and the honest readings are gel capsule, thimble, suppository. At 29 pt the lunula is a smudge and it is a red pill. I tried it wider, squarer, tilted; a glossy red arch-topped shape is a capsule at small sizes and nothing short of drawing the finger fixes it.

**Weakness.** Medical. That is on the founder's banned list by name, and it is the same species of failure as v1: a shape that becomes something else at the size that matters. Also nails-only, like the bottle, without the bottle's instant nameability. This was the concept I wanted to win. It doesn't.

## 6. Ranking

Scored 0–3 per criterion. The hazard column is scored on wrong readings, not null ones, and I weight it double because a wrong reading fights the label.

| | Nameable at 60 pt | Says "done" | No wrong readings (×2) | Ours, not a cliché | On the system | Survives 29 pt | Pairs with `Hair Done` | Total |
|---|---|---|---|---|---|---|---|---|
| **A. Bottle** | 3 | 1 | 3 (6) | 1 | 2 | 3 | 3 | **19** |
| **B. "d."** | 0 | 3 | 2 (4) | 2 | 3 | 2 | 1 | **15** |
| **C. Nail** | 2 | 2 | 1 (2) | 2 | 3 | 1 | 3 | **15** |
| **Three dots** | 0 | 1 | 0 (0) | 2 | 1 | 3 | 0 | **7** |

Tie-break between B and C: the nail's wrong reading is on the banned list; the "d." merely under-communicates. A null reading beats a medical one.

**1. The bottle. 2. "d." 3. The nail. 4. Three stacked full stops.**

### Recommendation: the bottle

Ship the bottle, and here is the argument the founder can push back on. The icon's job on a home screen is to be found and named in a glance by a woman who has forty other icons and no interest in our wordmark's punctuation. The bottle is the only mark of the four that strangers name correctly at 29 px, on light and on dark, and it cannot become blood, a pill or a menu, because it is a container with a cap. Yes, it says nails and not hair; the label under it says `Hair Done`, and together they are the first two lines of the wordmark, which is more of the lyric than any other pairing gets. Yes, it is a product, and the brand sells a person; but nobody has ever mistaken a polish-bottle icon for a shop, and the app's first screenshot is a pro, not a bottle. Yes, it is the category's cliché; we answer that with proportion (a squat body under a tall plain slab of a cap, no brush, no ridges, no label), with the DropMark highlight that makes the bottle and the in-app full stop one family, and with a palette nobody else in the category has. The three dots are the better brand idea and the worse icon; the founder has already rejected two marks for saying nothing on a home screen and should not accept a third for the same reason. Keep the full stop as the in-app mark. Let the bottle be the thing you tap.

If the founder wants it settled by evidence rather than by me: five-second test, ten women who have never seen the app, the icon at 60 pt among real icons, one question, "what do you think this app is for?" Ship whichever mark gets "nails", "beauty" or "getting ready" most often. I would bet on the bottle and I would not bet on the dots.

## 7. Production notes

- Source: 1024 × 1024 PNG, opaque, square corners. iOS masks to its own radius (about 0.2237 of the side); nothing important within 0.10 of an edge. All four concepts respect this.
- Sizes iOS actually shows: 180 px (home, 60 pt @3x), 120 px, 87 and 58 px (settings), 60 and 40 px (notifications), 29 pt in Spotlight on older devices. Judge at 60 pt and 29 pt, not at 1024.
- Provide light, dark and tinted variants in the asset catalogue (Xcode 16 `AppIcon` with all three appearances).
- Paper on a white wallpaper: the icon's edge is defined by the warm tint alone and is faint. Acceptable, and consistent with the brief ("on paper"), but test on the iOS default wallpapers, not on cream.
- `brand.md`, the mark section, currently specifies the app icon as the single full stop low and right. Whichever concept ships, that paragraph gets rewritten, and the "never pair it with a second dot" rule stays; it is a good rule and the three-dot proposal is the proof.
- The in-app `DropMark` view and the wordmark's lacquer final stop do not change under any of these. The icon is not the mark.
- No strokes anywhere. If an engineer reaches for a stroke, the spec is wrong, not the engineer.
