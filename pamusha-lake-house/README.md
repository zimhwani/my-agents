# Pamusha Lake House — website

Static, dependency-free site (HTML + CSS + vanilla JS, no build step) for the
Pamusha Lake House holiday home at The Honeysuckles, Gippsland Lakes, Victoria.

```
pamusha-lake-house/
├── index.html          Home — hero, story, spaces, hot tub, setting, reviews, enquiry
├── the-house.html      Rooms & spaces in detail, amenities
├── explore.html        Lakes, beach, towns, wildlife, seasons
├── house-manual.html   Guest guide (Wi-Fi, arrival, how things work, emergency, checkout)
├── assets/css, js, img
├── docs/               Research brief, brand system, UX spec (not deployed)
└── vercel.json         Static-site config for Vercel
```

## Deploy to Vercel

**Path A — Vercel Git integration (no secrets, recommended)**
1. vercel.com → *Add New → Project* → import `zimhwani/my-agents`
   (the repo is already connected to Vercel from the earlier marketing sites,
   so it appears in the import list).
2. Set **Root Directory = `pamusha-lake-house`**, Framework Preset = *Other*.
   Leave build and output settings blank; `vercel.json` in this folder already
   declares a static site.
3. Under *Git*, set the **Production Branch** to `main` (after merging) or to
   `claude/sharp-johnson-vxg480` to go live from this branch straight away.
4. Deploy. Every push to that branch redeploys automatically.

Same thing from the Mac terminal, if you prefer the CLI you used for other projects:

```bash
cd my-agents/pamusha-lake-house
vercel link          # create a new project named pamusha-lake-house
vercel git connect   # attach zimhwani/my-agents so pushes deploy
vercel --prod        # first production deploy now, without waiting for a push
```
Then set Root Directory = `pamusha-lake-house` in the project settings once.

**Path B — GitHub Actions** (`.github/workflows/pamusha-deploy.yml`)
Add repository secrets `VERCEL_TOKEN` and `VERCEL_ORG_ID` (and, after the first
deploy, `VERCEL_PROJECT_ID`). The workflow then deploys on every push that
touches this folder. Until the secrets exist it no-ops.

**Custom domain:** after deploying, add your domain in Vercel → Project →
Domains, then point the domain's DNS (currently at GoDaddy) at Vercel.

## Add your photography

Drop JPGs into `assets/img/` using these file names, then run
`python3 docs/build/build.py` once so the pages pick them up (the build only
emits an image tag for files that exist, so nothing 404s). Each slot shows
designed placeholder art until then:

| File | Used for |
|---|---|
| `hero.jpg` (2400×1500) | Home hero — lake at dusk from the deck |
| `deck.jpg`, `living.jpg`, `kitchen.jpg` | Living spaces |
| `bed-1.jpg` … `bed-4.jpg` | Bedrooms |
| `bath-main.jpg`, `bath-ensuite.jpg` | Bathrooms |
| `hot-tub.jpg`, `fire-pit.jpg`, `swings.jpg` | Outdoors |
| `lake.jpg`, `beach.jpg`, `kangaroos.jpg` | Setting |
| `hosts.jpg` | Owner portrait for the story section |

Keep files under ~400 KB each (export at quality 80). Alt text lives in the HTML.

## Fill in the owner-only details

Search the HTML for `TODO` — Wi-Fi password, lockbox code, Airbnb listing URL,
phone, bin days, appliance notes. Everything else is already written.

### Owner settings (top of `assets/js/main.js`)

| Setting | What it does |
|---|---|
| `AIRBNB_URL` | Your listing URL. Until set, "Book on Airbnb" opens an Airbnb search for The Honeysuckles. |
| `WEB3FORMS_KEY` | Free key from web3forms.com; enquiries then email you. |
| `ENQUIRY_EMAIL` | Fallback: with no key, the form opens the guest's email app addressed to you. With neither set, the form politely says it isn't connected yet. |

### Assumptions to confirm

Check-in 3 pm / check-out 10 am, and "usually reply within a day" are stated on
the site. Guest reviews are paraphrased and labelled as such; replace with
verbatim quotes (with permission) when you have them. The 10/10 "Exceptional"
rating is attributed to Vrbo, where the listing is syndicated.

## Editing

`docs/build/build.py` assembles the pages from shared partials (head, header,
footer) plus one body file per page (`p_index.py`, `p_house.py`, `p_explore.py`,
`p_manual.py`, `p_404.py`). Edit those and rerun the script, or edit the HTML
directly if you prefer. The generated HTML is what gets deployed.

## QA record

`docs/qa/` holds the accessibility audit, copy reality check, design review and
Lighthouse benchmark that shaped the final build. After fixes: zero axe-core
violations on every page in light and dark mode at mobile and desktop widths;
Lighthouse mobile 96 performance / 0 CLS before the font and CSS trims.
