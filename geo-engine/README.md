# GEO Engine — AI Answer Visibility

MVP engine for the **"GEO-in-a-Box"** service: a done-for-you play that tells a
local business where it stands when buyers ask ChatGPT, Perplexity, and Google's
AI answers *"who's the best {category} near me?"* — and what to fix to become
the answer.

The **audit report is the product's wedge**: it's both the deliverable clients
pay for and the personalized cold-outreach hook ("here's where you're invisible
vs. your competitor who isn't").

## What it does

1. **Prompt engine** — turns a client profile into realistic buyer discovery
   questions for their vertical + location + services.
2. **Scanner** — runs those questions across AI answer engines and records the
   raw answers.
3. **Analyzer** — detects which brands (client + competitors) get named,
   computes share-of-voice, presence rate, first-mention rate, and a 0–100
   visibility score, and finds service-level gaps.
4. **Report** — renders a client-ready, self-contained **HTML** report (your
   lead magnet) plus a **Markdown** summary, with prioritized fixes.

## Quick start (no API key, no install)

The mock provider and the whole pipeline run on the Python standard library:

```bash
cd geo-engine
python -m geo run --client clients/example-medspa.json --out out
# → out/report.html   (open this — it's the sales asset)
# → out/report.md
# → out/scan.json
```

The mock provider deliberately simulates an *underserved* client (competitors
dominate, the client surfaces sometimes and rarely first) so you can see and
demo the full report shape offline.

## Real scans (Claude via the Anthropic SDK)

```bash
pip install -r requirements.txt        # installs `anthropic`
export ANTHROPIC_API_KEY=sk-ant-...    # or use `ant auth login`
python -m geo run --client clients/example-medspa.json --providers anthropic
```

- Default model is `claude-opus-4-8`. Override with `--model claude-sonnet-5`
  or `GEO_MODEL=claude-sonnet-5` to cut cost.
- Add providers as a comma list: `--providers mock,anthropic`.

## Commands

| Command | Purpose |
|---|---|
| `run` | scan + analyze + report in one shot (usual path) |
| `scan` | run the scan and persist `scan.json` only |
| `report --scan out/scan.json` | rebuild the report from a saved scan (no re-querying) |
| `fix` | draft the deliverables (schema, FAQ, comparison) behind a review gate |
| `batch --clients clients/` | scan every client in a folder + build a portfolio dashboard |

Common flags: `--client`, `--providers`, `--max-prompts`, `--model`, `--out`.

## Fix pipeline (the deliverables you sell)

```bash
python -m geo fix --scan out/scan.json --out out       # from a saved scan
python -m geo fix --client clients/example-medspa.json # scan then draft
```

Writes a review package to `out/fixes/`:

- **`schema.jsonld`** — valid schema.org LocalBusiness + FAQPage structured
  data, generated deterministically from the profile (business type mapped to
  the right schema.org `@type`).
- **`faq.md`** — an expert FAQ targeting the buyer questions where the client is
  invisible.
- **`comparison.md`** — an honest "{client} vs {top competitor}" page.
- **`INDEX.md`** — the approval checklist.

FAQ answers and the comparison are **drafted by Claude when an API key is set**,
and fall back to editable `[REVIEW]` templates otherwise. Nothing is published —
every file carries a "DRAFT — human review required" banner. Pass `--no-claude`
to force templates.

## Batch / portfolio (the ops autopilot layer)

```bash
python -m geo batch --clients clients --out portfolio
# → portfolio/index.html          (operator dashboard, sorted by score)
# → portfolio/<client>/report.html (per-client report)
```

Runs every `*.json` profile in the folder and builds a one-glance dashboard so a
solo operator can watch many accounts. Wire this to a weekly cron for autopilot.

## Client profile

A profile is a small JSON file (see `clients/example-medspa.json`):

```json
{
  "business_name": "Radiance Med Spa",
  "vertical": "med_spa",
  "location": "Austin, TX",
  "services": ["Botox", "dermal fillers", "microneedling"],
  "competitors": ["Viva Day Spa", "Milk + Honey", "Skinney Medspa"],
  "website": "https://example.com"
}
```

`vertical` labels ship for med spa, cosmetic clinic, dermatology, dental,
optometry, veterinary, physical therapy, chiropractic, law firm, HVAC, roofing,
and landscaping (anything else falls back to a generic label).

## Architecture

```
geo/
  config.py     client profiles, vertical labels, model default
  prompts.py    buyer discovery prompts per vertical/location/service
  providers.py  mock (offline) + anthropic (real); pluggable — add OpenAI etc.
  scan.py       run prompts × providers → scan.json (resilient per-query)
  analyze.py    brand detection, share-of-voice, visibility score, fixes
  fixes.py      schema.jsonld + FAQ + comparison drafts (Claude / templates)
  report.py     client-ready HTML + Markdown + portfolio dashboard
  batch.py      run a folder of clients → portfolio index
  cli.py        `python -m geo run|scan|report|fix|batch`
```

Every provider is just `.query(prompt) -> str`, so adding OpenAI, Perplexity, or
Gemini is a new class in `providers.py` and nothing else changes.

## Honest limitations

- AI answers are **non-deterministic** — sell this as a visibility/insurance
  signal, not a revenue-attribution promise.
- The mock provider is a simulator for demos and offline dev, not real data.

## Billing & payments (Stripe)

Secrets are read from the environment — **never hardcode a key**. Develop
against a **test** key; live keys are refused unless you explicitly opt in.

```bash
pip install stripe
export STRIPE_API_KEY=sk_test_...          # use a TEST key
python -m geo.billing setup --dry-run      # preview the catalog, no API calls
python -m geo.billing setup                # create products + prices
python -m geo.billing link --plan growth   # → a shareable Stripe payment link
```

Default plans (edit `PLANS` in `geo/billing.py` before going live):

| Plan | Price |
|---|---|
| `audit` | $299 one-time |
| `starter` | $500 / month |
| `growth` | $1,500 / month |

**Live-key guard:** a `sk_live_`/`rk_live_` key is refused unless
`GEO_STRIPE_ALLOW_LIVE=1` is set — creating catalog objects and charges is hard
to reverse, so this is deliberate friction.

**Fulfilment:** `geo/webhook.py` is a stdlib webhook receiver that verifies the
Stripe signature (`STRIPE_WEBHOOK_SECRET`) and, on `checkout.session.completed`,
provisions the customer (wire it to: create profile → run scan → send report).

```bash
export STRIPE_WEBHOOK_SECRET=whsec_...
python -m geo.webhook          # listens on :4242/stripe
```

## Status

Operational end-to-end offline; upgrades to live Claude the moment a key is set.

- [x] Prompt engine, scanner, analyzer, client-ready report
- [x] Mock provider (offline demos) + Anthropic provider (real, via the SDK)
- [x] Fix pipeline — schema/FAQ/comparison behind a human-approval gate
- [x] Batch runner + portfolio dashboard (multi-client ops)
- [x] Verified live scan + AI-drafted fixes against a real Claude API key
- [x] Stripe billing scaffold (catalog, payment links, webhook) — env-driven,
      test-mode-first; run live setup once against a test key + confirmed pricing
- [ ] Additional providers (OpenAI, Perplexity, Gemini) for per-engine SoV
- [ ] Weekly cron + client email digests
- [ ] Historical tracking so clients see visibility move over time
