import { addDays, sampleDates } from "./dates";
import { rankOffers, sortOffers } from "./rank";
import type { DatePricePoint, FlightOffer, FlightProvider, ScanResult, SearchParams } from "./types";

const MAX_OFFERS_PER_DATE = 8;
const MAX_OFFERS_TOTAL = 160;
const CACHE_TTL_MS = 30 * 60 * 1000;

interface CacheEntry {
  at: number;
  offers: FlightOffer[];
}
const cache = new Map<string, CacheEntry>();

function cacheKey(provider: string, p: SearchParams, dep: string, ret?: string): string {
  return JSON.stringify([provider, p.origin, p.destination, p.tripType, p.adults, p.children, p.infants, p.cabin, p.currency, p.maxStops, dep, ret ?? ""]);
}

export function clearSearchCache(): void {
  cache.clear();
}

async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T, i: number) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i], i);
    }
  });
  await Promise.all(workers);
  return out;
}

export interface ScanOptions {
  concurrency?: number;
  onProgress?: (done: number, total: number, date: string) => void;
}

/**
 * Queries the provider for every sampled departure date in the window, ranks the
 * combined set, and summarises the cheapest fare per date for the price calendar.
 */
export async function runScan(params: SearchParams, provider: FlightProvider, opts: ScanOptions = {}): Promise<ScanResult> {
  const dates = sampleDates(params.windowStart, params.windowEnd, params.stepDays);
  const warnings: string[] = [];
  let done = 0;

  const perDate = await mapLimit(dates, opts.concurrency ?? 3, async (date) => {
    const ret = params.tripType === "return" ? addDays(date, params.stayNights) : undefined;
    const key = cacheKey(provider.name, params, date, ret);
    const hit = cache.get(key);
    let offers: FlightOffer[] = [];
    let error: string | undefined;
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
      offers = hit.offers;
    } else {
      try {
        offers = await provider.search(params, date, ret);
        cache.set(key, { at: Date.now(), offers });
      } catch (e) {
        error = e instanceof Error ? e.message : String(e);
      }
    }
    done++;
    opts.onProgress?.(done, dates.length, date);
    return { date, offers, error };
  });

  // Keep the payload sane: the N cheapest per date, ranked as one pool afterwards.
  const pool: FlightOffer[] = [];
  const byDate: DatePricePoint[] = [];
  for (const { date, offers, error } of perDate) {
    const sorted = [...offers].sort((a, b) => a.price.total - b.price.total);
    pool.push(...sorted.slice(0, MAX_OFFERS_PER_DATE));
    byDate.push({
      date,
      cheapest: sorted[0]?.price.total ?? null,
      offerId: sorted[0]?.id ?? null,
      offersFound: offers.length,
      error,
    });
    if (error) warnings.push(error);
  }

  const ranked = sortOffers(rankOffers(pool), "best").slice(0, MAX_OFFERS_TOTAL);
  if (provider.isSample) warnings.unshift("Showing sample fares. Add Amadeus keys in .env.local for live prices.");

  return {
    params,
    provider: provider.name,
    isSample: provider.isSample,
    generatedAt: new Date().toISOString(),
    offers: ranked,
    byDate,
    datesScanned: dates.length,
    warnings,
  };
}
