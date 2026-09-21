# Hosted crypto dashboard (Vercel)

Same page as `deploy/trading-dashboard`, pointed at the crypto bot's Blob
prefix (`.../crypto`). Regenerate with:

```bash
python -m tradebot --env .env.crypto dashboard --export-vercel deploy/crypto-dashboard
```

Deploy as a second Vercel project: Add New → Project → import this repo →
Root Directory = `trading-bot/deploy/crypto-dashboard` → production branch
`claude/magical-allen-jan8gi`.
