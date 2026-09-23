# Placeholder work photos

Until pros upload their own work, every tile in the app (Home, profiles,
bookings, Pro mode) can show a real photo instead of the drawn gradient art.

## How it works

`WorkTile` looks for a bundled image named `work-<category>-<n>` before falling
back to the art. Files live in `HairDone/Resources/Work/`:

| Category | Files | Show |
|---|---|---|
| nails | `work-nails-1.jpg` … | hands, polish, gel, acrylics, a lamp |
| hair | `work-hair-1.jpg` … | braids, blow-dries, colour, cuts, from behind |
| makeup | `work-makeup-1.jpg` … | a brush on a cheek, a lip, lashes going on |
| lashes | `work-lashes-1.jpg` … | closed eye, tweezers, a finished set |
| brows | `work-brows-1.jpg` … | threading, lamination, a tinted brow |
| thelot | `work-thelot-1.jpg` … | getting-ready scenes, bridal prep, mirrors |

A pro's tiles pick from her category by a stable seed, so Kiara's grid always
shows the same mix. Three to five photos per category is enough; one is fine.

## Where to get them

Free, licensed for this, no attribution required: Unsplash and Pexels (check
the licence line on each photo's page). Search terms that work:

- nails: "gel manicure close up", "nail polish application", "acrylic nails hand"
- hair: "braiding hair close up", "blow dry salon", "balayage back view"
- makeup: "makeup artist brush cheek", "lipstick application close up"
- lashes: "lash extensions application"
- brows: "eyebrow threading", "brow lamination"
- thelot: "bride getting ready", "getting ready mirror"

Rules from brand.md: hands and hair, not faces to camera; natural light;
women of different ages and skin tones across the set; no product shots, no
logos, no ring lights in frame. Portrait or square crops work best.

## Fastest: one command with a Pexels key

```bash
PEXELS_API_KEY=your_key tools/fetch-photos.sh
```

Free key in a minute at https://www.pexels.com/api/. Downloads four portrait
photos per category with curated searches and runs the naming and resizing.
Swap any you don't like by hand afterwards; the names just need to stay 1, 2, 3.

## Adding them (on the Mac)

```bash
tools/add-photos.sh nails ~/Downloads/nails
tools/add-photos.sh hair ~/Downloads/hair
# ...one folder per category
xcodegen generate
```

The script renames, converts to JPEG and resizes to 1200 px on the long side.
Then build; the tiles show the photos. Remove a category's files and it goes
back to the art.

## Not bundled from here

The build environment can't reach Unsplash, Pexels, Wikimedia or any image
host, and generating images needs a paid Higgsfield plan, so this folder ships
empty. Twelve photos take about ten minutes to collect on the Mac.
