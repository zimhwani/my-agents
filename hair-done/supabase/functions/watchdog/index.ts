// The watchdog. Called by pg_cron with the cron secret (migration 0019):
//   { mode: "digest" }   every morning: what needs Keith today, what to watch, the numbers. Always emails.
//   { mode: "alert" }    every hour: emails only when a red finding is new in the last 24 h.
//   add  dry: true       returns the report without emailing or logging it (for trying it out).
//
// Read-only. The database snapshot is a STABLE function (Postgres refuses writes inside it); Stripe and
// App Store Connect are only ever sent GET requests. The one write is the watchdog's own log row.
//
// Secrets (Supabase > Edge Functions > Secrets; tools/setup-watchdog.sh sets them):
//   WATCHDOG_TO            where the email goes. Without it nothing is emailed; runs are still logged.
//   RESEND_API_KEY, and WATCHDOG_FROM or RECEIPT_FROM    the sender (same Resend account as receipts).
//   STRIPE_WATCHDOG_KEY    a restricted, read-only Stripe key; falls back to STRIPE_SECRET_KEY.
//   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8    App Store Connect API key, for review and TestFlight state.
//   ANTHROPIC_API_KEY      for the two-line "do this first" at the top of the morning email. Optional.
import Anthropic from "npm:@anthropic-ai/sdk@1";
import { admin, json } from "../_shared/stripe.ts";
import { assess, type AppStore, type Report, type Snapshot, type Stripe } from "./assess.ts";
import { render, subject } from "./email.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const TO = env("WATCHDOG_TO");
const FROM = env("WATCHDOG_FROM") || env("RECEIPT_FROM");
const RESEND_KEY = env("RESEND_API_KEY");
const STRIPE_KEY = env("STRIPE_WATCHDOG_KEY") || env("STRIPE_SECRET_KEY");
const BUNDLE = "com.keithchinyanda.hairdone";

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const body = await req.json().catch(() => ({}));
  const mode: "digest" | "alert" = body.mode === "alert" ? "alert" : "digest";
  const dry = body.dry === true;

  let report: Report;
  const { data: snap, error } = await admin.rpc("watchdog_snapshot");
  if (error) {
    // The snapshot itself failing is the loudest thing the watchdog can say.
    report = { level: "red", numbers: [], blind: ["the database"],
      findings: [{ key: "snapshot_failed", level: "red", area: "Watchdog", title: "The watchdog couldn't read the database", detail: error.message }] };
  } else {
    const [stripe, appStore] = await Promise.all([checkStripe(), checkAppStore(mode)]);
    report = assess(snap as Snapshot, stripe, appStore);
  }
  const reds = report.findings.filter((f) => f.level === "red").map((f) => f.key);

  if (mode === "alert") {
    const { data: recent } = await admin.rpc("watchdog_recent_alerts", { hours: 24 });
    const seen = new Set<string>((recent as string[]) ?? []);
    const fresh = reds.filter((k) => !seen.has(k));
    if (!fresh.length) return finish(mode, dry, report, [], "skipped");
    const only: Report = { ...report, findings: report.findings.filter((f) => fresh.includes(f.key)) };
    return finish(mode, dry, only, fresh, await send(mode, only, null, dry));
  }

  const brief = await writeBrief(report);
  return finish(mode, dry, report, reds, await send(mode, report, brief, dry), brief);
});

async function finish(mode: string, dry: boolean, report: Report, alerted: string[], email: string | null, brief: string | null = null) {
  if (!dry) {
    await admin.rpc("watchdog_record", { p_mode: mode, p_level: report.level, p_findings: report.findings,
      // Only what actually reached Keith counts as told, so a fix to the email setup re-sends it.
      p_alerted: email === "sent" ? alerted : [], p_email: email ?? "not_sent" });
  }
  return json({ mode, dry, level: report.level, email, alerted, findings: report.findings, numbers: report.numbers, blind: report.blind,
                ...(dry ? { brief, preview: render(mode, report, brief).text } : {}) });
}

// ---------------------------------------------------------------------------------------------
// Stripe: GET only
// ---------------------------------------------------------------------------------------------
async function stripeGet(path: string) {
  const res = await fetch(`https://api.stripe.com/v1/${path}`, { method: "GET", headers: { Authorization: `Bearer ${STRIPE_KEY}` } });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`Stripe ${path.split("?")[0]} ${res.status}: ${body?.error?.message ?? ""}`.trim());
  return body;
}

async function checkStripe(): Promise<Stripe> {
  if (!STRIPE_KEY) return null;
  try {
    const since = Math.floor(Date.now() / 1000) - 86400;
    const [endpoints, events, disputes, balance] = await Promise.all([
      stripeGet("webhook_endpoints?limit=20"),
      stripeGet(`events?delivery_success=false&created[gte]=${since}&limit=100`),
      stripeGet("disputes?limit=50"),
      stripeGet("balance"),
    ]);
    const aud = (rows: { amount: number; currency: string }[]) =>
      (rows ?? []).filter((r) => r.currency === "aud").reduce((n, r) => n + r.amount, 0);
    return {
      live: /^(sk|rk)_live_/.test(STRIPE_KEY),
      endpoints: (endpoints.data ?? []).map((e: any) => ({ url: e.url, status: e.status })),
      failedDeliveries: (events.data ?? []).length,
      disputes: (disputes.data ?? []).filter((d: any) => ["needs_response", "warning_needs_response"].includes(d.status))
        .map((d: any) => ({ id: d.id, amount: d.amount, status: d.status, due_by: d.evidence_details?.due_by ?? null })),
      balance: { available: aud(balance.available), pending: aud(balance.pending) },
    };
  } catch (e) {
    return { error: (e as Error).message };
  }
}

// ---------------------------------------------------------------------------------------------
// App Store Connect: GET only, signed with an ES256 JWT
// ---------------------------------------------------------------------------------------------
const b64url = (bytes: Uint8Array | string) =>
  (typeof bytes === "string" ? btoa(bytes) : btoa(String.fromCharCode(...bytes)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function ascToken() {
  const pem = env("ASC_KEY_P8").replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: "ES256", kid: env("ASC_KEY_ID"), typ: "JWT" }));
  const claims = b64url(JSON.stringify({ iss: env("ASC_ISSUER_ID"), iat: now, exp: now + 600, aud: "appstoreconnect-v1" }));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(`${head}.${claims}`)));
  return `${head}.${claims}.${b64url(sig)}`;
}

async function checkAppStore(mode: string): Promise<AppStore> {
  if (!env("ASC_KEY_ID") || !env("ASC_ISSUER_ID") || !env("ASC_KEY_P8")) return null;
  try {
    const token = await ascToken();
    const get = async (path: string) => {
      const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, { method: "GET", headers: { Authorization: `Bearer ${token}` } });
      if (!res.ok) throw new Error(`App Store Connect ${path.split("?")[0]} ${res.status}`);
      return res.json();
    };
    const app = (await get(`/v1/apps?filter[bundleId]=${BUNDLE}`)).data?.[0];
    if (!app) return { error: `no app with bundle id ${BUNDLE}` };
    const [versions, builds, reviews] = await Promise.all([
      get(`/v1/apps/${app.id}/appStoreVersions?limit=1`),
      get(`/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1`),
      mode === "digest" ? get(`/v1/apps/${app.id}/customerReviews?sort=-createdDate&limit=20`) : Promise.resolve({ data: [] }),
    ]);
    const v = versions.data?.[0]?.attributes;
    const b = builds.data?.[0]?.attributes;
    const dayAgo = Date.now() - 86400e3;
    return {
      version: v ? { version: v.versionString, state: v.appVersionState ?? v.appStoreState } : null,
      build: b ? { version: b.version, processing: b.processingState, expired: !!b.expired, expires: b.expirationDate ?? null } : null,
      lowRatings: (reviews.data ?? []).map((r: any) => r.attributes)
        .filter((r: any) => r.rating <= 3 && Date.parse(r.createdDate) > dayAgo)
        .map((r: any) => ({ rating: r.rating, title: r.title ?? "", body: r.body ?? "" })),
    };
  } catch (e) {
    return { error: (e as Error).message };
  }
}

// ---------------------------------------------------------------------------------------------
// The "do this first" lines. The model only sees the findings' titles and details, never anything a
// client or pro typed, and the full list is in the email under it, so it can't hide or invent one.
// ---------------------------------------------------------------------------------------------
const BRIEF_SYSTEM = `You write the first lines of a morning operations email for Keith, who runs Hair Done, a Melbourne app where clients book mobile hair, nails and makeup pros.

You get the findings the watchdog's rules produced, as JSON. Red means it needs Keith today; amber means keep an eye on it.

Write two to four short sentences of plain text: what to do first and why, then anything else red. Use only facts in the JSON: no new numbers, causes or advice beyond each finding's "fix". If there is nothing red, say in one sentence that nothing needs him today and name the amber item most worth a look, if any. No greeting, no sign-off, no lists, no markdown, no emoji. Refer to pros as "they".`;

async function writeBrief(report: Report): Promise<string | null> {
  if (!env("ANTHROPIC_API_KEY") || !report.findings.length) return null;
  try {
    const client = new Anthropic({ timeout: 45_000, maxRetries: 1 });
    const facts = report.findings.map(({ level, area, title, detail, fix }) => ({ level, area, title, detail, fix }));
    const res = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 2000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: { effort: "low" },
      system: BRIEF_SYSTEM,
      messages: [{ role: "user", content: JSON.stringify(facts) }],
    });
    if (res.stop_reason === "refusal") return null;
    const text = res.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join(" ").trim();
    return text || null;
  } catch (e) {
    console.error("watchdog brief", (e as Error).message);
    return null;
  }
}

// ---------------------------------------------------------------------------------------------
// Sending (the words and layout are in email.ts)
// ---------------------------------------------------------------------------------------------
async function send(mode: string, r: Report, brief: string | null, dry: boolean): Promise<string> {
  if (dry) return "dry_run";
  if (!TO || !FROM || !RESEND_KEY) return "not_configured";
  const { text, html } = render(mode, r, brief);
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json",
                 "Idempotency-Key": `watchdog-${mode}-${Math.floor(Date.now() / 600000)}` },
      body: JSON.stringify({ from: `Hair Done watchdog <${FROM}>`, to: TO.split(",").map((s) => s.trim()), subject: subject(mode, r), html, text }),
    });
    if (!res.ok) return `resend ${res.status}: ${(await res.text()).slice(0, 160)}`;
    return "sent";
  } catch (e) {
    return `resend: ${(e as Error).message}`;
  }
}
