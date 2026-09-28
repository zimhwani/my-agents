import { addDays, endOfNextJanuary, humanDate, isValidISODate, todayISO, daysBetween } from "./dates";
import { airportLabel } from "./airports";
import type { Cabin, SearchParams, Stopover, TripLeg, TripType } from "./types";

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

  // Stopover (multi-city): a valid airport that is not the origin or destination.
  const so = (o.stopover && typeof o.stopover === "object" ? o.stopover : null) as Record<string, unknown> | null;
  const soAirport = so ? iata(so.airport, "") : "";
  const origin = iata(o.origin, d.origin);
  const destination = iata(o.destination, d.destination);
  const stopover: Stopover | undefined =
    soAirport && soAirport !== origin && soAirport !== destination
      ? { airport: soAirport, nights: clampInt(so!.nights, 1, 14, 3), leg: so!.leg === "return" && tripType === "return" ? "return" : "outbound" }
      : undefined;

  let returnDate = isValidISODate(o.returnDate) ? o.returnDate : undefined;
  if (returnDate && daysBetween(windowStart, returnDate) <= 0) returnDate = undefined;

  const adults = clampInt(o.adults, 1, 9, d.adults);
  const children = clampInt(o.children, 0, 8, d.children);
  const infants = clampInt(o.infants, 0, adults, d.infants);

  return {
    origin,
    destination,
    tripType,
    windowStart,
    windowEnd,
    stayNights: clampInt(o.stayNights, 1, 90, d.stayNights),
    returnDate: tripType === "return" ? returnDate : undefined,
    ...(stopover ? { stopover } : {}),
    stepDays: clampInt(o.stepDays, 1, 31, d.stepDays),
    adults,
    children,
    infants,
    cabin,
    currency: typeof o.currency === "string" && /^[A-Z]{3}$/.test(o.currency) ? o.currency : d.currency,
    maxStops: clampInt(o.maxStops, 0, 3, d.maxStops),
  };
}

/**
 * The flight legs to price for one departure date: two (or one) for a plain trip,
 * three (or two) when a stopover makes it multi-city. Returns null when the
 * stopover does not fit before the return date.
 */
export function legsFor(p: SearchParams, departureDate: string, returnDate?: string): TripLeg[] | null {
  const s = p.stopover;
  if (!s) {
    const legs: TripLeg[] = [{ from: p.origin, to: p.destination, date: departureDate }];
    if (returnDate) legs.push({ from: p.destination, to: p.origin, date: returnDate });
    return legs;
  }
  if (s.leg === "outbound") {
    // The first flight usually lands the next day; the onward flight is `nights` after that.
    const onward = addDays(departureDate, s.nights + 1);
    if (returnDate && daysBetween(onward, returnDate) <= 0) return null;
    const legs: TripLeg[] = [
      { from: p.origin, to: s.airport, date: departureDate },
      { from: s.airport, to: p.destination, date: onward },
    ];
    if (returnDate) legs.push({ from: p.destination, to: p.origin, date: returnDate });
    return legs;
  }
  if (!returnDate) return null;
  return [
    { from: p.origin, to: p.destination, date: departureDate },
    { from: p.destination, to: s.airport, date: returnDate },
    { from: s.airport, to: p.origin, date: addDays(returnDate, s.nights) },
  ];
}

export function stopoverSummary(s: Stopover | undefined): string {
  if (!s) return "";
  return `${s.nights}-night stopover in ${airportLabel(s.airport)}${s.leg === "return" ? " on the way home" : ""}`;
}

/** Return date for a given departure, honouring a fixed return date when set. */
export function returnDateFor(p: SearchParams, departureDate: string): string | undefined {
  if (p.tripType !== "return") return undefined;
  if (p.returnDate) return daysBetween(departureDate, p.returnDate) > 0 ? p.returnDate : undefined;
  // "Stay N nights" means nights at the destination, so an outbound stopover pushes the return out.
  const extra = p.stopover?.leg === "outbound" ? p.stopover.nights + 1 : 0;
  return addDays(departureDate, p.stayNights + extra);
}

/** Why no departure date could be searched, in plain words (null when some can). */
export function whyNoDates(p: SearchParams): string | null {
  const dates = sampleDatesFor(p);
  if (dates.length === 0) return "That date window is empty. Pick a later end date.";
  const usable = dates.filter((d) => {
    const ret = returnDateFor(p, d);
    if (p.tripType === "return" && !ret) return false;
    return legsFor(p, d, ret) !== null;
  });
  if (usable.length) return null;
  if (p.stopover && p.returnDate) {
    return `${p.stopover.nights} nights in ${airportLabel(p.stopover.airport)} doesn’t fit before you fly home on ${humanDate(p.returnDate)}. Choose a later return date or fewer nights.`;
  }
  if (p.returnDate) return `Your return date, ${humanDate(p.returnDate)}, is before every departure date. Choose a later return date.`;
  return "None of those dates work. Try a wider window.";
}

function sampleDatesFor(p: SearchParams): string[] {
  const out: string[] = [];
  const step = Math.max(1, p.stepDays);
  for (let d = p.windowStart; daysBetween(d, p.windowEnd) >= 0; d = addDays(d, step)) out.push(d);
  if (out.length && out[out.length - 1] !== p.windowEnd) out.push(p.windowEnd);
  return out;
}

export function tripSummary(p: SearchParams): string {
  if (p.tripType !== "return") return "one way";
  return p.returnDate ? `returning ${humanDate(p.returnDate)}` : `return, ${p.stayNights} nights away`;
}

export function passengerSummary(p: SearchParams): string {
  const parts = [`${p.adults} adult${p.adults === 1 ? "" : "s"}`];
  if (p.children) parts.push(`${p.children} child${p.children === 1 ? "" : "ren"}`);
  if (p.infants) parts.push(`${p.infants} infant${p.infants === 1 ? "" : "s"}`);
  return parts.join(", ");
}
