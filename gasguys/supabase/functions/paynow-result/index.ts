// Paynow's resulturl. Paynow posts status changes here, signed with the integration key. We verify
// the hash, then re-poll Paynow ourselves before crediting anything (never trust the body alone).
import { service } from "../_shared/gasguys.ts";
import { mapStatus, pollPaynow, verifyPaynow } from "../_shared/paynow.ts";

Deno.serve(async (req) => {
  const currency = new URL(req.url).searchParams.get("currency") === "ZWG" ? "ZWG" : "USD";
  const fields = await verifyPaynow(await req.text(), currency);
  if (!fields) return new Response("bad hash", { status: 400 });

  const svc = await service();
  const payment = await svc.store.paymentByRef(fields.reference);
  if (!payment || payment.status !== "pending") return new Response("ok");

  const status = payment.pollUrl ? await pollPaynow(payment.pollUrl) : mapStatus(fields.status ?? "");
  if (status !== "pending") await svc.settlePayment(payment.reference, status);
  return new Response("ok");
});
