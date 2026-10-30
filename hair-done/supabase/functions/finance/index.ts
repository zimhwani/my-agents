// The finance agent. Called by pg_cron every Monday at 7 am Melbourne time with the cron secret (migration 0025):
//   {}                       checks last Monday to this Monday (Melbourne midnights) and emails Keith
//   { days: 40, dry: true }  any number of days back to today, without emailing or logging (for trying it out)
// Read-only: the database snapshot is a STABLE function and Stripe is only sent GET requests. No model:
// every figure is arithmetic on the bookings and what Stripe reports (rules in assess.ts).
//
// Stripe key: STRIPE_WATCHDOG_KEY (the restricted read-only one) if it can see payments, else
// STRIPE_SECRET_KEY, and the email says which. Email: WATCHDOG_TO, RESEND_API_KEY, WATCHDOG_FROM or RECEIPT_FROM.
import { admin, json } from "../_shared/stripe.ts";
import { assess, type Finding, type Intent, type StripeView } from "./assess.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const TO = env("WATCHDOG_TO");
const FROM = env("WATCHDOG_FROM") || env("RECEIPT_FROM");
const RESEND_KEY = env("RESEND_API_KEY");
const KEYS = [env("STRIPE_WATCHDOG_KEY"), env("STRIPE_SECRET_KEY")].filter(Boolean);
const TZ = "Australia/Melbourne";

/** Midnight at the start of today in Melbourne, as a UTC instant. */
function melbourneMidnight(now: Date): Date {
  const p = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false, timeZoneName: "longOffset" }).formatToParts(now).map((x) => [x.type, x.value]));
  const off = /GMT([+-])(\d\d):(\d\d)/.exec(p.timeZoneName ?? "") ?? ["", "+", "00", "00"];
  const mins = (off[1] === "-" ? -1 : 1) * (Number(off[2]) * 60 + Number(off[3]));
  return new Date(Date.UTC(Number(p.year), Number(p.month) - 1, Number(p.day)) - mins * 60e3);
}

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const body = await req.json().catch(() => ({}));
  const dry = body.dry === true;
  const to = body.days ? new Date() : melbourneMidnight(new Date());
  const from = new Date(to.getTime() - (Number(body.days) || 7) * 86400e3);

  const { data: snap, error } = await admin.rpc("finance_snapshot", { p_from: from.toISOString(), p_to: to.toISOString() });
  if (error) return json({ error: error.message }, 500);
  const stripe = await readStripe(snap, from, to);
  const report = assess(snap, stripe.view);
  if (stripe.note) report.numbers.push(stripe.note);

  const email = dry ? "dry_run" : await send(report, from, to);
  if (!dry) await admin.rpc("finance_record", { p_from: from.toISOString(), p_to: to.toISOString(), p_level: report.level,
    p_report: report, p_email: email });
  return json({ dry, from, to, email, ...report, ...(dry ? { preview: render(report, from, to).text } : {}) });
});

// ---------------------------------------------------------------------------------------------
// Stripe: GET only
// ---------------------------------------------------------------------------------------------
async function readStripe(snap: Record<string, any>, from: Date, to: Date): Promise<{ view: StripeView; note?: string }> {
  if (!KEYS.length) return { view: null };
  let last = "";
  for (const [i, key] of KEYS.entries()) {
    try {
      const view = await readWith(key, snap, from, to);
      const note = i > 0 && KEYS.length > 1
        ? "Read Stripe with the payment key: the read-only key can't see payments yet (give it Read on PaymentIntents, Charges, Application fees, Payouts, Refunds and Disputes)."
        : undefined;
      return { view, note };
    } catch (e) {
      last = (e as Error).message;
      if (!/permission|restricted|403/i.test(last)) break;   // only a permissions gap is worth trying the other key for
    }
  }
  return { view: { error: last } };
}

async function readWith(key: string, snap: Record<string, any>, from: Date, to: Date): Promise<StripeView> {
  const get = async (path: string) => {
    const res = await fetch(`https://api.stripe.com/v1/${path}`, { method: "GET", headers: { Authorization: `Bearer ${key}` } });
    const b = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`Stripe ${path.split("?")[0]} ${res.status}: ${b?.error?.message ?? ""}`.trim());
    return b;
  };
  const list = async (path: string, pages = 5) => {
    const out: any[] = [];
    let after = "";
    for (let n = 0; n < pages; n++) {
      const b = await get(`${path}${path.includes("?") ? "&" : "?"}limit=100${after ? `&starting_after=${after}` : ""}`);
      out.push(...(b.data ?? []));
      if (!b.has_more || !b.data?.length) break;
      after = b.data[b.data.length - 1].id;
    }
    return out;
  };
  const norm = (p: any): Intent => ({
    id: p.id, status: p.status, amount: p.amount, amount_received: p.amount_received ?? 0,
    fee: p.application_fee_amount ?? null, destination: p.transfer_data?.destination ?? null,
    refunded: typeof p.latest_charge === "object" ? p.latest_charge?.amount_refunded ?? 0 : 0,
    disputed: typeof p.latest_charge === "object" ? !!p.latest_charge?.disputed : false,
    booking_id: p.metadata?.booking_id ?? null, kind: p.metadata?.kind ?? null, created: p.created,
    charge: typeof p.latest_charge === "object" ? p.latest_charge?.id ?? null : p.latest_charge ?? null,
  });
  const window = `created[gte]=${Math.floor(from.getTime() / 1000)}&created[lt]=${Math.floor(to.getTime() / 1000)}`;

  const intents: Record<string, Intent> = {};
  for (const b of (snap.charged ?? []) as Record<string, any>[]) {
    for (const id of [b.pi, b.tip_pi].filter(Boolean)) intents[id] = norm(await get(`payment_intents/${id}?expand[]=latest_charge`));
    if (!b.pi) {   // a cancellation charged without a hold has its own payment, found by its booking id
      const found = await get(`payment_intents/search?query=${encodeURIComponent(`metadata['booking_id']:'${b.id}'`)}&expand[]=data.latest_charge`);
      for (const p of found.data ?? []) intents[p.id] = norm(p);
    }
  }
  const [week, payouts, fees, balance, refunds, disputes] = await Promise.all([
    list(`payment_intents?${window}`), list(`payouts?${window}`), list(`application_fees?${window}`),
    get("balance"), list(`refunds?${window}`, 2), list(`disputes?${window}`, 2),
  ]);
  const aud = (rows: any[]) => (rows ?? []).filter((r) => r.currency === "aud").reduce((n, r) => n + r.amount, 0);
  return {
    live: /^(sk|rk)_live_/.test(key),
    intents,
    week: week.map(norm),
    payouts: payouts.map((p) => ({ amount: p.amount, status: p.status, arrival: p.arrival_date })),
    app_fees: fees.map((a) => ({ id: a.id, amount: a.amount - (a.amount_refunded ?? 0),
      charge: typeof a.originating_transaction === "string" ? a.originating_transaction : a.charge ?? null })),
    balance: { available: aud(balance.available), pending: aud(balance.pending) },
    refunds: refunds.map((r) => ({ amount: r.amount, intent: r.payment_intent ?? null, created: r.created })),
    disputes: disputes.map((d) => ({ id: d.id, amount: d.amount, status: d.status, intent: d.payment_intent ?? null })),
  };
}

// ---------------------------------------------------------------------------------------------
// The email
// ---------------------------------------------------------------------------------------------
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const day = (d: Date) => d.toLocaleDateString("en-AU", { timeZone: TZ, weekday: "short", day: "numeric", month: "short" });

function render(r: ReturnType<typeof assess>, from: Date, to: Date) {
  const span = `${day(from)} to ${day(new Date(to.getTime() - 1))}`;
  const red = r.findings.filter((f) => f.level === "red"), amber = r.findings.filter((f) => f.level === "amber");
  const head = r.findings.length ? `${red.length ? `${red.length} thing${red.length === 1 ? "" : "s"} don't add up` : "Nothing wrong"}${amber.length ? `, ${amber.length} to look at` : ""}.`
    : "Everything adds up: every charge, fee, transfer and tip matches its booking.";
  const item = (f: Finding) => [`- ${f.title}`, f.detail && `  ${f.detail}`, f.fix && `  Fix: ${f.fix}`].filter(Boolean).join("\n");
  const text = [
    `Hair Done money, ${span}`, "", head,
    red.length && `\nDOESN'T ADD UP\n${red.map(item).join("\n")}`,
    amber.length && `\nLOOK AT\n${amber.map(item).join("\n")}`,
    `\nTHE NUMBERS\n${r.numbers.map((n) => `- ${n}`).join("\n")}`,
    r.blind.length && `\nCOULDN'T CHECK\n${r.blind.map((b) => `- ${b}`).join("\n")}`,
    "\nRead-only: this check can't move money or change bookings. Supabase migration 0025, function finance.",
  ].filter(Boolean).join("\n");
  const block = (h: string, inner: string) => `<h2 style="font:600 13px -apple-system,Helvetica,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#6F625B;margin:26px 0 6px">${esc(h)}</h2>${inner}`;
  const rows = (l: Finding[], color: string) => l.map((f) => `<div style="padding:10px 0;border-top:1px solid #E7E1D8"><div style="font-weight:600;color:${color}">${esc(f.title)}</div>${f.detail ? `<div style="color:#4A453E">${esc(f.detail)}</div>` : ""}${f.fix ? `<div style="font:13px Menlo,monospace;background:#F4EFE7;padding:6px 8px;border-radius:4px;margin-top:4px">${esc(f.fix)}</div>` : ""}</div>`).join("");
  const html = `<!doctype html><html><body style="margin:0;background:#F8F3EC"><div style="max-width:600px;margin:0 auto;padding:28px 20px;font:15px/1.5 -apple-system,Helvetica,sans-serif;color:#241A16">
  <div style="font:italic 24px Georgia,serif">Hair Done money</div>
  <div style="color:#6F625B;margin:2px 0 16px">${esc(span)}</div>
  <p style="font-size:16px;margin:0">${esc(head)}</p>
  ${red.length ? block("Doesn't add up", rows(red, "#B3261E")) : ""}
  ${amber.length ? block("Look at", rows(amber, "#8A5A00")) : ""}
  ${block("The numbers", `<ul style="padding-left:18px;margin:0;color:#4A453E">${r.numbers.map((n) => `<li>${esc(n)}</li>`).join("")}</ul>`)}
  ${r.blind.length ? block("Couldn't check", `<ul style="padding-left:18px;margin:0;color:#4A453E">${r.blind.map((b) => `<li>${esc(b)}</li>`).join("")}</ul>`) : ""}
  <p style="font-size:12px;color:#8C867D;margin-top:30px">Read-only: this check can't move money or change bookings. Supabase migration 0025, function finance.</p>
  </div></body></html>`;
  const subject = `Hair Done money, ${span}: ${r.level === "clear" ? "all adds up" : r.level === "red" ? `${red.length} thing${red.length === 1 ? "" : "s"} don't add up` : `${amber.length} to look at`}`;
  return { subject, text, html };
}

async function send(r: ReturnType<typeof assess>, from: Date, to: Date): Promise<string> {
  if (!TO || !FROM || !RESEND_KEY) return "not_configured";
  const { subject, text, html } = render(r, from, to);
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json", "Idempotency-Key": `finance-${to.toISOString().slice(0, 10)}` },
      body: JSON.stringify({ from: `Hair Done finance <${FROM}>`, to: TO.split(",").map((s) => s.trim()), subject, html, text }),
    });
    return res.ok ? "sent" : `resend ${res.status}: ${(await res.text()).slice(0, 160)}`;
  } catch (e) {
    return `resend: ${(e as Error).message}`;
  }
}

