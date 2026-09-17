export type TripType = "return" | "oneway";
export type Cabin = "ECONOMY" | "PREMIUM_ECONOMY" | "BUSINESS";
export type SortMode = "best" | "cheapest" | "fastest";

export interface SearchParams {
  origin: string;
  destination: string;
  tripType: TripType;
  /** First departure date considered, YYYY-MM-DD */
  windowStart: string;
  /** Last departure date considered, YYYY-MM-DD */
  windowEnd: string;
  /** Nights at destination for return trips */
  stayNights: number;
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
}

export interface Itinerary {
  segments: Segment[];
  durationMin: number;
  layovers: Layover[];
}

export interface FlightOffer {
  id: string;
  provider: "amadeus" | "sample";
  price: { total: number; currency: string; perAdult?: number; perChild?: number };
  validatingCarrier: string;
  validatingCarrierName: string;
  outbound: Itinerary;
  inbound?: Itinerary;
  departureDate: string;
  returnDate?: string;
  seatsLeft?: number;
  bookingUrl?: string;
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
  provider: "amadeus" | "sample";
  isSample: boolean;
  generatedAt: string;
  offers: RankedOffer[];
  byDate: DatePricePoint[];
  datesScanned: number;
  warnings: string[];
}

export interface FlightProvider {
  readonly name: "amadeus" | "sample";
  readonly isSample: boolean;
  search(params: SearchParams, departureDate: string, returnDate?: string): Promise<FlightOffer[]>;
}

/** Intents the voice agent understands (shared by the local parser and Claude). */
export type Intent =
  | { type: "search" }
  | { type: "set_dates"; windowStart?: string; windowEnd?: string }
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
