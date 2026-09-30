// POST { meterId, amount, currency, method, payerPhone?, giftMessage? } from the signed-in web app.
// Returns the payment and what the customer has to do next (PIN prompt, InnBucks code or card page).
import { body, signedInCustomer } from "../_shared/auth.ts";
import { cors, json, service } from "../_shared/gasguys.ts";
import { normalizePhone } from "../_shared/core/service.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors();
  const svc = await service();
  const who = await signedInCustomer(req, svc);
  if (who instanceof Response) return who;
  const { customer } = who;

  const b = await body(req);
  const payerPhone = b.payerPhone ? normalizePhone(String(b.payerPhone)) : customer.phone;
  if (!payerPhone) return json({ error: "invalid_phone" }, 400);
  const method = b.method === "innbucks" || b.method === "card" ? b.method : "ecocash";
  const res = await svc.startPurchase({
    meterId: String(b.meterId ?? ""),
    amount: Number(b.amount),
    currency: b.currency === "ZWG" ? "ZWG" : "USD",
    method,
    payerPhone,
    payerName: customer.name,
    payerCustomerId: customer.id,
    giftMessage: typeof b.giftMessage === "string" ? b.giftMessage.slice(0, 200) : null,
    channel: "web",
  });
  return res.ok ? json({ payment: { ...res.payment, token: null }, instruction: res.instruction }) : json({ error: res.error }, 400);
});
