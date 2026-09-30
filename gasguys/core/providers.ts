// The seams between Gasguys and the outside world. The sandbox (src/sandbox) implements every one
// with a simulator so the whole journey can be tested before any credentials exist; the Supabase
// edge functions implement them against Paynow / EcoCash / InnBucks, the MQTT broker and the
// WhatsApp Cloud API. Swapping one for the other is a constructor argument, not a code change.

import type { Alert, Currency, Customer, Meter, PayMethod, Payment, RefillOrder } from "./types.ts";

// ── Payments ────────────────────────────────────────────────────────────────────────────────────

export type PaymentRequest = {
  reference: string;
  method: PayMethod;
  currency: Currency;
  amount: number;
  payerPhone: string; // wallet to push the EcoCash prompt to
  description: string;
};

/** What the customer has to do next, rendered by the web app and the bot. */
export type PaymentInstruction =
  | { kind: "ussd_push"; phone: string } // EcoCash: a PIN prompt pops up on the phone
  | { kind: "code"; code: string; expiresAt: string; deepLink?: string } // InnBucks: pay a code in the app
  | { kind: "redirect"; url: string }; // Card / diaspora: hosted checkout page

export type InitiateResult =
  | { ok: true; providerRef: string; instruction: PaymentInstruction; pollUrl?: string }
  | { ok: false; error: string };

export type ProviderStatus = "pending" | "paid" | "failed" | "expired";

export interface PaymentProvider {
  readonly name: string;
  supports(method: PayMethod, currency: Currency): boolean;
  initiate(req: PaymentRequest): Promise<InitiateResult>;
  /** Pull status, for when a webhook is late or lost. */
  poll(providerRef: string, pollUrl?: string): Promise<ProviderStatus>;
}

// ── Meters ──────────────────────────────────────────────────────────────────────────────────────

export type MeterCommand =
  | { type: "credit"; grams: number; counter: number } // add credit; counter marks the token as used
  | { type: "set_valve"; open: boolean } // remote shut-off (ops only)
  | { type: "clear_leak" } // technician has checked the site
  | { type: "ping" };

export type CommandResult = { delivered: boolean; reason?: "offline" | "timeout" | "rejected" };

export interface MeterGateway {
  send(meterId: string, cmd: MeterCommand): Promise<CommandResult>;
}

// ── Messaging (WhatsApp, with SMS as a fallback for safety alerts) ─────────────────────────────

export type OutMessage =
  | { kind: "text"; text: string }
  | { kind: "buttons"; text: string; buttons: { id: string; title: string }[] } // max 3, titles ≤ 20
  | { kind: "list"; text: string; button: string; rows: { id: string; title: string; description?: string }[] } // max 10
  | { kind: "template"; name: string; params: string[]; text: string }; // business-initiated, pre-approved

export interface Messenger {
  send(phone: string, messages: OutMessage[]): Promise<void>;
}

// ── Storage ─────────────────────────────────────────────────────────────────────────────────────

export interface Store {
  customerById(id: string): Promise<Customer | null>;
  customerByPhone(phone: string): Promise<Customer | null>;
  saveCustomer(c: Customer): Promise<void>;

  meter(id: string): Promise<Meter | null>;
  metersFor(customerId: string): Promise<Meter[]>;
  allMeters(): Promise<Meter[]>;
  saveMeter(m: Meter): Promise<void>;
  meterKey(id: string): Promise<string | null>; // per-valve secret; lives in a locked-down table

  payment(id: string): Promise<Payment | null>;
  paymentByRef(reference: string): Promise<Payment | null>;
  paymentsFor(opts: { customerId?: string; meterId?: string; limit?: number }): Promise<Payment[]>;
  savePayment(p: Payment): Promise<void>;

  refills(opts: { meterId?: string; open?: boolean }): Promise<RefillOrder[]>;
  saveRefill(r: RefillOrder): Promise<void>;

  alerts(opts: { meterId?: string; open?: boolean }): Promise<Alert[]>;
  saveAlert(a: Alert): Promise<void>;

  /** Conversation state for the WhatsApp bot, keyed by phone. */
  botSession(phone: string): Promise<unknown | null>;
  saveBotSession(phone: string, state: unknown): Promise<void>;
}
