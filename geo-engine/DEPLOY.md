# Deploying the GEO engine

Short version: **this is two things, and they deploy differently.**

| Piece | What it is | Best home |
|---|---|---|
| The **reports & portfolio** (`*.html`) | Static, self-contained files | Vercel / Netlify / Cloudflare Pages / GitHub Pages |
| The **engine** (scan / analyze / fix / digest / prospect) | A scheduled **Python batch job**, not a web server | **GitHub Actions cron** (or any host cron: Render, Railway, Fly, a cheap VM) |

## Why not "just Vercel"?

Vercel is excellent for the **static output** — the reports are inline-CSS HTML
with no backend, so serving them is trivial. But the engine's core work is a
*recurring background scan*, not a request/response web app. Vercel serverless
functions are meant for short request handlers; a weekly portfolio scan is a
scheduled batch. So:

- **Host the HTML on Vercel** (or Pages) — point it at the generated `portfolio/`.
- **Run the scan on a scheduler.** Since the repo already lives on GitHub, the
  cleanest option is **GitHub Actions cron** — free, secrets built in, and it
  can publish the refreshed reports as an artifact or push them to your host.

(Vercel *does* have Cron Jobs on paid plans; if you'd rather keep everything
there, wrap `geo digest` in a Vercel cron function. Actions is simpler for a
batch job and needs no extra account.)

## Recommended setup

1. **Scheduled scan** — `/.github/workflows/geo-weekly.yml` (already in the repo)
   runs `geo digest` every Monday: scans `clients/`, refreshes `portfolio/`,
   emails the digest, and uploads the reports as an artifact. Trigger it
   manually anytime from the Actions tab.

2. **Secrets** (repo → Settings → Secrets → Actions):
   - `ANTHROPIC_API_KEY` — real scans (omit to run the offline mock provider)
   - `OPENAI_API_KEY`, `PERPLEXITY_API_KEY`, `GEMINI_API_KEY` — extra engines
   - `SMTP_HOST` / `SMTP_USER` / `SMTP_PASS` / `EMAIL_FROM` / `DIGEST_TO` — email
   - `STRIPE_API_KEY` — billing (only where you run `geo.billing`)

3. **Publish reports to Vercel** — either:
   - add a deploy step to the workflow (Vercel CLI / action) that ships
     `geo-engine/portfolio`, or
   - keep the existing `vercel.json` and point its `outputDirectory` at the
     generated folder, building in CI.

## The landing page (acquisition tool)

`site/index.html` is a self-contained marketing page whose CTA form posts to a
Vercel serverless function, `api/audit.py`, which captures the lead (emails you)
and returns an instant teaser. `vercel.json` wires the static site + the Python
function.

### Path A — Vercel Git integration (simplest, zero secrets in GitHub)

1. In Vercel: **Add New → Project → import this GitHub repo**.
2. Set **Root Directory = `geo-engine`** (so `vercel.json`, `site/`, `api/`,
   and `requirements.txt` are the project root).
3. Deploy. Vercel then auto-deploys on every push — no workflow needed.

### Path B — GitHub Actions (`.github/workflows/vercel-deploy.yml`)

Already in the repo. It deploys on push once you add three **GitHub Actions
secrets** (Settings → Secrets and variables → Actions):

- `VERCEL_TOKEN` — create at vercel.com/account/tokens
- `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` — run `vercel link` once locally (writes
  them to `.vercel/project.json`), or copy from the Vercel project settings.

Until `VERCEL_TOKEN` is set the workflow safely no-ops. Use Path A **or** B, not
both.

### Then, either path — set env vars

Add env vars in the Vercel project (Settings → Environment Variables):
   - `EMAIL_LEADS_TO` (+ `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS`/`EMAIL_FROM`) — where leads go
   - `ANTHROPIC_API_KEY` **and** `GEO_LIVE_AUDIT=1` — *only if* you want the form
     to run a live teaser scan per submission (costs API tokens; leave off to
     just capture the lead and send the audit offline via `geo prospect`).

**Filling the funnel:** `geo find` pulls targets, `geo prospect` drafts outreach —
so inbound (landing page) and outbound (prospecting) feed the same pipeline.

## Local / one-off

Everything runs locally too:

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=...             # optional; mock otherwise
python -m geo digest --clients clients --out portfolio --email you@co.com --dry-run
```

## Network note

Outbound calls (Anthropic, OpenAI, Stripe, SMTP) need egress to those hosts.
Some sandboxes/CI restrict egress by allowlist — if a provider or Stripe call
fails with a proxy/tunnel error, that's the network policy, not the code.
