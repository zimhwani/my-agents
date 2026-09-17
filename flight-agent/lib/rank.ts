import { airportLabel } from "./airports";
import { formatDuration, formatTime, wallClockMinutes } from "./dates";
import type { FlightOffer, Itinerary, Layover, RankedOffer, Segment, SortMode } from "./types";

/** Minutes between two local wall-clock stamps at the SAME airport (so no tz math needed). */
export function wallClockDiffMinutes(a: string, b: string): number {
  const p = (s: string) => {
    const [date, time] = s.split("T");
    const [y, m, d] = date.split("-").map(Number);
    const [h, mi] = (time ?? "00:00").split(":").map(Number);
    return Date.UTC(y, m - 1, d, h, mi);
  };
  return Math.round((p(b) - p(a)) / 60_000);
}

export function computeLayovers(segments: Segment[]): Layover[] {
  const out: Layover[] = [];
  for (let i = 1; i < segments.length; i++) {
    const prev = segments[i - 1];
    const next = segments[i];
    const minutes = wallClockDiffMinutes(prev.arrival, next.departure);
    const crossesMidnight = prev.arrival.slice(0, 10) !== next.departure.slice(0, 10);
    // Treat a connection as "overnight" when it spans midnight and is long enough that
    // the family is effectively stuck in the terminal (or a hotel) for the night.
    const overnight = crossesMidnight && minutes >= 240;
    out.push({ airport: next.from, minutes, overnight });
  }
  return out;
}

export function buildItinerary(segments: Segment[], durationMin?: number): Itinerary {
  const layovers = computeLayovers(segments);
  const total =
    durationMin ??
    segments.reduce((s, seg) => s + seg.durationMin, 0) + layovers.reduce((s, l) => s + l.minutes, 0);
  return { segments, durationMin: total, layovers };
}

export interface Penalties {
  layover: number;
  timing: number;
  stops: number;
  warnings: string[];
}

function layoverPenalty(l: Layover): number {
  let p = 0;
  if (l.minutes < 60) p = 0.6;
  else if (l.minutes < 90) p = 0.25;
  else if (l.minutes <= 240) p = 0;
  else if (l.minutes <= 360) p = 0.15;
  else if (l.minutes <= 600) p = 0.35;
  else p = 0.6;
  if (l.overnight) p += 0.3;
  return p;
}

function describeLayover(l: Layover): string | null {
  const where = airportLabel(l.airport);
  if (l.minutes < 60) return `Tight connection in ${where} (${formatDuration(l.minutes)})`;
  if (l.minutes < 90) return `Short connection in ${where} (${formatDuration(l.minutes)})`;
  if (l.overnight) return `Overnight layover in ${where} (${formatDuration(l.minutes)})`;
  if (l.minutes > 360) return `Long layover in ${where} (${formatDuration(l.minutes)})`;
  return null;
}

/** Departures before 06:00 and arrivals between 23:00 and 06:00 are rough with kids. */
function timingPenalty(it: Itinerary, arrivalCity: string, weight: number, warnings: string[]): number {
  let p = 0;
  const first = it.segments[0];
  const last = it.segments[it.segments.length - 1];
  const dep = wallClockMinutes(first.departure);
  const arr = wallClockMinutes(last.arrival);
  if (dep < 6 * 60) {
    p += 0.3;
    warnings.push(`Departs ${airportLabel(first.from)} at ${formatTime(first.departure)}`);
  } else if (dep >= 23 * 60) {
    p += 0.1;
  }
  if (arr >= 23 * 60 || arr < 6 * 60) {
    p += 0.4;
    warnings.push(`Arrives in ${arrivalCity} at ${formatTime(last.arrival)}`);
  }
  return p * weight;
}

export function penaltiesFor(offer: FlightOffer): Penalties {
  const warnings: string[] = [];
  const legs = [offer.outbound, ...(offer.inbound ? [offer.inbound] : [])];

  let layover = 0;
  for (const leg of legs) {
    for (const l of leg.layovers) {
      layover += layoverPenalty(l);
      const w = describeLayover(l);
      if (w) warnings.push(w);
    }
  }

  let timing = timingPenalty(offer.outbound, airportLabel(offer.outbound.segments.at(-1)!.to), 1, warnings);
  if (offer.inbound) timing += timingPenalty(offer.inbound, airportLabel(offer.inbound.segments.at(-1)!.to), 0.6, warnings);

  let stops = 0;
  for (const leg of legs) {
    const n = leg.segments.length - 1;
    if (n >= 2) {
      stops += 0.3 * (n - 1);
      warnings.push(`${n} stops ${leg === offer.outbound ? "outbound" : "on the way home"}`);
    }
  }

  return {
    layover: Math.min(1, layover),
    timing: Math.min(1, timing),
    stops: Math.min(1, stops),
    warnings,
  };
}

export function totalDuration(offer: FlightOffer): number {
  return offer.outbound.durationMin + (offer.inbound?.durationMin ?? 0);
}

export function totalStops(offer: FlightOffer): number {
  return offer.outbound.segments.length - 1 + (offer.inbound ? offer.inbound.segments.length - 1 : 0);
}

const WEIGHTS = { price: 0.4, duration: 0.25, layover: 0.15, timing: 0.1, stops: 0.1 };

/**
 * Scores every offer relative to the others in the set. Scores are 0-100, higher is better.
 * "best" balances price, total travel time, quality of the interchanges and family-friendly timings.
 */
export function rankOffers(offers: FlightOffer[]): RankedOffer[] {
  if (offers.length === 0) return [];
  const prices = offers.map((o) => o.price.total);
  const durs = offers.map(totalDuration);
  const minP = Math.min(...prices);
  const minD = Math.min(...durs);
  // Penalty grows with how far above the cheapest / fastest an offer is; 100% above = max penalty.
  // (Min-max scaling would turn a $50 spread into a full-strength penalty.)
  const norm = (v: number, lo: number) => (lo <= 0 ? 0 : Math.min(1, (v - lo) / lo));

  const ranked: RankedOffer[] = offers.map((o) => {
    const pen = penaltiesFor(o);
    const priceN = norm(o.price.total, minP);
    const durN = norm(totalDuration(o), minD);
    const bestPenalty =
      WEIGHTS.price * priceN +
      WEIGHTS.duration * durN +
      WEIGHTS.layover * pen.layover +
      WEIGHTS.timing * pen.timing +
      WEIGHTS.stops * pen.stops;
    const badges: string[] = [];
    const smoothConnections = [o.outbound, o.inbound]
      .filter((x): x is Itinerary => !!x)
      .every((leg) => leg.layovers.every((l) => l.minutes >= 90 && l.minutes <= 300 && !l.overnight));
    if (pen.timing === 0 && smoothConnections) badges.push("Family-friendly times");
    return {
      ...o,
      scores: {
        best: Math.round((1 - bestPenalty) * 100),
        cheapest: Math.round((1 - priceN) * 100),
        fastest: Math.round((1 - durN) * 100),
      },
      badges,
      warnings: pen.warnings,
      totalDurationMin: totalDuration(o),
      stops: totalStops(o),
    };
  });

  const cheapest = [...ranked].sort(byCheapest)[0];
  const fastest = [...ranked].sort(byFastest)[0];
  const best = [...ranked].sort(byBest)[0];
  cheapest.badges.unshift("Cheapest");
  if (!fastest.badges.includes("Fastest")) fastest.badges.unshift("Fastest");
  if (!best.badges.includes("Best overall")) best.badges.unshift("Best overall");
  return ranked;
}

function byCheapest(a: RankedOffer, b: RankedOffer): number {
  return a.price.total - b.price.total || b.scores.best - a.scores.best;
}
function byFastest(a: RankedOffer, b: RankedOffer): number {
  return a.totalDurationMin - b.totalDurationMin || a.price.total - b.price.total;
}
function byBest(a: RankedOffer, b: RankedOffer): number {
  return b.scores.best - a.scores.best || a.price.total - b.price.total;
}

export function sortOffers(offers: RankedOffer[], mode: SortMode): RankedOffer[] {
  const cmp = mode === "cheapest" ? byCheapest : mode === "fastest" ? byFastest : byBest;
  return [...offers].sort(cmp);
}

/** Cheapest offer per departure date, for the price calendar. */
export function cheapestByDate(offers: RankedOffer[]): Map<string, RankedOffer> {
  const m = new Map<string, RankedOffer>();
  for (const o of offers) {
    const cur = m.get(o.departureDate);
    if (!cur || o.price.total < cur.price.total) m.set(o.departureDate, o);
  }
  return m;
}
