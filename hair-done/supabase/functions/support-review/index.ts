// The API behind the reply page (site/reply/index.html). Public: the signed link from the support email
// is the key (migration 0022). It lasts 7 days, and sends or closes once.
//   POST { token, action: "view" }                 the message, who sent it, their bookings, the draft
//   POST { token, action: "send", text }           emails the reply from hello@, in the same thread
//   POST { token, action: "close" }                done, no reply (spam, or handled another way)
import { admin } from "../_shared/stripe.ts";
import { facts } from "../support/assess.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const RESEND_KEY = env("RESEND_API_KEY");
const HELLO = "hello@hairdonenailsdone.app";
const ORIGIN = "https://hairdonenailsdone.app";
const cors = { "Access-Control-Allow-Origin": ORIGIN, "Access-Control-Allow-Methods": "POST, OPTIONS",
               "Access-Control-Allow-Headers": "content-type", "Cache-Control": "no-store", Vary: "Origin" };
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...cors } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply({ error: "post_only" }, 405);
  const body = await req.json().catch(() => ({}));
  const token = typeof body.token === "string" ? body.token : "";
  const { data: ctx } = await admin.rpc("support_open", { p_token: token });
  if (!ctx) return reply({ error: "link_expired" }, 404);
  const item = ctx.item;
  const to = item.from_email || ctx.person?.email || null;

  if (body.action === "close") {
    const { data: d } = await admin.rpc("support_done", { p_token: token, p_status: "closed", p_reply: null, p_error: null });
    return d?.ok ? reply({ ok: true, status: "closed" }) : reply(d ?? { error: "failed" }, 409);
  }

  if (body.action === "send") {
    if (["sent", "closed"].includes(item.status)) return reply({ error: "already_done", status: item.status }, 409);
    const text = typeof body.text === "string" ? body.text.trim().slice(0, 8000) : "";
    if (!text) return reply({ error: "empty" }, 400);
    if (!to) return reply({ error: "no_email" }, 400);
    if (!RESEND_KEY) return reply({ error: "email_not_configured" }, 503);
    const subject = item.source === "report"
      ? `About your report${item.booking_ref ? ` on ${item.booking_ref}` : ""}`
      : /^re:/i.test(item.subject ?? "") ? item.subject : `Re: ${item.subject || "your message"}`;
    const threading = item.message_id ? { "In-Reply-To": item.message_id, References: item.message_id } : {};
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json", "Idempotency-Key": `support-reply-${item.id}` },
      body: JSON.stringify({ from: `Hair Done <${HELLO}>`, to: [to], reply_to: HELLO, subject, text, headers: threading }),
    }).catch((e) => ({ ok: false, status: 0, text: async () => (e as Error).message }) as unknown as Response);
    if (!res.ok) {
      const why = `resend ${res.status}: ${(await res.text()).slice(0, 200)}`;
      await admin.rpc("support_done", { p_token: token, p_status: "sent", p_reply: null, p_error: why });
      return reply({ error: "send_failed", detail: why }, 502);
    }
    const { data: d } = await admin.rpc("support_done", { p_token: token, p_status: "sent", p_reply: text, p_error: null });
    return reply({ ok: true, status: "sent", to, recorded: !!d?.ok });
  }

  return reply({
    status: item.status, source: item.source, received: item.received_at, category: item.category, urgency: item.urgency,
    summary: item.summary, subject: item.subject, body: item.body, draft: item.draft, booking_ref: item.booking_ref,
    from: { name: ctx.person?.first_name || item.from_name || null, email: to },
    report: ctx.report ? { reason: ctx.report.reason } : null,
    facts: facts(ctx), reply: item.reply, replied_at: item.replied_at, reply_error: item.reply_error,
  });
});
