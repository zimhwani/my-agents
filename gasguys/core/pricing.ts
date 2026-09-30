import type { Currency } from "./types.ts";

// Demo tariff. In production these live in the `settings` table and are changed by ops, not code.
export type Tariff = {
  usdPerKg: number;
  zwgPerUsd: number; // ZiG interbank rate used to quote ZiG prices
  minUsd: number;
  maxUsd: number;
};

export const DEFAULT_TARIFF: Tariff = { usdPerKg: 1.85, zwgPerUsd: 26.5, minUsd: 0.5, maxUsd: 200 };

export const PRESETS_USD = [1, 2, 5, 10];

export const toUsd = (amount: number, currency: Currency, t: Tariff = DEFAULT_TARIFF) =>
  round2(currency === "USD" ? amount : amount / t.zwgPerUsd);

export const fromUsd = (usd: number, currency: Currency, t: Tariff = DEFAULT_TARIFF) =>
  round2(currency === "USD" ? usd : usd * t.zwgPerUsd);

/** Grams of LPG an amount buys. Rounded down to 10 g, the token's unit. */
export function gramsFor(amount: number, currency: Currency, t: Tariff = DEFAULT_TARIFF): number {
  const usd = toUsd(amount, currency, t);
  return Math.floor((usd / t.usdPerKg) * 100) * 10;
}

export function validateAmount(amount: number, currency: Currency, t: Tariff = DEFAULT_TARIFF): string | null {
  if (!Number.isFinite(amount) || amount <= 0) return "amount_invalid";
  const usd = toUsd(amount, currency, t);
  if (usd < t.minUsd) return "amount_too_small";
  if (usd > t.maxUsd) return "amount_too_big";
  return null;
}

/** Rough cooking days a quantity lasts for a household. */
export const daysFor = (grams: number, avgDailyGrams: number) =>
  avgDailyGrams > 0 ? Math.max(0, Math.floor(grams / avgDailyGrams)) : 0;

export const formatMoney = (amount: number, currency: Currency) =>
  currency === "USD" ? `$${amount.toFixed(2)}` : `ZiG ${amount.toFixed(2)}`;

export const formatKg = (grams: number) => `${(grams / 1000).toFixed(grams < 10000 ? 2 : 1)} kg`;

const round2 = (n: number) => Math.round(n * 100) / 100;
