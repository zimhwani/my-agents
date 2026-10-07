// GET → { url }: a Stripe Connect onboarding link for the signed-in pro.
// GET ?status=1 → { payouts_connected }: asks Stripe directly and records the answer.
//
// New Stripe accounts block Accounts v1 creation unless "Accounts v1 support" is switched on, so this
// tries v1 (Express, AU, daily payouts) and falls back to Accounts v2 (a recipient account with the
// Express dashboard). Either way the result is an acct_… id that destination charges pay out to.
import { stripe, stripeKey, admin, userClient, json, notConfigured } from "../_shared/stripe.ts";

const V2_VERSION = "2026-09-30.endive";

async function v2(path: string, body?: unknown, method = "POST") {
  const res = await fetch(`https://api.stripe.com${path}`, {
    method,
    headers: { "Authorization": `Bearer ${stripeKey}`, "Stripe-Version": V2_VERSION, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`Stripe v2 ${path} ${res.status}: ${JSON.stringify(data)}`);
  return data as Record<string, unknown>;
}

async function createAccount(proId: string, name: string, email: string | undefined): Promise<string> {
  try {
    const acct = await stripe.accounts.create({
      type: "express",
      country: "AU",
      email,
      business_type: "individual",
      capabilities: { transfers: { requested: true }, card_payments: { requested: true } },
      business_profile: { mcc: "7230", product_description: "Mobile hair, nails, makeup, lashes and brows" },
      settings: { payouts: { schedule: { interval: "daily", delay_days: 2 } } },
      metadata: { pro_id: proId },
    }, { idempotencyKey: `connect-v3-${proId}` });
    return acct.id;
  } catch (e) {
    const msg = (e as Error).message ?? "";
    if (!/Accounts v1|v2\/core\/accounts/i.test(msg)) throw e;
    console.log("v1 account creation blocked; using Accounts v2");
  }
  const acct = await v2("/v2/core/accounts", {
    display_name: name,
    ...(email ? { contact_email: email } : {}),
    identity: { country: "au", entity_type: "individual" },
    dashboard: "express",
    defaults: { currency: "aud", responsibilities: { fees_collector: "application", losses_collector: "application" } },
    configuration: { recipient: { capabilities: { stripe_balance: { stripe_transfers: { requested: true } } } } },
    metadata: { pro_id: proId },
  });
  return acct.id as string;
}

async function onboardingLink(accountId: string, back: string): Promise<string> {
  try {
    const link = await stripe.accountLinks.create({
      account: accountId, type: "account_onboarding",
      refresh_url: `${back}?state=refresh`, return_url: `${back}?state=done`,
    });
    return link.url;
  } catch (e) {
    console.log("v1 account link failed, trying v2:", (e as Error).message);
  }
  const link = await v2("/v2/core/account_links", {
    account: accountId,
    use_case: {
      type: "account_onboarding",
      account_onboarding: { configurations: ["recipient"], refresh_url: `${back}?state=refresh`, return_url: `${back}?state=done` },
    },
  });
  return link.url as string;
}

/** Can Stripe pay this pro out yet? v1 retrieve works for both kinds of account; v2 is the fallback. */
export async function payoutsReady(accountId: string): Promise<boolean> {
  try {
    const a = await stripe.accounts.retrieve(accountId);
    return a.payouts_enabled === true && a.capabilities?.transfers === "active";
  } catch (e) {
    console.log("v1 retrieve failed, trying v2:", (e as Error).message);
  }
  const a = await v2(`/v2/core/accounts/${accountId}?include=configuration.recipient`, undefined, "GET");
  const status = (a as any)?.configuration?.recipient?.capabilities?.stripe_balance?.stripe_transfers?.status;
  return status === "active";
}

Deno.serve(async (req) => {
  if (!stripeKey) return notConfigured();
  const { data: { user } } = await userClient(req).auth.getUser();
  if (!user) return json({ error: "not_signed_in" }, 401);

  const { data: pro } = await admin.from("pros").select("id, stripe_account_id").eq("id", user.id).maybeSingle();
  if (!pro) return json({ error: "not_a_pro" }, 403);

  try {
    if (new URL(req.url).searchParams.get("status")) {
      if (!pro.stripe_account_id) return json({ payouts_connected: false });
      const ready = await payoutsReady(pro.stripe_account_id);
      await admin.from("pros").update({ payouts_connected: ready }).eq("id", pro.id);
      return json({ payouts_connected: ready });
    }

    let accountId = pro.stripe_account_id as string | null;
    if (!accountId) {
      const { data: contact } = await admin.from("profile_contacts").select("email").eq("profile_id", user.id).maybeSingle();
      const { data: profile } = await admin.from("profiles").select("first_name").eq("id", user.id).maybeSingle();
      // Phone sign-in leaves email blank; Stripe rejects "", and asks for it during onboarding anyway.
      accountId = await createAccount(pro.id, profile?.first_name || "Hair Done pro", contact?.email?.trim() || undefined);
      await admin.from("pros").update({ stripe_account_id: accountId }).eq("id", pro.id);
    }

    const url = await onboardingLink(accountId, `${Deno.env.get("SUPABASE_URL")}/functions/v1/payouts-return`);
    return json({ url });
  } catch (e) {
    console.error("connect-onboarding failed:", (e as Error).message);
    return json({ error: "stripe_error", message: (e as Error).message }, 502);
  }
});
