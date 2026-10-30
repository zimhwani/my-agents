// Finance rules: the week's bookings (finance_snapshot, migration 0025) and what Stripe says, in; what
// doesn't add up, and the week's numbers, out. No I/O, so it can be tested: node finance/assess.test.ts
// No model anywhere here: every figure is arithmetic on the two records.

export type Level = "red" | "amber";
export type Finding = { key: string; level: Level; title: string; detail?: string; fix?: string };

/** One PaymentIntent as Stripe reports it, cut to what the checks use. */
export type Intent = {
  id: string; status: string; amount: number; amount_received: number; fee: number | null; destination: string | null;
  refunded: number; disputed: boolean; booking_id: string | null; kind: string | null; created: number;
  charge: string | null;                    // the charge it made, which is what an application fee points at
};
export type StripeView = {
  live: boolean;
  intents: Record<string, Intent>;          // every intent the bookings point at, plus any found by search
  week: Intent[];                           // every intent created in the window
  payouts: { amount: number; status: string; arrival: number }[];   // Stripe to Hair Done's bank
  app_fees: { id: string; amount: number; charge: string | null }[];   // fees collected in the window, less refunds
  balance: { available: number; pending: number };
  refunds: { amount: number; intent: string | null; created: number }[];
  disputes: { id: string; amount: number; status: string; intent: string | null }[];
} | { error: string } | null;

type Row = Record<string, any>;

export const GST_THRESHOLD = 7_500_000;   // $75,000 a year, in cents
export const PLATFORM_RATE = 0.12;

export const money = (c: number) => `${c < 0 ? "-" : ""}$${(Math.abs(c) / 100).toLocaleString("en-AU", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

/** Hair Done's fee on a charge, the same rule as applicationFee() in _shared/stripe.ts. */
export function expectedFee(b: Row): number {
  if (!b.pro_account) return 0;
  const full = b.services + b.travel + b.booking_fee;
  if (b.charged >= full - b.discount) return Math.round((b.services + b.travel) * PLATFORM_RATE) + b.booking_fee - b.discount;
  return Math.round(b.charged * PLATFORM_RATE);
}

/** The next ATO sharing economy report: Jan to Jun is due 31 July, Jul to Dec is due 31 January. Until a
 *  due date passes, the half before it is still the one to report (in January, last July to December).
 *  Matches the half finance_snapshot counts (migration 0026). */
export function nextReport(now: Date): { period: string; due: Date } {
  const [y, m1] = new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Melbourne", year: "numeric", month: "2-digit" })
    .format(now).split("-").map(Number);
  const m = m1 - 1;
  if (m === 0) return { period: `July to December ${y - 1}`, due: new Date(Date.UTC(y, 0, 31)) };
  if (m <= 6) return { period: `January to June ${y}`, due: new Date(Date.UTC(y, 6, 31)) };
  return { period: `July to December ${y}`, due: new Date(Date.UTC(y + 1, 0, 31)) };
}

export function assess(s: Row, stripe: StripeView): { level: "red" | "amber" | "clear"; findings: Finding[]; numbers: string[]; blind: string[] } {
  const f: Finding[] = [];
  const blind: string[] = [];
  const charged: Row[] = s.charged ?? [];
  const real = charged.filter((b) => !b.sample);
  const test = (b: Row) => (b.sample ? " (sample pro, test money)" : "");
  const lvl = (b: Row): Level => (b.sample ? "amber" : "red");

  if (!stripe) blind.push("Stripe (no key in the function's secrets)");
  else if ("error" in stripe) {
    blind.push(`Stripe (${stripe.error})`);
    f.push({ key: "stripe_unreachable", level: "red", title: "Couldn't read Stripe, so nothing was reconciled", detail: stripe.error,
      fix: /permission|restricted|403/i.test(stripe.error)
        ? "The read-only Stripe key needs Read on PaymentIntents, Charges, Application fees, Payouts, Refunds and Disputes: Stripe > Developers > API keys > the watchdog key > Edit."
        : undefined });
  } else {
    // ---- Each booking charged this week, against its payment in Stripe -----------------------
    for (const b of charged) {
      const wantFee = expectedFee(b);
      const pi = (b.pi && stripe.intents[b.pi]?.amount_received === b.charged ? stripe.intents[b.pi] : null)
        ?? Object.values(stripe.intents).find((i) => i.booking_id === b.id && i.kind !== "tip" && i.amount_received === b.charged)
        ?? (b.pi ? stripe.intents[b.pi] : undefined);
      if (!pi) {
        f.push({ key: `missing:${b.ref}`, level: lvl(b), title: `Stripe has no payment for ${b.ref}${test(b)}`,
          detail: `The booking says ${money(b.charged)} was taken on ${String(b.captured_at).slice(0, 10)}.`, fix: `Search Stripe > Payments for ${b.ref}.` });
        continue;
      }
      if (pi.status !== "succeeded") {
        f.push({ key: `status:${b.ref}`, level: lvl(b), title: `${b.ref}: the booking says paid, Stripe says ${pi.status.replace(/_/g, " ")}${test(b)}`,
          detail: `Payment ${pi.id}.`, fix: "Open the payment in Stripe. If the hold lapsed, the client was never charged." });
      } else if (pi.amount_received !== b.charged) {
        f.push({ key: `amount:${b.ref}`, level: lvl(b), title: `${b.ref}: Stripe took ${money(pi.amount_received)}, the booking says ${money(b.charged)}${test(b)}`,
          detail: `Difference ${money(pi.amount_received - b.charged)}. Payment ${pi.id}.` });
      }
      if ((pi.fee ?? 0) !== wantFee) {
        f.push({ key: `fee:${b.ref}`, level: lvl(b), title: `${b.ref}: Hair Done's fee was ${money(pi.fee ?? 0)}, should be ${money(wantFee)}${test(b)}`,
          detail: b.pro_account ? "12% of services and travel, plus the $3 booking fee (12% of the charge on a late cancel)." : "No pro account, so there should be no fee or transfer." });
      }
      if ((pi.destination ?? null) !== (b.pro_account ?? null)) {
        f.push({ key: `dest:${b.ref}`, level: lvl(b), title: `${b.ref}: the money went to the wrong place${test(b)}`,
          detail: `Stripe sent it to ${pi.destination ?? "Hair Done alone"}; the pro's account is ${b.pro_account ?? "none"}.` });
      }
      if (pi.refunded > 0) {
        f.push({ key: `refund:${b.ref}`, level: "amber", title: `${b.ref}: ${money(pi.refunded)} refunded in Stripe${test(b)}`,
          detail: "The app doesn't record refunds, so this was done in the Stripe dashboard. The pro's share comes back out of their next payout." });
      }
      if (pi.disputed) {
        f.push({ key: `dispute:${b.ref}`, level: "red", title: `${b.ref}: the client disputed this charge${test(b)}`, fix: "Stripe > Payments > Disputes. Evidence is due by the date Stripe shows." });
      }
      if (b.tip > 0) {
        const t = b.tip_pi ? stripe.intents[b.tip_pi] : undefined;
        if (!t || t.status !== "succeeded" || t.amount_received !== b.tip) {
          f.push({ key: `tip:${b.ref}`, level: lvl(b), title: `${b.ref}: the ${money(b.tip)} tip doesn't match Stripe${test(b)}`,
            detail: t ? `Stripe shows ${money(t.amount_received)}, ${t.status}.` : "No tip payment found." });
        } else if ((t.fee ?? 0) !== 0 || (t.destination ?? null) !== (b.pro_account ?? null)) {
          f.push({ key: `tipfee:${b.ref}`, level: lvl(b), title: `${b.ref}: the tip didn't go to the pro in full${test(b)}`,
            detail: `Fee ${money(t.fee ?? 0)}, sent to ${t.destination ?? "Hair Done"}. Tips should be 100% to the pro.` });
        }
      }
    }

    // ---- Payments in Stripe that no booking accounts for --------------------------------------
    const known: Row[] = s.known ?? [];
    const ids = new Set(known.flatMap((k) => [k.pi, k.tip_pi]).filter(Boolean));
    const bookings = new Set(known.map((k) => k.id));
    for (const i of stripe.week) {
      if (i.status !== "succeeded" || ids.has(i.id)) continue;
      if (i.booking_id && bookings.has(i.booking_id)) continue;   // a cancellation charge made without a hold
      f.push({ key: `orphan:${i.id}`, level: "amber", title: `${money(i.amount_received)} in Stripe that no booking accounts for`,
        detail: `Payment ${i.id}${i.booking_id ? `, for booking id ${i.booking_id}` : ", with no booking on it"}.`,
        fix: "Look it up in Stripe > Payments. A test or a manual charge is fine; anything else isn't." });
    }
    for (const d of stripe.disputes.filter((d) => !charged.some((b) => b.pi === d.intent))) {
      f.push({ key: `dispute:${d.id}`, level: "red", title: `A dispute opened this week (${money(d.amount)})`, detail: `Status ${d.status.replace(/_/g, " ")}.`,
        fix: "Stripe > Payments > Disputes." });
    }
    for (const p of stripe.payouts.filter((p) => p.status === "failed")) {
      f.push({ key: `bankpayout:${p.arrival}`, level: "red", title: `A ${money(p.amount)} payout to Hair Done's bank failed`, fix: "Stripe > Balances > Payouts: usually the bank details." });
    }
    // Every fee Stripe collected should belong to a booking's payment; name any that doesn't.
    const bookingCharges = new Set(Object.values(stripe.intents).map((i) => i.charge).filter(Boolean));
    for (const a of stripe.app_fees.filter((a) => a.amount > 0 && !(a.charge && bookingCharges.has(a.charge)))) {
      const from = stripe.week.find((i) => i.charge === a.charge);
      f.push({ key: `fee_orphan:${a.id}`, level: "amber", title: `A ${money(a.amount)} Hair Done fee that no booking this week accounts for`,
        detail: `Fee ${a.id}, on charge ${a.charge ?? "unknown"}${from ? ` (payment ${from.id}, ${money(from.amount_received)})` : ""}.`,
        fix: "Look it up in Stripe > Connect > Collected fees. A fee from a test or an older booking is fine." });
    }
  }

  for (const p of (s.payouts ?? []).filter((p: Row) => p.status === "failed")) {
    f.push({ key: `propayout:${p.pro}:${p.created}`, level: "red", title: `A ${money(p.cents)} payout to ${p.pro} failed`, fix: "Stripe > Connect > their account > Payouts." });
  }

  // ---- GST and the ATO's platform report ------------------------------------------------------
  const fees12 = Number(s.fees_12m ?? 0), gross12 = Number(s.gross_12m ?? 0);
  if (fees12 >= GST_THRESHOLD) {
    f.push({ key: "gst_over", level: "red", title: `Hair Done's fees passed the $75,000 GST threshold (${money(fees12)} in 12 months)`,
      fix: "Talk to your accountant this week: you have 21 days to register once you pass it." });
  } else if (fees12 >= 0.8 * GST_THRESHOLD) {
    f.push({ key: "gst_near", level: "amber", title: `Hair Done's fees are ${Math.round((100 * fees12) / GST_THRESHOLD)}% of the GST threshold`,
      detail: `${money(fees12)} in the last 12 months, against $75,000.`, fix: "Worth a word with your accountant before you get there." });
  }
  const now = new Date(s.now ?? Date.now());
  const r = nextReport(now);
  const days = Math.ceil((r.due.getTime() - now.getTime()) / 86400e3);
  const half = s.half ?? {};
  if (days <= 30 && half.pros > 0) {
    f.push({ key: `serr:${r.period}`, level: days <= 7 ? "red" : "amber", title: `The ATO platform report for ${r.period} is due in ${days} days`,
      detail: `${half.pros} pro${half.pros === 1 ? "" : "s"} paid, ${money(half.paid_to_pros_cents ?? 0)} to them so far.${half.pros_without_abn ? ` ${half.pros_without_abn} without an ABN.` : ""}`,
      fix: "Ask your accountant to lodge it, or lodge it through the ATO's online services for business." });
  }

  // ---- The week's numbers -----------------------------------------------------------------------
  const sum = (rows: Row[], k: (b: Row) => number) => rows.reduce((n, b) => n + k(b), 0);
  const fees = sum(real, expectedFee), tips = sum(real, (b) => b.tip);
  const toPros = sum(real.filter((b) => b.pro_account), (b) => b.charged - expectedFee(b) + b.tip);
  const numbers = [
    `This week: ${real.length} real booking${real.length === 1 ? "" : "s"} charged, ${money(sum(real, (b) => b.charged) + tips)} taken (with tips)`,
    `Hair Done's fees: ${money(fees)}. To pros: ${money(toPros)}, including ${money(tips)} in tips`,
  ];
  const samples = charged.length - real.length;
  if (samples) numbers.push(`Sample pros: ${samples} test booking${samples === 1 ? "" : "s"}, checked but left out of the totals`);
  if (stripe && !("error" in stripe)) {
    numbers.push(`Stripe (${stripe.live ? "live" : "test mode"}): ${money(stripe.balance.available)} available, ${money(stripe.balance.pending)} on the way` +
      (stripe.payouts.length ? `; ${stripe.payouts.length} payout${stripe.payouts.length === 1 ? "" : "s"} to your bank this week, ${money(sum(stripe.payouts, (p) => p.amount))}` : ""));
  }
  numbers.push(`Last 12 months: ${money(fees12)} in Hair Done fees on ${money(gross12)} of bookings. GST threshold $75,000 (check with your accountant which of the two counts for a marketplace)`);
  numbers.push(`Next ATO platform report: ${r.period}, due ${r.due.toLocaleDateString("en-AU", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" })}. ${half.pros ?? 0} pro${half.pros === 1 ? "" : "s"} paid so far, ${money(half.paid_to_pros_cents ?? 0)}`);

  f.sort((a, b) => (a.level === b.level ? 0 : a.level === "red" ? -1 : 1));
  return { level: f.some((x) => x.level === "red") ? "red" : f.length ? "amber" : "clear", findings: f, numbers, blind };
}
