// The sandbox: the real GasguysService wired to simulated payments, valves and WhatsApp, all in the
// browser. Nothing here talks to a network, and no credentials exist anywhere in it.

import { handleInbound, type Inbound } from "../../core/bot.ts";
import { ValveDevice, newDevice, type DeviceLog, type DeviceState } from "../../core/device.ts";
import type {
  CommandResult,
  InitiateResult,
  Messenger,
  MeterCommand,
  MeterGateway,
  OutMessage,
  PaymentProvider,
  PaymentRequest,
  ProviderStatus,
} from "../../core/providers.ts";
import { GasguysService } from "../../core/service.ts";
import { randomKeyHex } from "../../core/token.ts";
import type { Currency, Meter, PayMethod } from "../../core/types.ts";
import { MemoryStore, emptyData, type SandboxData } from "./store.ts";

export type ChatEntry = { dir: "in" | "out"; at: string; msg: OutMessage | Inbound };

/** A payment waiting on the simulated customer: an EcoCash PIN prompt, an InnBucks code or a card page. */
export type PendingPrompt = {
  providerRef: string;
  reference: string;
  method: PayMethod;
  currency: Currency;
  amount: number;
  phone: string;
  code?: string;
  createdAt: string;
};

type Persisted = {
  v: 1;
  data: SandboxData;
  devices: Record<string, DeviceState>;
  chats: Record<string, ChatEntry[]>;
  prompts: PendingPrompt[];
  settings: { autoApprove: boolean; speed: number; paused: boolean };
};

const KEY = "gasguys.sandbox.v1";

export class Sandbox {
  p: Persisted;
  store: MemoryStore;
  svc: GasguysService;
  devices = new Map<string, ValveDevice>();
  private listeners = new Set<() => void>();
  private dirty = false;
  private timer: ReturnType<typeof setInterval> | null = null;

  constructor() {
    this.p = load() ?? seed();
    this.store = new MemoryStore(this.p.data, () => this.changed());
    for (const [id, s] of Object.entries(this.p.devices)) this.devices.set(id, new ValveDevice(s, this.p.data.meterKeys[id]));
    this.svc = new GasguysService({
      store: this.store,
      payments: [new SandboxPayments(this)],
      gateway: new SandboxGateway(this),
      messenger: new SandboxMessenger(this),
    });
  }

  // ── Plumbing ────────────────────────────────────────────────────────────────────────────────

  subscribe(fn: () => void) {
    this.listeners.add(fn);
    return () => void this.listeners.delete(fn);
  }

  changed() {
    if (this.dirty) return;
    this.dirty = true;
    queueMicrotask(() => {
      this.dirty = false;
      this.p.devices = Object.fromEntries([...this.devices].map(([id, d]) => [id, d.s]));
      try {
        localStorage.setItem(KEY, JSON.stringify(this.p));
      } catch {
        /* private mode or full storage: the sandbox still works for this tab */
      }
      this.listeners.forEach((l) => l());
    });
  }

  reset() {
    localStorage.removeItem(KEY);
    location.reload();
  }

  start() {
    if (this.timer) return;
    this.timer = setInterval(() => void this.tick(), 1000);
    // Another tab (say, the card checkout or the app on its own) changed the sandbox: adopt its state.
    addEventListener("storage", (e) => {
      if (e.key !== KEY || !e.newValue) return;
      const next = JSON.parse(e.newValue) as Persisted;
      this.p = next;
      this.store.data = next.data;
      for (const [id, st] of Object.entries(next.devices)) {
        const d = this.devices.get(id);
        if (d) d.s = st;
        else this.devices.set(id, new ValveDevice(st, next.data.meterKeys[id]));
      }
      this.listeners.forEach((l) => l());
    });
  }

  /** One real second = `speed` simulated minutes of cooking. */
  private async tick() {
    if (this.p.settings.paused) return;
    const now = new Date().toISOString();
    for (const d of this.devices.values()) {
      const before = JSON.stringify(d.s);
      d.tick(this.p.settings.speed);
      if (d.s.online && JSON.stringify(d.s) !== before) await this.svc.ingestTelemetry(d.telemetry(now));
    }
    for (const pr of this.p.prompts) {
      const age = Date.now() - Date.parse(pr.createdAt);
      if (this.p.settings.autoApprove && pr.method !== "card" && age > 4000) await this.resolvePrompt(pr.providerRef, "paid");
      else if (age > 10 * 60_000) await this.resolvePrompt(pr.providerRef, "expired");
    }
    this.changed();
  }

  // ── Simulated customer actions ─────────────────────────────────────────────────────────────

  /** The customer enters their PIN (or declines) on the EcoCash prompt, pays the InnBucks code, or completes the card page. */
  async resolvePrompt(providerRef: string, status: "paid" | "failed" | "expired") {
    const pr = this.p.prompts.find((x) => x.providerRef === providerRef);
    if (!pr) return;
    this.p.prompts = this.p.prompts.filter((x) => x !== pr);
    this.changed();
    // This is the provider's webhook arriving at our backend.
    await this.svc.settlePayment(pr.reference, status);
  }

  /** A WhatsApp message from `phone` reaching the webhook. */
  async whatsappInbound(phone: string, msg: Inbound) {
    this.chat(phone).push({ dir: "in", at: new Date().toISOString(), msg });
    this.changed();
    await this.svc.send(phone, await handleInbound(this.svc, phone, msg));
  }

  chat(phone: string) {
    return (this.p.chats[phone] ??= []);
  }

  device(meterId: string) {
    return this.devices.get(meterId);
  }

  logs(meterId: string): DeviceLog[] {
    return this.devices.get(meterId)?.logs ?? [];
  }

  async deviceAction(meterId: string, fn: (d: ValveDevice) => void | Promise<unknown>) {
    const d = this.devices.get(meterId);
    if (!d) return;
    const wasOnline = d.s.online;
    await fn(d);
    if (d.s.online) await this.svc.ingestTelemetry(d.telemetry(new Date().toISOString()));
    else if (wasOnline) await this.svc.markOffline(meterId);
    this.changed();
  }

  async installMeter(meter: Meter) {
    await this.store.saveMeter(meter);
    this.p.data.meterKeys[meter.id] = randomKeyHex();
    this.devices.set(meter.id, new ValveDevice(newDevice(meter.id, meter.gasGrams, meter.creditGrams), this.p.data.meterKeys[meter.id]));
    this.changed();
  }
}

// ── Simulated providers ────────────────────────────────────────────────────────────────────────

class SandboxPayments implements PaymentProvider {
  readonly name = "sandbox";
  constructor(private sb: Sandbox) {}
  supports(_m: PayMethod, _c: Currency) {
    return true;
  }
  async initiate(req: PaymentRequest): Promise<InitiateResult> {
    const providerRef = "SBX" + Math.random().toString(36).slice(2, 10).toUpperCase();
    const code = req.method === "innbucks" ? String(Math.floor(100000 + Math.random() * 900000)) : undefined;
    this.sb.p.prompts.push({
      providerRef,
      reference: req.reference,
      method: req.method,
      currency: req.currency,
      amount: req.amount,
      phone: req.payerPhone,
      code,
      createdAt: new Date().toISOString(),
    });
    this.sb.changed();
    if (req.method === "ecocash") return { ok: true, providerRef, instruction: { kind: "ussd_push", phone: req.payerPhone } };
    if (req.method === "innbucks")
      return {
        ok: true,
        providerRef,
        instruction: { kind: "code", code: code!, expiresAt: new Date(Date.now() + 10 * 60_000).toISOString(), deepLink: `com.innbucks.customer://purchase?paymentToken=${code}` },
      };
    return { ok: true, providerRef, instruction: { kind: "redirect", url: `${location.origin}${location.pathname}#/checkout/${providerRef}` } };
  }
  async poll(providerRef: string): Promise<ProviderStatus> {
    return this.sb.p.prompts.some((p) => p.providerRef === providerRef) ? "pending" : "paid";
  }
}

class SandboxGateway implements MeterGateway {
  constructor(private sb: Sandbox) {}
  async send(meterId: string, cmd: MeterCommand): Promise<CommandResult> {
    const d = this.sb.device(meterId);
    if (!d) return { delivered: false, reason: "rejected" };
    if (!d.s.online) return { delivered: false, reason: "offline" };
    if (cmd.type === "credit") d.applyCredit(cmd.grams, cmd.counter);
    if (cmd.type === "clear_leak") d.setLeak(false);
    if (cmd.type === "set_valve" && !cmd.open) d.setTamper(true);
    this.sb.changed();
    return { delivered: true };
  }
}

class SandboxMessenger implements Messenger {
  constructor(private sb: Sandbox) {}
  async send(phone: string, messages: OutMessage[]) {
    const at = new Date().toISOString();
    for (const m of messages) this.sb.chat(phone).push({ dir: "out", at, msg: m });
    this.sb.changed();
  }
}

// ── Seed data ──────────────────────────────────────────────────────────────────────────────────

export const DEMO_PHONE = "263771234567";
export const GOGO_PHONE = "263712345678";
export const DEMO_METER = "37012345678";
export const GOGO_METER = "37098765432";
export const SPARE_METER = "37055501234";

function load(): Persisted | null {
  try {
    const raw = localStorage.getItem(KEY);
    const p = raw ? (JSON.parse(raw) as Persisted) : null;
    return p?.v === 1 ? p : null;
  } catch {
    return null;
  }
}

function seed(): Persisted {
  const data = emptyData();
  const now = new Date().toISOString();
  const cust = (id: string, phone: string, name: string, lang: "en" | "sn" | "nd") =>
    (data.customers[id] = { id, phone, name, lang, createdAt: now });
  cust("c-tendai", DEMO_PHONE, "Tendai Moyo", "en");
  cust("c-gogo", GOGO_PHONE, "Siphiwe Ncube", "nd");
  cust("c-rudo", "263782220011", "Rudo Chikwanha", "sn");
  cust("c-themba", "263719876543", "Themba Dube", "nd");
  cust("c-farai", "263773334455", "Farai Mutasa", "sn");

  const devices: Record<string, DeviceState> = {};
  const meter = (id: string, customerId: string | null, suburb: string, cylinderKg: number, gas: number, credit: number, avg: number, extra: Partial<DeviceState> = {}) => {
    const s = { ...newDevice(id, gas, credit), ...extra };
    s.valve = s.creditGrams > 0 && s.gasGrams > 0 && !s.leak && !s.tamper ? "open" : "closed";
    devices[id] = s;
    data.meterKeys[id] = randomKeyHex();
    data.meters[id] = {
      id,
      customerId,
      suburb,
      cylinderKg,
      gasGrams: gas,
      creditGrams: credit,
      valve: s.valve,
      online: s.online,
      batteryPct: s.batteryPct,
      leak: s.leak,
      tamper: s.tamper,
      tokenCounter: 0,
      avgDailyGrams: avg,
      lastSeen: now,
    };
  };
  meter(DEMO_METER, "c-tendai", "Mbare, Harare", 9, 3100, 1240, 190);
  meter(GOGO_METER, "c-gogo", "Lupane, Mat North", 9, 5200, 150, 160);
  meter(SPARE_METER, null, "Chitungwiza", 9, 9000, 0, 170);
  meter("37033307711", "c-rudo", "Glen View, Harare", 14, 1300, 2600, 220);
  meter("37044408822", "c-themba", "Nkulumane, Bulawayo", 9, 6100, 900, 180, { leak: true });
  meter("37066609933", "c-farai", "Sakubva, Mutare", 19, 11200, 3500, 260, { online: false });
  meter("37077701144", null, "Warehouse (not installed)", 9, 9000, 0, 170);
  for (const id of ["37044408822"]) data.alerts["a-" + id] = { id: "a-" + id, meterId: id, kind: "leak", at: now, resolved: false };
  for (const id of ["37066609933"]) {
    data.meters[id].online = false;
    data.alerts["o-" + id] = { id: "o-" + id, meterId: id, kind: "offline", at: now, resolved: false };
  }
  data.meters["37044408822"].leak = true;
  data.meters["37044408822"].valve = "closed";

  return { v: 1, data, devices, chats: {}, prompts: [], settings: { autoApprove: false, speed: 5, paused: false } };
}

export const sandbox = new Sandbox();
