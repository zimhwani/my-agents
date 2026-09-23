// GET → { url }: a Stripe Connect Express onboarding link for the signed-in pro.
// Creates her Express account the first time (AU, individual, daily payouts two days after).
import { stripe, stripeKey, admin, userClient, json, notConfigured } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (!stripeKey) return notConfigured();
  const { data: { user } } = await userClient(req).auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { data: pro } = await admin.from("pros").select("id, stripe_account_id").eq("id", user.id).maybeSingle();
  if (!pro) return json({ error: "not_a_pro" }, 403);
  const { data: contact } = await admin.from("profile_contacts").select("email").eq("profile_id", user.id).maybeSingle();

  let accountId = pro.stripe_account_id;
  if (!accountId) {
    const acct = await stripe.accounts.create({
      type: "express",
      country: "AU",
      email: contact?.email ?? undefined,
      business_type: "individual",
      capabilities: { transfers: { requested: true }, card_payments: { requested: true } },
      business_profile: { mcc: "7230", product_description: "Mobile hair, nails, makeup, lashes and brows" },
      settings: { payouts: { schedule: { interval: "daily", delay_days: 2 } } },
      metadata: { pro_id: pro.id },
    }, { idempotencyKey: `connect-${pro.id}` });
    accountId = acct.id;
    await admin.from("pros").update({ stripe_account_id: accountId }).eq("id", pro.id);
  }

  const back = `${Deno.env.get("SUPABASE_URL")}/functions/v1/payouts-return`;
  const link = await stripe.accountLinks.create({
    account: accountId,
    type: "account_onboarding",
    refresh_url: `${back}?state=refresh`,
    return_url: `${back}?state=done`,
  });
  return json({ url: link.url });
});
