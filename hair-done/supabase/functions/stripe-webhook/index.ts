// Stripe → us. Verifies the signature, then keeps bookings and payouts in step with Stripe.
// Events we care about: payment_intent.amount_capturable_updated (hold placed), payment_intent.succeeded (captured → paid),
// payment_intent.canceled, account.updated (Connect onboarding finished), transfer.created / payout.paid.
import { stripe, admin, json } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature");
  const body = await req.text();
  let event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, sig!, Deno.env.get("STRIPE_WEBHOOK_SECRET")!);
  } catch (e) {
    return json({ error: `bad_signature: ${(e as Error).message}` }, 400);
  }

  switch (event.type) {
    case "payment_intent.amount_capturable_updated": {
      // Hold is in place. Nothing to change on the booking; the client-side flow already moved it to requested/confirmed.
      break;
    }
    case "payment_intent.succeeded": {
      const pi = event.data.object as { id: string; metadata: { booking_id?: string } };
      if (pi.metadata.booking_id) {
        await admin.from("bookings").update({ status: "paid", captured_at: new Date().toISOString() }).eq("id", pi.metadata.booking_id).eq("stripe_payment_intent_id", pi.id);
        await admin.from("messages").insert({
          thread_id: (await admin.from("threads").select("id").eq("booking_id", pi.metadata.booking_id).single()).data?.id,
          sender_id: null,
          text: "Paid. Receipt's in your inbox.",
        });
      }
      break;
    }
    case "payment_intent.canceled": {
      const pi = event.data.object as { id: string; metadata: { booking_id?: string } };
      // A cancelled hold on a still-live booking means the card fell over; tell both sides.
      if (pi.metadata.booking_id) {
        const { data: b } = await admin.from("bookings").select("status").eq("id", pi.metadata.booking_id).single();
        if (b && ["requested", "confirmed"].includes(b.status)) {
          await admin.rpc("move_booking", { b_id: pi.metadata.booking_id, new_status: "cancelledByClient", reason: "Payment hold was released" });
        }
      }
      break;
    }
    case "account.updated": {
      const acct = event.data.object as { id: string; payouts_enabled: boolean; metadata: { pro_id?: string } };
      if (acct.metadata.pro_id) {
        await admin.from("pros").update({ payouts_connected: acct.payouts_enabled }).eq("id", acct.metadata.pro_id);
      }
      break;
    }
    case "payout.paid": {
      const po = event.data.object as { id: string; amount: number; arrival_date: number; metadata: { pro_id?: string } };
      await admin.from("payouts").update({ status: "paid" }).eq("stripe_transfer_id", po.id);
      break;
    }
    default:
      break;
  }
  return json({ received: true });
});
