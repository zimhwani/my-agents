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
1. vercel.com → *Add New → Project* → import `zimhwani/my-agents`.
2. Set **Root Directory = `pamusha-lake-house`**, Framework Preset = *Other*.
3. Deploy. Every push to the production branch redeploys automatically.

**Path B — GitHub Actions** (`.github/workflows/pamusha-deploy.yml`)
Add repository secrets `VERCEL_TOKEN` and `VERCEL_ORG_ID` (and, after the first
deploy, `VERCEL_PROJECT_ID`). The workflow then deploys on every push that
touches this folder. Until the secrets exist it no-ops.

**Custom domain:** after deploying, add your domain in Vercel → Project →
Domains, then point the domain's DNS (currently at GoDaddy) at Vercel.

## Add your photography

Drop JPGs into `assets/img/` using these file names; each slot falls back to
designed placeholder art until the file exists:

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

Enquiry form: the form posts to Web3Forms. Get a free access key at
web3forms.com and replace `YOUR_WEB3FORMS_ACCESS_KEY` in `index.html`.
