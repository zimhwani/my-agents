// Supabase Auth "Send SMS" hook: Auth calls this instead of an SMS provider whenever it needs to send a
// phone sign-in code, and we deliver the code on WhatsApp with an Authentication template. Zimbabwe SMS
// delivery through the built-in providers is patchy, and customers already use Gasguys on WhatsApp.
//
// Enable it in the Dashboard (Authentication → Hooks → Send SMS hook → HTTPS, URL
// https://<ref>.supabase.co/functions/v1/auth-send-sms), or [auth.hook.send_sms] in config.toml
// locally. The hook secret Supabase generates ("v1,whsec_…") goes in SEND_SMS_HOOK_SECRET.
//
// Request (per Supabase's Send SMS hook docs): a Standard Webhooks-signed POST with body
// { user: { id, phone, … }, sms: { otp } }. Reply 200 {} when sent; on failure reply with
// { error: { http_code, message } }, which Auth passes back to the app's signInWithOtp call.
import { Webhook } from "npm:standardwebhooks@1.0.0";
import { normalizePhone } from "../_shared/core/service.ts";
import { sendAuthCode } from "../_shared/whatsapp.ts";

type HookPayload = { user?: { phone?: string }; sms?: { otp?: string } };

const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
const fail = (http_code: number, message: string) => reply(http_code, { error: { http_code, message } });

Deno.serve(async (req) => {
  const secret = Deno.env.get("SEND_SMS_HOOK_SECRET");
  if (!secret) return fail(500, "SEND_SMS_HOOK_SECRET is not set");

  const raw = await req.text();
  let payload: HookPayload;
  try {
    // The Dashboard shows the secret as "v1,whsec_<base64>"; the library wants the base64 part.
    payload = new Webhook(secret.replace(/^v1,whsec_/, "")).verify(raw, Object.fromEntries(req.headers)) as HookPayload;
  } catch {
    return fail(401, "invalid signature");
  }

  const phone = normalizePhone(payload.user?.phone ?? "");
  const otp = payload.sms?.otp ?? "";
  // Gasguys only serves Zimbabwe mobile numbers; anything else never gets a code.
  if (!phone) return fail(400, "Only Zimbabwe mobile numbers can sign in");
  if (!/^\d{4,10}$/.test(otp)) return fail(400, "missing code");

  const sent = await sendAuthCode(phone, otp);
  if (!sent.ok) {
    console.error("auth-send-sms: WhatsApp send failed", sent.status, sent.error);
    return fail(sent.status === 503 ? 503 : 502, "Could not send the code on WhatsApp");
  }
  return reply(200, {});
});
