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

Common flags: `--client`, `--providers`, `--max-prompts`, `--model`, `--out`.

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
  scan.py       run prompts × providers → scan.json
  analyze.py    brand detection, share-of-voice, visibility score, fixes
  report.py     client-ready HTML + Markdown
  cli.py        `python -m geo run|scan|report`
```

Every provider is just `.query(prompt) -> str`, so adding OpenAI, Perplexity, or
Gemini is a new class in `providers.py` and nothing else changes.

## Honest limitations

- AI answers are **non-deterministic** — sell this as a visibility/insurance
  signal, not a revenue-attribution promise.
- The mock provider is a simulator for demos and offline dev, not real data.

## Roadmap (post-MVP)

- Real multi-provider scans (OpenAI, Perplexity, Gemini) with per-engine SoV.
- Fix pipeline: agents that draft schema, FAQ, and comparison pages behind a
  human-approval gate.
- Ops glue: Stripe billing + weekly cron scans + client email digests.
- Historical tracking so clients see visibility move over time.
