// POST { profile?: { lang, name }, update?: { lang?, name? } } from the web app right after sign-in, and
// when the customer changes language. Creates the customer on first sign-in (with `profile`) or links
// the row the WhatsApp bot already made for this phone to the login, then applies `update`.
// Returns { customer }.
import { body, cleanProfile, signedInCustomer } from "../_shared/auth.ts";
import { cors, json, service } from "../_shared/gasguys.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors();
  const b = await body(req);
  const svc = await service();
  const who = await signedInCustomer(req, svc, cleanProfile(b.profile));
  if (who instanceof Response) return who;
  const update = cleanProfile(b.update);
  const customer = Object.keys(update).length ? await svc.updateCustomer(who.customer, update) : who.customer;
  return json({ customer });
});
