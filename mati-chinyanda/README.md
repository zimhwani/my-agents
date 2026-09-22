# Mati Chinyanda — website

Premium, static personal-brand site (HTML + CSS + vanilla JS, no build step at deploy time) for
Mati Chinyanda: speaker, MC & event host, co-founder/co-host of *What Left The Group Chat*,
founder of FreekÀ Runway. Primary conversion: **book Mati** (speaker / MC / event producer).

```
mati-chinyanda/
├── index.html            Home — hero, marquee, intro, pillars, talks, stats, podcast, FreekÀ, press, enquiry form
├── speaking.html         Formats, signature talks (accordion), stages timeline, planner logistics
├── podcast.html          What Left The Group Chat — about, season-one episodes, platforms, guest enquiries
├── freeka-runway.html    FreekÀ Runway story, values, gallery, event-production services
├── about.html            Story, values, timeline, bios in three lengths (copy buttons)
├── book.html             Enquiry form + FAQ
├── 404.html
├── assets/css            style.css (design tokens + components), fonts.css (self-hosted Fraunces + Figtree)
├── assets/js/main.js     nav, reveal-on-scroll, marquee, count-up, accordion, lightbox, form, copy-bio
├── assets/img            optimised portrait crops (+ raw/ originals and MANIFEST.md)
├── assets/fonts          woff2 variable fonts (Fontsource builds, OFL)
├── docs/                 research-brief, brand-system, ux-spec, competitive-research, qa/ screenshots
├── docs/tools            build.py (assembles pages from docs/tools/pages/*), images.py, screenshot.mjs
└── vercel.json           static-site config (clean URLs, security + cache headers)
```

## Editing pages

Page bodies live in `docs/tools/pages/*.html` (JSON front-matter on line 1 sets path/title/description).
Shared head, header and footer are in `docs/tools/build.py`. After editing:

```bash
cd mati-chinyanda
python3 docs/tools/build.py            # regenerates *.html and sitemap.xml
python3 docs/tools/images.py           # (only if raw images changed; slots in docs/tools/slots.json)
http-server -p 8787 . & node docs/tools/screenshot.mjs http://localhost:8787 docs/qa   # QA shots
```

## Deploy to Vercel

**Path A — Vercel Git integration (no secrets, recommended)**
1. vercel.com → *Add New → Project* → import `zimhwani/my-agents` (already connected from earlier sites).
2. **Root Directory = `mati-chinyanda`**, Framework Preset = *Other*, leave build/output blank
   (`vercel.json` declares a static site with clean URLs).
3. Production Branch = `main` (after merging) or `claude/awesome-faraday-syn8sp` to go live now.
4. Deploy. Every push to that branch redeploys.

CLI equivalent:
```bash
cd my-agents/mati-chinyanda && vercel link && vercel git connect && vercel --prod
```

**Path B — GitHub Actions** (`.github/workflows/mati-deploy.yml`): add repo secrets `VERCEL_TOKEN`,
`VERCEL_ORG_ID` (and after first deploy `VERCEL_PROJECT_ID_MATI`). Until then the workflow no-ops.

After deploying, update `SITE` in `docs/tools/build.py` and `robots.txt` to the final domain
(canonical + OG URLs), rebuild, push.

## Before going public — things only Mati can supply

| Item | Where it plugs in |
|---|---|
| Booking email (site uses `hello@matichinyanda.com` placeholder) | `EMAIL` in `docs/tools/build.py` |
| Form backend: create a Formspree form and replace `YOUR_FORM_ID` in `01-home.html` and `06-book.html`. Until then the form opens a pre-filled email. | page fragments |
| Confirm **FashionOne** wording (no public record found; included per client brief) | `05-about.html`, marquee on home, footer |
| Testimonials from organisers/designers (none published online; section intentionally omitted rather than invented) | add a `.quote` block on home + speaking |
| Client / venue logos for the marquee (currently ventures & recognitions) | `01-home.html` marquee |
| Showreel link (YouTube/Vimeo) | hero secondary CTA + speaking page |
| FreekÀ Runway show photography (typographic tiles stand in for now) | `assets/img/raw/` → `slots.json` → gallery |
| Personal Instagram / LinkedIn URLs (only the podcast's channels were verifiable) | footer `.social` + JSON-LD `sameAs` |
| Confirm co-host surnames, episode 4 title, and heritage wording on the podcast page | `03-podcast.html` |
| Speaker kit PDF | link from about + book pages |

Facts used on the site and their confidence levels are documented in `docs/research-brief.md`.
Women of Colour Melbourne Annual Gathering 2026 (24 Oct 2026, RMIT) MC credit supplied by the client
and cross-checked against the event listing.
