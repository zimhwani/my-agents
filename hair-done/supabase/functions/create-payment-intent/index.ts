// POST { booking_id }                     → what PaymentSheet needs to take the card for a new booking.
// POST { booking_id, action: "confirm" }  → after PaymentSheet says done: check with Stripe and mark the
//                                           booking held (or card saved), so the pro sees the request now
//                                           rather than when the webhook lands. The webhook does the same.
//
// Within 6 days of the start: a PaymentIntent with manual capture (the hold), card saved for later.
// Further out: a SetupIntent (card saved, no hold); the settle function places the hold 6 days before.
import {
  stripe, stripeKey, admin, userClient, json, notConfigured, applicationFee, bookingTotal,
  customerFor, rememberCard, HOLD_LEAD_MS, type Booking,
} from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!stripeKey) return notConfigured();
  const { data: { user } } = await userClient(req).auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { booking_id, action } = await req.json();
  const { data: b } = await admin.from("bookings").select("*").eq("id", booking_id).maybeSingle<Booking>();
  if (!b || b.client_id !== user.id) return json({ error: "not_found" }, 404);

  if (action === "confirm") return confirm(b, user.id);

  if (b.status !== "requested" || b.hold_state !== "none") return json({ error: "already_paid" }, 409);
  const { data: pro } = await admin.from("pros").select("stripe_account_id, payouts_connected").eq("id", b.pro_id).single();
  if (!pro?.stripe_account_id || !pro.payouts_connected) return json({ error: "pro_payouts_not_set_up" }, 409);

  const customer = await customerFor(user.id);
  const ephemeralKey = await stripe.ephemeralKeys.create({ customer }, { apiVersion: "2024-06-20" });
  const metadata = { booking_id: b.id, reference: b.reference, pro_id: b.pro_id ?? "", client_id: user.id, kind: "booking" };

  if (new Date(b.starts_at).getTime() - Date.now() > HOLD_LEAD_MS) {
    const si = await stripe.setupIntents.create({
      customer, usage: "off_session", automatic_payment_methods: { enabled: true }, metadata,
    }, { idempotencyKey: `setup-${b.id}` });
    await admin.from("bookings").update({ stripe_setup_intent_id: si.id }).eq("id", b.id);
    return json({ mode: "setup", client_secret: si.client_secret, customer_id: customer, ephemeral_key: ephemeralKey.secret,
                  amount_cents: bookingTotal(b) });
  }

  const amount = bookingTotal(b);
  const pi = await stripe.paymentIntents.create({
    amount, currency: "aud", customer,
    capture_method: "manual",
    setup_future_usage: "off_session",          // so a tip, or a charge after a late cancel, needs no second tap
    automatic_payment_methods: { enabled: true },
    application_fee_amount: applicationFee(b, amount),
    transfer_data: { destination: pro.stripe_account_id },
    description: `Hair Done ${b.reference}`,
    statement_descriptor_suffix: "HAIR DONE",
    metadata,
  }, { idempotencyKey: `hold-${b.id}` });
  await admin.from("bookings").update({ stripe_payment_intent_id: pi.id }).eq("id", b.id);
  return json({ mode: "payment", client_secret: pi.client_secret, customer_id: customer, ephemeral_key: ephemeralKey.secret,
                amount_cents: amount });
});

async function confirm(b: Booking, profileId: string) {
  if (b.stripe_payment_intent_id) {
    const pi = await stripe.paymentIntents.retrieve(b.stripe_payment_intent_id);
    if (pi.status !== "requires_capture") return json({ held: false, stripe_status: pi.status });
    const pm = typeof pi.payment_method === "string" ? pi.payment_method : pi.payment_method?.id ?? null;
    if (pm && typeof pi.customer === "string") await rememberCard(profileId, pi.customer, pm);
    const { data } = await admin.rpc("booking_hold_placed", { b_id: b.id, state: "held", pm });
    return json({ held: true, booking: data });
  }
  if (b.stripe_setup_intent_id) {
    const si = await stripe.setupIntents.retrieve(b.stripe_setup_intent_id);
    if (si.status !== "succeeded") return json({ held: false, stripe_status: si.status });
    const pm = typeof si.payment_method === "string" ? si.payment_method : si.payment_method?.id ?? null;
    if (pm && typeof si.customer === "string") await rememberCard(profileId, si.customer, pm);
    const { data } = await admin.rpc("booking_hold_placed", { b_id: b.id, state: "saved", pm });
    return json({ held: true, booking: data });
  }
  return json({ held: false, stripe_status: "no_intent" });
}
