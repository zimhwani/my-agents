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
