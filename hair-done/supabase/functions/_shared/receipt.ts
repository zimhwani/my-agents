// The client's receipt for a paid booking: built from the booking as it was frozen, and the card
// from Stripe. Hair Done isn't registered for GST, so it's a receipt, never a tax invoice, and
// it splits the lines by who's charging: the pro (her name and ABN) and Hair Done (the booking fee).
// Email goes through Resend (secrets RESEND_API_KEY and RECEIPT_FROM, an address on a domain
// verified in Resend); without them nothing is sent and callers get `not_configured`.
import { admin, stripe } from "./stripe.ts";

export const HAIR_DONE = {
  name: "Hair Done",
  abn: "45 281 131 814",
  operator: "hd.nd labs",
  place: "Melbourne VIC",
  email: "hello@hairdonenailsdone.app",
  terms: "hairdonenailsdone.app/terms",
};
const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = Deno.env.get("RECEIPT_FROM") ?? "";
const TZ = "Australia/Melbourne";

export type Line = { name: string; note: string; cents: number };
export type Receipt = {
  booking_id: string; client_id: string; reference: string; client_first: string;
  pro_name: string; pro_first: string; pro_abn: string | null;
  starts_at: string; address: string; title: string;
  pro_lines: Line[]; hair_done_lines: Line[]; total_cents: number;
  card: string | null; paid_at: string | null;
};

const money = (c: number) => `${c < 0 ? "−" : ""}$${(Math.abs(c) / 100).toFixed(2)}`;
const minutes = (m: number) => m % 60 === 0 ? `${m / 60} hr` : m > 60 ? `${Math.floor(m / 60)} hr ${m % 60} min` : `${m} min`;
const when = (iso: string) =>
  new Intl.DateTimeFormat("en-AU", { timeZone: TZ, weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" })
    .format(new Date(iso)).replace(/ (am|pm)/, " $1").replace(",", "");
const stamp = (iso: string) =>
  new Intl.DateTimeFormat("en-AU", { timeZone: TZ, day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" })
    .format(new Date(iso));
const abnText = (abn: string | null) => {
  const d = (abn ?? "").replace(/\D/g, "");
  return d.length === 11 ? `${d.slice(0, 2)} ${d.slice(2, 5)} ${d.slice(5, 8)} ${d.slice(8)}` : null;
};
const brandName = (b: string) =>
  ({ visa: "Visa", mastercard: "Mastercard", amex: "Amex", discover: "Discover", jcb: "JCB", diners: "Diners", unionpay: "UnionPay", eftpos_au: "eftpos" } as Record<string, string>)[b] ?? b;

/** The receipt, or null if there's no paid booking by that id. */
export async function buildReceipt(bookingId: string): Promise<Receipt | null> {
  const { data: b } = await admin.from("bookings").select("*").eq("id", bookingId).maybeSingle();
  if (!b || b.status !== "paid") return null;
  const [{ data: services }, { data: pro }, { data: proProfile }, { data: client }, { data: paid }] = await Promise.all([
    admin.from("booking_services").select("name, minutes, price_cents").eq("booking_id", b.id).order("sort_order"),
    admin.from("pros").select("last_initial, abn").eq("id", b.pro_id).maybeSingle(),
    admin.from("profiles").select("first_name").eq("id", b.pro_id).maybeSingle(),
    admin.from("profiles").select("first_name").eq("id", b.client_id).maybeSingle(),
    admin.from("booking_events").select("at").eq("booking_id", b.id).eq("status", "paid").order("at", { ascending: false }).limit(1).maybeSingle(),
  ]);
  const proFirst = proProfile?.first_name ?? "Your pro";
  const proName = pro?.last_initial ? `${proFirst} ${pro.last_initial}.` : proFirst;
  const svc = (services ?? []) as { name: string; minutes: number; price_cents: number }[];

  const proLines: Line[] = svc.map((s) => ({ name: s.name, note: minutes(s.minutes), cents: s.price_cents }));
  if (b.travel_fee_cents > 0) proLines.push({ name: "Travel fee", note: "", cents: b.travel_fee_cents });
  if (b.tip_cents > 0) proLines.push({ name: "Tip", note: `100% to ${proFirst}`, cents: b.tip_cents });
  const hdLines: Line[] = [{ name: "Booking fee", note: "", cents: b.booking_fee_cents }];
  if (b.discount_cents > 0) hdLines.push({ name: "Discount", note: "", cents: -b.discount_cents });

  return {
    booking_id: b.id, client_id: b.client_id, reference: b.reference, client_first: client?.first_name ?? "",
    pro_name: proName, pro_first: proFirst, pro_abn: abnText(pro?.abn ?? null),
    starts_at: b.starts_at, address: `${b.address_line1}, ${b.address_suburb} ${b.address_state} ${b.address_postcode}`,
    title: svc.length === 1 ? `${svc[0].name} with ${proName}` : `${proName}, ${svc.length} services`,
    pro_lines: proLines, hair_done_lines: hdLines,
    total_cents: [...proLines, ...hdLines].reduce((t, l) => t + l.cents, 0),
    card: await cardFor(b.stripe_payment_intent_id),
    paid_at: paid?.at ?? b.captured_at ?? null,
  };
}

/** "Visa •••• 4242", or "Apple Pay (Visa •••• 4242)", from the charge itself. */
async function cardFor(intentId: string | null): Promise<string | null> {
  if (!intentId) return null;
  try {
    const pi = await stripe.paymentIntents.retrieve(intentId, { expand: ["latest_charge"] });
    const card = (pi.latest_charge as { payment_method_details?: { card?: { brand: string; last4: string; wallet?: { type: string } | null } } } | null)
      ?.payment_method_details?.card;
    if (!card) return null;
    const plain = `${brandName(card.brand)} •••• ${card.last4}`;
    return card.wallet?.type === "apple_pay" ? `Apple Pay (${plain})` : plain;
  } catch {
    return null;
  }
}

export function receiptText(r: Receipt): string {
  const row = (l: Line) => `${l.name}${l.note ? ` (${l.note})` : ""}  ${money(l.cents)}`;
  const out = [
    `Hair Done receipt ${r.reference}`, r.title, when(r.starts_at), r.address, "",
    `From ${r.pro_name}${r.pro_abn ? ` · ABN ${r.pro_abn}` : ""}`, ...r.pro_lines.map(row), "",
    `From Hair Done · ABN ${HAIR_DONE.abn}`, ...r.hair_done_lines.map(row), "",
    `Total paid  ${money(r.total_cents)}`,
  ];
  const paid = [r.card, r.paid_at ? stamp(r.paid_at) : null].filter(Boolean).join(" · ");
  if (paid) out.push(paid);
  out.push("", footerText(r.pro_first));
  return out.join("\n");
}

const footerText = (proFirst: string) =>
  `No GST included. ${proFirst} provides the service; Hair Done arranges the booking and payment.\n` +
  `Hair Done is run by ${HAIR_DONE.operator} · ${HAIR_DONE.place} · ${HAIR_DONE.email} · ${HAIR_DONE.terms}`;

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

export function receiptHTML(r: Receipt): string {
  const ink = "#241A16", soft = "#6F625B", line = "#E2D8CC", paper = "#F8F3EC", lacquer = "#C8323A";
  const serif = "Georgia,'Times New Roman',serif";
  const sans = "-apple-system,BlinkMacSystemFont,'Helvetica Neue',Arial,sans-serif";
  const row = (l: Line) => `<tr><td style="padding:10px 0;border-bottom:1px solid ${line};font:16px ${sans};color:${ink}">${esc(l.name)}` +
    (l.note ? `<div style="font:13px ${sans};color:${soft};margin-top:2px">${esc(l.note)}</div>` : "") +
    `</td><td align="right" style="padding:10px 0;border-bottom:1px solid ${line};font:16px ${sans};color:${ink};vertical-align:top;white-space:nowrap">${money(l.cents)}</td></tr>`;
  const head = (who: string, abn: string | null) =>
    `<tr><td style="padding:22px 0 2px;font:600 15px ${sans};color:${ink}">From ${esc(who)}</td>` +
    `<td align="right" style="padding:22px 0 2px;font:12px ${sans};color:${soft}">${abn ? `ABN ${abn}` : ""}</td></tr>`;
  const paid = [r.card, r.paid_at ? stamp(r.paid_at) : null].filter(Boolean).map((s) => esc(s!)).join(" · ");
  return `<!doctype html><html lang="en-AU"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Hair Done receipt ${esc(r.reference)}</title></head>
<body style="margin:0;background:#fff"><div style="max-width:480px;margin:0 auto;padding:16px">
<div style="background:${paper};border-radius:6px;padding:26px 22px 22px">
<div style="font:italic 26px ${serif};color:${ink}">hd<span style="color:${lacquer}">.</span></div>
<p style="font:15px ${sans};color:${ink};margin:14px 0 18px">${r.client_first ? `Thanks, ${esc(r.client_first)}. ` : ""}Here's your receipt.</p>
<div style="font:500 12px ${sans};letter-spacing:.08em;text-transform:uppercase;color:${soft}">Receipt · ${esc(r.reference)}</div>
<div style="font:28px/1.2 ${serif};color:${ink};margin-top:8px">${esc(r.title)}</div>
<div style="font:15px/1.45 ${sans};color:${soft};margin-top:6px">${esc(when(r.starts_at))}<br>${esc(r.address)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse">
${head(r.pro_name, r.pro_abn)}${r.pro_lines.map(row).join("")}
${head("Hair Done", HAIR_DONE.abn)}${r.hair_done_lines.map(row).join("")}
<tr><td style="padding:18px 0 0;font:600 17px ${sans};color:${ink}">Total paid</td>
<td align="right" style="padding:18px 0 0;font:300 28px ${sans};color:${ink}">${money(r.total_cents)}<span style="color:${lacquer}">.</span></td></tr>
</table>
${paid ? `<div style="font:14px ${sans};color:${soft};margin-top:4px">${paid}</div>` : ""}
<div style="font:12px/1.5 ${sans};color:${soft};margin-top:18px">${esc(footerText(r.pro_first)).replace("\n", "<br>")
    .replace(HAIR_DONE.terms, `<a href="https://${HAIR_DONE.terms}" style="color:${soft}">${HAIR_DONE.terms}</a>`)}</div>
</div></div></body></html>`;
}

/** Where the client's receipts go: the email she gave us, else her sign-in email. */
async function emailFor(clientId: string): Promise<string | null> {
  const { data: c } = await admin.from("profile_contacts").select("email").eq("profile_id", clientId).maybeSingle();
  if (c?.email) return c.email;
  const { data } = await admin.auth.admin.getUserById(clientId);
  return data.user?.email ?? null;
}

export const emailReady = () => !!(RESEND_KEY && FROM);

/** Emails the receipt. Throws `not_configured`, `no_email` or Resend's error. */
export async function sendReceipt(r: Receipt): Promise<string> {
  if (!emailReady()) throw new Error("not_configured");
  const to = await emailFor(r.client_id);
  if (!to) throw new Error("no_email");
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json", "Idempotency-Key": `receipt-${r.booking_id}-${Math.floor(Date.now() / 60000)}` },
    body: JSON.stringify({
      from: `Hair Done <${FROM}>`, to: [to], reply_to: HAIR_DONE.email,
      subject: `Your Hair Done receipt, ${r.reference}`, html: receiptHTML(r), text: receiptText(r),
    }),
  });
  if (!res.ok) throw new Error(`resend ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return to;
}

/** After a booking's paid: email the receipt if we can. Never throws; payment comes first. */
export async function receiptAfterPaid(bookingId: string) {
  if (!emailReady()) return;
  try {
    const r = await buildReceipt(bookingId);
    if (r) await sendReceipt(r);
  } catch (e) {
    console.error("receipt email", bookingId, (e as Error).message);
  }
}
