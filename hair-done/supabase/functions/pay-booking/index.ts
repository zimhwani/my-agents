// POST { booking_id, tip_cents? } → the client taps "Pay" on the Done sheet.
// Captures the hold for the booking total, charges any tip as its own payment (100% to the pro,
// no fee), then marks the booking paid. Idempotent: a second tap does nothing new.
import {
  stripe, stripeKey, admin, userClient, json, notConfigured, applicationFee, bookingTotal, systemLine, type Booking,
} from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!stripeKey) return notConfigured();
  const { data: { user } } = await userClient(req).auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { booking_id, tip_cents } = await req.json();
  const tip = Math.max(0, Math.min(Math.round(Number(tip_cents) || 0), 50000));
  const { data: b } = await admin.from("bookings").select("*").eq("id", booking_id).maybeSingle<Booking>();
  if (!b || b.client_id !== user.id) return json({ error: "not_found" }, 404);
  if (b.status === "paid") return json({ paid: true });
  if (b.status !== "done" || b.hold_state !== "held" || !b.stripe_payment_intent_id) return json({ error: "not_ready" }, 409);

  const amount = bookingTotal(b);
  const pi = await stripe.paymentIntents.retrieve(b.stripe_payment_intent_id);
  if (pi.status === "requires_capture") {
    await stripe.paymentIntents.capture(pi.id, { amount_to_capture: amount, application_fee_amount: applicationFee(b, amount) },
                                        { idempotencyKey: `capture-${b.id}` });
  } else if (pi.status !== "succeeded") {
    return json({ error: "hold_lapsed", stripe_status: pi.status }, 409);
  }
  await admin.from("bookings").update({ hold_state: "captured", captured_at: new Date().toISOString() }).eq("id", b.id);

  let tipIntent: string | null = null;
  if (tip > 0 && b.stripe_payment_method && typeof pi.customer === "string") {
    const { data: pro } = await admin.from("pros").select("stripe_account_id").eq("id", b.pro_id).single();
    try {
      const t = await stripe.paymentIntents.create({
        amount: tip, currency: "aud", customer: pi.customer, payment_method: b.stripe_payment_method,
        off_session: true, confirm: true,
        transfer_data: pro?.stripe_account_id ? { destination: pro.stripe_account_id } : undefined,
        description: `Hair Done ${b.reference} tip`,
        metadata: { booking_id: b.id, kind: "tip" },
      }, { idempotencyKey: `tip-${b.id}-${tip}` });
      tipIntent = t.id;
    } catch (e) {
      // The booking is paid either way; a tip that won't go through shouldn't hold that up.
      await systemLine(b.id, "The tip didn't go through, so it wasn't charged.");
      console.error("tip failed", b.id, (e as Error).message);
    }
  }
  if (tipIntent) await admin.from("bookings").update({ tip_cents: tip, stripe_tip_intent_id: tipIntent }).eq("id", b.id);

  const { error } = await admin.rpc("move_booking", { b_id: b.id, new_status: "paid" });
  if (error && !/bad_transition/.test(error.message)) return json({ error: error.message }, 500);
  return json({ paid: true, tip_cents: tipIntent ? tip : 0 });
});
