// The customer app's backend in live mode. Supabase Auth phone OTP for sign-in (the code is delivered
// on WhatsApp by the auth-send-sms hook), row-level-security SELECTs for reads, Realtime on meters,
// payments and refill orders for live updates, and edge functions for every write. The browser only
// ever holds the anon key and the customer's own session; money and meter state are written by the
// edge functions with the service role (supabase/migrations/0002_rls.sql).

import { createClient, type RealtimeChannel, type SupabaseClient } from "@supabase/supabase-js";
import { DEFAULT_TARIFF, type Tariff } from "../../core/pricing.ts";
import type { PaymentInstruction } from "../../core/providers.ts";
import { daysLeft, formatMeterId, maskName, normalizeMeterId } from "../../core/service.ts";
import type { Customer, Lang, Meter, Payment, RefillOrder } from "../../core/types.ts";
import { isOpenRefill, rowToCustomer, rowToMeter, rowToPayment, rowToRefill, tariffFrom, toE164, upsertById } from "./rows.ts";
import type { Backend, Fail, GiftRecipient, PurchaseRequest, PurchaseResult } from "./types.ts";

/** Placeholder until the business WhatsApp number exists; same placeholder as the app's support phone. */
const SUPPORT_WHATSAPP = "https://wa.me/263000000000";
const POLL_MS = 3000;
const POLL_GIVE_UP_MS = 15 * 60_000;

export class SupabaseBackend implements Backend {
  readonly mode = "live" as const;
  readonly sandbox = null;
  readonly supportWhatsApp = SUPPORT_WHATSAPP;

  private sb: SupabaseClient;
  private isReady = false;
  private listeners = new Set<() => void>();
  private uid: string | null = null;
  private me: Customer | null = null;
  private myMeters: Meter[] = [];
  private myPayments: Payment[] = [];
  private refills: RefillOrder[] = [];
  private currentTariff: Tariff = DEFAULT_TARIFF;
  private owners = new Map<string, string | null>(); // meterId → masked owner name (null = lookup in flight/failed)
  private channel: RealtimeChannel | null = null;
  private refreshTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(url: string, anonKey: string) {
    this.sb = createClient(url, anonKey, { auth: { persistSession: true, autoRefreshToken: true, storageKey: "gasguys.auth" } });
    void this.init();
  }

  private async init() {
    try {
      await this.loadTariff();
      const { data } = await this.sb.auth.getSession();
      if (data.session) await this.load(data.session.user.id);
    } catch (e) {
      console.warn("gasguys: could not restore session", e);
    }
    // Token refresh failures and sign-outs in another tab end the session here too.
    this.sb.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session) {
        if (this.uid) this.clear();
      }
    });
    this.isReady = true;
    this.emit();
  }

  ready() {
    return this.isReady;
  }

  subscribe(fn: () => void) {
    this.listeners.add(fn);
    return () => void this.listeners.delete(fn);
  }

  private emit() {
    this.listeners.forEach((l) => l());
  }

  tariff() {
    return this.currentTariff;
  }
  daysLeft(m: Meter) {
    return daysLeft(m);
  }

  // ── Sign-in ──

  async requestOtp(phone: string) {
    // channel "sms" on purpose: the Send SMS auth hook (supabase/functions/auth-send-sms) receives the
    // code and delivers it through our own WhatsApp template. Supabase's built-in channel "whatsapp"
    // only works with its Twilio provider.
    const { error } = await this.sb.auth.signInWithOtp({ phone: toE164(phone), options: { channel: "sms" } });
    return error ? ({ ok: false, error: error.status === 429 ? "rate_limited" : "otp_send_failed" } as Fail) : ({ ok: true } as const);
  }

  async verifyOtp(phone: string, code: string, profile: { lang: Lang; name: string }) {
    const { data, error } = await this.sb.auth.verifyOtp({ phone: toE164(phone), token: code, type: "sms" });
    if (error || !data.user) return { ok: false, error: "otp_wrong" } as Fail;
    // First sign-in creates the customer (or links the one WhatsApp already created) to this login.
    const res = await this.call<{ customer: Customer }>("me", { profile });
    if (!("customer" in res)) return res;
    await this.load(data.user.id, res.customer);
    return { ok: true, customer: res.customer } as const;
  }

  async signOut() {
    await this.sb.auth.signOut();
    this.clear();
  }

  // ── Snapshot ──

  customer() {
    return this.me;
  }
  meters() {
    return this.myMeters;
  }
  payments() {
    return this.myPayments;
  }
  payment(id: string) {
    return this.myPayments.find((p) => p.id === id) ?? null;
  }
  openRefill(meterId: string) {
    return this.refills.find((r) => r.meterId === meterId && isOpenRefill(r)) ?? null;
  }

  private clear() {
    void this.channel?.unsubscribe();
    this.channel = null;
    this.uid = null;
    this.me = null;
    this.myMeters = [];
    this.myPayments = [];
    this.refills = [];
    this.emit();
  }

  private async loadTariff() {
    const { data } = await this.sb.from("settings").select("value").eq("key", "tariff").maybeSingle();
    if (data) this.currentTariff = tariffFrom(data.value);
  }

  /** Loads everything the app shows for the signed-in user, then listens for changes. */
  private async load(uid: string, known?: Customer) {
    this.uid = uid;
    let me = known ?? null;
    if (!me) {
      const { data } = await this.sb.from("customers").select("id,phone,name,lang,created_at").eq("auth_user", uid).maybeSingle();
      me = data ? rowToCustomer(data) : null;
    }
    if (!me) {
      // Signed in, but the customer row isn't linked yet (e.g. the tab closed right after the code).
      const res = await this.call<{ customer: Customer }>("me", {});
      me = "customer" in res ? res.customer : null;
    }
    this.me = me;
    await this.refresh();
    this.listen();
  }

  private async refresh() {
    const me = this.me;
    if (!me) return this.emit();
    // RLS narrows every one of these to the signed-in customer (0002_rls.sql).
    const [meters, payments, refills] = await Promise.all([
      this.sb.from("meters").select("*").eq("customer_id", me.id),
      this.sb.from("payments").select("*").order("created_at", { ascending: false }).limit(100),
      this.sb.from("refill_orders").select("*").in("status", ["requested", "scheduled", "out_for_delivery"]).order("created_at", { ascending: false }),
    ]);
    if (meters.error || payments.error || refills.error) console.warn("gasguys: refresh failed", meters.error ?? payments.error ?? refills.error);
    if (!meters.error) this.myMeters = (meters.data ?? []).map(rowToMeter).sort((a, b) => a.id.localeCompare(b.id));
    if (!payments.error) {
      // Keep rows we already hold that fell outside the window (a payment being watched, say).
      const fresh = (payments.data ?? []).map(rowToPayment);
      this.myPayments = this.myPayments.filter((p) => !fresh.some((f) => f.id === p.id)).reduce((list, p) => upsertById(list, p), fresh);
    }
    if (!refills.error) this.refills = (refills.data ?? []).map(rowToRefill);
    this.emit();
  }

  private refreshSoon() {
    if (this.refreshTimer) clearTimeout(this.refreshTimer);
    this.refreshTimer = setTimeout(() => {
      this.refreshTimer = null;
      void this.refresh();
    }, 250);
  }

  /** Realtime: telemetry changing a meter, a payment settling, ops moving a refill along. */
  private listen() {
    void this.channel?.unsubscribe();
    const me = this.me;
    if (!me) return;
    this.channel = this.sb
      .channel(`customer-${me.id}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "meters", filter: `customer_id=eq.${me.id}` }, (e) => {
        const row = e.new as Record<string, unknown> | undefined;
        if (row && row.id) {
          const m = rowToMeter(row);
          this.myMeters = this.myMeters.map((x) => (x.id === m.id ? m : x));
          this.emit();
        }
        this.refreshSoon();
      })
      // RLS decides which payment and refill rows this user is sent.
      .on("postgres_changes", { event: "*", schema: "public", table: "payments" }, (e) => {
        const row = e.new as Record<string, unknown> | undefined;
        if (row && row.id) {
          this.myPayments = upsertById(this.myPayments, rowToPayment(row));
          this.emit();
        }
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "refill_orders" }, () => this.refreshSoon())
      .subscribe();
  }

  // ── Writes, all through edge functions ──

  /** Calls an edge function with the user's session. Errors come back as { ok: false, error: code }. */
  private async call<T extends object>(fn: string, body: unknown): Promise<T | Fail> {
    const { data, error } = await this.sb.functions.invoke(fn, { body: body as Record<string, unknown> });
    if (!error) return data as T;
    let code = "network";
    try {
      const ctx = (error as { context?: Response }).context;
      const j = ctx && typeof ctx.json === "function" ? await ctx.json() : null;
      if (j && typeof j.error === "string") code = j.error;
    } catch {
      /* not JSON */
    }
    return { ok: false, error: code };
  }

  async updateCustomer(patch: Partial<Pick<Customer, "name" | "lang">>) {
    if (!this.me) return;
    this.me = { ...this.me, ...patch };
    this.emit();
    const res = await this.call<{ customer: Customer }>("me", { update: patch });
    if ("customer" in res) {
      this.me = res.customer;
      this.emit();
    }
  }

  async linkMeter(meterId: string) {
    const res = await this.call<{ meter: Meter }>("link-meter", { meterId: normalizeMeterId(meterId) });
    if (!("meter" in res)) return res;
    this.myMeters = [...this.myMeters.filter((m) => m.id !== res.meter.id), res.meter];
    this.emit();
    this.listen();
    void this.refresh();
    return { ok: true, meter: res.meter } as const;
  }

  watchPayment(id: string) {
    const started = Date.now();
    let stopped = false;
    const tick = async () => {
      if (stopped) return;
      const { data } = await this.sb.from("payments").select("*").eq("id", id).maybeSingle();
      if (stopped) return;
      if (data) {
        const p = rowToPayment(data);
        const before = this.payment(id);
        if (!before || before.status !== p.status || before.delivery !== p.delivery) {
          this.myPayments = upsertById(this.myPayments, p);
          this.emit();
          // Credit landed: pull the meter's new balance too.
          if (p.status !== "pending") void this.refresh();
        }
        if (p.status !== "pending") return;
      }
      if (Date.now() - started < POLL_GIVE_UP_MS) timer = setTimeout(tick, POLL_MS);
    };
    let timer: ReturnType<typeof setTimeout> = setTimeout(tick, 0);
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }

  async requestRefill(meterId: string, slot: string) {
    const res = await this.call<{ refill: RefillOrder }>("refill-request", { meterId, slot });
    if (!("refill" in res)) return res;
    this.refills = [res.refill, ...this.refills.filter((r) => r.id !== res.refill.id)];
    this.emit();
    return { ok: true, refill: res.refill } as const;
  }

  async giftLookup(meterId: string): Promise<GiftRecipient | null> {
    const res = await this.call<{ recipient: GiftRecipient }>("gift-lookup", { meterId: normalizeMeterId(meterId) });
    if (!("recipient" in res)) return null;
    this.owners.set(res.recipient.meterId, res.recipient.name);
    return res.recipient;
  }

  meterOwnerName(meterId: string) {
    const known = this.owners.get(meterId);
    if (known) return known;
    const own = this.myMeters.find((m) => m.id === meterId);
    if (own && this.me) return maskName(this.me.name);
    if (!this.owners.has(meterId)) {
      // Receipts and history for gifts sent: look the name up once, re-render when it arrives.
      this.owners.set(meterId, null);
      void this.giftLookup(meterId).then((r) => r && this.emit());
    }
    return formatMeterId(meterId);
  }

  async startPurchase(req: PurchaseRequest): Promise<PurchaseResult> {
    const res = await this.call<{ payment: Payment; instruction: PaymentInstruction }>("payments-start", req);
    if (!("payment" in res)) return res;
    this.myPayments = upsertById(this.myPayments, res.payment);
    this.emit();
    return { ok: true, payment: res.payment, instruction: res.instruction };
  }
}
