# Hosted trading dashboard (Vercel)

A static shell of the bot's dashboard. It has no data of its own: `config.js`
points at the Vercel Blob store where the bot uploads `live.json` (every tick)
and `trades.json` (every close). Regenerate this folder whenever the dashboard
template or `DASHBOARD_DATA_URL` changes:

```bash
python -m tradebot dashboard --export-vercel deploy/trading-dashboard
```

Deploy, pick one (same as the other sites in this repo):

**Path A — Vercel Git integration (no secrets).** Vercel → Add New → Project →
import this GitHub repo → Root Directory = `trading-bot/deploy/trading-dashboard`
→ Deploy. Set the production branch to the branch you work on (Settings → Git)
so pushes auto-deploy.

**Path B — GitHub Actions.** `.github/workflows/dashboard-deploy.yml` deploys on
push once `VERCEL_TOKEN` and `VERCEL_ORG_ID` exist as repo secrets. The first
run creates a Vercel project named `trading-dashboard`; add its ID as
`VERCEL_DASHBOARD_PROJECT_ID` afterwards to pin future deploys.

**Path C — from your laptop.** `npm i -g vercel && vercel login`, then
`cd deploy/trading-dashboard && vercel deploy --prod`.

`config.js` holds a public URL, not a secret, so committing it is fine.
