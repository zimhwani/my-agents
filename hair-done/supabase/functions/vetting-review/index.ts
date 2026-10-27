// The API behind the review page (site/review/index.html on hairdonenailsdone.app). Public, because the
// signed review link is the key: it names one review, lasts 72 hours and decides once (migration 0020).
//   POST { token, action: "view" }                                   the pro, the checks, photo links (10 min)
//   POST { token, action: "decide", decision, reason?, insurance? }  approved or sent_back, then emails the pro
// Supabase serves HTML from *.supabase.co as plain text, which is why the page itself lives on the site.
import { admin } from "../_shared/stripe.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const FROM = env("RECEIPT_FROM") || env("WATCHDOG_FROM");   // pros see this one, so the receipts address first
const RESEND_KEY = env("RESEND_API_KEY");
const ORIGIN = "https://hairdonenailsdone.app";
const SUPPORT = "hello@hairdonenailsdone.app";   // HAIR_DONE.email in _shared/receipt.ts
const cors = { "Access-Control-Allow-Origin": ORIGIN, "Access-Control-Allow-Methods": "POST, OPTIONS",
               "Access-Control-Allow-Headers": "content-type", "Cache-Control": "no-store", Vary: "Origin" };
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...cors } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply({ error: "post_only" }, 405);
  const body = await req.json().catch(() => ({}));
  const token = typeof body.token === "string" ? body.token : "";

  const { data: r } = await admin.rpc("vetting_open", { p_token: token });
  if (!r) return reply({ error: "link_expired" }, 404);

  if (body.action === "decide") {
    if (r.decided_at) return reply({ error: "already_decided", decision: r.decision }, 409);
    const decision = body.decision === "approved" ? "approved" : body.decision === "sent_back" ? "sent_back" : null;
    if (!decision) return reply({ error: "bad_decision" }, 400);
    const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 500) : "";
    if (decision === "sent_back" && !reason) return reply({ error: "reason_needed" }, 400);
    const { data: d, error } = await admin.rpc("vetting_decide", { p_token: token, p_decision: decision, p_reason: reason,
      p_insurance: body.insurance === true });
    if (error) return reply({ error: error.message }, 500);
    if (d?.error) return reply(d, 409);
    const email = await tellPro(r.pro, decision, reason);
    return reply({ ok: true, decision, email });
  }

  // View: the photos come as signed links that stop working after 10 minutes, and only while it's undecided.
  const p = r.pro ?? {};
  const open = !r.decided_at && !r.stale;
  const sign = async (bucket: string, path: string) =>
    (await admin.storage.from(bucket).createSignedUrl(path, 600)).data?.signedUrl ?? null;
  const doc = (file: string) => (p.id_docs ?? []).find((d: any) => String(d.name).endsWith(`/${file}`));
  const [idUrl, selfieUrl, work] = open ? await Promise.all([
    doc("photo-id.jpg") ? sign("id-docs", doc("photo-id.jpg").name) : null,
    doc("selfie.jpg") ? sign("id-docs", doc("selfie.jpg").name) : null,
    Promise.all((p.work ?? []).slice(0, 24).map((w: any) => sign("work", w.path))),
  ]) : [null, null, []];
  return reply({
    verdict: r.verdict, checks: r.checks, decided: r.decided_at ? r.decision : null, stale: r.stale,
    pro: { name: [p.first_name, p.last_name].filter(Boolean).join(" "), specialties: p.specialties, suburb: p.suburb,
           abn: p.abn, joined: p.joined, submitted: r.submitted_at, services: p.services,
           travel_radius_km: p.travel_radius_km, travel_fee_cents: p.travel_fee_cents },
    photos: { id: idUrl, selfie: selfieUrl, work: work.filter(Boolean) },
  });
});

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** One short email to the pro saying what happened. Never throws: the decision is already made. */
async function tellPro(p: Record<string, any>, decision: string, reason: string): Promise<string> {
  if (!FROM || !RESEND_KEY) return "not_configured";
  if (!p?.email) return "no_email";
  const hi = p.first_name ? `Hi ${p.first_name},` : "Hi,";
  const [subject, lines] = decision === "approved"
    ? ["You're ID checked", [hi, "", "Your ID check is done. Once your payouts are set up, clients can find you and book you.",
        "", "Your ID photo and selfie are deleted within 7 days, as our privacy policy says.", "", "Hair Done"]]
    : ["Your ID check needs another go", [hi, "", `We couldn't finish your ID check: ${reason.replace(/\.$/, "")}.`,
        "", "Open Hair Done, go to Today, and send your photo ID and a selfie again. Reply to this email if anything's unclear.", "", "Hair Done"]];
  const text = lines.join("\n");
  const html = `<div style="font:16px/1.55 -apple-system,Helvetica,sans-serif;color:#241A16;max-width:560px">${lines.map((l) => (l ? `<p style="margin:0 0 4px">${esc(l)}</p>` : "<br>")).join("")}</div>`;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json", "Idempotency-Key": `idcheck-${p.id}-${decision}-${String(p.submitted)}` },
      body: JSON.stringify({ from: `Hair Done <${FROM}>`, to: [p.email], reply_to: SUPPORT, subject, text, html }),
    });
    return res.ok ? "sent" : `resend ${res.status}`;
  } catch (e) {
    return `resend: ${(e as Error).message}`;
  }
}
