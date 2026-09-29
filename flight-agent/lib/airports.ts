export interface Airport {
  code: string;
  city: string;
  name: string;
  country: string;
  /** IANA timezone, used only for descriptive output */
  tz: string;
  lat: number;
  lon: number;
}

export const AIRPORTS: Record<string, Airport> = {
  MEL: { code: "MEL", city: "Melbourne", name: "Melbourne Airport (Tullamarine)", country: "Australia", tz: "Australia/Melbourne", lat: -37.67, lon: 144.84 },
  HRE: { code: "HRE", city: "Harare", name: "Robert Gabriel Mugabe International", country: "Zimbabwe", tz: "Africa/Harare", lat: -17.93, lon: 31.09 },
  DOH: { code: "DOH", city: "Doha", name: "Hamad International", country: "Qatar", tz: "Asia/Qatar", lat: 25.27, lon: 51.61 },
  DXB: { code: "DXB", city: "Dubai", name: "Dubai International", country: "United Arab Emirates", tz: "Asia/Dubai", lat: 25.25, lon: 55.36 },
  JNB: { code: "JNB", city: "Johannesburg", name: "O. R. Tambo International", country: "South Africa", tz: "Africa/Johannesburg", lat: -26.14, lon: 28.24 },
  ADD: { code: "ADD", city: "Addis Ababa", name: "Bole International", country: "Ethiopia", tz: "Africa/Addis_Ababa", lat: 8.98, lon: 38.8 },
  SIN: { code: "SIN", city: "Singapore", name: "Changi", country: "Singapore", tz: "Asia/Singapore", lat: 1.36, lon: 103.99 },
  SYD: { code: "SYD", city: "Sydney", name: "Kingsford Smith", country: "Australia", tz: "Australia/Sydney", lat: -33.94, lon: 151.18 },
  PER: { code: "PER", city: "Perth", name: "Perth Airport", country: "Australia", tz: "Australia/Perth", lat: -31.94, lon: 115.97 },
  LUN: { code: "LUN", city: "Lusaka", name: "Kenneth Kaunda International", country: "Zambia", tz: "Africa/Lusaka", lat: -15.33, lon: 28.45 },
  NBO: { code: "NBO", city: "Nairobi", name: "Jomo Kenyatta International", country: "Kenya", tz: "Africa/Nairobi", lat: -1.32, lon: 36.93 },
  AUH: { code: "AUH", city: "Abu Dhabi", name: "Zayed International", country: "United Arab Emirates", tz: "Asia/Dubai", lat: 24.43, lon: 54.65 },
  BKK: { code: "BKK", city: "Bangkok", name: "Suvarnabhumi", country: "Thailand", tz: "Asia/Bangkok", lat: 13.69, lon: 100.75 },
  HKG: { code: "HKG", city: "Hong Kong", name: "Hong Kong International", country: "China", tz: "Asia/Hong_Kong", lat: 22.31, lon: 113.91 },
  KUL: { code: "KUL", city: "Kuala Lumpur", name: "KLIA", country: "Malaysia", tz: "Asia/Kuala_Lumpur", lat: 2.75, lon: 101.71 },
  CPT: { code: "CPT", city: "Cape Town", name: "Cape Town International", country: "South Africa", tz: "Africa/Johannesburg", lat: -33.97, lon: 18.6 },
  DUR: { code: "DUR", city: "Durban", name: "King Shaka International", country: "South Africa", tz: "Africa/Johannesburg", lat: -29.61, lon: 31.12 },
  VFA: { code: "VFA", city: "Victoria Falls", name: "Victoria Falls Airport", country: "Zimbabwe", tz: "Africa/Harare", lat: -18.1, lon: 25.84 },
  BUQ: { code: "BUQ", city: "Bulawayo", name: "Joshua Mqabuko Nkomo International", country: "Zimbabwe", tz: "Africa/Harare", lat: -20.02, lon: 28.62 },
  MRU: { code: "MRU", city: "Mauritius", name: "Sir Seewoosagur Ramgoolam International", country: "Mauritius", tz: "Indian/Mauritius", lat: -20.43, lon: 57.68 },
  WDH: { code: "WDH", city: "Windhoek", name: "Hosea Kutako International", country: "Namibia", tz: "Africa/Windhoek", lat: -22.48, lon: 17.47 },
  KGL: { code: "KGL", city: "Kigali", name: "Kigali International", country: "Rwanda", tz: "Africa/Kigali", lat: -1.97, lon: 30.14 },
};

export const CARRIERS: Record<string, string> = {
  QR: "Qatar Airways",
  EK: "Emirates",
  EY: "Etihad Airways",
  SQ: "Singapore Airlines",
  QF: "Qantas",
  SA: "South African Airways",
  ET: "Ethiopian Airlines",
  KQ: "Kenya Airways",
  "4Z": "Airlink",
  MK: "Air Mauritius",
  WB: "RwandAir",
  FA: "FlySafair",
  UM: "Air Zimbabwe",
  MH: "Malaysia Airlines",
  CX: "Cathay Pacific",
  TG: "Thai Airways",
  VA: "Virgin Australia",
};

/** Spoken or typed names that aren't the official city name. */
export const CITY_ALIASES: Record<string, string> = {
  joburg: "JNB", "jo burg": "JNB", jozi: "JNB", "o r tambo": "JNB",
  capetown: "CPT", "vic falls": "VFA", "victoria falls": "VFA",
  "abu dhabi": "AUH", "addis": "ADD", mauritius: "MRU", "kuala lumpur": "KUL", "hong kong": "HKG",
};

/** Great-circle distance in km (for sample fares and flight times). */
export function distanceKm(a: string, b: string): number {
  const A = AIRPORTS[a];
  const B = AIRPORTS[b];
  if (!A || !B) return 9000;
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(B.lat - A.lat) / 2) ** 2 + Math.cos(r(A.lat)) * Math.cos(r(B.lat)) * Math.sin(r(B.lon - A.lon) / 2) ** 2;
  return Math.round(2 * 6371 * Math.asin(Math.sqrt(h)));
}

export function region(code: string): "australia" | "africa" | "other" {
  const tz = AIRPORTS[code]?.tz ?? "";
  if (tz.startsWith("Australia/")) return "australia";
  if (tz.startsWith("Africa/") || tz.startsWith("Indian/")) return "africa";
  return "other";
}

/** "Johannesburg (JNB)", "jnb", "joburg" -> "JNB". Unknown 3-letter codes pass through. */
export function resolveAirport(input: string): string | null {
  const t = input.trim().toLowerCase();
  if (!t) return null;
  const paren = /\(([a-z]{3})\)\s*$/.exec(t);
  if (paren) return paren[1].toUpperCase();
  if (/^[a-z]{3}$/.test(t)) return t.toUpperCase();
  if (CITY_ALIASES[t]) return CITY_ALIASES[t];
  const hit = Object.values(AIRPORTS).find((a) => a.city.toLowerCase() === t || a.name.toLowerCase() === t);
  return hit?.code ?? null;
}

export function airportLabel(code: string): string {
  const a = AIRPORTS[code];
  return a ? a.city : code;
}

export function carrierName(code: string, dictionary?: Record<string, string>): string {
  const fromDict = dictionary?.[code];
  if (fromDict) return titleCase(fromDict);
  return CARRIERS[code] ?? code;
}

function titleCase(s: string): string {
  return s
    .toLowerCase()
    .split(/\s+/)
    .map((w) => (w.length ? w[0].toUpperCase() + w.slice(1) : w))
    .join(" ");
}
