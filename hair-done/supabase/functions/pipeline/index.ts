// Pro pipeline. Called by pg_cron every Monday morning with the cron secret (migration 0027):
//   {}               notices sign-ups and ID checks, lets go of anyone gone quiet, finds new leads on ABN Lookup
//                    (keeping about 25 waiting to be messaged), and emails Keith what's due with a link to the page
//   add  dry: true   says what it would do, and returns the leads it would add, without saving or emailing
//   { test: true }   emails Keith an example, marked [Test], with a link to the real page
//
// It never contacts a prospect. The page (site/pipeline/, through the pipeline-board function) drafts each
// message; Keith sends it from his own account and marks it sent.
//
// Secrets: ABR_GUID (already set for vetting). Without it, no new leads: only the ones Keith adds. Email uses
// the watchdog's: WATCHDOG_TO, RESEND_API_KEY, WATCHDOG_FROM or RECEIPT_FROM.
import { admin, json } from "../_shared/stripe.ts";
import { AREA_WORDS, areaFor, matchPro, nextAction, pickLeads, SEARCHES, tally, type AbnMatch, type Pro, type Prospect } from "./assess.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const GUID = env("ABR_GUID");
const TO = env("WATCHDOG_TO");
const FROM = env("WATCHDOG_FROM") || env("RECEIPT_FROM");
const RESEND_KEY = env("RESEND_API_KEY");
const PAGE = "https://hairdonenailsdone.app/pipeline/";
const WAITING = 25;   // leads waiting to be messaged: about a week of DMs (the spec's 200 DMs for 50 pros)
const GOAL = 50;      // ID-checked pros before any client marketing (docs/product-spec.md)

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const body = await req.json().catch(() => ({}));
  const dry = body.dry === true, test = body.test === true;
  const now = new Date();

  const snap = await snapshot();
  if ("error" in snap) return json(snap, 500);
  const changes: string[] = [];

  // Who has joined, been ID checked or gone quiet since last week.
  for (const p of snap.prospects) {
    const m = matchPro(p, snap.pros);
    const status = m?.status ?? (nextAction(p, now) === "quiet" ? "quiet" : null);
    if (!status) continue;
    changes.push(`${p.name}: ${status}`);
    if (!dry && !test) await admin.rpc("pipeline_change", { p_id: p.id, p_status: status, p_fields: {}, p_pro: m?.pro_id ?? null });
  }

  // New leads, enough to keep about a week's worth waiting.
  const waiting = snap.prospects.filter((p) => p.status === "new").length;
  const room = test ? 0 : Math.max(0, WAITING - waiting);
  let found: ReturnType<typeof pickLeads> = [], searched = 0, lookupErrors: string[] = [];
  if (room > 0 && GUID) {
    const known = new Set([...snap.prospects.map((p) => p.abn ?? ""), ...snap.pros.map((p) => (p.abn ?? "").replace(/\D/g, ""))].filter(Boolean));
    const all: AbnMatch[] = [];
    for (const q of SEARCHES) {
      const r = await searchNames(q);
      if ("error" in r) lookupErrors.push(`${q}: ${r.error}`); else { all.push(...r.names); searched++; }
    }
    found = pickLeads(all, known, room);
    if (!dry && found.length) await admin.rpc("pipeline_add_leads", { p_leads: found });
  }

  const after = dry || test ? snap : await snapshot();
  if ("error" in after) return json(after, 500);
  const t = tally(after.prospects, now);
  const idChecked = after.pros.filter((p) => p.is_verified).length;
  const summary = { ...t, added: found.length, searched, lookup_errors: lookupErrors, changes, id_checked_pros: idChecked, abr: !!GUID };
  if (dry) return json({ dry, ...summary, leads: found });

  const { data: token } = await admin.rpc("pipeline_token", { p_days: 8 });
  const email = await tellKeith(after.prospects, summary, token as string, test, now);
  if (!test) await admin.rpc("pipeline_record", { p_summary: summary, p_email: email });
  return json({ test, ...summary, email });
});

async function snapshot(): Promise<{ prospects: Prospect[]; pros: Pro[] } | { error: string }> {
  const { data, error } = await admin.rpc("pipeline_snapshot");
  if (error) return { error: error.message };
  return { prospects: data?.prospects ?? [], pros: data?.pros ?? [] };
}

/** ABN Lookup's JSON name search. It answers JSONP, so the callback wrapper is cut off. GET only. */
async function searchNames(name: string): Promise<{ names: AbnMatch[] } | { error: string }> {
  try {
    const res = await fetch(`https://abr.business.gov.au/json/MatchingNames.aspx?name=${encodeURIComponent(name)}&maxResults=200&callback=c&guid=${encodeURIComponent(GUID)}`,
      { method: "GET", signal: AbortSignal.timeout(20_000) });
    if (!res.ok) return { error: `ABN Lookup answered ${res.status}` };
    const data = JSON.parse((await res.text()).trim().replace(/^c\(/, "").replace(/\);?$/, ""));
    if (data.Message) return { error: String(data.Message).slice(0, 160) };
    return { names: data.Names ?? [] };
  } catch (e) {
    return { error: (e as Error).message };
  }
}

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

async function tellKeith(ps: Prospect[], s: Record<string, any>, token: string, test: boolean, now: Date): Promise<string> {
  if (!TO || !FROM || !RESEND_KEY) return "not_configured";
  const link = `${PAGE}#t=${token}`;
  const due = [s.to_message && plural(s.to_message, "pro") + " to message", s.follow_ups && plural(s.follow_ups, "follow-up"),
               s.referrals && plural(s.referrals, "referral") + " to ask for"].filter(Boolean);
  const subject = `${test ? "[Test] " : ""}Hair Done pipeline: ${due.length ? due.join(", ") : "nothing due this week"}`;
  const top = ps.filter((p) => nextAction(p, now) === "message").sort((a, b) => (b.score ?? 0) - (a.score ?? 0)).slice(0, 5)
    .map((p) => `${p.name} · ${p.suburb || AREA_WORDS[areaFor(p.postcode)]}`);
  const lines = [
    ...(test ? ["This is a test: nothing in the pipeline changed. The button opens the real page.", ""] : []),
    `${s.id_checked_pros} of ${GOAL} pros ID checked. From the pipeline so far: ${s.messaged} messaged, ${s.replied} replied, ${s.signed_up} signed up.`,
    ...(s.added ? [`${plural(s.added, "new lead")} from ABN Lookup this week.`] : !s.abr ? ["ABN Lookup isn't connected, so only the pros you add are here."] : []),
    ...(s.changes.length ? ["", "Since last week:", ...s.changes.map((c: string) => `- ${c}`)] : []),
    ...(top.length ? ["", "Best to message first:", ...top.map((t) => `- ${t}`)] : []),
    ...(s.lookup_errors.length ? ["", `ABN Lookup had trouble with ${plural(s.lookup_errors.length, "search", "searches")}: ${s.lookup_errors[0]}`] : []),
    "", "Every message is drafted on the page. You send it from your own account, then tap Sent.",
    `Open the pipeline (the link works for 8 days): ${link}`,
  ];
  const text = lines.join("\n");
  const html = `<!doctype html><html><body style="margin:0;background:#F8F3EC"><div style="max-width:600px;margin:0 auto;padding:28px 20px;font:15px/1.5 -apple-system,Helvetica,sans-serif;color:#241A16">
  <div style="font:italic 24px Georgia,serif">${esc(due.length ? due.join(", ") : "Nothing due this week")}</div>
  ${lines.filter((l) => !l.startsWith("Open the pipeline")).map((l) => (l ? `<p style="margin:0 0 4px">${esc(l)}</p>` : "<br>")).join("")}
  <p style="margin:18px 0"><a href="${esc(link)}" style="display:inline-block;background:#241A16;color:#F8F3EC;text-decoration:none;padding:12px 18px;border-radius:6px;font-weight:600">Open the pipeline</a></p>
  <p style="color:#6F625B;font-size:13px">The link works for 8 days. A new one comes every Monday.</p>
  </div></body></html>`;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json",
                 "Idempotency-Key": `pipeline-${test ? "test-" : ""}${token.split(".")[1]}` },
      body: JSON.stringify({ from: `Hair Done pipeline <${FROM}>`, to: TO.split(",").map((x) => x.trim()), subject, html, text }),
    });
    return res.ok ? "sent" : `resend ${res.status}: ${(await res.text()).slice(0, 160)}`;
  } catch (e) {
    return `resend: ${(e as Error).message}`;
  }
}
