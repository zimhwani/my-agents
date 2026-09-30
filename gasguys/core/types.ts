// Gasguys domain model. Shared by the web app, the sandbox backend and the Supabase edge functions,
// so it stays dependency-free and runs in the browser, Node and Deno.

export type Lang = "en" | "sn" | "nd";
export type Currency = "USD" | "ZWG";
export type PayMethod = "ecocash" | "innbucks" | "card";

export type Customer = {
  id: string;
  phone: string; // E.164 without "+", e.g. 263771234567
  name: string;
  lang: Lang;
  createdAt: string;
};

export type ValveState = "open" | "closed";

export type Meter = {
  id: string; // printed on the valve and its QR, e.g. GG-10234
  customerId: string | null;
  suburb: string;
  cylinderKg: number; // 9, 14, 19 or 48
  gasGrams: number; // gas physically left in the cylinder (load cell / flow estimate)
  creditGrams: number; // paid-for gas the valve will still let through
  valve: ValveState;
  online: boolean;
  batteryPct: number;
  leak: boolean;
  tamper: boolean;
  tokenCounter: number; // highest token counter issued by the backend
  avgDailyGrams: number;
  lastSeen: string;
};

export type PaymentStatus = "pending" | "paid" | "failed" | "expired";
export type Delivery = "online" | "token";

export type Payment = {
  id: string;
  reference: string; // our reference, shown to the customer and sent to the provider
  customerId: string | null; // who paid, when known
  payerPhone: string;
  payerName: string;
  meterId: string;
  method: PayMethod;
  currency: Currency;
  amount: number; // in `currency`, two decimals
  amountUsd: number;
  grams: number;
  status: PaymentStatus;
  providerRef: string | null;
  pollUrl: string | null; // where to ask the provider for status if the webhook never comes
  gift: boolean;
  giftMessage: string | null;
  token: string | null; // 12-digit offline token, always issued as a fallback
  delivery: Delivery | null;
  channel: "web" | "whatsapp";
  createdAt: string;
  settledAt: string | null;
};

export type RefillStatus = "requested" | "scheduled" | "out_for_delivery" | "delivered" | "cancelled";

export type RefillOrder = {
  id: string;
  meterId: string;
  status: RefillStatus;
  slot: string; // human slot label, e.g. "Tomorrow morning"
  auto: boolean; // raised by the meter's low-gas signal rather than by the customer
  createdAt: string;
};

export type AlertKind = "leak" | "low_gas" | "low_credit" | "tamper" | "offline" | "low_battery";

export type Alert = {
  id: string;
  meterId: string;
  kind: AlertKind;
  at: string;
  resolved: boolean;
};

/** What a meter reports over MQTT (or what the sandbox simulator reports). */
export type Telemetry = {
  meterId: string;
  gasGrams: number;
  creditGrams: number;
  valve: ValveState;
  batteryPct: number;
  leak: boolean;
  tamper: boolean;
  tokenCounter: number;
  at: string;
};
