// POST { booking_id, send? } → the client's receipt for a paid booking (_shared/receipt.ts).
//   send false: the details the app can't see itself (her pro's ABN, the card it was paid on, when)
//   send true:  also emails it to her, and says where it went
import { admin, userClient, json } from "../_shared/stripe.ts";
import { buildReceipt, sendReceipt, emailReady } from "../_shared/receipt.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const { data: { user } } = await userClient(req).auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { booking_id, send } = await req.json().catch(() => ({}));
  const { data: b } = await admin.from("bookings").select("client_id").eq("id", booking_id ?? "").maybeSingle();
  if (!b || b.client_id !== user.id) return json({ error: "not_found" }, 404);
  const r = await buildReceipt(booking_id);
  if (!r) return json({ error: "not_paid" }, 409);

  const details = { pro_abn: r.pro_abn, card: r.card, paid_at: r.paid_at, can_email: emailReady() };
  if (!send) return json(details);
  try {
    return json({ ...details, sent_to: await sendReceipt(r) });
  } catch (e) {
    const why = (e as Error).message;
    if (why === "not_configured" || why === "no_email") return json({ error: why }, 503);
    console.error("receipt send", booking_id, why);
    return json({ error: "send_failed" }, 502);
  }
});
