// Push notifications through APNs. Called by the database (pg_net) with the cron secret:
//   { event: "status", booking_id, status }   a booking moved
//   { event: "message", message_id }          someone sent a message
//   { event: "moved", booking_id }            the client moved the booking to a new time
//   { event: "reminders" }                    every five minutes: unanswered requests, day-before, two hours before
// Copy follows docs/product-spec.md §12. Needs secrets APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8, APNS_TOPIC;
// without them it answers 503 and sends nothing.
import { admin, json } from "../_shared/stripe.ts";

const KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const KEY_P8 = Deno.env.get("APNS_KEY_P8") ?? "";
const TOPIC = Deno.env.get("APNS_TOPIC") ?? "com.keithchinyanda.hairdone";
const TZ = "Australia/Melbourne";

// ---------------------------------------------------------------------------------------------
// APNs
// ---------------------------------------------------------------------------------------------
let cachedJwt: { token: string; at: number } | null = null;

function b64url(bytes: Uint8Array | string): string {
  const s = typeof bytes === "string" ? btoa(bytes) : btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.at < 50 * 60) return cachedJwt.token;
  const pem = KEY_P8.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const head = b64url(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: TEAM_ID, iat: now }));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${head}.${claims}`)));
  const token = `${head}.${claims}.${b64url(sig)}`;
  cachedJwt = { token, at: now };
  return token;
}

type Push = { to: string; side: "client" | "pro"; title?: string; body: string; kind: "booking" | "message"; bookingId: string; threadId?: string };

async function sendTo(p: Push): Promise<number> {
  const { data: devices } = await admin.from("devices").select("apns_token, environment").eq("profile_id", p.to).eq("active", true);
  if (!devices?.length) return 0;
  const jwt = await apnsJwt();
  let sent = 0;
  for (const d of devices as { apns_token: string; environment: string }[]) {
    const host = d.environment === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
    const payload = {
      aps: { alert: p.title ? { title: p.title, body: p.body } : { body: p.body }, sound: "default",
             "thread-id": p.threadId ?? p.bookingId },
      kind: p.kind, side: p.side, booking_id: p.bookingId, ...(p.threadId ? { thread_id: p.threadId } : {}),
    };
    const res = await fetch(`https://${host}/3/device/${d.apns_token}`, {
      method: "POST",
      headers: { authorization: `bearer ${jwt}`, "apns-topic": TOPIC, "apns-push-type": "alert",
                 "apns-priority": "10", "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (res.ok) { sent++; continue; }
    const reason = (await res.json().catch(() => ({}))).reason ?? res.status;
    console.log("apns", res.status, reason, d.environment);
    if (res.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered" || reason === "DeviceTokenNotForTopic") {
      await admin.from("devices").update({ active: false, updated_at: new Date().toISOString() }).eq("apns_token", d.apns_token);
    }
  }
  return sent;
}

/** Sends once per key: a doubled trigger or a retried reminder can't send twice. */
async function once(key: string, p: Push): Promise<number> {
  const { data: fresh } = await admin.rpc("claim_push", { p_key: key });
  if (!fresh) return 0;
  return sendTo(p);
}

// ---------------------------------------------------------------------------------------------
// Words
// ---------------------------------------------------------------------------------------------
const money = (cents: number) => {
  const d = Math.max(0, cents) / 100;
  return Number.isInteger(d) ? `$${d}` : `$${d.toFixed(2)}`;
};

function parts(iso: string) {
  const f = new Intl.DateTimeFormat("en-AU", { timeZone: TZ, weekday: "long", year: "numeric", month: "2-digit",
    day: "2-digit", hour: "numeric", minute: "2-digit", hour12: true });
  const o: Record<string, string> = {};
  for (const p of f.formatToParts(new Date(iso))) o[p.type] = p.value;
  return o;
}
const localDate = (iso: string) => { const p = parts(iso); return `${p.year}-${p.month}-${p.day}`; };
const clock = (iso: string) => { const p = parts(iso); return `${p.hour}:${p.minute} ${(p.dayPeriod ?? "").toLowerCase()}`.trim(); };
function dayWord(iso: string) {
  const today = localDate(new Date().toISOString());
  const tomorrow = localDate(new Date(Date.now() + 864e5).toISOString());
  const d = localDate(iso);
  return d === today ? "today" : d === tomorrow ? "tomorrow" : parts(iso).weekday;
}
/** "Saturday at 2:00 pm", "today at 2:00 pm" */
const when = (iso: string) => `${dayWord(iso)} at ${clock(iso)}`;
/** "Sat 2:00 pm" */
const shortWhen = (iso: string) => `${dayWord(iso) === "today" ? "today" : dayWord(iso) === "tomorrow" ? "tomorrow" : parts(iso).weekday.slice(0, 3)} ${clock(iso)}`;
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

/** Clients get no pushes from 10 pm to 7 am, except the ones about a booking happening today. */
function quietForClient(urgentToday: boolean) {
  const h = Number(new Intl.DateTimeFormat("en-AU", { timeZone: TZ, hour: "numeric", hour12: false }).format(new Date()));
  return (h >= 22 || h < 7) && !urgentToday;
}

// ---------------------------------------------------------------------------------------------
// Bookings
// ---------------------------------------------------------------------------------------------
type B = {
  id: string; pro_id: string | null; client_id: string | null; status: string; starts_at: string;
  address_suburb: string; services_cents: number; travel_fee_cents: number; booking_fee_cents: number;
  discount_cents: number; tip_cents: number; platform_fee_cents: number; cancellation_charge_cents: number;
  decline_reason: string | null;
};

async function load(bookingId: string) {
  const { data: b } = await admin.from("bookings").select("*").eq("id", bookingId).maybeSingle<B>();
  if (!b || !b.pro_id || !b.client_id) return null;
  const { data: people } = await admin.from("profiles").select("id, first_name").in("id", [b.pro_id, b.client_id]);
  const name = (id: string) => (people ?? []).find((p) => p.id === id)?.first_name || "Someone";
  const { data: svcs } = await admin.from("booking_services").select("name").eq("booking_id", b.id).order("sort_order");
  const first = svcs?.[0]?.name ?? "a booking";
  const service = (svcs?.length ?? 0) > 1 ? `${first} and more` : first;
  const total = b.services_cents + b.travel_fee_cents + b.booking_fee_cents - b.discount_cents;
  const proGets = b.services_cents + b.travel_fee_cents - b.platform_fee_cents;
  return { b, pro: name(b.pro_id), client: name(b.client_id), service: service.toLowerCase(), total, proGets };
}

async function onStatus(bookingId: string, status: string) {
  const x = await load(bookingId);
  if (!x) return 0;
  const { b, pro, client, service, total, proGets } = x;
  const today = dayWord(b.starts_at) === "today";
  const toClient = (body: string, urgent = false) =>
    quietForClient(urgent && today) ? Promise.resolve(0)
      : once(`status:${b.id}:${status}:client`, { to: b.client_id!, side: "client", body, kind: "booking", bookingId: b.id });
  const toPro = (body: string, suffix = "") =>
    once(`status:${b.id}:${status}${suffix}:pro`, { to: b.pro_id!, side: "pro", body, kind: "booking", bookingId: b.id });

  switch (status) {
    case "requested":
      return (await toPro(`New request: ${client}, ${service}, ${shortWhen(b.starts_at)}, ${b.address_suburb}. ${money(proGets)} to you.`))
        + (await toClient(`Sent. ${pro} usually replies within an hour.`));
    case "confirmed": {
      // Accepted by the pro if she was sent the request; otherwise it was instant book.
      const { data: wasRequest } = await admin.rpc("push_sent", { p_key: `status:${b.id}:requested:pro` });
      return wasRequest
        ? toClient(`You're booked. ${pro}'s coming ${when(b.starts_at)}.`)
        : toPro(`Booked: ${client}, ${service}, ${shortWhen(b.starts_at)}, ${b.address_suburb}.`);
    }
    case "declined":
      if (b.decline_reason === "Payment not finished") return 0;
      if (b.decline_reason === "No reply in time") {
        return (await toClient(`${pro} didn't answer in time. Not your fault. Here's who else is free.`))
          + (await toPro(`You missed ${client}'s request. It's gone to someone else.`));
      }
      return toClient(`${pro} can't do ${dayWord(b.starts_at)}. Here's who else is free.`);
    case "onHerWay":
      return toClient(`${pro}'s on her way.`, true);
    case "arrived":
      return toClient(`${pro}'s at your door.`, true);
    case "done":
      return toClient(`Done. Pay ${money(total)} to ${pro} and tip if you like.`);
    case "paid": {
      let n = await toClient(`Paid. ${money(total + b.tip_cents)} to ${pro}. Your receipt's on the booking.`);
      n += await toPro(`Paid. ${money(proGets + b.tip_cents)} from ${client}.`);
      if (b.tip_cents > 0) n += await toPro(`${client} tipped ${money(b.tip_cents)}. Lovely.`, ":tip");
      return n;
    }
    case "cancelledByClient": {
      const c = b.cancellation_charge_cents;
      const full = b.services_cents + b.travel_fee_cents + b.booking_fee_cents;
      const toHer = c <= 0 ? 0 : c >= full ? proGets : c - Math.round(c * 0.12);
      return toPro(`${client} cancelled ${dayWord(b.starts_at)}. ${toHer > 0 ? `You'll get ${money(toHer)}.` : "No charge."}`);
    }
    case "cancelledByPro":
      return toClient(`${pro} cancelled ${dayWord(b.starts_at)}. You won't be charged. Here's who else is free.`, true);
    case "noShow":
      return toClient(`${pro} waited 15 minutes. You've been charged ${money(b.cancellation_charge_cents)}.`);
    default:
      return 0;
  }
}

/** The client moved the booking (24 hours' notice or more): the pro is told, nothing to accept. */
async function onMoved(bookingId: string) {
  const x = await load(bookingId);
  if (!x) return 0;
  const { b, client, service } = x;
  return once(`moved:${b.id}:${b.starts_at}`, { to: b.pro_id!, side: "pro", kind: "booking", bookingId: b.id,
    body: `${client} moved ${service} to ${when(b.starts_at)}. Nothing to do.` });
}

// ---------------------------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------------------------
async function onMessage(messageId: string) {
  const { data: m } = await admin.from("messages").select("id, thread_id, sender_id, text").eq("id", messageId).maybeSingle();
  if (!m?.sender_id) return 0;
  const { data: t } = await admin.from("threads").select("id, booking_id, pro_id, client_id").eq("id", m.thread_id).maybeSingle();
  if (!t) return 0;
  const to = m.sender_id === t.pro_id ? t.client_id : t.pro_id;
  if (!to) return 0;
  const { data: sender } = await admin.from("profiles").select("first_name").eq("id", m.sender_id).maybeSingle();
  const text = String(m.text);
  const body = text.length > 180 ? text.slice(0, 177) + "..." : text;
  return once(`message:${m.id}`, { to, side: to === t.pro_id ? "pro" : "client", title: sender?.first_name || "Hair Done", body, kind: "message",
                                   bookingId: t.booking_id, threadId: t.id });
}

// ---------------------------------------------------------------------------------------------
// Reminders
// ---------------------------------------------------------------------------------------------
async function reminders() {
  let n = 0;
  const now = Date.now();
  const iso = (ms: number) => new Date(ms).toISOString();

  // Requests still waiting at 60 and 105 minutes (they lapse at 120).
  const { data: waiting } = await admin.from("bookings").select("id, created_at")
    .eq("status", "requested").neq("hold_state", "none").gte("created_at", iso(now - 120 * 60e3)).lte("created_at", iso(now - 60 * 60e3));
  for (const w of waiting ?? []) {
    const x = await load(w.id);
    if (!x) continue;
    const age = (now - new Date(w.created_at).getTime()) / 60e3;
    if (age >= 105) {
      n += await once(`remind:${w.id}:105`, { to: x.b.pro_id!, side: "pro", body: `15 minutes left on ${x.client}'s request.`, kind: "booking", bookingId: w.id });
    } else {
      n += await once(`remind:${w.id}:60`, { to: x.b.pro_id!, side: "pro", body: `${x.client}'s still waiting. 1 hour left.`, kind: "booking", bookingId: w.id });
    }
  }

  // The day before (23 to 24 hours out) and, for clients, two hours before.
  const { data: soon } = await admin.from("bookings").select("id, starts_at")
    .eq("status", "confirmed").gte("starts_at", iso(now + 105 * 60e3)).lte("starts_at", iso(now + 24 * 3600e3));
  for (const s of soon ?? []) {
    const hours = (new Date(s.starts_at).getTime() - now) / 3600e3;
    const x = await load(s.id);
    if (!x) continue;
    if (hours >= 23) {
      if (!quietForClient(false)) {
        n += await once(`remind:${s.id}:24h:client`, { to: x.b.client_id!, side: "client", body: `${x.pro}'s coming tomorrow at ${clock(s.starts_at)}.`, kind: "booking", bookingId: s.id });
      }
      n += await once(`remind:${s.id}:24h:pro`, { to: x.b.pro_id!, side: "pro", body: `Tomorrow: ${x.client}, ${x.service}, ${clock(s.starts_at)} in ${x.b.address_suburb}.`, kind: "booking", bookingId: s.id });
    } else if (hours <= 2.1 && !quietForClient(true)) {
      n += await once(`remind:${s.id}:2h`, { to: x.b.client_id!, side: "client", body: `${x.pro}'s coming at ${clock(s.starts_at)}. Two hours to go.`, kind: "booking", bookingId: s.id });
    }
  }
  return n;
}

// ---------------------------------------------------------------------------------------------
Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  if (!KEY_ID || !TEAM_ID || !KEY_P8) return json({ error: "apns_not_configured" }, 503);
  try {
    const body = await req.json().catch(() => ({}));
    let sent = 0;
    if (body.event === "status" && body.booking_id) sent = await onStatus(body.booking_id, body.status);
    else if (body.event === "message" && body.message_id) sent = await onMessage(body.message_id);
    else if (body.event === "moved" && body.booking_id) sent = await onMoved(body.booking_id);
    else if (body.event === "reminders") sent = await reminders();
    return json({ sent });
  } catch (e) {
    console.error("notify failed:", (e as Error).message);
    return json({ error: (e as Error).message }, 500);
  }
});
