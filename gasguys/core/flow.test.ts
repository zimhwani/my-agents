// End-to-end: WhatsApp bot → payment → webhook → valve credit → notifications, on fake providers.
import { beforeEach, describe, expect, it } from "vitest";
import { MemoryStore, emptyData } from "../src/sandbox/store.ts";
import { handleInbound } from "./bot.ts";
import { ValveDevice, newDevice } from "./device.ts";
import type { MeterGateway, Messenger, OutMessage, PaymentProvider } from "./providers.ts";
import { GasguysService } from "./service.ts";
import { randomKeyHex } from "./token.ts";

const PHONE = "263771234567";
const METER = "37012345678";

let svc: GasguysService;
let store: MemoryStore;
let device: ValveDevice;
let online = true;
let sent: Record<string, OutMessage[]>;
let refs: string[];

beforeEach(async () => {
  store = new MemoryStore(emptyData(), () => {});
  const key = randomKeyHex();
  store.data.meterKeys[METER] = key;
  device = new ValveDevice(newDevice(METER, 9000, 0), key);
  online = true;
  sent = {};
  refs = [];
  const payments: PaymentProvider = {
    name: "fake",
    supports: () => true,
    initiate: async (r) => (refs.push(r.reference), { ok: true, providerRef: "P" + r.reference, instruction: { kind: "ussd_push", phone: r.payerPhone } }),
    poll: async () => "pending",
  };
  const gateway: MeterGateway = {
    send: async (_id, cmd) => {
      if (!online) return { delivered: false, reason: "offline" };
      if (cmd.type === "credit") device.applyCredit(cmd.grams, cmd.counter);
      return { delivered: true };
    },
  };
  const messenger: Messenger = { send: async (p, m) => void (sent[p] ??= []).push(...m) };
  svc = new GasguysService({ store, payments: [payments], gateway, messenger });
  await store.saveMeter({
    id: METER, customerId: null, suburb: "Mbare", cylinderKg: 9, gasGrams: 9000, creditGrams: 0, valve: "closed",
    online: true, batteryPct: 90, leak: false, tamper: false, tokenCounter: 0, avgDailyGrams: 180, lastSeen: "",
  });
});

const text = (m: OutMessage) => ("text" in m ? m.text : "");

describe("WhatsApp purchase flow", () => {
  it("registers, links a meter, buys $2 with EcoCash and opens the valve", async () => {
    let r = await handleInbound(svc, PHONE, { type: "text", text: "hi" });
    expect(r[0].kind).toBe("buttons");
    r = await handleInbound(svc, PHONE, { type: "button", id: "lang:sn", profileName: "Tendai Moyo" });
    expect(text(r[0])).toContain("11");
    r = await handleInbound(svc, PHONE, { type: "text", text: "370 1234 5678" });
    expect(text(r[0])).toContain("370 1234 5678");
    await handleInbound(svc, PHONE, { type: "button", id: "buy" });
    await handleInbound(svc, PHONE, { type: "button", id: "amt:USD:2" });
    await handleInbound(svc, PHONE, { type: "button", id: "pay:ecocash" });
    r = await handleInbound(svc, PHONE, { type: "button", id: "confirm" });
    expect(text(r[0])).toContain("PIN");
    expect(refs).toHaveLength(1);

    const paid = await svc.settlePayment(refs[0], "paid");
    expect(paid?.delivery).toBe("online");
    expect(paid?.grams).toBe(1080); // $2 at $1.85/kg, rounded down to 10 g
    expect(device.s.creditGrams).toBe(1080);
    expect(device.s.valve).toBe("open");
    expect(text(sent[PHONE].at(-1)!)).toMatch(/kg/);

    // A resent webhook must not credit twice.
    await svc.settlePayment(refs[0], "paid");
    expect(device.s.creditGrams).toBe(1080);
  });

  it("falls back to an offline token the valve accepts exactly once", async () => {
    const c = await svc.ensureCustomer(PHONE, "en", "Tendai");
    await svc.linkMeter(c.id, METER);
    online = false;
    const start = await svc.startPurchase({ meterId: METER, amount: 1, currency: "USD", method: "ecocash", payerPhone: PHONE, payerCustomerId: c.id, channel: "web" });
    expect(start.ok).toBe(true);
    const paid = await svc.settlePayment(start.ok ? start.payment.reference : "", "paid");
    expect(paid?.delivery).toBe("token");
    expect(device.s.creditGrams).toBe(0);
    expect((await device.enterToken(paid!.token!)).ok).toBe(true);
    expect(device.s.creditGrams).toBe(540);
    expect((await device.enterToken(paid!.token!)).ok).toBe(false);
  });

  it("marks a purchase for someone else's meter as a gift and tells the owner", async () => {
    const owner = await svc.ensureCustomer("263712345678", "nd", "Siphiwe Ncube");
    await svc.linkMeter(owner.id, METER);
    expect((await svc.giftLookup(METER))?.name).toBe("S. Ncube");
    const start = await svc.startPurchase({ meterId: METER, amount: 5, currency: "USD", method: "card", payerPhone: "447700900123", payerName: "Tendai", channel: "web" });
    const paid = await svc.settlePayment(start.ok ? start.payment.reference : "", "paid");
    expect(paid?.gift).toBe(true);
    expect(text(sent["263712345678"][0])).toContain("Tendai");
  });

  it("books a refill and warns the owner when the cylinder runs low", async () => {
    const c = await svc.ensureCustomer(PHONE, "en", "Tendai");
    await svc.linkMeter(c.id, METER);
    await svc.ingestTelemetry({ meterId: METER, gasGrams: 900, creditGrams: 5000, valve: "open", batteryPct: 80, leak: false, tamper: false, tokenCounter: 0, at: "" });
    expect(await store.refills({ meterId: METER, open: true })).toHaveLength(1);
    await svc.ingestTelemetry({ meterId: METER, gasGrams: 880, creditGrams: 5000, valve: "open", batteryPct: 80, leak: false, tamper: false, tokenCounter: 0, at: "" });
    expect(await store.refills({ meterId: METER })).toHaveLength(1); // no duplicate booking
    expect(sent[PHONE]).toHaveLength(1);
  });

  it("rejects amounts under the minimum", async () => {
    const r = await svc.startPurchase({ meterId: METER, amount: 0.2, currency: "USD", method: "ecocash", payerPhone: PHONE, channel: "web" });
    expect(r).toEqual({ ok: false, error: "amount_too_small" });
  });
});
