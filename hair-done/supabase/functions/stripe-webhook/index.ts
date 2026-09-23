// Stripe → us. Two endpoints point here: the platform one (STRIPE_WEBHOOK_SECRET) and the Connect one
// for pros' accounts (STRIPE_CONNECT_WEBHOOK_SECRET). Everything is idempotent; the app and the settle
// function usually get there first and this just agrees.
import Stripe from "npm:stripe@16";
import { stripe, stripeKey, cryptoProvider, admin, json, notConfigured, rememberCard } from "../_shared/stripe.ts";

const secrets = [Deno.env.get("STRIPE_WEBHOOK_SECRET"), Deno.env.get("STRIPE_CONNECT_WEBHOOK_SECRET")].filter(Boolean) as string[];

Deno.serve(async (req) => {
  if (!stripeKey || secrets.length === 0) return notConfigured();
  const sig = req.headers.get("stripe-signature") ?? "";
  const body = await req.text();
  let event: Stripe.Event | null = null;
  for (const secret of secrets) {
    try { event = await stripe.webhooks.constructEventAsync(body, sig, secret, undefined, cryptoProvider); break; }
    catch { /* try the next secret */ }
  }
  if (!event) return json({ error: "bad_signature" }, 400);

  switch (event.type) {
    // The hold is on. Mark the booking held (instant book confirms) and keep the card for next time.
    case "payment_intent.amount_capturable_updated": {
      const pi = event.data.object as Stripe.PaymentIntent;
      if (pi.metadata.kind !== "booking" || !pi.metadata.booking_id) break;
      const pm = typeof pi.payment_method === "string" ? pi.payment_method : pi.payment_method?.id ?? null;
      if (pm && typeof pi.customer === "string" && pi.metadata.client_id) await rememberCard(pi.metadata.client_id, pi.customer, pm);
      await admin.rpc("booking_hold_placed", { b_id: pi.metadata.booking_id, state: "held", pm });
      break;
    }
    // Card saved for a booking more than six days out.
    case "setup_intent.succeeded": {
      const si = event.data.object as Stripe.SetupIntent;
      if (si.metadata?.kind !== "booking" || !si.metadata.booking_id) break;
      const pm = typeof si.payment_method === "string" ? si.payment_method : si.payment_method?.id ?? null;
      if (pm && typeof si.customer === "string" && si.metadata.client_id) await rememberCard(si.metadata.client_id, si.customer, pm);
      await admin.rpc("booking_hold_placed", { b_id: si.metadata.booking_id, state: "saved", pm });
      break;
    }
    // Captured. Only a finished booking becomes paid; a cancellation charge or a tip leaves the status alone.
    case "payment_intent.succeeded": {
      const pi = event.data.object as Stripe.PaymentIntent;
      if (pi.metadata.kind !== "booking" || !pi.metadata.booking_id) break;
      const { data: b } = await admin.from("bookings").select("status").eq("id", pi.metadata.booking_id).maybeSingle();
      if (b?.status === "done") {
        await admin.from("bookings").update({ hold_state: "captured", captured_at: new Date().toISOString() }).eq("id", pi.metadata.booking_id);
        await admin.rpc("move_booking", { b_id: pi.metadata.booking_id, new_status: "paid" });
      }
      break;
    }
    // A hold that lapsed or was cancelled outside our own release: a live booking has lost its money.
    case "payment_intent.canceled": {
      const pi = event.data.object as Stripe.PaymentIntent;
      if (pi.metadata.kind !== "booking" || !pi.metadata.booking_id) break;
      const { data: b } = await admin.from("bookings").select("status, hold_state").eq("id", pi.metadata.booking_id).maybeSingle();
      if (b && b.hold_state === "held" && ["requested", "confirmed"].includes(b.status)) {
        await admin.from("bookings").update({ hold_state: "failed", settle_error: `hold ${pi.cancellation_reason ?? "cancelled"}` })
          .eq("id", pi.metadata.booking_id);
      }
      break;
    }
    // Connect: a pro finished (or lost) payout setup.
    case "account.updated": {
      const acct = event.data.object as Stripe.Account;
      const proId = acct.metadata?.pro_id;
      if (proId) await admin.from("pros").update({ payouts_connected: acct.payouts_enabled === true })
        .eq("id", proId).eq("stripe_account_id", acct.id);
      break;
    }
    // Connect: money landed in a pro's bank. Recorded for her Earnings screen.
    case "payout.paid": {
      const po = event.data.object as Stripe.Payout;
      const { data: pro } = await admin.from("pros").select("id").eq("stripe_account_id", event.account ?? "").maybeSingle();
      if (pro) {
        const { data: existing } = await admin.from("payouts").select("id").eq("stripe_transfer_id", po.id).maybeSingle();
        const row = { pro_id: pro.id, amount_cents: po.amount, status: "paid", stripe_transfer_id: po.id,
                      arrives_on: new Date(po.arrival_date * 1000).toISOString().slice(0, 10) };
        if (existing) await admin.from("payouts").update(row).eq("id", existing.id);
        else await admin.from("payouts").insert(row);
      }
      break;
    }
    default:
      break;
  }
  return json({ received: true });
});
