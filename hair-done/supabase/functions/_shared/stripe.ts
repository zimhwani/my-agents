// Shared Stripe + Supabase clients for edge functions (Deno).
import Stripe from "npm:stripe@16";
import { createClient } from "npm:@supabase/supabase-js@2";

// Until STRIPE_SECRET_KEY is set in the project's secrets, functions answer 503 rather than crash.
export const stripeKey = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
export const stripe = new Stripe(stripeKey || "sk_test_not_set", {
  apiVersion: "2024-06-20",
  httpClient: Stripe.createFetchHttpClient(),
});
export const cryptoProvider = Stripe.createSubtleCryptoProvider();

export const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

export function userClient(req: Request) {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false },
  });
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export const notConfigured = () => json({ error: "stripe_not_configured" }, 503);

export const PLATFORM_RATE = 0.12;
export const BOOKING_FEE_CENTS = 300;
/** Stripe card holds lapse at 7 days, so a booking further out saves the card and holds 6 days before. */
export const HOLD_LEAD_MS = 6 * 24 * 60 * 60 * 1000;

export type Booking = {
  id: string; reference: string; pro_id: string | null; client_id: string | null; status: string;
  starts_at: string; services_cents: number; travel_fee_cents: number; booking_fee_cents: number;
  discount_cents: number; tip_cents: number; cancellation_charge_cents: number;
  stripe_payment_intent_id: string | null; stripe_setup_intent_id: string | null;
  stripe_payment_method: string | null; hold_state: string; capture_paused_until: string | null;
  done_at: string | null;
};

/** What the client pays for the booking itself: services + travel + $3 − discount. */
export const bookingTotal = (b: Booking) =>
  b.services_cents + b.travel_fee_cents + b.booking_fee_cents - b.discount_cents;

/** Our cut of a charge. Full charges take 12% of services + travel plus the $3; a late-cancel
 *  charge (50% of the pro's price, no booking fee) takes 12% of what was charged. */
export function applicationFee(b: Booking, charged: number) {
  const full = b.services_cents + b.travel_fee_cents + b.booking_fee_cents;
  if (charged >= full - b.discount_cents) {
    return Math.round((b.services_cents + b.travel_fee_cents) * PLATFORM_RATE) + b.booking_fee_cents - b.discount_cents;
  }
  return Math.round(charged * PLATFORM_RATE);
}

export async function customerFor(profileId: string): Promise<string> {
  const { data: contact } = await admin.from("profile_contacts")
    .select("stripe_customer_id, email, phone").eq("profile_id", profileId).maybeSingle();
  if (contact?.stripe_customer_id) return contact.stripe_customer_id;
  const { data: profile } = await admin.from("profiles").select("first_name, last_name").eq("id", profileId).single();
  const c = await stripe.customers.create({
    name: [profile?.first_name, profile?.last_name].filter(Boolean).join(" ") || undefined,
    email: contact?.email ?? undefined,
    phone: contact?.phone ?? undefined,
    metadata: { profile_id: profileId },
  }, { idempotencyKey: `customer-${profileId}` });
  await admin.from("profile_contacts").upsert({ profile_id: profileId, stripe_customer_id: c.id });
  return c.id;
}

/** Keep a copy of the card's display details, so the app can list saved cards without Stripe. */
export async function rememberCard(profileId: string, customerId: string, pmId: string) {
  const pm = await stripe.paymentMethods.retrieve(pmId);
  const card = pm.card;
  const brand = card?.wallet?.type === "apple_pay" ? "Apple Pay" : (card?.brand ?? pm.type);
  await admin.from("payment_methods").upsert({
    profile_id: profileId, stripe_customer_id: customerId, stripe_pm_id: pmId, brand,
    last4: card?.last4 ?? "", expiry: card ? `${String(card.exp_month).padStart(2, "0")}/${String(card.exp_year).slice(-2)}` : "",
  }, { onConflict: "profile_id,stripe_pm_id" });
}

export async function systemLine(bookingId: string, text: string) {
  const { data: t } = await admin.from("threads").select("id").eq("booking_id", bookingId).maybeSingle();
  if (t) await admin.from("messages").insert({ thread_id: t.id, sender_id: null, text });
}
