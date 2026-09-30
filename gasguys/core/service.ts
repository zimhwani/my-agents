// Gasguys business logic. Pure orchestration over the provider interfaces, so the same code runs in
// the browser sandbox and in the Supabase edge functions.

import { t } from "./i18n/index.ts";
import { DEFAULT_TARIFF, daysFor, formatKg, formatMoney, gramsFor, toUsd, validateAmount, type Tariff } from "./pricing.ts";
import type { Messenger, MeterGateway, OutMessage, PaymentInstruction, PaymentProvider, Store } from "./providers.ts";
import { formatToken, generateToken } from "./token.ts";
import type { Alert, AlertKind, Currency, Customer, Lang, Meter, PayMethod, Payment, RefillOrder, Telemetry } from "./types.ts";

export type Deps = {
  store: Store;
  payments: PaymentProvider[];
  gateway: MeterGateway;
  messenger: Messenger;
  tariff?: Tariff;
  now?: () => Date;
  id?: () => string;
};

export type PurchaseInput = {
  meterId: string;
  amount: number;
  currency: Currency;
  method: PayMethod;
  payerPhone: string;
  payerName?: string;
  payerCustomerId?: string | null;
  giftMessage?: string | null;
  channel: "web" | "whatsapp";
};

export type PurchaseStart =
  | { ok: true; payment: Payment; instruction: PaymentInstruction }
  | { ok: false; error: string };

/** Share of cylinder capacity below which we book a refill. */
export const LOW_GAS_SHARE = 0.15;
/** Days of credit below which we nudge a top-up. */
export const LOW_CREDIT_DAYS = 2;

export class GasguysService {
  readonly store: Store;
  readonly tariff: Tariff;
  private d: Deps;

  constructor(deps: Deps) {
    this.d = deps;
    this.store = deps.store;
    this.tariff = deps.tariff ?? DEFAULT_TARIFF;
  }

  private now = () => (this.d.now ? this.d.now() : new Date());
  private iso = () => this.now().toISOString();
  private newId = () => (this.d.id ? this.d.id() : crypto.randomUUID());

  // ── Customers and meters ─────────────────────────────────────────────────────────────────────

  async ensureCustomer(phone: string, lang: Lang = "en", name = ""): Promise<Customer> {
    const existing = await this.store.customerByPhone(phone);
    if (existing) return existing;
    const c: Customer = { id: this.newId(), phone, name, lang, createdAt: this.iso() };
    await this.store.saveCustomer(c);
    return c;
  }

  async updateCustomer(c: Customer, patch: Partial<Pick<Customer, "name" | "lang">>): Promise<Customer> {
    const next = { ...c, ...patch };
    await this.store.saveCustomer(next);
    return next;
  }

  async linkMeter(customerId: string, meterId: string): Promise<{ ok: true; meter: Meter } | { ok: false; error: string }> {
    const m = await this.store.meter(normalizeMeterId(meterId));
    if (!m) return { ok: false, error: "meter_not_found" };
    if (m.customerId && m.customerId !== customerId) return { ok: false, error: "meter_taken" };
    const next = { ...m, customerId };
    await this.store.saveMeter(next);
    return { ok: true, meter: next };
  }

  /** What a gift-giver may see about someone else's meter: initial and surname, and the suburb. */
  async giftLookup(meterId: string): Promise<{ meterId: string; name: string; suburb: string } | null> {
    const m = await this.store.meter(normalizeMeterId(meterId));
    if (!m || !m.customerId) return null;
    const owner = await this.store.customerById(m.customerId);
    return { meterId: m.id, name: maskName(owner?.name ?? ""), suburb: m.suburb };
  }

  daysLeft(m: Meter) {
    return daysFor(Math.min(m.creditGrams, m.gasGrams), m.avgDailyGrams);
  }

  // ── Buying gas ───────────────────────────────────────────────────────────────────────────────

  async startPurchase(input: PurchaseInput): Promise<PurchaseStart> {
    const meter = await this.store.meter(normalizeMeterId(input.meterId));
    if (!meter) return { ok: false, error: "meter_not_found" };
    const invalid = validateAmount(input.amount, input.currency, this.tariff);
    if (invalid) return { ok: false, error: invalid };
    const provider = this.d.payments.find((p) => p.supports(input.method, input.currency));
    if (!provider) return { ok: false, error: "method_unavailable" };

    const payerIsOwner = !!input.payerCustomerId && input.payerCustomerId === meter.customerId;
    const payment: Payment = {
      id: this.newId(),
      reference: newReference(),
      customerId: input.payerCustomerId ?? null,
      payerPhone: input.payerPhone,
      payerName: input.payerName ?? "",
      meterId: meter.id,
      method: input.method,
      currency: input.currency,
      amount: input.amount,
      amountUsd: toUsd(input.amount, input.currency, this.tariff),
      grams: gramsFor(input.amount, input.currency, this.tariff),
      status: "pending",
      providerRef: null,
      pollUrl: null,
      gift: !payerIsOwner && meter.customerId !== null && (input.payerCustomerId ?? null) !== meter.customerId,
      giftMessage: input.giftMessage ?? null,
      token: null,
      delivery: null,
      channel: input.channel,
      createdAt: this.iso(),
      settledAt: null,
    };
    await this.store.savePayment(payment);

    const res = await provider.initiate({
      reference: payment.reference,
      method: input.method,
      currency: input.currency,
      amount: input.amount,
      payerPhone: input.payerPhone,
      description: `Gasguys ${formatKg(payment.grams)} for meter ${meter.id}`,
    });
    if (!res.ok) {
      await this.store.savePayment({ ...payment, status: "failed" });
      return { ok: false, error: res.error };
    }
    const saved = { ...payment, providerRef: res.providerRef, pollUrl: res.pollUrl ?? null };
    await this.store.savePayment(saved);
    return { ok: true, payment: saved, instruction: res.instruction };
  }

  /**
   * Called by the payment webhook (or a poll). Idempotent: providers resend callbacks, and only the
   * first `paid` for a reference ever credits a meter.
   */
  async settlePayment(reference: string, status: "paid" | "failed" | "expired"): Promise<Payment | null> {
    const p = await this.store.paymentByRef(reference);
    if (!p || p.status !== "pending") return p;
    if (status !== "paid") {
      const failed = { ...p, status, settledAt: this.iso() };
      await this.store.savePayment(failed);
      await this.notifyPayer(failed, [{ kind: "text", text: this.tr(await this.payerLang(failed), status === "expired" ? "payment_timeout" : "payment_failed") }]);
      return failed;
    }
    const paid: Payment = { ...p, status: "paid", settledAt: this.iso() };
    await this.store.savePayment(paid);
    return this.deliverCredit(paid);
  }

  /** Issues the token, pushes the credit online if the valve is reachable, and tells everyone. */
  private async deliverCredit(p: Payment): Promise<Payment> {
    const meter = (await this.store.meter(p.meterId))!;
    const key = await this.store.meterKey(meter.id);
    const counter = meter.tokenCounter + 1;
    const token = key ? await generateToken(key, counter, p.grams) : null;
    const res = await this.d.gateway.send(meter.id, { type: "credit", grams: p.grams, counter });
    const delivery = res.delivered ? "online" : "token";
    await this.store.saveMeter({
      ...meter,
      tokenCounter: counter,
      // The meter's own report is the truth; this keeps the dashboard right until it next reports.
      creditGrams: res.delivered ? meter.creditGrams + p.grams : meter.creditGrams,
      valve: res.delivered && !meter.leak && meter.gasGrams > 0 ? "open" : meter.valve,
    });
    const done: Payment = { ...p, token, delivery };
    await this.store.savePayment(done);

    const lang = await this.payerLang(done);
    const kg = (done.grams / 1000).toFixed(2);
    const payerMsgs: OutMessage[] = [
      {
        kind: "buttons",
        text: [
          `✅ ${this.tr(lang, "payment_success")}`,
          delivery === "online" ? this.tr(lang, "credit_sent", { kg }) : this.tr(lang, "token_enter", { kg }),
          delivery === "token" && token ? `🔢 ${formatToken(token)}` : "",
          this.tr(lang, "receipt_ref", { ref: done.reference }),
        ]
          .filter(Boolean)
          .join("\n"),
        buttons: [
          { id: "balance", title: this.tr(lang, "bot_check_balance") },
          { id: "menu", title: this.tr(lang, "bot_menu_button") },
        ],
      },
    ];
    if (done.gift) payerMsgs.push({ kind: "text", text: `🎁 ${this.tr(lang, "gift_sent", { name: (await this.giftLookup(meter.id))?.name ?? meter.id })}` });
    await this.notifyPayer(done, payerMsgs);

    if (done.gift && meter.customerId) {
      const owner = await this.store.customerById(meter.customerId);
      if (owner) {
        const from = done.payerName || "+" + done.payerPhone;
        const text = [
          `🎁 ${this.tr(owner.lang, "gift_received", { name: from, kg })}`,
          done.giftMessage ? `“${done.giftMessage}”` : "",
          delivery === "token" && token ? `${this.tr(owner.lang, "token_enter", { kg })}\n🔢 ${formatToken(token)}` : "",
        ]
          .filter(Boolean)
          .join("\n");
        await this.d.messenger.send(owner.phone, [{ kind: "template", name: "gift_received", params: [from, kg], text }]);
      }
    }
    return done;
  }

  async pollPending(): Promise<void> {
    for (const p of await this.store.paymentsFor({ limit: 50 })) {
      if (p.status !== "pending" || !p.providerRef) continue;
      const provider = this.d.payments.find((x) => x.supports(p.method, p.currency));
      const s = await provider?.poll(p.providerRef, p.pollUrl ?? undefined);
      if (s && s !== "pending") await this.settlePayment(p.reference, s);
    }
  }

  // ── Refills ──────────────────────────────────────────────────────────────────────────────────

  async requestRefill(meterId: string, slot: string, auto = false): Promise<RefillOrder> {
    const open = await this.store.refills({ meterId, open: true });
    if (open[0]) return open[0];
    const r: RefillOrder = { id: this.newId(), meterId, status: "requested", slot, auto, createdAt: this.iso() };
    await this.store.saveRefill(r);
    return r;
  }

  async moveRefill(r: RefillOrder, status: RefillOrder["status"], agentName = "Farai"): Promise<RefillOrder> {
    const next = { ...r, status };
    await this.store.saveRefill(next);
    const meter = await this.store.meter(r.meterId);
    const owner = meter?.customerId ? await this.store.customerById(meter.customerId) : null;
    if (owner && status === "out_for_delivery")
      await this.d.messenger.send(owner.phone, [{ kind: "template", name: "refill_on_way", params: [agentName], text: `🚚 ${this.tr(owner.lang, "refill_on_way", { name: agentName })}` }]);
    if (meter && status === "delivered") {
      // A full cylinder goes on; the valve keeps whatever credit it had.
      await this.store.saveMeter({ ...meter, gasGrams: meter.cylinderKg * 1000 });
      await this.resolve(meter.id, "low_gas");
    }
    return next;
  }

  // ── Telemetry and alerts ─────────────────────────────────────────────────────────────────────

  async ingestTelemetry(tm: Telemetry): Promise<Meter | null> {
    const prev = await this.store.meter(tm.meterId);
    if (!prev) return null;
    const m: Meter = {
      ...prev,
      gasGrams: tm.gasGrams,
      creditGrams: tm.creditGrams,
      valve: tm.valve,
      batteryPct: tm.batteryPct,
      leak: tm.leak,
      tamper: tm.tamper,
      online: true,
      lastSeen: tm.at,
    };
    await this.store.saveMeter(m);
    const owner = m.customerId ? await this.store.customerById(m.customerId) : null;
    const lang = owner?.lang ?? "en";

    if (!prev.online) await this.resolve(m.id, "offline");
    if (m.leak && !prev.leak) {
      await this.raise(m.id, "leak");
      if (owner)
        await this.d.messenger.send(owner.phone, [
          {
            kind: "buttons",
            text: `⚠️ ${this.tr(lang, "leak_title").toUpperCase()}\n${this.tr(lang, "leak_shutoff")}\n${this.tr(lang, "leak_steps")}\n${this.tr(lang, "leak_tech_coming")}`,
            buttons: [
              { id: "safe", title: this.tr(lang, "leak_im_safe").slice(0, 20) },
              { id: "agent", title: this.tr(lang, "bot_talk_agent").slice(0, 20) },
            ],
          },
        ]);
    }
    if (!m.leak && prev.leak) await this.resolve(m.id, "leak");
    if (m.tamper && !prev.tamper) await this.raise(m.id, "tamper");

    const lowGas = m.gasGrams < m.cylinderKg * 1000 * LOW_GAS_SHARE;
    if (lowGas && !(await this.isOpen(m.id, "low_gas"))) {
      await this.raise(m.id, "low_gas");
      await this.requestRefill(m.id, "Next available", true);
      if (owner)
        await this.d.messenger.send(owner.phone, [
          {
            kind: "buttons",
            text: `🛢️ ${this.tr(lang, "low_cylinder_body", { kg: (m.gasGrams / 1000).toFixed(1) })}`,
            buttons: [{ id: "refill", title: this.tr(lang, "refill_title").slice(0, 20) }],
          },
        ]);
    }

    const days = daysFor(m.creditGrams, m.avgDailyGrams);
    const lowCredit = days < LOW_CREDIT_DAYS && !m.leak && !!owner;
    if (lowCredit && !(await this.isOpen(m.id, "low_credit"))) {
      await this.raise(m.id, "low_credit");
      if (owner)
        await this.d.messenger.send(owner.phone, [
          {
            kind: "buttons",
            text: `🔥 ${this.tr(lang, "low_gas_title")}\n${this.tr(lang, "low_gas_body", { days, meter: formatMeterId(m.id) })}`,
            buttons: [
              { id: "buy:1", title: `$1 ≈ ${formatKg(gramsFor(1, "USD", this.tariff))}` },
              { id: "buy:5", title: `$5 ≈ ${formatKg(gramsFor(5, "USD", this.tariff))}` },
              { id: "buy", title: this.tr(lang, "amount_other").slice(0, 20) },
            ],
          },
        ]);
    }
    if (!lowCredit) await this.resolve(m.id, "low_credit");
    if (m.batteryPct < 15 && !(await this.isOpen(m.id, "low_battery"))) await this.raise(m.id, "low_battery");
    return m;
  }

  async markOffline(meterId: string) {
    const m = await this.store.meter(meterId);
    if (!m || !m.online) return;
    await this.store.saveMeter({ ...m, online: false });
    await this.raise(meterId, "offline");
  }

  /** Technician has checked the site: clear the lock on the valve. */
  async clearLeak(meterId: string) {
    await this.d.gateway.send(meterId, { type: "clear_leak" });
    await this.resolve(meterId, "leak");
  }

  private async isOpen(meterId: string, kind: AlertKind) {
    return (await this.store.alerts({ meterId, open: true })).some((a) => a.kind === kind);
  }
  private async raise(meterId: string, kind: AlertKind) {
    if (await this.isOpen(meterId, kind)) return;
    const a: Alert = { id: this.newId(), meterId, kind, at: this.iso(), resolved: false };
    await this.store.saveAlert(a);
  }
  private async resolve(meterId: string, kind: AlertKind) {
    for (const a of await this.store.alerts({ meterId, open: true })) if (a.kind === kind) await this.store.saveAlert({ ...a, resolved: true });
  }

  /** Sends bot replies (or anything else) to a customer on WhatsApp. */
  send(phone: string, messages: OutMessage[]) {
    return this.d.messenger.send(phone, messages);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────────────────────

  private tr = t;

  private async payerLang(p: Payment): Promise<Lang> {
    const c = p.customerId ? await this.store.customerById(p.customerId) : await this.store.customerByPhone(p.payerPhone);
    return c?.lang ?? "en";
  }

  private async notifyPayer(p: Payment, msgs: OutMessage[]) {
    await this.d.messenger.send(p.payerPhone, msgs);
  }

  describePrice(amount: number, currency: Currency) {
    return { label: formatMoney(amount, currency), grams: gramsFor(amount, currency, this.tariff) };
  }
}

// ── Formatting helpers shared by the UI and the bot ────────────────────────────────────────────

/** Meter numbers are 11 digits, like ZESA meters, and printed 3-4-4 on the valve sticker. */
export const normalizeMeterId = (s: string) => s.replace(/\D/g, "");
export const formatMeterId = (id: string) => id.replace(/^(\d{3})(\d{4})(\d{4})$/, "$1 $2 $3");

/** "Tendai Moyo" → "T. Moyo": enough for a gift-giver to recognise family, not enough to dox anyone. */
export function maskName(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "Gasguys customer";
  if (parts.length === 1) return parts[0][0].toUpperCase() + ".";
  return `${parts[0][0].toUpperCase()}. ${parts[parts.length - 1]}`;
}

/** Zimbabwe mobile numbers: accepts 0771234567, 771234567, +263 77 123 4567; returns 263771234567. */
export function normalizePhone(input: string): string | null {
  let d = input.replace(/\D/g, "");
  if (d.startsWith("00")) d = d.slice(2);
  if (d.startsWith("0")) d = "263" + d.slice(1);
  else if (d.length === 9 && d.startsWith("7")) d = "263" + d;
  if (!/^2637[1378]\d{7}$/.test(d)) return null;
  return d;
}

export const formatPhone = (p: string) => p.replace(/^263(\d{2})(\d{3})(\d{4})$/, "0$1 $2 $3");

/** EcoCash-style receipt reference, short enough to read out over the phone. */
export function newReference(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const b = crypto.getRandomValues(new Uint8Array(6));
  return "GG-" + Array.from(b, (x) => alphabet[x % alphabet.length]).join("");
}
