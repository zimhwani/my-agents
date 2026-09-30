// The customer app's backend in sandbox mode: the in-browser sandbox (src/sandbox), exactly as the
// app used it before the Backend interface existed. The signed-in customer's id is kept under the
// same localStorage key as before, so sessions and test scripts carry over.

import { formatMeterId, maskName, normalizeMeterId } from "../../core/service.ts";
import type { Customer, Meter } from "../../core/types.ts";
import { DEMO_PHONE, GOGO_METER, SPARE_METER, type Sandbox } from "../sandbox/index.ts";
import type { Backend, Fail, GiftRecipient, PurchaseRequest, PurchaseResult, SandboxExtras } from "./types.ts";

const SESSION = "gasguys.session";
const SANDBOX_OTP = "123456";

const read = (k: string) => {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
};
const write = (k: string, v: string | null) => {
  try {
    if (v === null) localStorage.removeItem(k);
    else localStorage.setItem(k, v);
  } catch {
    /* ignore */
  }
};

export class SandboxBackend implements Backend {
  readonly mode = "sandbox" as const;
  readonly supportWhatsApp = "#/whatsapp";
  readonly sandbox: SandboxExtras;
  private sessionId: string | null = read(SESSION);
  private listeners = new Set<() => void>();

  constructor(private sb: Sandbox) {
    this.sandbox = {
      demoPhone: DEMO_PHONE,
      giftMeter: GOGO_METER,
      spareMeter: SPARE_METER,
      otp: SANDBOX_OTP,
      promptFor: (reference) => {
        const pr = sb.p.prompts.find((x) => x.reference === reference);
        return pr ? { providerRef: pr.providerRef, method: pr.method } : null;
      },
      resolvePrompt: (providerRef, status) => sb.resolvePrompt(providerRef, status),
    };
  }

  ready() {
    return true;
  }

  subscribe(fn: () => void) {
    this.listeners.add(fn);
    const off = this.sb.subscribe(fn);
    return () => {
      this.listeners.delete(fn);
      off();
    };
  }

  private setSession(id: string | null) {
    write(SESSION, id);
    this.sessionId = id;
    this.listeners.forEach((l) => l());
  }

  tariff() {
    return this.sb.svc.tariff;
  }
  daysLeft(m: Meter) {
    return this.sb.svc.daysLeft(m);
  }

  // ── Sign-in: no SMS, the code is always 123456 ──

  async requestOtp(_phone: string) {
    return { ok: true } as const;
  }

  async verifyOtp(phone: string, code: string, profile: { lang: Customer["lang"]; name: string }) {
    if (code !== SANDBOX_OTP) return { ok: false, error: "otp_wrong" } as Fail;
    const customer = await this.sb.svc.ensureCustomer(phone, profile.lang, profile.name);
    this.setSession(customer.id);
    return { ok: true, customer } as const;
  }

  async signOut() {
    this.setSession(null);
  }

  // ── The signed-in customer ──

  customer() {
    return this.sessionId ? (this.sb.p.data.customers[this.sessionId] ?? null) : null;
  }

  async updateCustomer(patch: Partial<Pick<Customer, "name" | "lang">>) {
    const c = this.customer();
    if (c) await this.sb.svc.updateCustomer(c, patch);
  }

  meters() {
    const c = this.customer();
    return c ? Object.values(this.sb.p.data.meters).filter((m) => m.customerId === c.id) : [];
  }

  async linkMeter(meterId: string) {
    const c = this.customer();
    if (!c) return { ok: false, error: "unauthorized" } as Fail;
    return this.sb.svc.linkMeter(c.id, meterId);
  }

  payments() {
    const c = this.customer();
    if (!c) return [];
    const mine = new Set(this.meters().map((m) => m.id));
    return Object.values(this.sb.p.data.payments)
      .filter((p) => p.customerId === c.id || mine.has(p.meterId))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  payment(id: string) {
    return this.sb.p.data.payments[id] ?? null;
  }

  watchPayment() {
    return () => {}; // the sandbox settles payments in this tab and notifies subscribers itself
  }

  openRefill(meterId: string) {
    return Object.values(this.sb.p.data.refills).find((r) => r.meterId === meterId && r.status !== "delivered" && r.status !== "cancelled") ?? null;
  }

  async requestRefill(meterId: string, slot: string) {
    return { ok: true, refill: await this.sb.svc.requestRefill(meterId, slot) } as const;
  }

  // ── Buying and gifting ──

  giftLookup(meterId: string): Promise<GiftRecipient | null> {
    return this.sb.svc.giftLookup(normalizeMeterId(meterId));
  }

  meterOwnerName(meterId: string) {
    const owner = this.sb.p.data.customers[this.sb.p.data.meters[meterId]?.customerId ?? ""];
    return owner ? maskName(owner.name) : formatMeterId(meterId);
  }

  async startPurchase(req: PurchaseRequest): Promise<PurchaseResult> {
    const c = this.customer();
    if (!c) return { ok: false, error: "unauthorized" };
    return this.sb.svc.startPurchase({
      meterId: req.meterId,
      amount: req.amount,
      currency: req.currency,
      method: req.method,
      payerPhone: req.payerPhone,
      payerName: c.name,
      payerCustomerId: c.id,
      giftMessage: req.giftMessage,
      channel: "web",
    });
  }
}
