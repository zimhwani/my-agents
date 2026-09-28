/**
 * Google Flights via SerpApi (https://serpapi.com/google-flights-api).
 *
 * One request per departure date. For return trips Google lists the round-trip
 * fare against each outbound option and lets you pick the return leg afterwards,
 * so the offer carries the full round-trip price with the outbound itinerary and
 * `inbound` is left undefined (the booking link opens the same search).
 */
import { carrierName } from "../airports";
import { legsFor } from "../params";
import { buildItinerary } from "../rank";
import type { FlightOffer, FlightProvider, SearchParams, Segment } from "../types";

export interface SerpApiConfig {
  apiKey: string;
}

export function serpApiConfigFromEnv(env: Record<string, string | undefined> = process.env): SerpApiConfig | null {
  const apiKey = env.SERPAPI_KEY?.trim();
  return apiKey ? { apiKey } : null;
}

interface SerpAirport { name?: string; id: string; time: string }
interface SerpFlight {
  departure_airport: SerpAirport;
  arrival_airport: SerpAirport;
  duration?: number;
  airplane?: string;
  airline?: string;
  flight_number?: string;
  overnight?: boolean;
}
interface SerpLayover { duration: number; name?: string; id: string; overnight?: boolean }
export interface SerpItinerary {
  flights: SerpFlight[];
  layovers?: SerpLayover[];
  total_duration?: number;
  price?: number;
  departure_token?: string;
  booking_token?: string;
}
export interface SerpResponse {
  error?: string;
  best_flights?: SerpItinerary[];
  other_flights?: SerpItinerary[];
  search_metadata?: { google_flights_url?: string };
}

const CABIN_CODE: Record<SearchParams["cabin"], number> = { ECONOMY: 1, PREMIUM_ECONOMY: 2, BUSINESS: 3 };

/** "QR 905" -> { carrier: "QR", flightNumber: "QR905" } */
function splitFlightNumber(s: string | undefined): { carrier: string; flightNumber: string } {
  const m = /^([A-Z0-9]{2})\s*([0-9]{1,4}[A-Z]?)$/i.exec((s ?? "").trim());
  if (!m) return { carrier: "", flightNumber: s ?? "" };
  return { carrier: m[1].toUpperCase(), flightNumber: `${m[1].toUpperCase()}${m[2]}` };
}

/** "2026-12-03 22:15" -> "2026-12-03T22:15" */
function stamp(t: string): string {
  return t.trim().replace(" ", "T").slice(0, 16);
}

export function mapSerpItinerary(it: SerpItinerary, params: SearchParams, departureDate: string, returnDate: string | undefined, googleUrl?: string, index = 0): FlightOffer | null {
  if (!it.flights?.length || typeof it.price !== "number") return null;
  const segments: Segment[] = it.flights.map((f) => {
    const { carrier, flightNumber } = splitFlightNumber(f.flight_number);
    return {
      carrier,
      carrierName: f.airline || carrierName(carrier),
      flightNumber,
      from: f.departure_airport.id,
      to: f.arrival_airport.id,
      departure: stamp(f.departure_airport.time),
      arrival: stamp(f.arrival_airport.time),
      durationMin: f.duration ?? 0,
      aircraft: f.airplane,
    };
  });
  const outbound = buildItinerary(segments, it.total_duration);
  const validating = segments[0].carrier;
  const legs = params.stopover ? legsFor(params, departureDate, returnDate) : null;
  return {
    id: `serpapi-${departureDate}-${index}-${segments.map((s) => s.flightNumber).join("-")}`,
    provider: "serpapi",
    price: { total: it.price, currency: params.currency },
    validatingCarrier: validating,
    validatingCarrierName: segments[0].carrierName,
    outbound,
    inbound: undefined,
    departureDate,
    returnDate: params.tripType === "return" ? returnDate : undefined,
    bookingUrl: googleUrl ?? googleFlightsLink(params, departureDate, returnDate),
    ...(legs && params.stopover ? { stopover: params.stopover, laterLegs: legs.slice(1) } : {}),
  };
}

export function googleFlightsLink(params: SearchParams, departureDate: string, returnDate?: string): string {
  const q = returnDate
    ? `Flights from ${params.origin} to ${params.destination} on ${departureDate} returning ${returnDate}`
    : `One way flights from ${params.origin} to ${params.destination} on ${departureDate}`;
  return `https://www.google.com/travel/flights?q=${encodeURIComponent(q)}`;
}

export class SerpApiProvider implements FlightProvider {
  readonly name = "serpapi" as const;
  readonly isSample = false;

  constructor(private readonly cfg: SerpApiConfig, private readonly fetchImpl: typeof fetch = fetch) {}

  buildQuery(params: SearchParams, departureDate: string, returnDate?: string): URLSearchParams {
    const legs = params.stopover ? legsFor(params, departureDate, returnDate) : null;
    const q = new URLSearchParams({
      engine: "google_flights",
      departure_id: params.origin,
      arrival_id: params.destination,
      outbound_date: departureDate,
      type: params.tripType === "return" && returnDate ? "1" : "2",
      adults: String(params.adults),
      children: String(params.children),
      infants_on_lap: String(params.infants),
      currency: params.currency,
      hl: "en",
      gl: "au",
      travel_class: String(CABIN_CODE[params.cabin]),
      // SerpApi: 0 any, 1 nonstop, 2 one stop or fewer, 3 two stops or fewer
      stops: params.maxStops === 0 ? "1" : params.maxStops === 1 ? "2" : params.maxStops === 2 ? "3" : "0",
      api_key: this.cfg.apiKey,
    });
    if (params.tripType === "return" && returnDate) q.set("return_date", returnDate);
    if (legs) {
      // Multi-city: Google Flights prices the whole itinerary and lists options for the first leg.
      q.set("type", "3");
      q.set("multi_city_json", JSON.stringify(legs.map((l) => ({ departure_id: l.from, arrival_id: l.to, date: l.date }))));
      for (const k of ["departure_id", "arrival_id", "outbound_date", "return_date"]) q.delete(k);
    }
    return q;
  }

  async search(params: SearchParams, departureDate: string, returnDate?: string): Promise<FlightOffer[]> {
    const res = await this.fetchImpl(`https://serpapi.com/search.json?${this.buildQuery(params, departureDate, returnDate)}`);
    const json = (await res.json().catch(() => ({}))) as SerpResponse;
    if (!res.ok || json.error) {
      throw new Error(`Google Flights (SerpApi) failed for ${departureDate}: ${json.error ?? res.statusText}`);
    }
    const all = [...(json.best_flights ?? []), ...(json.other_flights ?? [])];
    const url = json.search_metadata?.google_flights_url;
    return all
      .map((it, i) => mapSerpItinerary(it, params, departureDate, returnDate, url, i))
      .filter((o): o is FlightOffer => o !== null);
  }
}
