import { endOfNextJanuary, isValidISODate, todayISO, daysBetween } from "./dates";
import type { Cabin, SearchParams, TripType } from "./types";

const CABINS: Cabin[] = ["ECONOMY", "PREMIUM_ECONOMY", "BUSINESS"];

/** The brief: Melbourne -> Harare, two adults and two children, now until end of January. */
export function defaultParams(now: Date = new Date()): SearchParams {
  const start = todayISO(now);
  return {
    origin: "MEL",
    destination: "HRE",
    tripType: "return",
    windowStart: start,
    windowEnd: endOfNextJanuary(start),
    stayNights: 21,
    stepDays: 7,
    adults: 2,
    children: 2,
    infants: 0,
    cabin: "ECONOMY",
    currency: "AUD",
    maxStops: 2,
  };
}

function clampInt(v: unknown, min: number, max: number, fallback: number): number {
  const n = typeof v === "string" ? Number(v) : v;
  if (typeof n !== "number" || !Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function iata(v: unknown, fallback: string): string {
  if (typeof v !== "string") return fallback;
  const s = v.trim().toUpperCase();
  return /^[A-Z]{3}$/.test(s) ? s : fallback;
}

/** Merge untrusted input over the defaults and clamp everything to sane ranges. */
export function normalizeParams(input: unknown, now: Date = new Date()): SearchParams {
  const d = defaultParams(now);
  const o = (input && typeof input === "object" ? input : {}) as Record<string, unknown>;

  const tripType: TripType = o.tripType === "oneway" ? "oneway" : "return";
  const cabin = CABINS.includes(o.cabin as Cabin) ? (o.cabin as Cabin) : d.cabin;

  let windowStart = isValidISODate(o.windowStart) ? o.windowStart : d.windowStart;
  let windowEnd = isValidISODate(o.windowEnd) ? o.windowEnd : d.windowEnd;
  // Never search the past, and never let the window run backwards.
  if (daysBetween(d.windowStart, windowStart) < 0) windowStart = d.windowStart;
  if (daysBetween(windowStart, windowEnd) < 0) windowEnd = windowStart;
  // Keep scans bounded: at most a year out.
  if (daysBetween(windowStart, windowEnd) > 366) windowEnd = windowStart;

  const adults = clampInt(o.adults, 1, 9, d.adults);
  const children = clampInt(o.children, 0, 8, d.children);
  const infants = clampInt(o.infants, 0, adults, d.infants);

  return {
    origin: iata(o.origin, d.origin),
    destination: iata(o.destination, d.destination),
    tripType,
    windowStart,
    windowEnd,
    stayNights: clampInt(o.stayNights, 1, 90, d.stayNights),
    stepDays: clampInt(o.stepDays, 1, 31, d.stepDays),
    adults,
    children,
    infants,
    cabin,
    currency: typeof o.currency === "string" && /^[A-Z]{3}$/.test(o.currency) ? o.currency : d.currency,
    maxStops: clampInt(o.maxStops, 0, 3, d.maxStops),
  };
}

export function passengerSummary(p: SearchParams): string {
  const parts = [`${p.adults} adult${p.adults === 1 ? "" : "s"}`];
  if (p.children) parts.push(`${p.children} child${p.children === 1 ? "" : "ren"}`);
  if (p.infants) parts.push(`${p.infants} infant${p.infants === 1 ? "" : "s"}`);
  return parts.join(", ");
}
