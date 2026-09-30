// The sandbox backend must behave exactly as the app's direct sandbox calls did.
import { describe, expect, it } from "vitest";
import { DEMO_METER, DEMO_PHONE, GOGO_METER, SPARE_METER, Sandbox } from "../sandbox/index.ts";
import { SandboxBackend } from "./sandbox.ts";

const fresh = () => new SandboxBackend(new Sandbox());

describe("SandboxBackend", () => {
  it("signs in with 123456 only, and new numbers become new customers", async () => {
    const b = fresh();
    expect(b.mode).toBe("sandbox");
    expect(await b.requestOtp(DEMO_PHONE)).toEqual({ ok: true });
    expect(await b.verifyOtp(DEMO_PHONE, "000000", { lang: "en", name: "" })).toEqual({ ok: false, error: "otp_wrong" });
    expect(b.customer()).toBeNull();
    const res = await b.verifyOtp(DEMO_PHONE, "123456", { lang: "sn", name: "Someone" });
    expect(res.ok && res.customer.name).toBe("Tendai Moyo"); // existing customer keeps their name
    expect(b.meters().map((m) => m.id)).toEqual([DEMO_METER]);

    await b.signOut();
    expect(b.customer()).toBeNull();
    const nu = await b.verifyOtp("263779990002", "123456", { lang: "nd", name: "Nomsa" });
    expect(nu.ok && nu.customer).toMatchObject({ name: "Nomsa", lang: "nd" });
    expect(b.meters()).toEqual([]);
    expect(await b.linkMeter(GOGO_METER)).toEqual({ ok: false, error: "meter_taken" });
    expect(await b.linkMeter("370 0000 0000")).toEqual({ ok: false, error: "meter_not_found" });
    const linked = await b.linkMeter("370 5550 1234");
    expect(linked.ok && linked.meter.id).toBe(SPARE_METER);
    expect(b.meters().map((m) => m.id)).toEqual([SPARE_METER]);
  });

  it("buys, lets the tester approve the prompt, and lists the payment", async () => {
    const b = fresh();
    await b.verifyOtp(DEMO_PHONE, "123456", { lang: "en", name: "" });
    const start = await b.startPurchase({ meterId: DEMO_METER, amount: 2, currency: "USD", method: "ecocash", payerPhone: DEMO_PHONE, giftMessage: null });
    if (!start.ok) throw new Error(start.error);
    expect(start.instruction).toEqual({ kind: "ussd_push", phone: DEMO_PHONE });
    expect(start.payment).toMatchObject({ customerId: b.customer()!.id, payerName: "Tendai Moyo", channel: "web", gift: false });
    const prompt = b.sandbox.promptFor(start.payment.reference);
    expect(prompt?.method).toBe("ecocash");
    await b.sandbox.resolvePrompt(prompt!.providerRef, "paid");
    expect(b.payment(start.payment.id)?.status).toBe("paid");
    expect(b.sandbox.promptFor(start.payment.reference)).toBeNull();
    expect(b.payments()[0].id).toBe(start.payment.id);
  });

  it("gifts show the recipient's masked name; refills open once", async () => {
    const b = fresh();
    await b.verifyOtp(DEMO_PHONE, "123456", { lang: "en", name: "" });
    expect(await b.giftLookup("370 9876 5432")).toEqual({ meterId: GOGO_METER, name: "S. Ncube", suburb: "Lupane, Mat North" });
    expect(b.meterOwnerName(GOGO_METER)).toBe("S. Ncube");
    expect(b.meterOwnerName("37099999999")).toBe("370 9999 9999");
    expect(b.openRefill(DEMO_METER)).toBeNull();
    const r = await b.requestRefill(DEMO_METER, "Tomorrow morning · 9 kg");
    expect(r.ok && b.openRefill(DEMO_METER)?.id).toBe(r.ok && r.refill.id);
  });

  it("notifies subscribers when the session changes", async () => {
    const b = fresh();
    let n = 0;
    const off = b.subscribe(() => n++);
    await b.verifyOtp(DEMO_PHONE, "123456", { lang: "en", name: "" });
    expect(n).toBeGreaterThan(0);
    off();
  });
});
