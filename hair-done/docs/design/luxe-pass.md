# Luxe pass: why build 21 reads as "a nice app" and what changes

Answers to `../build-brief.md` §4 and `../brand.md`. Where this file changes a number the brief set (radius, gutter, section gap, a font size), this file wins and the brief should be updated to match; the tokens and the brand rules it doesn't mention stand.

Written by the UI designer, with the brand guardian reading over the shoulder and the whimsy injector allowed one sentence at the end. Judged from the six TestFlight screenshots and the code that draws them. The gradient tiles are placeholder art; everything below is judged as if they held photos.

## 1. Diagnosis

The headline: the welcome screen is the only screen that behaves like the brief ("magazine, not marketplace"), and nothing after it inherits its confidence. Once you're inside, every unit of content is a white 20pt-radius card with 16pt padding on a cream background, the serif stops working below the page title, and colour is spent on tints, pills and badges instead of saved for one red button. The result is competent, friendly and indistinguishable from a food-delivery app with a nice font.

The specific problems, by screen.

### 1. Home: the type scale has no jumps

"Morning, Mati." is 34pt serif. The next serif on the page, "Who's free today", is 20pt. Everything else is 13 to 17pt sans. Luxe editorial type works by contrast: one enormous line, then tiny quiet text, and almost nothing in between. Here the steps are 34 → 20 → 17 → 15 → 13, five sizes within a factor of 2.6, so nothing on the screen is clearly the headline and nothing is clearly the fine print. Pro names, the words a person says out loud, are 17pt SF semibold on every card, which the brand doc explicitly says should be serif.

### 2. Home: the suburb line is a weather app

"📍 Southern Ward" in 15pt sans with a filled location glyph, directly under the greeting. It's the pattern every ride-share and delivery app uses. The suburb should be an eyebrow: 12pt, tracked, uppercase, quiet, above or below the headline.

### 3. Home: card on paper, everywhere

Search field: white box, radius 14. Next up: white card, radius 20. Every pro: white card, radius 20. List/Map: white capsule. On a cream background the white boxes outnumber the paper, so paper stops reading as a considered choice and starts reading as "off-white". The brief's own rule is "hairlines over boxes, air over borders". There is not one hairline on Home.

### 4. Home: the category row is a kids' activity picker

Six tinted 132×112 tiles with an SF Symbol in the top-left (scissors, a hand, a paintbrush) and a bold label at the bottom. The tints are pastel (beige, pink, lilac, periwinkle, mint, cream) and sit at equal saturation in a row. This is the most "marketplace" object in the app. A magazine would set the six words in the serif and underline the one you're in.

### 5. Home and Bookings: pill overload

Counted on the Bookings screenshot: two ink-filled segment pills, three "Confirmed" pills in pink-with-red, one "Requested" pill in yellow-with-orange, a lacquer border on today's card, a lacquer dot, and the system red badge on the tab bar. That is six red objects on a screen whose brand rule is "if two things on one screen are lacquer, one of them is wrong". On Home the "Free today" label sits on the photo in a paper capsule; the Work screen has "Cover" and "Pinned" capsules overlapping each other on one tile (and "Pinned" wraps). Status is information, not a button; it should be tracked text with, at most, a 5pt colour dot.

### 6. Home: the pro card is four things fighting

Photo strip (clipped to the card's top radius), then in one 16pt-padded box: a tinted initials avatar, name, specialty line, honey star + rating + count + distance, and "from $60" stacked at the right. The avatar repeats what the three photos already say. The star is a fourth colour. Nothing is large and nothing is quiet: name 17 semibold, price 17 semibold, rating 15 semibold. The photos can't bleed because the card owns them.

### 7. Who's free and Favourites: story-ring tiles

150×150 tile, radius 16, tinted initials circle overlaid bottom-left with a white ring. It's the Instagram story pattern. The photo should be the tile (portrait, 4:5), the name in serif beneath it, and nothing on top of the photo.

### 8. Colour: candy where there should be stone

Category tints (#EAD9CB, #F3D0CB, #E8D2DF, #D8D4E5, #D9DED0, #EFE3C8) are all at the pastel end. Against paper they read sweet, not warm. The status tints (lacquerSoft pink, warnSoft yellow, successSoft mint) are the same register. Luxe beauty palettes desaturate: stone, oat, rose-brown, mauve, sage, sand. About 12 to 15% less saturation and 5 to 8% darker moves the same six hues from "nursery" to "linen".

### 9. Paper and hairlines are too close

`line` (#E8DFD5) on `paper` (#F8F3EC) is a 1.06:1 contrast. It disappears, which is why every surface grew a white box to be seen. If hairlines are going to replace cards, they need to be visible: about #E2D8CC.

### 10. Profile: the cover is a mosaic, not a cover

Four photos in a 2×2 with 3pt gaps at 360pt tall, a tinted avatar with a paper ring overlapping the bottom edge, then the name at 28pt with a green "ID checked" seal beside it, then five capsules ("Instant book" in pink, "Replies in about an hour", "212 done"). Reviews are white cards with avatar, name, stars, date, text, a service tag and a reply. It's a LinkedIn profile with photos. A magazine profile is one big photo, the name as the headline, the facts as a quiet line, and the reviews as pull quotes separated by hairlines.

### 11. You: card inside card

A white settings card, then a white Favourites card containing tiles, then a pink Pro mode card with a red hairline. The 72pt "MO" avatar is visually larger than the name beside it. Three boxes, three fills, three radii of 20.

### 12. Motion: the press-scale is the only idea

Every button and card scales to 0.97 on press. Nothing on Home is revealed; sections just exist. The profile cover is fixed; pulling down shows paper above it. The lacquer check on "You're booked" is the one considered moment and it's the right one; Home and the profile need one each.

Two things that are right and should not be touched: the welcome screen (video, wordmark, one italic word, one lacquer button) and the copy, which is the most luxe thing in the app.

## 2. Direction: quiet editorial

Stays inside the brand: paper, ink, one lacquer, serif display, hairlines, the Australian voice. Moves it from "warm marketplace" to "quiet editorial". The references are Net-a-Porter's and SSENSE's product pages, Aesop's site and The Row's app: big photographs, one huge serif line per screen, tiny tracked eyebrows, hairlines instead of boxes, numbers set large and regular, one accent used about once.

### Type

All styles are built on system text styles or `UIFontMetrics`, so Dynamic Type still works. Serif is New York (system `.serif`). Sans is SF.

| Style | Face | Size / weight | Use |
|---|---|---|---|
| `display` | serif | 44 regular, scaled to `.largeTitle` | The Home greeting. One per app. |
| `hero` | serif | 38 medium, scaled to `.largeTitle` | Screen titles: Bookings, You, Work. The pro's name on her profile. |
| `title` | serif | 28 medium (`.title`) | Sheet titles. |
| `heading` | serif | 24 medium, scaled to `.title2` | Section headers. Was 20. |
| `name` | serif | 20 medium (`.title3`) | Pro names in lists and tiles. Category words on Home. |
| `serifItalic` | serif | 20 italic | The pro's one-line headline. Photo captions in the viewer. |
| `serifBody` | serif | 17 regular | Review quotes. |
| `italicSub` | serif | 15 italic | Section sub-lines: "Closest first", "Pick as many as you like." |
| `numeral` | serif | 28 regular, monospaced digits | Totals, the rating on a profile. Regular weight; numbers are never bold. |
| `body` / `bodyStrong` | SF | 17 regular / semibold | Body. Buttons use `bodyStrong`. |
| `sub` / `subStrong` | SF | 15 | Meta lines. |
| `caption` | SF | 13 | Fine print. |
| `price` | SF | 17 regular, monospaced digits | Prices in rows. Was semibold. |
| `label` / `eyebrow` | SF | 12 medium, uppercase, tracked 1.5 | Eyebrows and status. `inkSoft`. |

Italic: one word in one serif headline per screen, on the word you'd lean on. On Home it's her name. Never in the wordmark.

### Space and shape

- Gutter 24 (was 20). Section rhythm 44 (was 32). Card padding 20.
- Radius: card 12 (was 20), tile 6 (was 16), input 10, chip 8 (a soft rectangle, not a capsule). The only capsule left is the primary button.
- A card is allowed when content needs a boundary to be understood as one unit: a receipt, a settings group, a form. It is a hairline on paper, no fill. It is never used to separate list items; those get air (24 to 36pt) and, where they'd blur together, a hairline.
- Photos in lists bleed edge to edge. Text sits in the gutter beneath them.

### Colour

- Lacquer: the primary button, the selected service check, the saved heart, the underline on a text link. Not status, not tags, not borders, not "Instant book".
- Status is ink text, tracked, with a 5pt dot in the status colour. Cancelled is `inkSoft` with no dot.
- Tints, light: hair #DCCFC2 (stone), nails #DDC4BC (rose-brown), makeup #D6C7CE (mauve), lashes #CFCBD6 (grey lilac), brows #CBD0C3 (sage), the lot #DED3BC (sand). That's roughly 12 to 15% less saturation and 5 to 8% less lightness than the brief's values. Dark values move the same way. They are used on Pro-mode chips and placeholder art; they no longer appear on Home.
- `line` #E2D8CC light (was #E8DFD5): visible on paper without being a border.
- Soft status tints (`lacquerSoft`, `successSoft`, `warnSoft`) drop toward the paper: #F1DBD7, #E0E9E1, #F0E5D2.
- Honey stays honey (brief token) but appears only in five-star rows and the picker. The compact rating line uses a small ink star.
- Paper and card tokens are unchanged. Card white is still used for message bubbles and controls that sit over photos.

### Images

- Radius 6 in grids, 0 when bleeding. Profile work grid: 2pt gaps, radius 2.
- Aspect: portrait 4:5 for tiles (who's free, favourites), 3:2 for the pro card strip, 3:4-ish for the profile cover.
- Nothing on the photo: no avatar, no capsule, no caption. The "free today" line becomes an eyebrow above the name.
- Cover: one dominant photo with two supporting ones, 440pt, stretches on pull.

### Components

- Primary button: keep the pill. It's the welcome screen's shape and the one soft object per screen. Height 54, lacquer, `bodyStrong`.
- Secondary button: ink 1pt outline on paper, no fill.
- Chips: hairline soft rectangle (radius 8), `sub` medium, no fill; selected is ink fill with paper text. Category chips in Pro mode keep their tint as the fill.
- Status badge: dot + tracked text. Verified: outline seal in `inkSoft` and tracked "ID checked". Tags: tracked text with no background unless the caller passes one (the "Cover" tag on a photo still gets its paper).
- Section header: 24pt serif, optional italic serif sub-line, action as ink text with an underline.
- Empty state: a 6pt lacquer full stop above a 24pt serif line. No SF Symbol.
- Price row: totals in `numeral`; line items in `price` (regular).
- Rating line: 10pt ink star, "4.8" `sub` medium, "121 reviews" `sub` soft.

### Tab bar

System tab bar, unchanged in structure. Outline glyphs at regular weight (`.environment(\.symbolVariants, .none)` on the shell so selection doesn't swap to filled), labels kept, tint lacquer. The unread badge stays system red; there's no supported way to recolour it and a fake badge would be worse. This lives in `App/RootView.swift`, which is outside this pass; it's a two-line change for the next one.

### Motion

- Home: on first appear the greeting rises 10pt and fades in over 0.55s, and each section follows at 60ms intervals. Once per launch, never on tab return. Off under Reduce Motion.
- Profile: the cover stretches with the pull (scroll-driven, so it's not an animation under Reduce Motion), and the name block rises in 100ms after the cover. The saved heart still bounces.
- Everything else keeps the brief's spring and the press-scale.

The whimsy injector's one sentence: the greeting leans on her name in italic, because that's what your most put-together friend does when she says good morning.

## 3. What this pass changed in code

Tokens: `Palette` (tints, line, soft status colours), `Typography` (the scale above, tracked labels), `Layout` (gutter, section, radii, hairline card, `reveal()`). Components: `Buttons`, `Chips`, `Stars`, `ProCard`, `ProMiniTile`, `Bits`. Screens: `HomeView`, `ProProfileView`. Every component keeps its initialiser and property names, so Bookings, Account, Inbox, Booking and Pro mode pick up the new drawing without edits. No copy changed.

Not done here, on purpose: the tab bar glyph weight (`RootView`, out of scope), the You screen's three stacked cards (Account is out of scope; it gets hairline cards for free and needs its own pass to drop the Favourites and Pro-mode boxes), and the Work screen's overlapping tags (the tag redraw stops "Pinned" wrapping, but the two tags should be one line of tracked text under the tile, which is Pro-mode work).
