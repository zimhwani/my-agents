# ✈️ Harare Flight Agent

A voice-controlled flight travel agent that **tracks Melbourne → Harare fares for two adults and two children**, scanning every sampled departure date between now and the end of January and ranking what it finds by price, total travel time, quality of the interchanges and family-friendly timings.

Talk to it ("find the cheapest flights in December", "read me the top three", "tell me about option two", "start tracking prices daily") or type the same commands. It answers out loud.

## Quick start

```bash
cd flight-agent
npm install
cp .env.example .env.local   # optional: add keys (see below)
npm run dev                  # http://localhost:3000
```

It works immediately with **sample fares** (clearly labelled) so you can try the voice flow before adding keys. Voice input uses the browser's Web Speech API, so open it in Chrome, Edge or Safari and allow the microphone.

## Keys

| Key | What it unlocks | Without it |
| --- | --- | --- |
| `AMADEUS_CLIENT_ID` / `AMADEUS_CLIENT_SECRET` | Live fares from the [Amadeus Self-Service API](https://developers.amadeus.com) (free tier). `AMADEUS_ENV=test` is the free sandbox; `production` is live GDS content. | Deterministic sample fares modelled on the real MEL–HRE routings (Qatar via Doha, Emirates via Dubai, Singapore Airlines + Airlink via Johannesburg, Qantas + Airlink via Sydney/Johannesburg) with seasonal pricing. |
| `ANTHROPIC_API_KEY` | Claude (`claude-opus-5`) understands free-form speech and writes the spoken replies. Server-side refusal fallbacks are enabled by default. | A built-in rule-based parser handles the common commands (dates, months, passengers, sorting, selecting an option, tracking). |

Amadeus self-service does not sell tickets; each result links to Google Flights for the same dates so you can check and book.

## What it does

- **Scans a date window, not a single date.** Default: today → 31 January, every 7 days (edit "check every" for finer coverage). Return trips use a configurable number of nights away; one-way is a toggle or a voice command.
- **Ranks three ways.** *Cheapest*, *fastest*, and *best overall*, which scores each offer on price (40%), total travel time (25%), interchange quality (15%: tight < 60 min, long > 6 h and overnight layovers are penalised), timing (10%: departures before 06:00 and arrivals between 23:00–06:00 are penalised) and number of stops (10%). Badges and warnings ("Tight connection in Doha (45m)", "Overnight layover in Dubai", "Family-friendly times") explain each result.
- **Price calendar.** Cheapest fare per departure date; click a date to filter.
- **Voice.** Push-to-talk or "keep listening" mode, spoken summaries of the results, details of any option by number, and a typed fallback.
- **Tracking.** "Start tracking prices every 6 hours" re-scans while the tab is open, keeps a history in the browser and announces price drops. For always-on tracking use the headless scan:

```bash
npm run scan                                   # writes data/latest.json + appends data/history.json
npm run scan -- --window-start 2026-12-01 --window-end 2027-01-31 --step 3
npm run scan -- --oneway --adults 2 --children 2 --cabin PREMIUM_ECONOMY
```

The repository also ships `.github/workflows/flight-agent-track.yml`, a daily GitHub Action that runs the scan with the Amadeus secrets and commits the history so you get a price log without keeping a laptop open. It no-ops until the secrets are set.

## Voice commands

| Say | Does |
| --- | --- |
| "search for flights" / "run it again" | Scans the current window |
| "cheapest flights between now and the end of January" | Sets the window and scans |
| "search early December" / "between 10 December and 20 January" / "around Christmas" | Sets the window and scans |
| "show me the cheapest" / "what's the fastest" / "best options" | Re-sorts and reads the top three |
| "read me the top five" | Reads N results |
| "tell me about option two" | Opens and reads that option's legs and layovers |
| "two adults and two children" / "just the two of us" | Changes travellers |
| "one way" / "return staying three weeks" | Trip type and length |
| "fly business" | Cabin |
| "start tracking prices daily" / "stop tracking" | Price tracking |
| "help" / "stop" | Lists commands / stops talking |

## Layout

```
app/            Next.js App Router pages and API routes (/api/search, /api/interpret, /api/status)
components/     Voice panel, search form, results, price calendar, tracker
hooks/          useSpeech: SpeechRecognition + speechSynthesis wrapper
lib/            Providers (amadeus, sample), ranking, date-window sampling, intent parser, Claude interpreter
scripts/scan.ts Headless scan for cron / CI
tests/          Vitest unit tests (npm test)
```

## Scripts

```bash
npm run dev        # local dev server
npm run build      # production build
npm test           # unit tests
npm run typecheck  # tsc --noEmit
npm run scan       # headless fare scan
```
