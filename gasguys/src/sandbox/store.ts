// In-browser Store for the sandbox. Everything lives in one object persisted to localStorage, so a
// tester's meters, payments and chats survive a reload. "Reset sandbox" wipes it.

import type { Store } from "../../core/providers.ts";
import type { Alert, Customer, Meter, Payment, RefillOrder } from "../../core/types.ts";

export type SandboxData = {
  customers: Record<string, Customer>;
  meters: Record<string, Meter>;
  meterKeys: Record<string, string>;
  payments: Record<string, Payment>;
  refills: Record<string, RefillOrder>;
  alerts: Record<string, Alert>;
  botSessions: Record<string, unknown>;
};

export const emptyData = (): SandboxData => ({
  customers: {},
  meters: {},
  meterKeys: {},
  payments: {},
  refills: {},
  alerts: {},
  botSessions: {},
});

const byNewest = <T extends { createdAt?: string; at?: string }>(a: T, b: T) =>
  (b.createdAt ?? b.at ?? "").localeCompare(a.createdAt ?? a.at ?? "");

export class MemoryStore implements Store {
  constructor(
    public data: SandboxData,
    private onChange: () => void,
  ) {}

  private put<K extends keyof SandboxData>(table: K, id: string, row: SandboxData[K][string]) {
    (this.data[table] as Record<string, unknown>)[id] = structuredClone(row);
    this.onChange();
  }

  async customerById(id: string) {
    return this.data.customers[id] ?? null;
  }
  async customerByPhone(phone: string) {
    return Object.values(this.data.customers).find((c) => c.phone === phone) ?? null;
  }
  async saveCustomer(c: Customer) {
    this.put("customers", c.id, c);
  }

  async meter(id: string) {
    return this.data.meters[id] ?? null;
  }
  async metersFor(customerId: string) {
    return Object.values(this.data.meters).filter((m) => m.customerId === customerId);
  }
  async allMeters() {
    return Object.values(this.data.meters);
  }
  async saveMeter(m: Meter) {
    this.put("meters", m.id, m);
  }
  async meterKey(id: string) {
    return this.data.meterKeys[id] ?? null;
  }

  async payment(id: string) {
    return this.data.payments[id] ?? null;
  }
  async paymentByRef(reference: string) {
    return Object.values(this.data.payments).find((p) => p.reference === reference) ?? null;
  }
  async paymentsFor(o: { customerId?: string; meterId?: string; limit?: number }) {
    return Object.values(this.data.payments)
      .filter((p) => (!o.customerId || p.customerId === o.customerId) && (!o.meterId || p.meterId === o.meterId))
      .sort(byNewest)
      .slice(0, o.limit ?? 100);
  }
  async savePayment(p: Payment) {
    this.put("payments", p.id, p);
  }

  async refills(o: { meterId?: string; open?: boolean }) {
    const open = (r: RefillOrder) => r.status !== "delivered" && r.status !== "cancelled";
    return Object.values(this.data.refills)
      .filter((r) => (!o.meterId || r.meterId === o.meterId) && (o.open === undefined || open(r) === o.open))
      .sort(byNewest);
  }
  async saveRefill(r: RefillOrder) {
    this.put("refills", r.id, r);
  }

  async alerts(o: { meterId?: string; open?: boolean }) {
    return Object.values(this.data.alerts)
      .filter((a) => (!o.meterId || a.meterId === o.meterId) && (o.open === undefined || !a.resolved === o.open))
      .sort(byNewest);
  }
  async saveAlert(a: Alert) {
    this.put("alerts", a.id, a);
  }

  async botSession(phone: string) {
    return this.data.botSessions[phone] ?? null;
  }
  async saveBotSession(phone: string, s: unknown) {
    this.put("botSessions", phone, s);
  }
}
