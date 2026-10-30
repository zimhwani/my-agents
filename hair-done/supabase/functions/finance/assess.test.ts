// Run: node finance/assess.test.ts   (Node 23.6+ runs TypeScript directly)
import assert from "node:assert/strict";
import { assess, expectedFee, nextReport, type Intent } from "./assess.ts";

// Mati's real booking, HD-WS5L, as the database has it: $65 services, $15 travel, $3 fee, $10 tip.
const ws5l = { id: "b1", ref: "HD-WS5L", status: "paid", sample: false, pro_account: "acct_M", services: 6500, travel: 1500,
  booking_fee: 300, discount: 0, tip: 1000, cancellation: 0, charged: 8300, pi: "pi_1", tip_pi: "pi_t1", captured_at: "2026-10-07T11:12:26Z" };
const sample = { ...ws5l, id: "b2", ref: "HD-AMF2", sample: true, pro_account: null, services: 6000, travel: 1000, charged: 7300, pi: "pi_2", tip_pi: "pi_t2" };
const late = { ...ws5l, id: "b3", ref: "HD-LATE", status: "cancelledByClient", tip: 0, tip_pi: null, cancellation: 4000, charged: 4000, pi: "pi_3" };

assert.equal(expectedFee(ws5l), 1260);   // 12% of $80 = $9.60, plus $3
assert.equal(expectedFee(sample), 0);    // no pro account: no fee, no transfer
assert.equal(expectedFee(late), 480);    // 12% of the $40 charged

const intent = (id: string, amt: number, fee: number | null, dest: string | null, extra: Partial<Intent> = {}): Intent =>
  ({ id, status: "succeeded", amount: amt, amount_received: amt, fee, destination: dest, refunded: 0, disputed: false, booking_id: null, kind: null, created: 0, charge: `ch_${id}`, ...extra });
const good = {
  live: false, week: [], payouts: [], refunds: [], disputes: [], app_fees: [{ id: "fee_1", amount: 1260, charge: "ch_pi_1" }, { id: "fee_3", amount: 480, charge: "ch_pi_3" }], balance: { available: 22331, pending: 22713 },
  intents: {
    pi_1: intent("pi_1", 8300, 1260, "acct_M", { booking_id: "b1" }), pi_t1: intent("pi_t1", 1000, null, "acct_M", { booking_id: "b1", kind: "tip" }),
    pi_2: intent("pi_2", 7300, null, null, { booking_id: "b2" }), pi_t2: intent("pi_t2", 1000, null, null, { booking_id: "b2", kind: "tip" }),
    pi_3: intent("pi_3", 4000, 480, "acct_M", { booking_id: "b3" }),
  },
};
const snap = { now: "2026-10-30T00:00:00Z", charged: [ws5l, sample, late],
  known: [{ id: "b1", pi: "pi_1", tip_pi: "pi_t1" }, { id: "b2", pi: "pi_2", tip_pi: "pi_t2" }, { id: "b3", pi: "pi_3" }],
  fees_12m: 1260, gross_12m: 9300, half: { pros: 1, pros_without_abn: 0, paid_to_pros_cents: 8040 }, payouts: [] };

// Everything matches: clear, and the numbers add up the way the bookings say.
const ok = assess(snap, good);
assert.equal(ok.level, "clear", JSON.stringify(ok.findings));
assert.match(ok.numbers[0], /2 real bookings charged, \$133\.00 taken/);
assert.match(ok.numbers[1], /Hair Done's fees: \$17\.40\. To pros: \$115\.60, including \$10\.00 in tips/);
assert.match(ok.numbers[2], /1 test booking/);

// Each way the money can go wrong, and the level it should get.
const tweak = (fn: (v: any) => void) => { const v = structuredClone(good); fn(v); return assess(snap, v); };
const keys = (r: ReturnType<typeof assess>) => Object.fromEntries(r.findings.map((x) => [x.key, x.level]));
const cases: [string, (v: any) => void, string, string][] = [
  ["undercharged", (v) => { v.intents.pi_1.amount_received = 8000; }, "amount:HD-WS5L", "red"],
  ["fee skipped", (v) => { v.intents.pi_1.fee = null; }, "fee:HD-WS5L", "red"],
  ["sent to someone else", (v) => { v.intents.pi_1.destination = "acct_X"; }, "dest:HD-WS5L", "red"],
  ["hold lapsed", (v) => { v.intents.pi_1.status = "canceled"; }, "status:HD-WS5L", "red"],
  ["payment gone", (v) => { delete v.intents.pi_1; }, "missing:HD-WS5L", "red"],
  ["refund in dashboard", (v) => { v.intents.pi_1.refunded = 2000; }, "refund:HD-WS5L", "amber"],
  ["disputed", (v) => { v.intents.pi_1.disputed = true; }, "dispute:HD-WS5L", "red"],
  ["tip short", (v) => { v.intents.pi_t1.amount_received = 500; }, "tip:HD-WS5L", "red"],
  ["fee taken off a tip", (v) => { v.intents.pi_t1.fee = 120; }, "tipfee:HD-WS5L", "red"],
  ["sample pro wrong", (v) => { v.intents.pi_2.amount_received = 1; }, "amount:HD-AMF2", "amber"],
  ["late cancel wrong fee", (v) => { v.intents.pi_3.fee = 1260; }, "fee:HD-LATE", "red"],
  ["orphan payment", (v) => { v.week.push(intent("pi_9", 5000, null, null)); }, "orphan:pi_9", "amber"],
  ["bank payout failed", (v) => { v.payouts.push({ amount: 9000, status: "failed", arrival: 1 }); }, "bankpayout:1", "red"],
  ["fee from no booking", (v) => { v.app_fees.push({ id: "fee_x", amount: 600, charge: "ch_pi_9" }); v.week.push(intent("pi_9", 10000, 600, "acct_M")); }, "fee_orphan:fee_x", "amber"],
];
for (const [what, fn, key, level] of cases) {
  const r = tweak(fn);
  assert.equal(keys(r)[key], level, `${what}: expected ${key}=${level}, got ${JSON.stringify(keys(r))}`);
}
// A cancellation charged without a hold has its own payment: found by booking id, not an orphan.
const noHold = assess({ ...snap, charged: [{ ...late, pi: null }] },
  { ...good, intents: { ...good.intents, pi_8: intent("pi_8", 4000, 480, "acct_M", { booking_id: "b3", kind: "cancellation" }) }, week: [intent("pi_8", 4000, 480, "acct_M", { booking_id: "b3", kind: "cancellation" })], app_fees: [{ id: "fee_8", amount: 480, charge: "ch_pi_8" }] });
assert.equal(noHold.level, "clear", JSON.stringify(noHold.findings));

// Stripe out of reach: red, and a permission error says which boxes to tick.
const denied = assess(snap, { error: "Stripe payment_intents 403: The provided key does not have the required permissions" });
assert.equal(denied.level, "red");
assert.match(denied.findings[0].fix ?? "", /PaymentIntents, Charges, Application fees/);
assert.equal(assess(snap, null).blind.length, 1);

// GST: quiet below 80%, amber from 80%, red at $75,000.
assert.equal(keys(assess({ ...snap, fees_12m: 5_900_000 }, good)).gst_near, undefined);
assert.equal(keys(assess({ ...snap, fees_12m: 6_000_000 }, good)).gst_near, "amber");
assert.equal(keys(assess({ ...snap, fees_12m: 7_500_000 }, good)).gst_over, "red");

// The ATO platform report: due 31 Jan for Jul to Dec, 31 Jul for Jan to Jun; flagged inside 30 days.
assert.equal(nextReport(new Date("2026-10-30")).due.toISOString().slice(0, 10), "2027-01-31");
assert.equal(nextReport(new Date("2027-03-01")).due.toISOString().slice(0, 10), "2027-07-31");
// Melbourne time decides, like the database: 9 am on 1 Feb in Melbourne is still 31 Jan in UTC.
assert.equal(nextReport(new Date("2027-01-31T22:00:00Z")).period, "January to June 2027");
assert.equal(nextReport(new Date("2027-01-31T12:00:00Z")).period, "July to December 2026");
assert.equal(keys(assess({ ...snap, now: "2027-01-10T00:00:00Z" }, good))["serr:July to December 2026"], "amber");
assert.equal(keys(assess({ ...snap, now: "2027-01-28T00:00:00Z" }, good))["serr:July to December 2026"], "red");
assert.equal(keys(assess({ ...snap, now: "2026-10-30T00:00:00Z" }, good))["serr:July to December 2026"], undefined);

console.log(`ok: clean week clear, ${cases.length + 1} ways money goes wrong caught, GST and ATO report timing`);
console.log(ok.numbers.map((n) => `  ${n}`).join("\n"));
