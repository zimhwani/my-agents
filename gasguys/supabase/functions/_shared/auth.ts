// Who is calling a web-app edge function. The browser sends the customer's Supabase session JWT
// (functions.invoke does it); we check it with the Auth admin API and map the verified phone number to
// a customer row, creating it on first sign-in and linking it to the login (customers.auth_user), which
// is what row-level security keys on (me() in 0002_rls.sql).

import type { User } from "npm:@supabase/supabase-js@2";
import { normalizePhone, type GasguysService } from "./core/service.ts";
import type { Customer, Lang } from "./core/types.ts";
import { json } from "./gasguys.ts";
import { admin } from "./store.ts";

export async function requireUser(req: Request): Promise<User | Response> {
  const jwt = req.headers.get("authorization")?.replace("Bearer ", "") ?? "";
  const { data } = await admin.auth.getUser(jwt);
  return data.user ?? json({ error: "unauthorized" }, 401);
}

export type Profile = Partial<Pick<Customer, "lang" | "name">>;

/** Only the fields a customer may set about themselves, validated. */
export function cleanProfile(v: unknown): Profile {
  const o = (v && typeof v === "object" ? v : {}) as Record<string, unknown>;
  const out: Profile = {};
  if (o.lang === "en" || o.lang === "sn" || o.lang === "nd") out.lang = o.lang as Lang;
  if (typeof o.name === "string") out.name = o.name.trim().slice(0, 60);
  return out;
}

/**
 * The signed-in user's customer. The phone on the Auth user was verified by the OTP, so it is safe to
 * adopt a customer row the WhatsApp bot created for the same number. `profile` only applies when the
 * row is new.
 */
export async function signedInCustomer(req: Request, svc: GasguysService, profile: Profile = {}): Promise<{ user: User; customer: Customer } | Response> {
  const user = await requireUser(req);
  if (user instanceof Response) return user;
  const phone = normalizePhone(user.phone ?? "");
  if (!phone) return json({ error: "phone_required" }, 400);
  const customer = await svc.ensureCustomer(phone, profile.lang ?? "en", profile.name ?? "");
  await admin.from("customers").update({ auth_user: user.id }).eq("id", customer.id).is("auth_user", null);
  const { data } = await admin.from("customers").select("auth_user").eq("id", customer.id).single();
  // Another login already owns this phone's customer row (e.g. the Auth user was recreated).
  if (data?.auth_user !== user.id) return json({ error: "account_linked_elsewhere" }, 409);
  return { user, customer };
}

/** Request body as an object; a missing or malformed body is treated as {}. */
export async function body(req: Request): Promise<Record<string, unknown>> {
  try {
    const b = await req.json();
    return b && typeof b === "object" ? (b as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}
