/**
 * Deterministic sample fares modelled on the real MEL <-> HRE routings
 * (Gulf carriers via Doha/Dubai, Singapore Airlines + Airlink via Johannesburg,
 * Qantas + Airlink via Sydney/Johannesburg). Used when no Amadeus keys are set
 * so the app, the voice agent and the tests all work offline. Prices are
 * plausible AUD levels with seasonal peaks, not live quotes.
 */
import { carrierName } from "../airports";
import { addDays, parseISODate } from "../dates";
import { buildItinerary } from "../rank";
import type { FlightOffer, FlightProvider, SearchParams, Segment } from "../types";

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
const TZ: Record<string, number> = { HRE: 2, DOH: 3, DXB: 4, AUH: 4, JNB: 2, LUN: 2, SIN: 8, ADD: 3, NBO: 3, PER: 8 };

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

export class SampleProvider implements FlightProvider {
  readonly name = "sample" as const;
  readonly isSample = true;

  async search(params: SearchParams, departureDate: string, returnDate?: string): Promise<FlightOffer[]> {
    const offers: FlightOffer[] = [];
    for (const r of ROUTINGS) {
      const outbound = buildItinerary(buildSegments(departureDate, r.outbound));
      const inbound = params.tripType === "return" && returnDate ? buildItinerary(buildSegments(returnDate, r.inbound)) : undefined;
      if (outbound.segments.length - 1 > params.maxStops) continue;
      if (inbound && inbound.segments.length - 1 > params.maxStops) continue;

      const noise = 0.92 + (hash32(`${r.key}|${departureDate}|${returnDate ?? ""}`) % 1600) / 10_000; // 0.92 .. 1.08
      const season = returnDate ? seasonMultiplier(departureDate) * 0.6 + seasonMultiplier(returnDate) * 0.4 : seasonMultiplier(departureDate);
      const cabinMult = params.cabin === "BUSINESS" ? 3.6 : params.cabin === "PREMIUM_ECONOMY" ? 1.9 : 1;
      const tripMult = inbound ? 1.75 : 1;
      const perAdult = Math.round((r.baseFare * tripMult * season * weekdayMultiplier(departureDate) * noise * cabinMult) / 5) * 5;
      const perChild = Math.round((perAdult * 0.75) / 5) * 5;
      const perInfant = Math.round((perAdult * 0.1) / 5) * 5;
      const total = perAdult * params.adults + perChild * params.children + perInfant * params.infants;

      offers.push({
        id: `sample-${departureDate}-${r.key}`,
        provider: "sample",
        price: { total, currency: params.currency, perAdult, perChild },
        validatingCarrier: r.validating,
        validatingCarrierName: carrierName(r.validating),
        outbound,
        inbound,
        departureDate,
        returnDate: inbound ? returnDate : undefined,
        seatsLeft: 2 + (hash32(`seats|${r.key}|${departureDate}`) % 8),
      });
    }
    // A little latency so the UI's progress states are exercised in dev.
    await new Promise((res) => setTimeout(res, 40));
    return offers;
  }
}
