// POST { meterId } → { recipient: { meterId, name, suburb } }, where name is masked ("T. Moyo"), so a
// relative can check they are paying the right meter. 404 meter_not_found for unknown or unassigned
// meters. Signed-in callers only, so owner names can't be enumerated anonymously; add rate limiting
// (per user) if abuse shows up.
import { requireUser, body } from "../_shared/auth.ts";
import { cors, json, service } from "../_shared/gasguys.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors();
  const user = await requireUser(req);
  if (user instanceof Response) return user;
  const b = await body(req);
  const svc = await service();
  const recipient = await svc.giftLookup(String(b.meterId ?? ""));
  return recipient ? json({ recipient }) : json({ error: "meter_not_found" }, 404);
});
