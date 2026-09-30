// POST { meterId, amount, currency, method, payerPhone?, giftMessage? } from the signed-in web app.
// Returns the payment and what the customer has to do next (PIN prompt, InnBucks code or card page).
import { cors, json, service } from "../_shared/gasguys.ts";
import { admin } from "../_shared/store.ts";
import { normalizePhone } from "../_shared/core/service.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors();
  const jwt = req.headers.get("authorization")?.replace("Bearer ", "") ?? "";
  const { data: auth } = await admin.auth.getUser(jwt);
  if (!auth.user) return json({ error: "unauthorized" }, 401);

  const svc = await service();
  const phone = normalizePhone(auth.user.phone ?? "");
  if (!phone) return json({ error: "phone_required" }, 400);
  const customer = await svc.ensureCustomer(phone);
  await admin.from("customers").update({ auth_user: auth.user.id }).eq("id", customer.id).is("auth_user", null);

  const body = await req.json();
  const payerPhone = body.payerPhone ? normalizePhone(body.payerPhone) : phone;
  if (!payerPhone) return json({ error: "invalid_phone" }, 400);
  const res = await svc.startPurchase({
    meterId: String(body.meterId ?? ""),
    amount: Number(body.amount),
    currency: body.currency === "ZWG" ? "ZWG" : "USD",
    method: ["ecocash", "innbucks", "card"].includes(body.method) ? body.method : "ecocash",
    payerPhone,
    payerName: customer.name,
    payerCustomerId: customer.id,
    giftMessage: body.giftMessage ?? null,
    channel: "web",
  });
  return res.ok ? json({ payment: { ...res.payment, token: null }, instruction: res.instruction }) : json({ error: res.error }, 400);
});
