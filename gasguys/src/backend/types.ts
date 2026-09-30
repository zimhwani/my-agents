// What the customer web app needs from a backend, and nothing more. Two implementations:
// SandboxBackend (src/backend/sandbox.ts) wraps the in-browser sandbox, SupabaseBackend
// (src/backend/supabase.ts) talks to Supabase Auth, Postgres (RLS reads, Realtime) and the edge
// functions. src/backend/index.ts picks one at startup.
//
// Reads are synchronous snapshots so components can render straight from them; the backend keeps
// the snapshot current and calls subscribers when it changes. Writes are async.

import type { Tariff } from "../../core/pricing.ts";
import type { PaymentInstruction } from "../../core/providers.ts";
import type { Currency, Customer, Lang, Meter, PayMethod, Payment, RefillOrder } from "../../core/types.ts";

export type Fail = { ok: false; error: string };

/** What a gift-giver may see about someone else's meter: masked owner name and suburb. */
export type GiftRecipient = { meterId: string; name: string; suburb: string };

export type PurchaseRequest = {
  meterId: string;
  amount: number;
  currency: Currency;
  method: PayMethod;
  /** EcoCash wallet for the PIN prompt; the signed-in customer's own number for other methods. */
  payerPhone: string;
  giftMessage: string | null;
};

export type PurchaseResult = { ok: true; payment: Payment; instruction: PaymentInstruction } | Fail;

/** Only the sandbox has these: demo data to prefill forms, and a way to play the payer's side. */
export type SandboxExtras = {
  demoPhone: string;
  giftMeter: string;
  spareMeter: string;
  otp: string;
  /** The simulated PIN prompt / InnBucks code / card page still waiting for this payment, if any. */
  promptFor(reference: string): { providerRef: string; method: PayMethod } | null;
  resolvePrompt(providerRef: string, status: "paid" | "failed"): Promise<void>;
};

export interface Backend {
  readonly mode: "sandbox" | "live";
  /** Present only in sandbox mode; the app hides every sandbox hint and control when it is null. */
  readonly sandbox: SandboxExtras | null;
  /** Where "Chat on WhatsApp" in Settings goes. */
  readonly supportWhatsApp: string;

  /** False while a live backend restores the session and loads its first snapshot. */
  ready(): boolean;
  /** Called whenever anything the getters below return may have changed. Returns an unsubscribe. */
  subscribe(fn: () => void): () => void;

  tariff(): Tariff;
  daysLeft(m: Meter): number;

  // ── Sign-in ──
  /** Sends a one-time code to a normalized phone (2637XXXXXXXX). */
  requestOtp(phone: string): Promise<{ ok: true } | Fail>;
  /** Checks the code and signs in, creating the customer on first sign-in with `profile`. */
  verifyOtp(phone: string, code: string, profile: { lang: Lang; name: string }): Promise<{ ok: true; customer: Customer } | Fail>;
  signOut(): Promise<void>;

  // ── The signed-in customer ──
  customer(): Customer | null;
  updateCustomer(patch: Partial<Pick<Customer, "name" | "lang">>): Promise<void>;
  meters(): Meter[];
  linkMeter(meterId: string): Promise<{ ok: true; meter: Meter } | Fail>;
  /** Payments the customer made, and payments onto their meters (gifts in), newest first. */
  payments(): Payment[];
  payment(id: string): Payment | null;
  /** Keep one payment fresh until it settles (live: polls the row). Returns a stop function. */
  watchPayment(id: string): () => void;
  openRefill(meterId: string): RefillOrder | null;
  requestRefill(meterId: string, slot: string): Promise<{ ok: true; refill: RefillOrder } | Fail>;

  // ── Buying and gifting ──
  giftLookup(meterId: string): Promise<GiftRecipient | null>;
  /** Masked owner name for a meter shown on a receipt or in history; the meter number if unknown. */
  meterOwnerName(meterId: string): string;
  startPurchase(req: PurchaseRequest): Promise<PurchaseResult>;
}
