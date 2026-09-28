export type TripType = "return" | "oneway";
export type Cabin = "ECONOMY" | "PREMIUM_ECONOMY" | "BUSINESS";
export type SortMode = "best" | "cheapest" | "fastest";

/** A planned multi-day break in one direction (multi-city trip). */
export interface Stopover {
  airport: string;
  nights: number;
  leg: "outbound" | "return";
}

/** One flight leg of a (possibly multi-city) trip. */
export interface TripLeg {
  from: string;
  to: string;
  date: string;
}

export interface SearchParams {
  origin: string;
  destination: string;
  tripType: TripType;
  /** First departure date considered, YYYY-MM-DD */
  windowStart: string;
  /** Last departure date considered, YYYY-MM-DD */
  windowEnd: string;
  /** Nights at destination for return trips (used when returnDate is not set) */
  stayNights: number;
  /** Fixed return date for return trips, YYYY-MM-DD; overrides stayNights */
  returnDate?: string;
  /** Optional stopover: turns the trip into a multi-city itinerary */
  stopover?: Stopover;
  /** Days between sampled departure dates inside the window */
  stepDays: number;
  adults: number;
  children: number;
  infants: number;
  cabin: Cabin;
  currency: string;
  /** Maximum stops per direction (0 = nonstop only) */
  maxStops: number;
}

export interface Segment {
  carrier: string;
  carrierName: string;
  flightNumber: string;
  from: string;
  to: string;
  /** Local wall-clock time at the airport, "YYYY-MM-DDTHH:mm" (no offset) */
  departure: string;
  arrival: string;
  durationMin: number;
  aircraft?: string;
}

export interface Layover {
  airport: string;
  minutes: number;
  overnight: boolean;
  /** Same flight number continues: a stop on the same aircraft, not a connection */
  sameFlight?: boolean;
  /** A planned multi-night stopover, not a connection */
  stopover?: boolean;
}

export interface Itinerary {
  segments: Segment[];
  durationMin: number;
  layovers: Layover[];
}

export interface FlightOffer {
  id: string;
  provider: "serpapi" | "sample";
  price: { total: number; currency: string; perAdult?: number; perChild?: number };
  validatingCarrier: string;
  validatingCarrierName: string;
  outbound: Itinerary;
  inbound?: Itinerary;
  departureDate: string;
  returnDate?: string;
  seatsLeft?: number;
  bookingUrl?: string;
  /** Set for multi-city trips */
  stopover?: Stopover;
  /** Legs after the first that are chosen when booking (live multi-city fares) */
  laterLegs?: TripLeg[];
}

export interface OfferScores {
  best: number;
  cheapest: number;
  fastest: number;
}

export interface RankedOffer extends FlightOffer {
  scores: OfferScores;
  badges: string[];
  warnings: string[];
  totalDurationMin: number;
  stops: number;
}

export interface DatePricePoint {
  date: string;
  cheapest: number | null;
  offerId: string | null;
  offersFound: number;
  error?: string;
}

export interface ScanResult {
  params: SearchParams;
  provider: "serpapi" | "sample";
  isSample: boolean;
  generatedAt: string;
  offers: RankedOffer[];
  byDate: DatePricePoint[];
  datesScanned: number;
  warnings: string[];
}

export interface FlightProvider {
  readonly name: "serpapi" | "sample";
  readonly isSample: boolean;
  search(params: SearchParams, departureDate: string, returnDate?: string): Promise<FlightOffer[]>;
}

/** Intents the voice agent understands (shared by the local parser and Claude). */
export type Intent =
  | { type: "search" }
  | { type: "set_dates"; windowStart?: string; windowEnd?: string; returnDate?: string; returnInferred?: boolean }
  | { type: "set_step"; stepDays: number }
  | { type: "set_stopover"; airport: string | null; nights?: number; leg?: "outbound" | "return"; windowStart?: string; windowEnd?: string; returnDate?: string }
  | { type: "set_passengers"; adults?: number; children?: number; infants?: number }
  | { type: "set_trip"; tripType?: TripType; stayNights?: number }
  | { type: "set_cabin"; cabin: Cabin }
  | { type: "set_sort"; sort: SortMode }
  | { type: "read_results"; count?: number; sort?: SortMode }
  | { type: "select_offer"; index: number }
  | { type: "track"; enabled: boolean; intervalHours?: number }
  | { type: "help" }
  | { type: "stop" }
  | { type: "unknown"; utterance: string };

export interface InterpretResponse {
  intent: Intent;
  /** What the assistant should say back. */
  speech: string;
  source: "claude" | "rules";
}
