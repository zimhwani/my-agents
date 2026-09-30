// POST { meterId } → { meter }: links an unassigned meter to the signed-in customer. Errors:
// meter_not_found, meter_taken (someone else's).
//
// TODO before launch: as written, any signed-in customer can claim any unassigned meter number. Either
// have the technician link the meter at install (ops console) and drop this function, or require a
// second factor here, e.g. a code shown on the valve's display or printed inside its cover.
import { body, signedInCustomer } from "../_shared/auth.ts";
import { cors, json, service } from "../_shared/gasguys.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors();
  const svc = await service();
  const who = await signedInCustomer(req, svc);
  if (who instanceof Response) return who;
  const b = await body(req);
  const res = await svc.linkMeter(who.customer.id, String(b.meterId ?? ""));
  return res.ok ? json({ meter: res.meter }) : json({ error: res.error }, res.error === "meter_not_found" ? 404 : 409);
});
