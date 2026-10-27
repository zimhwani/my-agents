// Pro vetting. Called by pg_cron every 15 minutes with the cron secret (migration 0020):
//   {}                   checks every pro who sent their ID and has no review yet, and emails Keith each one
//   { pro_id }           (re)checks that pro and emails a fresh review link (an old link has run out)
//   add  dry: true       returns the checks without saving or emailing (works on any pro, for trying it out)
//
// It decides nothing: the review page (site/review/, through the vetting-review function) is where Keith
// approves or sends it back. It never reads the ID photo or selfie: only their file names and sizes.
//
// Secrets: ABR_GUID (abr.business.gov.au > Web services > register; tools/setup-vetting.sh saves it).
// Without it the ABN is only checked for typos. Email uses the watchdog's: WATCHDOG_TO, RESEND_API_KEY,
// WATCHDOG_FROM or RECEIPT_FROM.
import { admin, json } from "../_shared/stripe.ts";
import { assess, VERDICT_WORDS, abnValid, type Abr, type Check, type Verdict } from "./assess.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const GUID = env("ABR_GUID");
const TO = env("WATCHDOG_TO");
const FROM = env("WATCHDOG_FROM") || env("RECEIPT_FROM");
const RESEND_KEY = env("RESEND_API_KEY");
const REVIEW_PAGE = "https://hairdonenailsdone.app/review/";

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const body = await req.json().catch(() => ({}));
  const dry = body.dry === true;
  const only = typeof body.pro_id === "string" ? body.pro_id : null;

  const { data: queue, error } = await admin.rpc("vetting_queue", { only_pro: only });
  if (error) return json({ error: error.message }, 500);

  const results = [];
  for (const p of (queue ?? []) as Record<string, any>[]) {
    const abr = p.abn && abnValid(p.abn) ? await lookUp(String(p.abn).replace(/\s/g, "")) : null;
    const { verdict, checks } = assess(p, abr);
    const who = `${p.first_name ?? "A pro"} ${p.last_initial ?? ""}`.trim();
    if (dry) { results.push({ pro: who, verdict, checks }); continue; }
    if (!p.submitted || p.is_verified) { results.push({ pro: who, skipped: p.is_verified ? "already ID checked" : "no ID sent" }); continue; }

    const { data: review, error: e } = await admin.rpc("vetting_save", { p_pro: p.id, p_submitted: p.submitted, p_verdict: verdict, p_checks: checks });
    if (e) { results.push({ pro: who, error: e.message }); continue; }
    const { data: token } = await admin.rpc("vetting_token", { p_review: review, p_hours: 72 });
    const email = await tellKeith(p, who, verdict, checks, token as string);
    await admin.rpc("vetting_emailed", { p_review: review, p_email: email });
    results.push({ pro: who, verdict, email });
  }
  return json({ dry, checked: results.length, results });
});

/** ABN Lookup's JSON service. It answers JSONP, so the callback wrapper is cut off. GET only. */
async function lookUp(abn: string): Promise<Abr> {
  if (!GUID) return null;
  try {
    const res = await fetch(`https://abr.business.gov.au/json/AbnDetails.aspx?abn=${abn}&callback=c&guid=${encodeURIComponent(GUID)}`,
      { method: "GET", signal: AbortSignal.timeout(15_000) });
    if (!res.ok) return { error: `ABN Lookup answered ${res.status}` };
    const text = (await res.text()).trim();
    return JSON.parse(text.replace(/^c\(/, "").replace(/\);?$/, ""));
  } catch (e) {
    return { error: (e as Error).message };
  }
}

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const MARK: Record<string, string> = { ok: "OK", warn: "Look", bad: "Problem", skip: "n/a" };
const COLOR: Record<string, string> = { ok: "#2E6B3F", warn: "#8A5A00", bad: "#B3261E", skip: "#6B655C" };

async function tellKeith(p: Record<string, any>, who: string, verdict: Verdict, checks: Check[], token: string): Promise<string> {
  if (!TO || !FROM || !RESEND_KEY) return "not_configured";
  const link = `${REVIEW_PAGE}#t=${token}`;
  const subject = `Hair Done: ${who} is waiting for their ID check (${VERDICT_WORDS[verdict]})`;
  const what = [(p.specialties ?? []).join(", "), p.suburb].filter(Boolean).join(", ");
  const sqlApprove = `update pros set is_verified = true, id_checked_at = now(), insurance_on_file = true where id = '${p.id}';`;
  const sqlBack = `update pros set id_submitted_at = null where id = '${p.id}';`;
  const text = [
    `${who} sent their photo ID and a selfie${what ? ` (${what})` : ""}.`, "",
    ...checks.map((c) => `- ${MARK[c.status]}: ${c.label}. ${c.note}`), "",
    "Nothing here looked at the ID photo or selfie: compare those yourself on the review page.",
    `Review and decide (link works once, for 72 hours): ${link}`, "",
    "If the page won't open, the same decision in the Supabase SQL editor:",
    `  Approve:    ${sqlApprove}`, `  Send back:  ${sqlBack}`,
  ].join("\n");
  const html = `<!doctype html><html><body style="margin:0;background:#F8F3EC"><div style="max-width:600px;margin:0 auto;padding:28px 20px;font:15px/1.5 -apple-system,Helvetica,sans-serif;color:#241A16">
  <div style="font:italic 24px Georgia,serif">${esc(who)} is waiting for their ID check</div>
  <p style="color:#6F625B;margin:6px 0 18px">${esc(what || "New pro")} · ${esc(VERDICT_WORDS[verdict])}</p>
  <table style="width:100%;border-collapse:collapse">${checks.map((c) => `<tr><td style="padding:8px 10px 8px 0;border-top:1px solid #E7E1D8;vertical-align:top;white-space:nowrap;font-weight:600;color:${COLOR[c.status]}">${MARK[c.status]}</td><td style="padding:8px 0;border-top:1px solid #E7E1D8"><b>${esc(c.label)}</b><br>${esc(c.note)}</td></tr>`).join("")}</table>
  <p style="margin:18px 0">Nothing here looked at the ID photo or selfie: compare those yourself on the review page.</p>
  <p><a href="${esc(link)}" style="display:inline-block;background:#241A16;color:#F8F3EC;text-decoration:none;padding:12px 18px;border-radius:6px;font-weight:600">Review and decide</a></p>
  <p style="color:#6F625B;font-size:13px">The link works once, for 72 hours. If the page won't open, the same decision in the Supabase SQL editor:<br>
  <code style="font:12px Menlo,monospace">${esc(sqlApprove)}</code><br><code style="font:12px Menlo,monospace">${esc(sqlBack)}</code></p>
  </div></body></html>`;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json", "Idempotency-Key": `vetting-${token.slice(0, 36)}-${token.split(".")[1]}` },
      body: JSON.stringify({ from: `Hair Done vetting <${FROM}>`, to: TO.split(",").map((s) => s.trim()), subject, html, text }),
    });
    return res.ok ? "sent" : `resend ${res.status}: ${(await res.text()).slice(0, 160)}`;
  } catch (e) {
    return `resend: ${(e as Error).message}`;
  }
}
