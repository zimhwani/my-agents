// Support and safety. Called by pg_cron every 5 minutes, and straight away by support-inbound (an email)
// and the reports trigger (migration 0022), all with the cron secret:
//   {}               sorts every new item, drafts a reply if drafting is on, and emails Keith each one
//   { dry: true }    the same, without saving or emailing: shows what it would do
// It never replies to anyone. Keith reads, edits and sends from hairdonenailsdone.app/reply/.
//
// Drafting uses Claude only while private.app_flags 'support_ai' is on (it starts off, until the privacy
// policy names Anthropic) and ANTHROPIC_API_KEY is set. Without it, items are still sorted and emailed.
// Email to Keith uses the watchdog's secrets: WATCHDOG_TO, RESEND_API_KEY, WATCHDOG_FROM or RECEIPT_FROM.
import Anthropic from "npm:@anthropic-ai/sdk@1";
import { admin, json } from "../_shared/stripe.ts";
import { DRAFT_SCHEMA, DRAFT_SYSTEM, draftInput, facts, merge, triage, type Triage } from "./assess.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const TO = env("WATCHDOG_TO");
const FROM = env("WATCHDOG_FROM") || env("RECEIPT_FROM");
const RESEND_KEY = env("RESEND_API_KEY");
const REPLY_PAGE = "https://hairdonenailsdone.app/reply/";

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const body = await req.json().catch(() => ({}));
  const dry = body.dry === true;

  const { data: flags } = await admin.rpc("app_flags");
  const drafting = (flags as Record<string, boolean> | null)?.support_ai === true && !!env("ANTHROPIC_API_KEY");
  const { data: ids, error } = await admin.rpc("support_new");
  if (error) return json({ error: error.message }, 500);

  const results = [];
  for (const id of (ids ?? []) as string[]) {
    const { data: ctx } = await admin.rpc("support_context", { p_item: id });
    if (!ctx) continue;
    const rules = triage(ctx);
    const model = drafting ? await draft(ctx) : null;
    const t = merge(rules, model);
    const summary = model?.summary || ctx.item.subject || "(no subject)";
    if (dry) { results.push({ id, ...t, summary, draft: model?.draft ?? null }); continue; }

    const { data: token } = await admin.rpc("support_token", { p_item: id, p_days: 7 });
    const notified = await tellKeith(ctx, t, summary, model?.draft ?? null, token as string, drafting);
    await admin.rpc("support_save", { p_item: id, p: { ...t, summary, draft: model?.draft ?? "", notified } });
    results.push({ id, category: t.category, urgency: t.urgency, notified });
  }
  return json({ dry, drafting, handled: results.length, results });
});

/** One structured call: category, urgency, a one-line summary and the draft. Null if anything goes wrong. */
async function draft(ctx: Record<string, any>): Promise<{ category: string; urgency: string; summary: string; draft: string } | null> {
  try {
    const client = new Anthropic({ timeout: 60_000, maxRetries: 1 });
    const res = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 4000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: { effort: "medium", format: { type: "json_schema", schema: DRAFT_SCHEMA } },
      system: DRAFT_SYSTEM,
      messages: [{ role: "user", content: draftInput(ctx) }],
    });
    if (res.stop_reason === "refusal" || res.stop_reason === "max_tokens") return null;
    const text = res.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
    return JSON.parse(text);
  } catch (e) {
    console.error("support draft", (e as Error).message);
    return null;
  }
}

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const WORDS: Record<string, string> = { safety: "Safety", money: "Money", booking: "Booking", pro: "Pro", account: "Account", other: "Other" };

async function tellKeith(ctx: Record<string, any>, t: Triage, summary: string, draftText: string | null, token: string, drafting: boolean): Promise<string> {
  if (!TO || !FROM || !RESEND_KEY) return "not_configured";
  const item = ctx.item;
  const who = ctx.person?.first_name || item.from_name || item.from_email || "Someone";
  const link = `${REPLY_PAGE}#t=${token}`;
  const urgent = t.category === "safety";
  const subject = urgent ? `URGENT, safety: ${who} (${item.source === "report" ? "in-app report" : "email"})`
    : `Hair Done support: ${summary} (${WORDS[t.category]}${t.urgency === "now" ? ", now" : ""})`;
  const lines = facts(ctx);
  const head = urgent
    ? "This may be about someone's safety. Read it now. If anyone is in danger, call 000 first."
    : `${WORDS[t.category]}, ${t.urgency === "now" ? "needs you now" : t.urgency === "today" ? "reply today" : "no rush"}. ${t.why}`;
  const text = [
    head, "",
    `From: ${who}${item.from_email ? ` <${item.from_email}>` : ""}${item.source === "report" ? " (in-app report)" : ""}`,
    item.subject ? `Subject: ${item.subject}` : "", "",
    String(item.body ?? "(no message)"), "",
    "What Hair Done knows:", ...lines.map((l) => `- ${l}`), "",
    draftText ? `Drafted reply (edit before sending):\n\n${draftText}` : drafting ? "No draft this time: write the reply on the page." : "Drafting is off: write the reply on the page.",
    "", `Reply or close: ${link}`, "(The link lasts 7 days.)",
  ].filter((l, i, a) => l !== "" || a[i - 1] !== "").join("\n");
  const html = `<!doctype html><html><body style="margin:0;background:#F8F3EC"><div style="max-width:600px;margin:0 auto;padding:28px 20px;font:15px/1.5 -apple-system,Helvetica,sans-serif;color:#241A16">
  <p style="margin:0 0 14px;padding:10px 12px;border-radius:6px;${urgent ? "background:#B3261E;color:#fff;font-weight:600" : "background:#EFE7DB"}">${esc(head)}</p>
  <div style="font:italic 22px Georgia,serif">${esc(who)}${item.source === "report" ? " sent a report" : " wrote in"}</div>
  <p style="color:#6F625B;margin:4px 0 14px">${esc(item.from_email ?? "")}${item.subject ? ` · ${esc(item.subject)}` : ""}</p>
  <div style="white-space:pre-wrap;border-left:3px solid #D9CFC2;padding:4px 0 4px 12px;margin:0 0 18px">${esc(String(item.body ?? "(no message)"))}</div>
  <div style="font:600 12px -apple-system,Helvetica,sans-serif;letter-spacing:.06em;text-transform:uppercase;color:#6F625B">What Hair Done knows</div>
  <ul style="padding-left:18px;margin:6px 0 18px">${lines.map((l) => `<li>${esc(l)}</li>`).join("")}</ul>
  ${draftText ? `<div style="font:600 12px -apple-system,Helvetica,sans-serif;letter-spacing:.06em;text-transform:uppercase;color:#6F625B">Drafted reply</div>
  <div style="white-space:pre-wrap;background:#fff;border:1px solid #E7E1D8;border-radius:6px;padding:12px;margin:6px 0 18px">${esc(draftText)}</div>` : ""}
  <p><a href="${esc(link)}" style="display:inline-block;background:#241A16;color:#F8F3EC;text-decoration:none;padding:12px 18px;border-radius:6px;font-weight:600">${draftText ? "Edit and send" : "Write a reply"}</a></p>
  <p style="color:#6F625B;font-size:13px">The link lasts 7 days. Nothing is sent until you press Send on that page.</p>
  </div></body></html>`;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json", "Idempotency-Key": `support-${item.id}` },
      // No reply-to: replying from the inbox would answer them from Keith's own address, not hello@.
      body: JSON.stringify({ from: `Hair Done support <${FROM}>`, to: TO.split(",").map((s) => s.trim()), subject, html, text }),
    });
    return res.ok ? "sent" : `resend ${res.status}: ${(await res.text()).slice(0, 160)}`;
  } catch (e) {
    return `resend: ${(e as Error).message}`;
  }
}
