import { addDays, endOfNextJanuary, humanDate, isValidISODate, todayISO, daysBetween } from "./dates";
import { airportLabel } from "./airports";
import type { Cabin, RouteLeg, SearchParams, Stopover, TripLeg, TripType } from "./types";

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

  let tripType: TripType = o.tripType === "oneway" ? "oneway" : o.tripType === "multicity" ? "multicity" : "return";
  // Multi-city: 2-6 flights, each with valid airports, offsets starting at 0 and never going backwards.
  let route: RouteLeg[] | undefined;
  if (tripType === "multicity" && Array.isArray(o.route)) {
    const legs = (o.route as unknown[]).slice(0, 6).map((l) => {
      const x = (l && typeof l === "object" ? l : {}) as Record<string, unknown>;
      return { from: iata(x.from, ""), to: iata(x.to, ""), offset: clampInt(x.offset, 0, 366, 0) };
    }).filter((l) => l.from && l.to && l.from !== l.to);
    for (let i = 1; i < legs.length; i++) legs[i].offset = Math.max(legs[i].offset, legs[i - 1].offset);
    if (legs.length >= 2) route = legs.map((l, i) => ({ ...l, offset: i === 0 ? 0 : l.offset - legs[0].offset }));
  }
  if (tripType === "multicity" && !route) tripType = "return";
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
    ...(stopover && !route ? { stopover } : {}),
    ...(route ? { route } : {}),
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
  if (p.route) return p.route.map((l) => ({ from: l.from, to: l.to, date: addDays(departureDate, l.offset) }));
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

/**
 * Turns spoken or typed multi-city flights into search params. Missing cities
 * chain from the previous flight (the first defaults to the origin), "HOME"
 * is the first departure city, and missing dates keep the current spacing
 * (or three days apart; the flight home fills the rest of the usual stay).
 */
export function withRoute(
  current: SearchParams,
  legs: { from?: string; to: string; date?: string }[],
  window?: { windowStart?: string; windowEnd?: string },
): SearchParams {
  const start = legs[0]?.from && legs[0].from !== "HOME" ? legs[0].from : current.origin;
  const filled = legs.map((l, i) => ({
    from: !l.from || l.from === "HOME" ? (i === 0 ? start : legs[i - 1].to === "HOME" ? start : legs[i - 1].to) : l.from,
    to: l.to === "HOME" ? start : l.to,
    date: l.date,
  }));
  const first = filled[0]?.date ?? window?.windowStart ?? current.windowStart;
  const old = current.route;
  let prev = first;
  const route: RouteLeg[] = filled.map((l, i) => {
    let date = i === 0 ? first : l.date;
    if (!date) {
      const kept = old?.[i] && old[i - 1] ? old[i].offset - old[i - 1].offset : undefined;
      const soFar = daysBetween(first, prev);
      date = addDays(prev, kept ?? (l.to === start ? Math.max(3, current.stayNights - soFar) : 3));
    }
    if (date < prev) date = prev;
    prev = date;
    return { from: l.from, to: l.to, offset: daysBetween(first, date) };
  });
  const exact = !!filled[0]?.date;
  return normalizeParams({
    ...current,
    tripType: "multicity",
    route,
    stopover: undefined,
    returnDate: undefined,
    windowStart: window?.windowStart ?? first,
    windowEnd: window?.windowEnd ?? (exact || current.windowEnd < first ? first : current.windowEnd),
  });
}

/** "MEL → JNB → CPT → HRE → MEL" (codes, for chips and headings). */
export function routeCodes(route: RouteLeg[]): string {
  return [route[0].from, ...route.map((l, i) => (i > 0 && route[i - 1].to !== l.from ? `${l.from}…${l.to}` : l.to))].join(" → ");
}

export function tripSummary(p: SearchParams): string {
  if (p.route) return `multi-city, ${p.route.length} flights`;
  if (p.tripType !== "return") return "one way";
  return p.returnDate ? `returning ${humanDate(p.returnDate)}` : `return, ${p.stayNights} nights away`;
}

export function passengerSummary(p: SearchParams): string {
  const parts = [`${p.adults} adult${p.adults === 1 ? "" : "s"}`];
  if (p.children) parts.push(`${p.children} child${p.children === 1 ? "" : "ren"}`);
  if (p.infants) parts.push(`${p.infants} infant${p.infants === 1 ? "" : "s"}`);
  return parts.join(", ");
}
