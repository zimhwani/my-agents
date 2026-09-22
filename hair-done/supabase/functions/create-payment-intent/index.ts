// POST { booking_id, payment_method_id? }
// Places a hold (manual capture) for the client's total. Captured by the webhook / sweep when the pro marks done.
// Returns { client_secret, payment_intent_id, customer_id, ephemeral_key } for PaymentSheet.
import { stripe, admin, userClient, json, PLATFORM_RATE } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const supa = userClient(req);
  const { data: { user } } = await supa.auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { booking_id } = await req.json();
  const { data: b, error } = await supa.from("bookings").select("*, pros(stripe_account_id)").eq("id", booking_id).single();
  if (error || !b || b.client_id !== user.id) return json({ error: "not_found" }, 404);
  if (b.stripe_payment_intent_id) return json({ error: "already_held" }, 409);

  // One Stripe customer per profile.
  const { data: profile } = await admin.from("profiles").select("id, first_name, profile_contacts(email, phone)").eq("id", user.id).single();
  const { data: existing } = await admin.from("payment_methods").select("stripe_customer_id").eq("profile_id", user.id).limit(1).maybeSingle();
  let customerId = existing?.stripe_customer_id;
  if (!customerId) {
    const contact = (profile as unknown as { profile_contacts?: { email?: string; phone?: string } | null })?.profile_contacts;
    const c = await stripe.customers.create({ name: profile?.first_name, email: contact?.email ?? undefined, phone: contact?.phone ?? undefined, metadata: { profile_id: user.id } });
    customerId = c.id;
  }

  const amount = b.services_cents + b.travel_fee_cents + b.booking_fee_cents - b.discount_cents;
  const applicationFee = Math.round((b.services_cents + b.travel_fee_cents) * PLATFORM_RATE) + b.booking_fee_cents;

  const intent = await stripe.paymentIntents.create({
    amount,
    currency: "aud",
    customer: customerId,
    capture_method: "manual",
    automatic_payment_methods: { enabled: true },
    application_fee_amount: applicationFee,
    transfer_data: b.pros?.stripe_account_id ? { destination: b.pros.stripe_account_id } : undefined,
    description: `Hair Done ${b.reference}`,
    metadata: { booking_id: b.id, reference: b.reference, pro_id: b.pro_id, client_id: b.client_id },
  });

  await admin.from("bookings").update({ stripe_payment_intent_id: intent.id }).eq("id", b.id);
  const ephemeralKey = await stripe.ephemeralKeys.create({ customer: customerId }, { apiVersion: "2024-06-20" });

  return json({ client_secret: intent.client_secret, payment_intent_id: intent.id, customer_id: customerId, ephemeral_key: ephemeralKey.secret });
});
