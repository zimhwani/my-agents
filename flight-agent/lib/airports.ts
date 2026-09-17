export interface Airport {
  code: string;
  city: string;
  name: string;
  country: string;
  /** IANA timezone, used only for descriptive output */
  tz: string;
}

export const AIRPORTS: Record<string, Airport> = {
  MEL: { code: "MEL", city: "Melbourne", name: "Melbourne Airport (Tullamarine)", country: "Australia", tz: "Australia/Melbourne" },
  HRE: { code: "HRE", city: "Harare", name: "Robert Gabriel Mugabe International", country: "Zimbabwe", tz: "Africa/Harare" },
  DOH: { code: "DOH", city: "Doha", name: "Hamad International", country: "Qatar", tz: "Asia/Qatar" },
  DXB: { code: "DXB", city: "Dubai", name: "Dubai International", country: "United Arab Emirates", tz: "Asia/Dubai" },
  JNB: { code: "JNB", city: "Johannesburg", name: "O. R. Tambo International", country: "South Africa", tz: "Africa/Johannesburg" },
  ADD: { code: "ADD", city: "Addis Ababa", name: "Bole International", country: "Ethiopia", tz: "Africa/Addis_Ababa" },
  SIN: { code: "SIN", city: "Singapore", name: "Changi", country: "Singapore", tz: "Asia/Singapore" },
  SYD: { code: "SYD", city: "Sydney", name: "Kingsford Smith", country: "Australia", tz: "Australia/Sydney" },
  PER: { code: "PER", city: "Perth", name: "Perth Airport", country: "Australia", tz: "Australia/Perth" },
  LUN: { code: "LUN", city: "Lusaka", name: "Kenneth Kaunda International", country: "Zambia", tz: "Africa/Lusaka" },
  NBO: { code: "NBO", city: "Nairobi", name: "Jomo Kenyatta International", country: "Kenya", tz: "Africa/Nairobi" },
  AUH: { code: "AUH", city: "Abu Dhabi", name: "Zayed International", country: "United Arab Emirates", tz: "Asia/Dubai" },
  BKK: { code: "BKK", city: "Bangkok", name: "Suvarnabhumi", country: "Thailand", tz: "Asia/Bangkok" },
  HKG: { code: "HKG", city: "Hong Kong", name: "Hong Kong International", country: "China", tz: "Asia/Hong_Kong" },
  KUL: { code: "KUL", city: "Kuala Lumpur", name: "KLIA", country: "Malaysia", tz: "Asia/Kuala_Lumpur" },
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
  FA: "FlySafair",
  UM: "Air Zimbabwe",
  MH: "Malaysia Airlines",
  CX: "Cathay Pacific",
  TG: "Thai Airways",
  VA: "Virgin Australia",
};

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
