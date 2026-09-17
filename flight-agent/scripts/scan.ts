/**
 * Headless fare scan for cron / GitHub Actions price tracking.
 *
 *   npm run scan                       # defaults: MEL->HRE, 2 adults + 2 children, now..31 Jan
 *   npm run scan -- --window-start 2026-12-01 --window-end 2027-01-31 --step 3 --oneway
 *
 * Writes data/latest.json (full result) and appends a compact snapshot to
 * data/history.json so price movements can be charted over time.
 */
import fs from "node:fs";
import path from "node:path";
import { humanDate } from "../lib/dates";
import { money } from "../lib/format";
import { normalizeParams } from "../lib/params";
import { getProvider } from "../lib/providers";
import { sortOffers } from "../lib/rank";
import { runScan } from "../lib/search";

function loadDotEnv() {
  for (const f of [".env.local", ".env"]) {
    const p = path.resolve(process.cwd(), f);
    if (!fs.existsSync(p)) continue;
    for (const line of fs.readFileSync(p, "utf8").split("\n")) {
      const m = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
      if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^"(.*)"$/, "$1");
    }
  }
}

function args(): Record<string, string | boolean> {
  const out: Record<string, string | boolean> = {};
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith("--")) { out[key] = next; i++; } else out[key] = true;
  }
  return out;
}

async function main() {
  loadDotEnv();
  const a = args();
  const params = normalizeParams({
    windowStart: a["window-start"],
    windowEnd: a["window-end"],
    stepDays: a.step,
    stayNights: a.stay,
    adults: a.adults,
    children: a.children,
    tripType: a.oneway ? "oneway" : undefined,
    cabin: a.cabin,
  });
  const provider = getProvider();
  console.log(`Scanning ${params.origin}->${params.destination} (${params.tripType}) ${params.windowStart}..${params.windowEnd} every ${params.stepDays}d via ${provider.name}`);

  const result = await runScan(params, provider, {
    concurrency: Number(process.env.SCAN_CONCURRENCY ?? 3) || 3,
    onProgress: (done, total, date) => process.stdout.write(`  ${done}/${total} ${date}\r`),
  });
  console.log("");

  const outDir = path.resolve(process.cwd(), typeof a.out === "string" ? a.out : "data");
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "latest.json"), JSON.stringify(result, null, 2));

  const cheapest = sortOffers(result.offers, "cheapest")[0];
  const best = sortOffers(result.offers, "best")[0];
  const snapshot = {
    at: result.generatedAt,
    provider: result.provider,
    isSample: result.isSample,
    window: [params.windowStart, params.windowEnd],
    cheapest: cheapest ? { total: cheapest.price.total, currency: cheapest.price.currency, date: cheapest.departureDate, carrier: cheapest.validatingCarrierName } : null,
    best: best ? { total: best.price.total, currency: best.price.currency, date: best.departureDate, carrier: best.validatingCarrierName } : null,
    byDate: result.byDate.map((d) => [d.date, d.cheapest]),
  };
  const historyPath = path.join(outDir, "history.json");
  const history = fs.existsSync(historyPath) ? (JSON.parse(fs.readFileSync(historyPath, "utf8")) as unknown[]) : [];
  history.push(snapshot);
  fs.writeFileSync(historyPath, JSON.stringify(history.slice(-365), null, 2));

  console.log(`Dates scanned: ${result.datesScanned}, offers kept: ${result.offers.length}`);
  if (cheapest) console.log(`Cheapest: ${money(cheapest.price.total, cheapest.price.currency)} ${cheapest.validatingCarrierName} on ${humanDate(cheapest.departureDate)}`);
  if (best) console.log(`Best:     ${money(best.price.total, best.price.currency)} ${best.validatingCarrierName} on ${humanDate(best.departureDate)} (score ${best.scores.best})`);
  for (const w of result.warnings) console.log(`! ${w}`);
  console.log(`Wrote ${path.join(outDir, "latest.json")} and ${historyPath}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
