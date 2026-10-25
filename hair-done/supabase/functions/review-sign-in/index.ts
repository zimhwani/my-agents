// POST { email, code } → { code } — sign-in for Apple's app reviewer, who can't receive our email codes.
// Off unless the secrets REVIEW_EMAIL and REVIEW_CODE (six digits) are set. For that one address and
// that code, it asks Supabase for a real one-time code for the account (made if it isn't there yet),
// and the app signs in with that as usual. Anything else gets "no". Misses are counted (review_try):
// past 10 in an hour it says no to everything. Clear the secrets once the app is approved.
import { admin, json } from "../_shared/stripe.ts";

const EMAIL = (Deno.env.get("REVIEW_EMAIL") ?? "").trim().toLowerCase();
const CODE = (Deno.env.get("REVIEW_CODE") ?? "").trim();

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!EMAIL || !/^\d{6}$/.test(CODE)) return json({ error: "no" }, 404);
  const { email, code } = await req.json().catch(() => ({}));
  if (String(email ?? "").trim().toLowerCase() !== EMAIL) return json({ error: "no" }, 404);

  const ok = String(code ?? "").trim() === CODE;
  const { data: room } = await admin.rpc("review_try", { p_ok: ok });
  if (!room || !ok) return json({ error: "no" }, 404);

  let link = await admin.auth.admin.generateLink({ type: "magiclink", email: EMAIL });
  if (link.error) {
    // First time: make the account (confirmed, no password), then ask again.
    const made = await admin.auth.admin.createUser({ email: EMAIL, email_confirm: true, user_metadata: { review: true } });
    if (made.error) return json({ error: "no" }, 404);
    link = await admin.auth.admin.generateLink({ type: "magiclink", email: EMAIL });
  }
  const otp = link.data?.properties?.email_otp;
  return otp ? json({ code: otp }) : json({ error: "no" }, 404);
});
