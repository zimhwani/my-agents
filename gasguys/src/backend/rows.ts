// Postgres rows (snake_case, as PostgREST and Realtime return them) → the core types the app renders.
// Pure, so it is unit-tested; the column names mirror supabase/migrations/0001_init.sql.

import { DEFAULT_TARIFF, type Tariff } from "../../core/pricing.ts";
import type { Customer, Lang, Meter, Payment, RefillOrder } from "../../core/types.ts";

type Row = Record<string, unknown>;

const str = (v: unknown, d = "") => (typeof v === "string" ? v : v == null ? d : String(v));
const strOrNull = (v: unknown) => (v == null ? null : String(v));
// numeric(12,2) columns can arrive as strings depending on the client; ints always as numbers.
const num = (v: unknown, d = 0) => {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : d;
};
const bool = (v: unknown) => v === true;
const oneOf = <T extends string>(v: unknown, allowed: readonly T[], d: T): T => (allowed.includes(v as T) ? (v as T) : d);

export const rowToCustomer = (r: Row): Customer => ({
  id: str(r.id),
  phone: str(r.phone),
  name: str(r.name),
  lang: oneOf<Lang>(r.lang, ["en", "sn", "nd"], "en"),
  createdAt: str(r.created_at),
});

export const rowToMeter = (r: Row): Meter => ({
  id: str(r.id),
  customerId: strOrNull(r.customer_id),
  suburb: str(r.suburb),
  cylinderKg: num(r.cylinder_kg, 9),
  gasGrams: num(r.gas_grams),
  creditGrams: num(r.credit_grams),
  valve: oneOf(r.valve, ["open", "closed"] as const, "closed"),
  online: bool(r.online),
  batteryPct: num(r.battery_pct, 100),
  leak: bool(r.leak),
  tamper: bool(r.tamper),
  tokenCounter: num(r.token_counter),
  avgDailyGrams: num(r.avg_daily_grams, 180),
  lastSeen: str(r.last_seen),
});

export const rowToPayment = (r: Row): Payment => ({
  id: str(r.id),
  reference: str(r.reference),
  customerId: strOrNull(r.customer_id),
  payerPhone: str(r.payer_phone),
  payerName: str(r.payer_name),
  meterId: str(r.meter_id),
  method: oneOf(r.method, ["ecocash", "innbucks", "card"] as const, "ecocash"),
  currency: oneOf(r.currency, ["USD", "ZWG"] as const, "USD"),
  amount: num(r.amount),
  amountUsd: num(r.amount_usd),
  grams: num(r.grams),
  status: oneOf(r.status, ["pending", "paid", "failed", "expired"] as const, "pending"),
  providerRef: strOrNull(r.provider_ref),
  pollUrl: strOrNull(r.poll_url),
  gift: bool(r.gift),
  giftMessage: strOrNull(r.gift_message),
  token: strOrNull(r.token),
  delivery: r.delivery === "online" || r.delivery === "token" ? r.delivery : null,
  channel: r.channel === "whatsapp" ? "whatsapp" : "web",
  createdAt: str(r.created_at),
  settledAt: strOrNull(r.settled_at),
});

export const rowToRefill = (r: Row): RefillOrder => ({
  id: str(r.id),
  meterId: str(r.meter_id),
  status: oneOf(r.status, ["requested", "scheduled", "out_for_delivery", "delivered", "cancelled"] as const, "requested"),
  slot: str(r.slot),
  auto: bool(r.auto),
  createdAt: str(r.created_at),
});

/** The `settings.tariff` jsonb, merged over the defaults the way the edge functions do it. */
export const tariffFrom = (value: unknown): Tariff => {
  const v = (value && typeof value === "object" ? value : {}) as Partial<Record<keyof Tariff, unknown>>;
  const pick = (k: keyof Tariff) => (typeof v[k] === "number" && Number.isFinite(v[k]) ? (v[k] as number) : DEFAULT_TARIFF[k]);
  return { usdPerKg: pick("usdPerKg"), zwgPerUsd: pick("zwgPerUsd"), minUsd: pick("minUsd"), maxUsd: pick("maxUsd") };
};

export const isOpenRefill = (r: RefillOrder) => r.status !== "delivered" && r.status !== "cancelled";

/** Supabase Auth wants E.164 with the plus; core keeps phones as bare digits (2637XXXXXXXX). */
export const toE164 = (phone: string) => "+" + phone.replace(/\D/g, "");

/** Keeps a list sorted newest first with at most one row per id: used to merge Realtime rows and fresh fetches. */
export function upsertById<T extends { id: string; createdAt: string }>(list: T[], row: T): T[] {
  return [row, ...list.filter((x) => x.id !== row.id)].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}
