// Runs every five minutes from pg_cron (with the cron secret) and does the Stripe work that's due:
//   1. Holds for bookings saved more than 6 days out, now within 6 days.
//   2. Releases: declined, pro cancelled, or client cancelled free.
//   3. Charges: late cancel (50%), cancel after she arrived or no-show (100% + $3), after any
//      "Something wrong?" pause.
//   4. Auto-capture 12 hours after done, unless paused.
// Every step is idempotent, so a missed or doubled run is harmless.
import {
  stripe, stripeKey, admin, json, notConfigured, applicationFee, bookingTotal, systemLine, HOLD_LEAD_MS, type Booking,
} from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  if (!stripeKey) return notConfigured();

  const done: Record<string, number> = { held: 0, released: 0, charged: 0, captured: 0, failed: 0 };
  const now = Date.now();
  const iso = (ms: number) => new Date(ms).toISOString();

  // 1. Deferred holds
  const { data: due } = await admin.from("bookings").select("*")
    .in("status", ["requested", "confirmed"]).eq("hold_state", "saved").lte("starts_at", iso(now + HOLD_LEAD_MS));
  for (const b of (due ?? []) as Booking[]) {
    try {
      const { data: pro } = await admin.from("pros").select("stripe_account_id").eq("id", b.pro_id).single();
      const { data: contact } = await admin.from("profile_contacts").select("stripe_customer_id").eq("profile_id", b.client_id).single();
      const amount = bookingTotal(b);
      const pi = await stripe.paymentIntents.create({
        amount, currency: "aud", customer: contact!.stripe_customer_id!, payment_method: b.stripe_payment_method!,
        capture_method: "manual", off_session: true, confirm: true,
        application_fee_amount: applicationFee(b, amount),
        transfer_data: { destination: pro!.stripe_account_id! },
        description: `Hair Done ${b.reference}`, statement_descriptor_suffix: "HAIR DONE",
        metadata: { booking_id: b.id, reference: b.reference, kind: "booking" },
      }, { idempotencyKey: `hold-${b.id}` });
      await admin.from("bookings").update({ stripe_payment_intent_id: pi.id, hold_state: "held", settle_error: null }).eq("id", b.id);
      done.held++;
    } catch (e) {
      await admin.from("bookings").update({ hold_state: "failed", settle_error: (e as Error).message }).eq("id", b.id);
      await systemLine(b.id, "Your card didn't go through for this one. Add another in the app and we'll try again.");
      done.failed++;
    }
  }

  // 2. Releases
  const { data: toRelease } = await admin.from("bookings").select("*")
    .in("hold_state", ["held", "saved", "failed"])
    .or("status.in.(declined,cancelledByPro),and(status.eq.cancelledByClient,cancellation_charge_cents.eq.0)");
  for (const b of (toRelease ?? []) as Booking[]) {
    try {
      if (b.hold_state === "held" && b.stripe_payment_intent_id) {
        const pi = await stripe.paymentIntents.retrieve(b.stripe_payment_intent_id);
        if (pi.status === "requires_capture") await stripe.paymentIntents.cancel(pi.id, {}, { idempotencyKey: `release-${b.id}` });
      }
      await admin.from("bookings").update({ hold_state: "released", settle_error: null }).eq("id", b.id);
      done.released++;
    } catch (e) {
      await admin.from("bookings").update({ settle_error: (e as Error).message }).eq("id", b.id);
      done.failed++;
    }
  }

  // 3. Cancellation and no-show charges
  const { data: toCharge } = await admin.from("bookings").select("*")
    .in("status", ["cancelledByClient", "noShow"]).gt("cancellation_charge_cents", 0).in("hold_state", ["held", "saved"])
    .or(`capture_paused_until.is.null,capture_paused_until.lt.${iso(now)}`);
  for (const b of (toCharge ?? []) as Booking[]) {
    const charge = b.cancellation_charge_cents;
    try {
      if (b.hold_state === "held" && b.stripe_payment_intent_id) {
        await stripe.paymentIntents.capture(b.stripe_payment_intent_id,
          { amount_to_capture: charge, application_fee_amount: applicationFee(b, charge) },
          { idempotencyKey: `charge-${b.id}` });
      } else {
        // Card saved but no hold yet (booked more than 6 days out): charge it now.
        const { data: pro } = await admin.from("pros").select("stripe_account_id").eq("id", b.pro_id).single();
        const { data: contact } = await admin.from("profile_contacts").select("stripe_customer_id").eq("profile_id", b.client_id).single();
        await stripe.paymentIntents.create({
          amount: charge, currency: "aud", customer: contact!.stripe_customer_id!, payment_method: b.stripe_payment_method!,
          off_session: true, confirm: true, application_fee_amount: applicationFee(b, charge),
          transfer_data: { destination: pro!.stripe_account_id! },
          description: `Hair Done ${b.reference} cancellation`,
          metadata: { booking_id: b.id, kind: "cancellation" },
        }, { idempotencyKey: `charge-${b.id}` });
      }
      await admin.from("bookings").update({ hold_state: "captured", captured_at: iso(now), settle_error: null }).eq("id", b.id);
      done.charged++;
    } catch (e) {
      await admin.from("bookings").update({ settle_error: (e as Error).message }).eq("id", b.id);
      done.failed++;
    }
  }

  // 4. Auto-capture 12 hours after done
  const { data: toCapture } = await admin.from("bookings").select("*")
    .eq("status", "done").eq("hold_state", "held").lte("done_at", iso(now - 12 * 3600 * 1000))
    .or(`capture_paused_until.is.null,capture_paused_until.lt.${iso(now)}`);
  for (const b of (toCapture ?? []) as Booking[]) {
    try {
      const amount = bookingTotal(b);
      const pi = await stripe.paymentIntents.retrieve(b.stripe_payment_intent_id!);
      if (pi.status === "requires_capture") {
        await stripe.paymentIntents.capture(pi.id, { amount_to_capture: amount, application_fee_amount: applicationFee(b, amount) },
                                            { idempotencyKey: `capture-${b.id}` });
      }
      await admin.from("bookings").update({ hold_state: "captured", captured_at: iso(now), settle_error: null }).eq("id", b.id);
      await admin.rpc("move_booking", { b_id: b.id, new_status: "paid" });
      done.captured++;
    } catch (e) {
      await admin.from("bookings").update({ settle_error: (e as Error).message }).eq("id", b.id);
      done.failed++;
    }
  }

  return json(done);
});
