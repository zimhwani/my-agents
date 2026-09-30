// POST { meterId, slot } → { refill }: books a cylinder swap for one of the signed-in customer's own
// meters. If one is already open, returns that one (core requestRefill).
import { body, signedInCustomer } from "../_shared/auth.ts";
import { cors, json, service } from "../_shared/gasguys.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors();
  const svc = await service();
  const who = await signedInCustomer(req, svc);
  if (who instanceof Response) return who;
  const b = await body(req);
  const meter = await svc.store.meter(String(b.meterId ?? ""));
  if (!meter || meter.customerId !== who.customer.id) return json({ error: "meter_not_found" }, 404);
  const slot = typeof b.slot === "string" && b.slot.trim() ? b.slot.trim().slice(0, 200) : "Next available";
  return json({ refill: await svc.requestRefill(meter.id, slot) });
});
