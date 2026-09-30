// Store backed by Postgres through supabase-js with the service role. Maps snake_case rows to the
// core types. RLS still guards the browser; this client bypasses it, so only edge functions use it.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { Store } from "./core/providers.ts";
import type { Alert, Customer, Meter, Payment, RefillOrder } from "./core/types.ts";

export const admin: SupabaseClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

type Row = Record<string, unknown>;
const camel = (r: Row) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()), v]));
const snake = (o: object) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k.replace(/[A-Z]/g, (c) => "_" + c.toLowerCase()), v]));

function one<T>(res: { data: Row | null; error: unknown }): T | null {
  if (res.error) throw res.error;
  return res.data ? (camel(res.data) as T) : null;
}
function many<T>(res: { data: Row[] | null; error: unknown }): T[] {
  if (res.error) throw res.error;
  return (res.data ?? []).map((r) => camel(r) as T);
}
async function upsert(table: string, row: object) {
  const { error } = await admin.from(table).upsert(snake(row));
  if (error) throw error;
}

const OPEN_REFILL = ["requested", "scheduled", "out_for_delivery"];

export class SupabaseStore implements Store {
  customerById = async (id: string) => one<Customer>(await admin.from("customers").select("id,phone,name,lang,created_at").eq("id", id).maybeSingle());
  customerByPhone = async (phone: string) =>
    one<Customer>(await admin.from("customers").select("id,phone,name,lang,created_at").eq("phone", phone).maybeSingle());
  saveCustomer = (c: Customer) => upsert("customers", c);

  meter = async (id: string) => one<Meter>(await admin.from("meters").select("*").eq("id", id).maybeSingle());
  metersFor = async (customerId: string) => many<Meter>(await admin.from("meters").select("*").eq("customer_id", customerId));
  allMeters = async () => many<Meter>(await admin.from("meters").select("*"));
  saveMeter = (m: Meter) => upsert("meters", m);
  meterKey = async (id: string) => {
    const { data, error } = await admin.schema("private").from("meter_keys").select("key_hex").eq("meter_id", id).maybeSingle();
    if (error) throw error;
    return (data?.key_hex as string) ?? null;
  };

  payment = async (id: string) => one<Payment>(await admin.from("payments").select("*").eq("id", id).maybeSingle());
  paymentByRef = async (reference: string) => one<Payment>(await admin.from("payments").select("*").eq("reference", reference).maybeSingle());
  paymentsFor = async (o: { customerId?: string; meterId?: string; limit?: number }) => {
    let q = admin.from("payments").select("*").order("created_at", { ascending: false }).limit(o.limit ?? 100);
    if (o.customerId) q = q.eq("customer_id", o.customerId);
    if (o.meterId) q = q.eq("meter_id", o.meterId);
    return many<Payment>(await q);
  };
  savePayment = (p: Payment) => upsert("payments", p);

  refills = async (o: { meterId?: string; open?: boolean }) => {
    let q = admin.from("refill_orders").select("*").order("created_at", { ascending: false });
    if (o.meterId) q = q.eq("meter_id", o.meterId);
    if (o.open === true) q = q.in("status", OPEN_REFILL);
    if (o.open === false) q = q.not("status", "in", `(${OPEN_REFILL.join(",")})`);
    return many<RefillOrder>(await q);
  };
  saveRefill = (r: RefillOrder) => upsert("refill_orders", r);

  alerts = async (o: { meterId?: string; open?: boolean }) => {
    let q = admin.from("alerts").select("*").order("at", { ascending: false });
    if (o.meterId) q = q.eq("meter_id", o.meterId);
    if (o.open !== undefined) q = q.eq("resolved", !o.open);
    return many<Alert>(await q);
  };
  saveAlert = (a: Alert) => upsert("alerts", a);

  botSession = async (phone: string) => {
    const { data, error } = await admin.from("bot_sessions").select("state").eq("phone", phone).maybeSingle();
    if (error) throw error;
    return data?.state ?? null;
  };
  saveBotSession = async (phone: string, state: unknown) => {
    const { error } = await admin.from("bot_sessions").upsert({ phone, state, updated_at: new Date().toISOString() });
    if (error) throw error;
  };
}
