// Mail to hello@hairdonenailsdone.app, posted here by the hairdone-mail Cloudflare Worker (mail-worker/)
// after it has forwarded the original to Keith. Stores it in the support queue (migration 0022) and asks
// the support function to look at it straight away. The Worker signs with the mail secret.
//   POST { from_email, from_name, subject, body, message_id }   header x-mail-secret
import { admin, json } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "post_only" }, 405);
  const { data: ok } = await admin.rpc("check_mail_secret", { s: req.headers.get("x-mail-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const p = await req.json().catch(() => null);
  if (!p?.from_email) return json({ error: "no_sender" }, 400);

  const { data: id, error } = await admin.rpc("support_receive", { p });
  if (error) return json({ error: error.message }, 500);
  await admin.rpc("support_kick");
  return json({ ok: true, id });
});
