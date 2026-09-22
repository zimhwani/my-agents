// GET → { url } : a Stripe Connect Express onboarding link for the signed-in pro.
// Creates the Express account the first time (AU, individual, daily payouts).
import { stripe, admin, userClient, json } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  const supa = userClient(req);
  const { data: { user } } = await supa.auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { data: pro } = await admin.from("pros").select("id, stripe_account_id, abn").eq("id", user.id).single();
  if (!pro) return json({ error: "not_a_pro" }, 403);
  const { data: contact } = await admin.from("profile_contacts").select("email, phone").eq("profile_id", user.id).maybeSingle();

  let accountId = pro.stripe_account_id;
  if (!accountId) {
    const acct = await stripe.accounts.create({
      type: "express",
      country: "AU",
      email: contact?.email ?? undefined,
      business_type: "individual",
      capabilities: { transfers: { requested: true } },
      business_profile: { mcc: "7230", product_description: "Mobile beauty services", url: "https://hairdone.app" },
      settings: { payouts: { schedule: { interval: "daily", delay_days: 2 } } },
      metadata: { pro_id: pro.id },
    });
    accountId = acct.id;
    await admin.from("pros").update({ stripe_account_id: accountId }).eq("id", pro.id);
  }

  const link = await stripe.accountLinks.create({
    account: accountId,
    type: "account_onboarding",
    refresh_url: "hairdone://payouts/refresh",
    return_url: "hairdone://payouts/done",
  });
  return json({ url: link.url });
});
