// Run: node watchdog/assess.test.ts   (Node 23.6+ runs TypeScript directly)
// A made-up snapshot with one of everything, so every rule has to fire, and the live snapshot from
// 27 Oct 2026, which has to come back clear.
import assert from "node:assert/strict";
import { assess, cronEvery } from "./assess.ts";
import { render, subject } from "./email.ts";

const NOW = "2026-10-27T06:00:00Z";
const h = (n: number) => new Date(Date.parse(NOW) + n * 3600e3).toISOString();
const cron = (name: string, schedule: string, last: string, extra = {}) =>
  ({ name, schedule, active: true, last_run: last, failed_24h: 0, last_error: null, ...extra });

const quiet = {
  now: NOW, settle_errors: [], card_failed: [], capture_late: [], charge_late: [], release_late: [], hold_late: [],
  sweep_late: [], waiting_reply: [], start_passed: [], capture_paused: [], reports_open: [], low_reviews: [],
  id_waiting: [], payouts_stuck: [], payouts_failed: [], http_failures: [], rls_off: [], last_runs: [],
  today: { starting_next_36h: 0, live_now: 0 }, supply: { real_pros: 1, bookable: 1, sample_pros_live: 10 },
  day: { new_people: 0, new_pros: 0, bookings_made: 0, paid: 0 }, week_paid_cents: 0, http_ok_24h: 144,
  flags: { phone_sign_in: false },
  cron: [cron("hairdone-sweep", "*/10 * * * *", h(-0.1)), cron("hairdone-photo-cleanup", "17 16 * * *", h(-14))],
};

const busy = {
  ...quiet,
  settle_errors: [{ ref: "HD-1", status: "done", hold: "held", error: "card_declined", since: h(-1), sample: false },
                  { ref: "HD-S", status: "done", hold: "held", error: "x", since: h(-1), sample: true }],
  card_failed: [{ ref: "HD-2", status: "confirmed", starts: h(5), sample: false }, { ref: "HD-3", status: "confirmed", starts: h(72), sample: false }],
  capture_late: [{ ref: "HD-4", done_at: h(-14), sample: false }],
  charge_late: [{ ref: "HD-5", status: "noShow", cents: 18300, since: h(-2), sample: false }],
  release_late: [{ ref: "HD-6", status: "declined", hold: "held", since: h(-2), sample: false }],
  hold_late: [{ ref: "HD-7", starts: h(100), sample: false }],
  sweep_late: [{ ref: "HD-8", status: "requested", created: h(-3), ends: h(1), sample: false }],
  waiting_reply: [{ ref: "HD-9", created: h(-1.5), starts: h(30), sample: false }, { ref: "HD-10", created: h(-0.2), starts: h(30), sample: false }],
  start_passed: [{ ref: "HD-11", starts: h(-4), sample: false }],
  capture_paused: [{ ref: "HD-12", until: h(40), sample: false }],
  reports_open: [{ id: "r1", reason: "something_wrong", detail: "She was <b>late</b> & rude", created: h(-3), ref: "HD-12" }],
  low_reviews: [{ rating: 2, service: "Lashes", text: "Meh", created: h(-20), ref: "HD-13", pro: "Ivy K", sample: false }],
  id_waiting: [{ id: "p1", name: "Ivy K", specialties: ["lashes"], suburb: "Brunswick", submitted: h(-50), abn: false, insurance: false, payouts: true }],
  payouts_stuck: [{ id: "p2", name: "Mo T", since: h(-100) }],
  payouts_failed: [{ pro: "Mo", cents: 12000, created: h(-30) }],
  http_failures: [{ code: 503, timed_out: false, error: null, body: "{\"error\":\"stripe_not_configured\"}", n: 12, last: h(-0.1) }],
  rls_off: ["secrets"],
  last_runs: [{ mode: "digest", ran_at: h(-24), email: "resend 403: domain not verified" }],
  cron: [cron("hairdone-sweep", "*/10 * * * *", h(-2)), cron("hairdone-settle", "*/5 * * * *", h(0), { failed_24h: 3, last_error: "boom" }),
         cron("hairdone-reminders", "*/5 * * * *", h(0), { active: false })],
};
const stripeLive = { live: true, endpoints: [{ url: "https://x.supabase.co/functions/v1/stripe-webhook", status: "disabled" }],
  failedDeliveries: 4, disputes: [{ id: "dp_1", amount: 18000, status: "needs_response", due_by: 1793000000 }],
  balance: { available: 1000, pending: 2500 } };
const asc = { version: { version: "1.0", state: "REJECTED" }, build: { version: "41", processing: "VALID", expired: false, expires: h(24 * 5) },
  lowRatings: [{ rating: 1, title: "Crashes", body: "on open" }] };

// cronEvery
assert.equal(cronEvery("* * * * *"), 1);
assert.equal(cronEvery("*/5 * * * *"), 5);
assert.equal(cronEvery("7 * * * *"), 60);
assert.equal(cronEvery("30 20 * * *"), 1440);
assert.equal(cronEvery("0 9 * * 1"), null);

// Quiet: nothing to say, but it says what it couldn't see.
const q = assess(quiet, null, null);
assert.equal(q.level, "clear", JSON.stringify(q.findings));
assert.equal(q.blind.length, 2);
assert.equal(subject("digest", q), "Hair Done: all clear");

// Busy: every rule fires at the level it should.
const b = assess(busy, stripeLive, asc);
const lvl = Object.fromEntries(b.findings.map((f) => [f.key, f.level]));
const expect: Record<string, string> = {
  "settle:HD-1": "red", "settle:HD-S": "amber", "card_failed:HD-2": "red", "card_failed:HD-3": "amber",
  "capture_late:HD-4": "red", "charge_late:HD-5": "red", "release_late:HD-6": "red", "hold_late:HD-7": "red",
  "sweep_late:HD-8": "red", "waiting:HD-9": "amber", "start_passed:HD-11": "amber", "paused:HD-12": "amber",
  "report:r1": "red", "review:HD-13": "amber", "id_waiting:p1": "red", "payouts_stuck:p2": "amber",
  ["payout_failed:Mo:" + h(-30)]: "red", "cron_stale:hairdone-sweep": "red", "cron_failed:hairdone-settle": "red",
  "cron_off:hairdone-reminders": "red", "http:503": "red", "rls:secrets": "red",
  "webhook_off:https://x.supabase.co/functions/v1/stripe-webhook": "red", "webhook_failing": "red", "dispute:dp_1": "red",
  "samples_in_live": "red", "asc_rejected:1.0": "red", "build_expiring:41": "amber", "asc_review:Crashes:1": "amber",
  "watchdog_email": "amber",
};
for (const [k, v] of Object.entries(expect)) assert.equal(lvl[k], v, `${k}: expected ${v}, got ${lvl[k]}`);
assert.equal(lvl["waiting:HD-10"], undefined, "a 12-minute-old request is not news");
assert.equal(Object.keys(lvl).length, Object.keys(expect).length, `unexpected: ${Object.keys(lvl).filter((k) => !(k in expect))}`);
assert.equal(b.level, "red");
assert.ok(b.findings.findIndex((f) => f.level === "amber") > b.findings.filter((f) => f.level === "red").length - 1, "reds first");

// The email: escaped, both halves present.
const { text, html } = render("digest", b, "Do the dispute first.");
assert.ok(html.includes("She was &lt;b&gt;late&lt;/b&gt; &amp; rude") && !html.includes("<b>late</b>"));
assert.ok(text.includes("NEEDS YOU TODAY") && text.includes("KEEP AN EYE ON") && text.includes("THE NUMBERS"));
assert.match(subject("digest", b), /^Hair Done: \d+ need you today, \d+ to watch$/);
assert.match(subject("alert", { ...b, findings: b.findings.slice(0, 1) }), /^Hair Done alert: /);
assert.ok(!/\b(she|her)\b/i.test(b.findings.map((f) => [f.title, f.detail, f.fix].join(" ")).join(" ")), "they/them for pros");

console.log(`ok: ${Object.keys(expect).length} rules fired as expected; quiet snapshot clear\n`);
console.log(text);
