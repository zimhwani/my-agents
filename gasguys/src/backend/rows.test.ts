import { describe, expect, it } from "vitest";
import { DEFAULT_TARIFF } from "../../core/pricing.ts";
import { daysLeft } from "../../core/service.ts";
import { isOpenRefill, rowToCustomer, rowToMeter, rowToPayment, rowToRefill, tariffFrom, toE164, upsertById } from "./rows.ts";

describe("Postgres rows → core types", () => {
  it("maps a payment row, including numeric columns that arrive as strings", () => {
    const p = rowToPayment({
      id: "p1",
      reference: "GG-ABC234",
      customer_id: "c1",
      payer_phone: "263771234567",
      payer_name: "Tendai Moyo",
      meter_id: "37012345678",
      method: "card",
      currency: "ZWG",
      amount: "53.00",
      amount_usd: "2.00",
      grams: 1080,
      status: "paid",
      provider_ref: null,
      poll_url: null,
      gift: true,
      gift_message: "For Gogo",
      token: "123456789012",
      delivery: "token",
      channel: "web",
      created_at: "2026-09-30T10:00:00Z",
      settled_at: "2026-09-30T10:01:00Z",
    });
    expect(p).toMatchObject({ amount: 53, amountUsd: 2, currency: "ZWG", method: "card", gift: true, delivery: "token", customerId: "c1", pollUrl: null });
  });

  it("maps a meter row and ignores columns the app doesn't use", () => {
    const m = rowToMeter({
      id: "37012345678",
      customer_id: "c1",
      suburb: "Mbare",
      cylinder_kg: 9,
      gas_grams: 3100,
      credit_grams: 1240,
      valve: "open",
      online: true,
      battery_pct: 88,
      leak: false,
      tamper: false,
      token_counter: 4,
      avg_daily_grams: 190,
      last_seen: "2026-09-30T10:00:00Z",
      installed_at: "2026-01-01T00:00:00Z",
    });
    expect(m).toEqual({
      id: "37012345678",
      customerId: "c1",
      suburb: "Mbare",
      cylinderKg: 9,
      gasGrams: 3100,
      creditGrams: 1240,
      valve: "open",
      online: true,
      batteryPct: 88,
      leak: false,
      tamper: false,
      tokenCounter: 4,
      avgDailyGrams: 190,
      lastSeen: "2026-09-30T10:00:00Z",
    });
    expect(daysLeft(m)).toBe(6);
  });

  it("falls back to safe values for unexpected enum values", () => {
    expect(rowToCustomer({ id: "c1", phone: "263771234567", name: null, lang: "fr", created_at: "x" })).toEqual({ id: "c1", phone: "263771234567", name: "", lang: "en", createdAt: "x" });
    expect(rowToMeter({ id: "1", valve: "ajar" }).valve).toBe("closed");
    const r = rowToRefill({ id: "r1", meter_id: "1", status: "scheduled", slot: "Tomorrow", auto: false, created_at: "x" });
    expect(isOpenRefill(r)).toBe(true);
    expect(isOpenRefill({ ...r, status: "delivered" })).toBe(false);
  });

  it("reads the tariff setting over the defaults", () => {
    expect(tariffFrom({ usdPerKg: 2, zwgPerUsd: "bad" })).toEqual({ ...DEFAULT_TARIFF, usdPerKg: 2 });
    expect(tariffFrom(null)).toEqual(DEFAULT_TARIFF);
  });

  it("formats phones for Supabase Auth and merges rows newest first", () => {
    expect(toE164("263771234567")).toBe("+263771234567");
    const a = { id: "a", createdAt: "2026-09-30T09:00:00Z", v: 1 };
    const b = { id: "b", createdAt: "2026-09-30T10:00:00Z", v: 1 };
    expect(upsertById(upsertById([a], b), { ...a, v: 2 })).toEqual([b, { ...a, v: 2 }]);
  });
});
