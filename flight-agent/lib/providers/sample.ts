/**
 * Deterministic sample fares modelled on the real MEL <-> HRE routings
 * (Gulf carriers via Doha/Dubai, Singapore Airlines + Airlink via Johannesburg,
 * Qantas + Airlink via Sydney/Johannesburg). Used when no SerpApi key is set
 * so the app, the voice agent and the tests all work offline. Prices are
 * plausible AUD levels with seasonal peaks, not live quotes.
 */
import { carrierName, distanceKm, region } from "../airports";
import { addDays, parseISODate } from "../dates";
import { buildItinerary, markStopover } from "../rank";
import type { FlightOffer, FlightProvider, Itinerary, SearchParams, Segment, TripLeg } from "../types";
import { legsFor } from "../params";

interface LegTemplate {
  carrier: string;
  flightNumber: string;
  from: string;
  to: string;
  /** Local departure "HH:mm" relative to the leg's own day offset */
  dep: string;
  /** Day offset from the itinerary start date */
  dayOffset: number;
  durationMin: number;
  aircraft?: string;
}

interface Routing {
  key: string;
  validating: string;
  /** Adult one-way base fare in AUD. */
  baseFare: number;
  outbound: LegTemplate[];
  inbound: LegTemplate[];
}

// Fixed UTC offsets for the sample only. Melbourne handles daylight saving below.
const TZ: Record<string, number> = {
  HRE: 2, DOH: 3, DXB: 4, AUH: 4, JNB: 2, LUN: 2, SIN: 8, ADD: 3, NBO: 3, PER: 8,
  CPT: 2, DUR: 2, VFA: 2, BUQ: 2, WDH: 2, KGL: 2, MRU: 4, BKK: 7, HKG: 8, KUL: 8,
};

function melbourneOffset(iso: string): number {
  // AEDT (+11) from the first Sunday in October to the first Sunday in April.
  const d = parseISODate(iso);
  const y = d.getFullYear();
  const firstSunday = (year: number, month: number) => {
    const x = new Date(year, month, 1);
    return new Date(year, month, 1 + ((7 - x.getDay()) % 7));
  };
  const dstStart = firstSunday(y, 9);
  const dstEnd = firstSunday(y, 3);
  return d >= dstStart || d < dstEnd ? 11 : 10;
}

function offsetFor(code: string, iso: string): number {
  if (code === "MEL" || code === "SYD") return melbourneOffset(iso);
  return TZ[code] ?? 0;
}

const ROUTINGS: Routing[] = [
  {
    key: "QR-DOH-night",
    validating: "QR",
    baseFare: 1290,
    outbound: [
      { carrier: "QR", flightNumber: "QR905", from: "MEL", to: "DOH", dep: "22:15", dayOffset: 0, durationMin: 860, aircraft: "Boeing 777-300ER" },
      { carrier: "QR", flightNumber: "QR1363", from: "DOH", to: "HRE", dep: "08:05", dayOffset: 1, durationMin: 530, aircraft: "Boeing 787-8" },
    ],
    inbound: [
      { carrier: "QR", flightNumber: "QR1364", from: "HRE", to: "DOH", dep: "18:35", dayOffset: 0, durationMin: 575, aircraft: "Boeing 787-8" },
      { carrier: "QR", flightNumber: "QR904", from: "DOH", to: "MEL", dep: "08:40", dayOffset: 1, durationMin: 830, aircraft: "Boeing 777-300ER" },
    ],
  },
  {
    key: "QR-DOH-day",
    validating: "QR",
    baseFare: 1340,
    outbound: [
      { carrier: "QR", flightNumber: "QR907", from: "MEL", to: "DOH", dep: "15:55", dayOffset: 0, durationMin: 865, aircraft: "Airbus A350-1000" },
      { carrier: "QR", flightNumber: "QR1363", from: "DOH", to: "HRE", dep: "08:05", dayOffset: 1, durationMin: 530, aircraft: "Boeing 787-8" },
    ],
    inbound: [
      { carrier: "QR", flightNumber: "QR1362", from: "HRE", to: "DOH", dep: "07:20", dayOffset: 0, durationMin: 575, aircraft: "Boeing 787-8" },
      { carrier: "QR", flightNumber: "QR906", from: "DOH", to: "MEL", dep: "02:10", dayOffset: 1, durationMin: 830, aircraft: "Airbus A350-1000" },
    ],
  },
  {
    key: "EK-DXB",
    validating: "EK",
    baseFare: 1360,
    outbound: [
      { carrier: "EK", flightNumber: "EK409", from: "MEL", to: "DXB", dep: "21:30", dayOffset: 0, durationMin: 850, aircraft: "Airbus A380-800" },
      { carrier: "EK", flightNumber: "EK713", from: "DXB", to: "HRE", dep: "09:20", dayOffset: 1, durationMin: 520, aircraft: "Boeing 777-300ER" },
    ],
    inbound: [
      { carrier: "EK", flightNumber: "EK714", from: "HRE", to: "DXB", dep: "19:10", dayOffset: 0, durationMin: 560, aircraft: "Boeing 777-300ER" },
      { carrier: "EK", flightNumber: "EK408", from: "DXB", to: "MEL", dep: "10:15", dayOffset: 1, durationMin: 815, aircraft: "Airbus A380-800" },
    ],
  },
  {
    key: "EK-DXB-early",
    validating: "EK",
    baseFare: 1180,
    outbound: [
      { carrier: "EK", flightNumber: "EK407", from: "MEL", to: "DXB", dep: "03:35", dayOffset: 0, durationMin: 850, aircraft: "Boeing 777-300ER" },
      { carrier: "EK", flightNumber: "EK713", from: "DXB", to: "HRE", dep: "09:20", dayOffset: 1, durationMin: 520, aircraft: "Boeing 777-300ER" },
    ],
    inbound: [
      { carrier: "EK", flightNumber: "EK712", from: "HRE", to: "DXB", dep: "08:00", dayOffset: 0, durationMin: 560, aircraft: "Boeing 777-300ER" },
      { carrier: "EK", flightNumber: "EK406", from: "DXB", to: "MEL", dep: "02:35", dayOffset: 1, durationMin: 815, aircraft: "Airbus A380-800" },
    ],
  },
  {
    key: "SQ-SIN-JNB",
    validating: "SQ",
    baseFare: 1240,
    outbound: [
      { carrier: "SQ", flightNumber: "SQ218", from: "MEL", to: "SIN", dep: "12:05", dayOffset: 0, durationMin: 470, aircraft: "Airbus A350-900" },
      { carrier: "SQ", flightNumber: "SQ478", from: "SIN", to: "JNB", dep: "01:30", dayOffset: 1, durationMin: 640, aircraft: "Airbus A350-900" },
      { carrier: "4Z", flightNumber: "4Z862", from: "JNB", to: "HRE", dep: "09:35", dayOffset: 1, durationMin: 105, aircraft: "Embraer 190" },
    ],
    inbound: [
      { carrier: "4Z", flightNumber: "4Z865", from: "HRE", to: "JNB", dep: "12:20", dayOffset: 0, durationMin: 105, aircraft: "Embraer 190" },
      { carrier: "SQ", flightNumber: "SQ479", from: "JNB", to: "SIN", dep: "16:40", dayOffset: 0, durationMin: 615, aircraft: "Airbus A350-900" },
      { carrier: "SQ", flightNumber: "SQ227", from: "SIN", to: "MEL", dep: "10:10", dayOffset: 1, durationMin: 450, aircraft: "Airbus A350-900" },
    ],
  },
  {
    key: "QF-SYD-JNB",
    validating: "QF",
    baseFare: 1520,
    outbound: [
      { carrier: "QF", flightNumber: "QF412", from: "MEL", to: "SYD", dep: "06:00", dayOffset: 0, durationMin: 85, aircraft: "Boeing 737-800" },
      { carrier: "QF", flightNumber: "QF63", from: "SYD", to: "JNB", dep: "10:35", dayOffset: 0, durationMin: 890, aircraft: "Boeing 787-9" },
      { carrier: "4Z", flightNumber: "4Z864", from: "JNB", to: "HRE", dep: "18:30", dayOffset: 0, durationMin: 105, aircraft: "Embraer 190" },
    ],
    inbound: [
      { carrier: "4Z", flightNumber: "4Z861", from: "HRE", to: "JNB", dep: "07:00", dayOffset: 0, durationMin: 105, aircraft: "Embraer 190" },
      { carrier: "QF", flightNumber: "QF64", from: "JNB", to: "SYD", dep: "18:50", dayOffset: 0, durationMin: 810, aircraft: "Boeing 787-9" },
      { carrier: "QF", flightNumber: "QF467", from: "SYD", to: "MEL", dep: "19:30", dayOffset: 1, durationMin: 95, aircraft: "Boeing 737-800" },
    ],
  },
];

/** Small stable hash so the same date always yields the same "market" noise. */
export function hash32(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

/** Seasonal multiplier for Australia -> southern Africa travel in the brief's window. */
export function seasonMultiplier(iso: string): number {
  const md = iso.slice(5); // MM-DD
  if (md >= "12-10" && md <= "12-24") return 1.5;
  if (md >= "12-25" || md <= "01-05") return 1.35;
  if (md >= "12-01" && md <= "12-09") return 1.15;
  if (md >= "01-06" && md <= "01-31") return 1.1;
  if (md >= "09-19" && md <= "10-04") return 1.12;
  if (md >= "11-01" && md <= "11-20") return 0.94;
  return 1.0;
}

function weekdayMultiplier(iso: string): number {
  const dow = parseISODate(iso).getDay();
  if (dow === 2 || dow === 3) return 0.96;
  if (dow === 5 || dow === 0) return 1.05;
  return 1.0;
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

function localStamp(iso: string, hhmm: string): string {
  return `${iso}T${hhmm}`;
}

/** Arrival wall-clock at the destination airport given departure wall-clock at origin. */
function arrivalStamp(depLocal: string, from: string, to: string, durationMin: number): string {
  const [date, time] = depLocal.split("T");
  const [y, m, d] = date.split("-").map(Number);
  const [h, mi] = time.split(":").map(Number);
  const depUtc = Date.UTC(y, m - 1, d, h, mi) - offsetFor(from, date) * 3_600_000;
  const arrUtc = depUtc + durationMin * 60_000;
  // Use the departure date for the destination offset guess, then refine once.
  let arr = new Date(arrUtc + offsetFor(to, date) * 3_600_000);
  const arrDate = `${arr.getUTCFullYear()}-${pad(arr.getUTCMonth() + 1)}-${pad(arr.getUTCDate())}`;
  arr = new Date(arrUtc + offsetFor(to, arrDate) * 3_600_000);
  return `${arr.getUTCFullYear()}-${pad(arr.getUTCMonth() + 1)}-${pad(arr.getUTCDate())}T${pad(arr.getUTCHours())}:${pad(arr.getUTCMinutes())}`;
}

function buildSegments(startDate: string, legs: LegTemplate[]): Segment[] {
  return legs.map((leg) => {
    const depDate = addDays(startDate, leg.dayOffset);
    const departure = localStamp(depDate, leg.dep);
    return {
      carrier: leg.carrier,
      carrierName: carrierName(leg.carrier),
      flightNumber: leg.flightNumber,
      from: leg.from,
      to: leg.to,
      departure,
      arrival: arrivalStamp(departure, leg.from, leg.to, leg.durationMin),
      durationMin: leg.durationMin,
      aircraft: leg.aircraft,
    };
  });
}

/**
 * Builds a leg that breaks for `nights` at `hub`: the part up to the hub flies on
 * `startDate`, the rest flies `nights` after landing there. Null when the routing
 * does not pass through the hub.
 */
function legWithStopover(startDate: string, legs: LegTemplate[], hub: string, nights: number): Segment[] | null {
  // No sample routing touches this city: pretend the Johannesburg routings connect there instead.
  const passes = ROUTINGS.some((r) => [...r.outbound, ...r.inbound].some((l) => l.to === hub));
  if (!passes) legs = legs.map((l) => ({ ...l, from: l.from === "JNB" ? hub : l.from, to: l.to === "JNB" ? hub : l.to }));
  const k = legs.findIndex((l) => l.to === hub);
  if (k < 0 || k === legs.length - 1) return null;
  const first = buildSegments(startDate, legs.slice(0, k + 1));
  const rest = legs.slice(k + 1);
  const base = rest[0].dayOffset;
  const onwardDate = addDays(first[first.length - 1].arrival.slice(0, 10), nights);
  const second = buildSegments(onwardDate, rest.map((l) => ({ ...l, dayOffset: l.dayOffset - base })));
  return [...first, ...second];
}

// ---------------------------------------------------------------- multi-city

function utcMs(local: string, airport: string): number {
  const [date, time] = local.split("T");
  const [y, m, d] = date.split("-").map(Number);
  const [h, mi] = time.split(":").map(Number);
  return Date.UTC(y, m - 1, d, h, mi) - offsetFor(airport, date) * 3_600_000;
}

function addMinutesLocal(local: string, minutes: number): string {
  const [date, time] = local.split("T");
  const [y, m, d] = date.split("-").map(Number);
  const [h, mi] = time.split(":").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d, h, mi) + minutes * 60_000);
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}T${pad(t.getUTCHours())}:${pad(t.getUTCMinutes())}`;
}

function flightMinutes(from: string, to: string): number {
  return Math.round((distanceKm(from, to) / 820) * 60 / 5) * 5 + 35;
}

function makeSegment(carrier: string, from: string, to: string, departure: string, seed: string): Segment {
  const durationMin = flightMinutes(from, to);
  return {
    carrier,
    carrierName: carrierName(carrier),
    flightNumber: `${carrier}${100 + (hash32(`${seed}|${from}${to}`) % 880)}`,
    from,
    to,
    departure,
    arrival: arrivalStamp(departure, from, to, durationMin),
    durationMin,
  };
}

const DEP_TIMES = ["06:40", "09:15", "11:50", "14:25", "17:05", "20:35", "22:10"];
const HUBS: [string, string][] = [["QR", "DOH"], ["EK", "DXB"], ["SQ", "SIN"]];

/** Up to three ways to fly one multi-city flight on its date, as segment lists. */
function legOptions(leg: TripLeg): Segment[][] {
  const out: Segment[][] = [];
  const seen = new Set<string>();
  const add = (segs: Segment[]) => {
    const sig = segs.map((x) => x.flightNumber).join("-");
    if (!seen.has(sig) && out.length < 3) { seen.add(sig); out.push(segs); }
  };
  // 1. Real routings from the sample schedule that cover this pair.
  for (const r of ROUTINGS) {
    for (const list of [r.outbound, r.inbound]) {
      const i = list.findIndex((l) => l.from === leg.from);
      const j = list.findIndex((l, k) => k >= i && l.to === leg.to);
      if (i < 0 || j < 0) continue;
      const part = list.slice(i, j + 1);
      add(buildSegments(leg.date, part.map((l) => ({ ...l, dayOffset: l.dayOffset - part[0].dayOffset }))));
    }
  }
  // 2. Plausible synthetic flights: direct for regional hops, via a Gulf/Asian hub for long haul.
  const km = distanceKm(leg.from, leg.to);
  const h = hash32(`${leg.from}${leg.to}`);
  if (out.length && km < 4500) return out;
  if (km < 4500) {
    const africa = region(leg.from) === "africa" && region(leg.to) === "africa";
    const carriers = africa ? ["4Z", "SA", "FA"] : leg.from === "MEL" || leg.to === "MEL" ? ["QF", "VA", "QF"] : ["QR", "EK", "SQ"];
    for (let k = 0; k < 3; k++) {
      const time = DEP_TIMES[(h + k * 2) % DEP_TIMES.length];
      add([makeSegment(carriers[k], leg.from, leg.to, `${leg.date}T${time}`, `${leg.date}|${k}`)]);
    }
    return out;
  }
  for (let k = 0; k < HUBS.length; k++) {
    const [carrier, hub] = HUBS[k];
    if (hub === leg.from || hub === leg.to) continue;
    const first = makeSegment(carrier, leg.from, hub, `${leg.date}T${DEP_TIMES[(h + k * 3) % DEP_TIMES.length]}`, `${leg.date}|${k}a`);
    const connect = 95 + (hash32(`${leg.date}${hub}${leg.to}`) % 20) * 10; // 1h35 .. 4h45
    const second = makeSegment(carrier, hub, leg.to, addMinutesLocal(first.arrival, connect), `${leg.date}|${k}b`);
    add([first, second]);
  }
  return out;
}

function multiCityOffers(params: SearchParams, departureDate: string): FlightOffer[] {
  const legs = legsFor(params, departureDate);
  if (!legs) return [];
  const options = legs.map(legOptions);
  if (options.some((o) => o.length === 0)) return [];
  const combos: number[][] = [];
  const total = options.reduce((n, o) => n * o.length, 1);
  for (let c = 0; c < Math.min(total, 60); c++) {
    let rest = c;
    combos.push(options.map((o) => { const i = rest % o.length; rest = Math.floor(rest / o.length); return i; }));
  }
  const cabinMult = params.cabin === "BUSINESS" ? 3.6 : params.cabin === "PREMIUM_ECONOMY" ? 1.9 : 1;
  const offers: FlightOffer[] = [];
  for (const combo of combos) {
    const its: Itinerary[] = combo.map((i, n) => buildItinerary(options[n][i]));
    // Each flight must leave at least an hour after the previous one lands.
    const ok = its.every((it, n) => {
      if (n === 0) return true;
      const prev = its[n - 1].segments.at(-1)!;
      return utcMs(it.segments[0].departure, it.segments[0].from) - utcMs(prev.arrival, prev.to) >= 60 * 60_000;
    });
    if (!ok || its.some((it) => it.segments.length - 1 > params.maxStops)) continue;
    const sig = its.map((it) => it.segments.map((x) => x.flightNumber).join("+")).join("/");
    const noise = 0.92 + (hash32(`${sig}|${departureDate}`) % 1600) / 10_000;
    const base = legs.reduce((sum, l) => sum + distanceKm(l.from, l.to) * 0.075 + 90, 0);
    const perAdult = Math.round((base * seasonMultiplier(departureDate) * weekdayMultiplier(departureDate) * noise * cabinMult) / 5) * 5;
    const perChild = Math.round((perAdult * 0.75) / 5) * 5;
    const perInfant = Math.round((perAdult * 0.1) / 5) * 5;
    const counts = new Map<string, number>();
    for (const it of its) for (const x of it.segments) counts.set(x.carrier, (counts.get(x.carrier) ?? 0) + x.durationMin);
    const validating = [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
    offers.push({
      id: `sample-${departureDate}-mc-${hash32(sig).toString(36)}`,
      provider: "sample",
      price: { total: perAdult * params.adults + perChild * params.children + perInfant * params.infants, currency: params.currency, perAdult, perChild },
      validatingCarrier: validating,
      validatingCarrierName: carrierName(validating),
      outbound: its[0],
      legs: its,
      departureDate,
      seatsLeft: 2 + (hash32(`seats|${sig}`) % 8),
    });
  }
  return offers.sort((a, b) => a.price.total - b.price.total).slice(0, 8);
}

export class SampleProvider implements FlightProvider {
  readonly name = "sample" as const;
  readonly isSample = true;

  async search(params: SearchParams, departureDate: string, returnDate?: string): Promise<FlightOffer[]> {
    if (params.route) {
      await new Promise((res) => setTimeout(res, 40));
      return multiCityOffers(params, departureDate);
    }
    const offers: FlightOffer[] = [];
    const so = params.stopover;
    for (const r of ROUTINGS) {
      let outSegs = buildSegments(departureDate, r.outbound);
      let inSegs = params.tripType === "return" && returnDate ? buildSegments(returnDate, r.inbound) : undefined;
      if (so?.leg === "outbound") {
        const split = legWithStopover(departureDate, r.outbound, so.airport, so.nights);
        if (!split) continue;
        outSegs = split;
      } else if (so?.leg === "return") {
        const split = returnDate ? legWithStopover(returnDate, r.inbound, so.airport, so.nights) : null;
        if (!split) continue;
        inSegs = split;
      }
      let outbound = buildItinerary(outSegs);
      let inbound = inSegs ? buildItinerary(inSegs) : undefined;
      if (so?.leg === "outbound") outbound = markStopover(outbound, so.airport);
      if (so?.leg === "return" && inbound) inbound = markStopover(inbound, so.airport);
      if (outbound.segments.length - 1 > params.maxStops) continue;
      if (inbound && inbound.segments.length - 1 > params.maxStops) continue;

      const noise = 0.92 + (hash32(`${r.key}|${departureDate}|${returnDate ?? ""}`) % 1600) / 10_000; // 0.92 .. 1.08
      const season = returnDate ? seasonMultiplier(departureDate) * 0.6 + seasonMultiplier(returnDate) * 0.4 : seasonMultiplier(departureDate);
      const cabinMult = params.cabin === "BUSINESS" ? 3.6 : params.cabin === "PREMIUM_ECONOMY" ? 1.9 : 1;
      const tripMult = (inbound ? 1.75 : 1) * (so ? 1.06 : 1);
      const perAdult = Math.round((r.baseFare * tripMult * season * weekdayMultiplier(departureDate) * noise * cabinMult) / 5) * 5;
      const perChild = Math.round((perAdult * 0.75) / 5) * 5;
      const perInfant = Math.round((perAdult * 0.1) / 5) * 5;
      const total = perAdult * params.adults + perChild * params.children + perInfant * params.infants;

      offers.push({
        id: `sample-${departureDate}-${r.key}${so ? `-${so.airport}${so.nights}${so.leg[0]}` : ""}`,
        provider: "sample",
        price: { total, currency: params.currency, perAdult, perChild },
        validatingCarrier: r.validating,
        validatingCarrierName: carrierName(r.validating),
        outbound,
        inbound,
        departureDate,
        returnDate: inbound ? returnDate : undefined,
        seatsLeft: 2 + (hash32(`seats|${r.key}|${departureDate}`) % 8),
        ...(so ? { stopover: so } : {}),
      });
    }
    // A little latency so the UI's progress states are exercised in dev.
    await new Promise((res) => setTimeout(res, 40));
    return offers;
  }
}
