// The watchdog's rules: a snapshot of the database (migration 0019) plus what Stripe and App Store
// Connect said, in; findings, out. No I/O here, so it can be tested with a saved snapshot:
//   node watchdog/assess.test.ts
// Red = needs Keith today (money stuck, a timer down, a report). Amber = keep an eye on it.

export type Level = "red" | "amber";
export type Finding = {
  key: string;        // stable across runs, so an hourly alert only fires once per problem
  level: Level;
  area: "Money" | "Bookings" | "Safety" | "Pros" | "Timers" | "Stripe" | "App Store" | "Database" | "Watchdog";
  title: string;
  detail?: string;
  fix?: string;
  quote?: string;     // words a client or pro wrote: shown in the email, never given to the model
};

type Row = Record<string, any>;
export type Snapshot = Record<string, any>;

export type Stripe = {
  live: boolean;
  endpoints: { url: string; status: string }[];
  failedDeliveries: number;
  disputes: { id: string; amount: number; status: string; due_by: number | null }[];
  balance: { available: number; pending: number };
} | { error: string } | null;

export type AppStore = {
  version: { version: string; state: string } | null;
  build: { version: string; processing: string; expired: boolean; expires: string | null } | null;
  lowRatings: { rating: number; title: string; body: string }[];
} | { error: string } | null;

export type Report = {
  level: "red" | "amber" | "clear";
  findings: Finding[];
  numbers: string[];
  blind: string[];    // what the watchdog couldn't see this run
};

const WEBHOOK_PATH = "/functions/v1/stripe-webhook";

export function money(cents: number) {
  const d = Math.max(0, cents) / 100;
  return Number.isInteger(d) ? `$${d}` : `$${d.toFixed(2)}`;
}

export function ago(iso: string | null | undefined, now: number) {
  if (!iso) return "never";
  const m = Math.round((now - Date.parse(iso)) / 60000);
  if (m < 0) return `in ${hours(-m)}`;
  return `${hours(m)} ago`;
}
function hours(m: number) {
  if (m < 90) return `${m} min`;
  if (m < 48 * 60) return `${Math.round(m / 60)} h`;
  return `${Math.round(m / 1440)} days`;
}

const STATUS: Record<string, string> = { requested: "requested", confirmed: "confirmed", onHerWay: "on the way",
  arrived: "arrived", inProgress: "in progress", done: "done", paid: "paid", declined: "declined",
  cancelledByClient: "client cancelled", cancelledByPro: "pro cancelled", noShow: "no-show" };
const st = (s: string) => STATUS[s] ?? s;

const sql = (ref: string) => `select * from bookings where reference = '${ref}';`;
const sampleNote = (r: Row) => (r.sample ? " (sample pro, test money)" : "");

/** Minutes between runs for the cron shapes this project uses; null if it can't tell. */
export function cronEvery(schedule: string): number | null {
  const [min, hour, dom, mon, dow] = schedule.trim().split(/\s+/);
  if ([dom, mon, dow].some((f) => f !== "*")) return null;
  if (min === "*" && hour === "*") return 1;
  const step = /^\*\/(\d+)$/.exec(min);
  if (step && hour === "*") return Number(step[1]);
  if (/^\d+$/.test(min) && hour === "*") return 60;
  if (/^\d+$/.test(min) && /^\d+$/.test(hour)) return 1440;
  return null;
}

export function assess(s: Snapshot, stripe: Stripe, appStore: AppStore): Report {
  const now = Date.parse(s.now);
  const f: Finding[] = [];
  const blind: string[] = [];
  const list = (k: string): Row[] => (Array.isArray(s[k]) ? s[k] : []);

  // ---- Money the timers should have moved -------------------------------------------------
  for (const r of list("settle_errors")) {
    f.push({ key: `settle:${r.ref}`, level: r.sample ? "amber" : "red", area: "Money",
      title: `Stripe step failed on ${r.ref}${sampleNote(r)}`,
      detail: `${st(r.status)}, card ${r.hold}, since ${ago(r.since, now)}: ${r.error}`,
      fix: `Look it up in Stripe by ${r.ref}. Settle retries every 5 min; it clears itself once Stripe accepts. ${sql(r.ref)}` });
  }
  const late: [string, string, (r: Row) => string][] = [
    ["release_late", "Client's money still held", (r) => `${st(r.status)}, card ${r.hold}, since ${ago(r.since, now)}. Should have been let go within 5 min.`],
    ["capture_late", "Done but never charged", (r) => `done ${ago(r.done_at, now)}. Auto-charge is due at 12 h.`],
    ["charge_late", "Cancellation charge not taken", (r) => `${st(r.status)}, ${money(r.cents)}, since ${ago(r.since, now)}.`],
    ["hold_late", "Card hold not placed", (r) => `starts ${ago(r.starts, now)}. The hold goes on 6 days before.`],
  ];
  for (const [k, title, detail] of late) {
    for (const r of list(k)) {
      f.push({ key: `${k}:${r.ref}`, level: r.sample ? "amber" : "red", area: "Money",
        title: `${title}: ${r.ref}${sampleNote(r)}`, detail: detail(r),
        fix: `The settle timer should have done this. Check Timers below, then ${sql(r.ref)}` });
    }
  }
  for (const r of list("sweep_late")) {
    f.push({ key: `sweep_late:${r.ref}`, level: r.sample ? "amber" : "red", area: "Bookings",
      title: `Booking ${r.ref} stuck at ${st(r.status)}${sampleNote(r)}`,
      detail: r.status === "inProgress" ? `ended ${ago(r.ends, now)}; should be done at 12 h.` : `made ${ago(r.created, now)}; should have lapsed or declined by now.`,
      fix: "The sweep timer (every 10 min) should have moved it. Check Timers below." });
  }
  for (const r of list("card_failed")) {
    const soon = Date.parse(r.starts) - now < 24 * 3600e3;
    f.push({ key: `card_failed:${r.ref}`, level: soon && !r.sample ? "red" : "amber", area: "Money",
      title: `Card didn't go through: ${r.ref}${sampleNote(r)}`,
      detail: `${st(r.status)}, starts ${ago(r.starts, now)}. The client was told in the thread to add another card.`,
      fix: soon ? "Starts within a day: worth a message so the pro doesn't turn up unpaid." : undefined });
  }

  // ---- Bookings a person should look at ------------------------------------------------------
  for (const r of list("waiting_reply")) {
    if (r.sample || now - Date.parse(r.created) < 60 * 60e3) continue;
    f.push({ key: `waiting:${r.ref}`, level: "amber", area: "Bookings",
      title: `Request ${r.ref} unanswered for ${ago(r.created, now).replace(" ago", "")}`,
      detail: "It declines itself at 2 h and the pro loses reliability. A nudge to the pro might save it." });
  }
  for (const r of list("start_passed")) {
    if (r.sample) continue;
    f.push({ key: `start_passed:${r.ref}`, level: "amber", area: "Bookings",
      title: `${r.ref} started ${ago(r.starts, now)} and nobody has moved it`,
      detail: "Still confirmed: no On my way, no Done. Either the pro forgot to tap, or it didn't happen.",
      fix: "Message the pro in the thread. If it didn't happen, it's a no-show or a cancel." });
  }
  for (const r of list("capture_paused")) {
    f.push({ key: `paused:${r.ref}`, level: "amber", area: "Safety",
      title: `Client pressed "Something wrong?" on ${r.ref}${sampleNote(r)}`,
      detail: `The charge waits until ${new Date(r.until).toLocaleString("en-AU", { timeZone: "Australia/Melbourne" })}, then goes through.` });
  }

  // ---- Trust and safety ---------------------------------------------------------------------
  for (const r of list("reports_open")) {
    f.push({ key: `report:${r.id}`, level: "red", area: "Safety",
      title: `Report: ${String(r.reason).replace(/_/g, " ")}${r.ref ? ` on ${r.ref}` : ""}`,
      detail: `Sent ${ago(r.created, now)}, not handled.`, quote: r.detail || undefined,
      fix: `When it's dealt with: update reports set handled_at = now() where id = '${r.id}';` });
  }
  for (const r of list("low_reviews")) {
    if (r.sample) continue;
    f.push({ key: `review:${r.ref}`, level: "amber", area: "Safety",
      title: `${r.rating}-star review for ${r.pro} (${r.service ?? "booking"} ${r.ref ?? ""})`.trim(),
      detail: `Left ${ago(r.created, now)}.`, quote: r.text || undefined });
  }

  // ---- Pros ---------------------------------------------------------------------------------
  for (const r of list("id_waiting")) {
    const waited = now - Date.parse(r.submitted);
    const missing = [!r.abn && "no ABN", !r.insurance && "no insurance on file", !r.payouts && "payouts not set up"].filter(Boolean);
    f.push({ key: `id_waiting:${r.id}`, level: waited > 48 * 3600e3 ? "red" : "amber", area: "Pros",
      title: `${r.name} is waiting for their ID check (${ago(r.submitted, now).replace(" ago", "")})`,
      detail: `${(r.specialties ?? []).join(", ")}${r.suburb ? `, ${r.suburb}` : ""}.${missing.length ? ` Also: ${missing.join(", ")}.` : ""}`,
      fix: "ID photos: Storage > id-docs > their id. Then the verify line in docs/go-live.md §5." });
  }
  for (const r of list("payouts_stuck")) {
    f.push({ key: `payouts_stuck:${r.id}`, level: "amber", area: "Pros",
      title: `${r.name} started payout setup and hasn't finished`,
      detail: `Last change ${ago(r.since, now)}. They can't be booked until Stripe says payouts are on.` });
  }
  for (const r of list("payouts_failed")) {
    f.push({ key: `payout_failed:${r.pro}:${r.created}`, level: "red", area: "Money",
      title: `A payout to ${r.pro} failed (${money(r.cents)})`,
      detail: `${ago(r.created, now)}. Usually wrong bank details.`, fix: "Stripe > Connect > their account > Payouts." });
  }

  // ---- Timers -------------------------------------------------------------------------------
  for (const j of list("cron")) {
    if (!j.active) {
      f.push({ key: `cron_off:${j.name}`, level: "red", area: "Timers", title: `Timer ${j.name} is switched off` });
      continue;
    }
    if (j.failed_24h > 0) {
      f.push({ key: `cron_failed:${j.name}`, level: "red", area: "Timers",
        title: `Timer ${j.name} failed ${j.failed_24h} time${j.failed_24h === 1 ? "" : "s"} in 24 h`, detail: j.last_error ?? undefined });
    }
    const every = cronEvery(j.schedule);
    if (every && j.last_run && now - Date.parse(j.last_run) > (3 * every + 2) * 60e3) {
      f.push({ key: `cron_stale:${j.name}`, level: "red", area: "Timers",
        title: `Timer ${j.name} hasn't run for ${ago(j.last_run, now).replace(" ago", "")}`, detail: `It should run every ${hours(every)}.` });
    }
  }
  for (const h of list("http_failures")) {
    const what = h.timed_out ? "timed out" : h.code ? `answered ${h.code}` : "failed";
    f.push({ key: `http:${h.code ?? (h.timed_out ? "timeout" : "error")}`, level: "red", area: "Timers",
      title: `A function the timers call ${what} (${h.n} time${h.n === 1 ? "" : "s"}, last ${ago(h.last, now)})`,
      detail: [h.error, h.body].filter(Boolean).join(" · ") || undefined,
      fix: "Supabase > Edge Functions > settle, notify, cleanup or watchdog > Logs." });
  }

  // ---- Database -----------------------------------------------------------------------------
  const rls = list("rls_off");
  if (rls.length) {
    f.push({ key: `rls:${rls.join(",")}`, level: "red", area: "Database",
      title: `Row-level security is off on ${rls.join(", ")}`, detail: "Anyone with the app's public key can read or write those tables." });
  }

  // ---- Stripe -------------------------------------------------------------------------------
  const supply = s.supply ?? {};
  if (!stripe) blind.push("Stripe (no key in the function's secrets)");
  else if ("error" in stripe) {
    blind.push(`Stripe (${stripe.error})`);
    f.push({ key: "stripe_unreachable", level: "amber", area: "Watchdog", title: "Couldn't check Stripe", detail: stripe.error });
  } else {
    const ours = stripe.endpoints.filter((e) => e.url.includes(WEBHOOK_PATH));
    if (!ours.length) {
      f.push({ key: "webhook_missing", level: "red", area: "Stripe", title: "No Stripe webhook points at the app",
        detail: `Expected an endpoint ending ${WEBHOOK_PATH}.`, fix: "docs/go-live.md §1.2." });
    }
    for (const e of ours.filter((e) => e.status !== "enabled")) {
      f.push({ key: `webhook_off:${e.url}`, level: "red", area: "Stripe", title: `A Stripe webhook is ${e.status}`,
        detail: "Stripe switches an endpoint off after days of failed deliveries.", fix: "Stripe > Developers > Webhooks." });
    }
    if (stripe.failedDeliveries > 0) {
      f.push({ key: "webhook_failing", level: "red", area: "Stripe",
        title: `Stripe couldn't deliver ${stripe.failedDeliveries} event${stripe.failedDeliveries === 1 ? "" : "s"} in 24 h`,
        detail: "Bookings or payouts may be out of step with Stripe.", fix: "Stripe > Developers > Webhooks > the endpoint > failed events." });
    }
    for (const d of stripe.disputes) {
      f.push({ key: `dispute:${d.id}`, level: "red", area: "Money", title: `A client disputed a charge (${money(d.amount)})`,
        detail: `Stripe needs evidence${d.due_by ? ` by ${new Date(d.due_by * 1000).toLocaleDateString("en-AU", { timeZone: "Australia/Melbourne" })}` : ""}, or the money goes back.`,
        fix: "Stripe > Payments > Disputes." });
    }
    if (stripe.live && supply.sample_pros_live > 0) {
      f.push({ key: "samples_in_live", level: "red", area: "Pros",
        title: `Stripe is live and ${supply.sample_pros_live} sample pros are still showing`,
        detail: "Real clients can find them and can't pay them.", fix: "Remove them: docs/go-live.md §6b, body {\"action\":\"remove\"}." });
    }
  }

  // ---- App Store ----------------------------------------------------------------------------
  if (!appStore) blind.push("App Store Connect (no API key in the function's secrets)");
  else if ("error" in appStore) {
    blind.push(`App Store Connect (${appStore.error})`);
    f.push({ key: "asc_unreachable", level: "amber", area: "Watchdog", title: "Couldn't check App Store Connect", detail: appStore.error });
  } else {
    const v = appStore.version;
    if (v && /REJECTED/.test(v.state)) {
      f.push({ key: `asc_rejected:${v.version}`, level: "red", area: "App Store", title: `Apple rejected version ${v.version}`,
        detail: v.state.replace(/_/g, " ").toLowerCase(), fix: "App Store Connect > the version > App Review messages." });
    } else if (v && v.state === "PENDING_DEVELOPER_RELEASE") {
      f.push({ key: `asc_release:${v.version}`, level: "amber", area: "App Store",
        title: `Version ${v.version} is approved and waiting for you to release it` });
    }
    const b = appStore.build;
    if (b && ["INVALID", "FAILED"].includes(b.processing)) {
      f.push({ key: `build_bad:${b.version}`, level: "amber", area: "App Store", title: `Build ${b.version} failed processing` });
    } else if (b && (b.expired || (b.expires && Date.parse(b.expires) - now < 10 * 86400e3))) {
      f.push({ key: `build_expiring:${b.version}`, level: "amber", area: "App Store",
        title: b.expired ? `TestFlight build ${b.version} has expired` : `TestFlight build ${b.version} expires ${ago(b.expires, now)}`,
        detail: "Testers can't open an expired build.", fix: "tools/release.sh then tools/testflight-ship.py." });
    }
    for (const r of appStore.lowRatings) {
      f.push({ key: `asc_review:${r.title}:${r.rating}`, level: "amber", area: "App Store",
        title: `${r.rating}-star App Store review: ${r.title}`, quote: r.body || undefined });
    }
  }

  // ---- The watchdog itself ------------------------------------------------------------------
  const badEmail = list("last_runs").find((r) => r.email && !["sent", "skipped"].includes(r.email));
  if (badEmail) {
    f.push({ key: "watchdog_email", level: "amber", area: "Watchdog", title: "An earlier watchdog email didn't send",
      detail: `${badEmail.mode} ${ago(badEmail.ran_at, now)}: ${badEmail.email}` });
  }

  // ---- Numbers --------------------------------------------------------------------------------
  const day = s.day ?? {};
  const numbers = [
    `Pros: ${supply.bookable ?? 0} bookable of ${supply.real_pros ?? 0} real${supply.sample_pros_live ? `, plus ${supply.sample_pros_live} sample` : ""}`,
    `Last 24 h: ${day.new_people ?? 0} new people, ${day.new_pros ?? 0} new pros, ${day.bookings_made ?? 0} bookings made, ${day.paid ?? 0} paid`,
    `Paid this week: ${money(s.week_paid_cents ?? 0)} (real bookings, with tips)`,
    `Next 36 h: ${s.today?.starting_next_36h ?? 0} bookings; ${s.today?.live_now ?? 0} happening now`,
    `Timers: ${list("cron").filter((j) => j.active).length} running; ${s.http_ok_24h ?? 0} good answers from their functions in about the last 6 h`,
  ];
  if (stripe && !("error" in stripe)) {
    numbers.push(`Stripe (${stripe.live ? "live" : "test mode"}): ${money(stripe.balance.available)} available, ${money(stripe.balance.pending)} on the way`);
  }
  if (appStore && !("error" in appStore)) {
    const v = appStore.version, b = appStore.build;
    numbers.push(`App Store: ${v ? `${v.version} ${v.state.replace(/_/g, " ").toLowerCase()}` : "no version yet"}${b ? `; latest build ${b.version}` : ""}`);
  }
  if (s.flags && s.flags.phone_sign_in === false) numbers.push("Phone sign-in is off (waiting on Twilio's sender ID)");

  const order = { red: 0, amber: 1 };
  f.sort((a, b) => order[a.level] - order[b.level]);
  const level = f.some((x) => x.level === "red") ? "red" : f.length ? "amber" : "clear";
  return { level, findings: f, numbers, blind };
}
