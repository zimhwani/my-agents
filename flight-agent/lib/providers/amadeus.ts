/**
 * Amadeus Self-Service "Flight Offers Search" provider.
 * Docs: https://developers.amadeus.com/self-service/category/flights/api-doc/flight-offers-search
 *
 * Needs AMADEUS_CLIENT_ID / AMADEUS_CLIENT_SECRET. AMADEUS_ENV=test uses the free
 * sandbox (limited airline coverage; results can be sparse for HRE), production
 * uses live GDS content.
 */
import { carrierName } from "../airports";
import { buildItinerary } from "../rank";
import type { FlightOffer, FlightProvider, SearchParams, Segment } from "../types";

interface AmadeusConfig {
  clientId: string;
  clientSecret: string;
  env: "test" | "production";
}

export function amadeusConfigFromEnv(env: NodeJS.ProcessEnv = process.env): AmadeusConfig | null {
  const clientId = env.AMADEUS_CLIENT_ID?.trim();
  const clientSecret = env.AMADEUS_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) return null;
  return { clientId, clientSecret, env: env.AMADEUS_ENV === "production" ? "production" : "test" };
}

/** "PT14H20M" -> 860 */
export function parseIsoDuration(s: string | undefined): number {
  if (!s) return 0;
  const m = /P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?/.exec(s);
  if (!m) return 0;
  const [, d = "0", h = "0", mi = "0"] = m;
  return Number(d) * 1440 + Number(h) * 60 + Number(mi);
}

interface AmadeusSegment {
  departure: { iataCode: string; at: string };
  arrival: { iataCode: string; at: string };
  carrierCode: string;
  number: string;
  aircraft?: { code: string };
  duration?: string;
  operating?: { carrierCode: string };
}
interface AmadeusItinerary {
  duration?: string;
  segments: AmadeusSegment[];
}
interface AmadeusOffer {
  id: string;
  numberOfBookableSeats?: number;
  itineraries: AmadeusItinerary[];
  price: { grandTotal?: string; total: string; currency: string };
  validatingAirlineCodes?: string[];
  travelerPricings?: { travelerType: string; price: { total: string } }[];
}
interface AmadeusResponse {
  data?: AmadeusOffer[];
  dictionaries?: { carriers?: Record<string, string>; aircraft?: Record<string, string> };
  errors?: { status?: number; code?: number; title?: string; detail?: string }[];
}

export function mapAmadeusOffer(
  o: AmadeusOffer,
  params: SearchParams,
  departureDate: string,
  returnDate: string | undefined,
  dict: AmadeusResponse["dictionaries"],
): FlightOffer {
  const toSegments = (it: AmadeusItinerary): Segment[] =>
    it.segments.map((s) => ({
      carrier: s.carrierCode,
      carrierName: carrierName(s.carrierCode, dict?.carriers),
      flightNumber: `${s.carrierCode}${s.number}`,
      from: s.departure.iataCode,
      to: s.arrival.iataCode,
      departure: s.departure.at.slice(0, 16),
      arrival: s.arrival.at.slice(0, 16),
      durationMin: parseIsoDuration(s.duration),
      aircraft: s.aircraft ? dict?.aircraft?.[s.aircraft.code] ?? s.aircraft.code : undefined,
    }));

  const [out, back] = o.itineraries;
  const outbound = buildItinerary(toSegments(out), parseIsoDuration(out.duration) || undefined);
  const inbound = back ? buildItinerary(toSegments(back), parseIsoDuration(back.duration) || undefined) : undefined;
  const validating = o.validatingAirlineCodes?.[0] ?? outbound.segments[0].carrier;
  const adultPrice = o.travelerPricings?.find((t) => t.travelerType === "ADULT")?.price.total;
  const childPrice = o.travelerPricings?.find((t) => t.travelerType === "CHILD")?.price.total;

  return {
    id: `amadeus-${departureDate}-${o.id}`,
    provider: "amadeus",
    price: {
      total: Number(o.price.grandTotal ?? o.price.total),
      currency: o.price.currency,
      perAdult: adultPrice ? Number(adultPrice) : undefined,
      perChild: childPrice ? Number(childPrice) : undefined,
    },
    validatingCarrier: validating,
    validatingCarrierName: carrierName(validating, dict?.carriers),
    outbound,
    inbound,
    departureDate,
    returnDate: inbound ? returnDate : undefined,
    seatsLeft: o.numberOfBookableSeats,
    bookingUrl: googleFlightsLink(params, departureDate, inbound ? returnDate : undefined),
  };
}

/** A deep link the user can open to book; Amadeus self-service does not sell tickets. */
export function googleFlightsLink(params: SearchParams, departureDate: string, returnDate?: string): string {
  const q = returnDate
    ? `Flights from ${params.origin} to ${params.destination} on ${departureDate} returning ${returnDate}`
    : `One way flights from ${params.origin} to ${params.destination} on ${departureDate}`;
  return `https://www.google.com/travel/flights?q=${encodeURIComponent(q)}`;
}

export class AmadeusProvider implements FlightProvider {
  readonly name = "amadeus" as const;
  readonly isSample = false;
  private token: { value: string; expiresAt: number } | null = null;

  constructor(private readonly cfg: AmadeusConfig, private readonly fetchImpl: typeof fetch = fetch) {}

  private get base(): string {
    return this.cfg.env === "production" ? "https://api.amadeus.com" : "https://test.api.amadeus.com";
  }

  private async accessToken(): Promise<string> {
    if (this.token && this.token.expiresAt > Date.now() + 30_000) return this.token.value;
    const res = await this.fetchImpl(`${this.base}/v1/security/oauth2/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "client_credentials",
        client_id: this.cfg.clientId,
        client_secret: this.cfg.clientSecret,
      }),
    });
    if (!res.ok) throw new Error(`Amadeus auth failed (${res.status}): ${await res.text()}`);
    const json = (await res.json()) as { access_token: string; expires_in: number };
    this.token = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
    return this.token.value;
  }

  async search(params: SearchParams, departureDate: string, returnDate?: string): Promise<FlightOffer[]> {
    const token = await this.accessToken();
    const travelers: { id: string; travelerType: string; associatedAdultId?: string }[] = [];
    let id = 1;
    for (let i = 0; i < params.adults; i++) travelers.push({ id: String(id++), travelerType: "ADULT" });
    for (let i = 0; i < params.children; i++) travelers.push({ id: String(id++), travelerType: "CHILD" });
    for (let i = 0; i < params.infants; i++) travelers.push({ id: String(id++), travelerType: "HELD_INFANT", associatedAdultId: String(i + 1) });

    const originDestinations = [
      { id: "1", originLocationCode: params.origin, destinationLocationCode: params.destination, departureDateTimeRange: { date: departureDate } },
    ];
    if (params.tripType === "return" && returnDate) {
      originDestinations.push({ id: "2", originLocationCode: params.destination, destinationLocationCode: params.origin, departureDateTimeRange: { date: returnDate } });
    }

    const body = {
      currencyCode: params.currency,
      originDestinations,
      travelers,
      sources: ["GDS"],
      searchCriteria: {
        maxFlightOffers: 25,
        flightFilters: {
          cabinRestrictions: [{ cabin: params.cabin, coverage: "MOST_SEGMENTS", originDestinationIds: originDestinations.map((o) => o.id) }],
          connectionRestriction: { maxNumberOfConnections: params.maxStops },
        },
      },
    };

    const res = await this.fetchImpl(`${this.base}/v2/shopping/flight-offers`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const json = (await res.json().catch(() => ({}))) as AmadeusResponse;
    if (!res.ok) {
      const detail = json.errors?.map((e) => `${e.title ?? e.code}: ${e.detail ?? ""}`).join("; ") || res.statusText;
      throw new Error(`Amadeus search failed (${res.status}) for ${departureDate}: ${detail}`);
    }
    return (json.data ?? []).map((o) => mapAmadeusOffer(o, params, departureDate, returnDate, json.dictionaries));
  }
}
