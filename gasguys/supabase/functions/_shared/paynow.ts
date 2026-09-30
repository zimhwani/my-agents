// Paynow (paynow.co.zw) as the first payment rail: EcoCash and InnBucks through Express Checkout
// (the customer gets a PIN prompt or a code, no redirect), cards through the hosted web checkout.
// Protocol per https://developers.paynow.co.zw: urlencoded form posts, SHA-512 hash of the values in
// order plus the integration key, upper-case hex. Paynow issues a separate integration per currency.
//
// UNVERIFIED against a live account: the InnBucks response fields (`authorizationcode`,
// `authorizationexpires`), and whether InnBucks works in test mode (a Paynow forum post says it
// doesn't). Check both when the merchant account is live.

import type { InitiateResult, PaymentProvider, PaymentRequest, ProviderStatus } from "./core/providers.ts";
import type { Currency, PayMethod } from "./core/types.ts";

const REMOTE = "https://www.paynow.co.zw/interface/remotetransaction";
const WEB = "https://www.paynow.co.zw/interface/initiatetransaction";

type Integration = { id: string; key: string };

function integration(currency: Currency): Integration | null {
  const id = Deno.env.get(`PAYNOW_${currency}_INTEGRATION_ID`);
  const key = Deno.env.get(`PAYNOW_${currency}_INTEGRATION_KEY`);
  return id && key ? { id, key } : null;
}

async function sha512Upper(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-512", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
}

/** Hash = SHA512(all values except "hash", in order, then the integration key). */
export async function paynowHash(fields: [string, string][], key: string): Promise<string> {
  return sha512Upper(fields.filter(([k]) => k.toLowerCase() !== "hash").map(([, v]) => v).join("") + key);
}

export async function verifyPaynow(body: string, currency: Currency): Promise<Record<string, string> | null> {
  const int = integration(currency);
  if (!int) return null;
  const fields = [...new URLSearchParams(body).entries()];
  const given = fields.find(([k]) => k.toLowerCase() === "hash")?.[1];
  if (!given || given.toUpperCase() !== (await paynowHash(fields, int.key))) return null;
  return Object.fromEntries(fields.map(([k, v]) => [k.toLowerCase(), v]));
}

export function mapStatus(s: string): ProviderStatus {
  const v = s.toLowerCase();
  if (v === "paid" || v === "awaiting delivery" || v === "delivered") return "paid";
  if (v === "cancelled" || v === "failed" || v === "disputed" || v === "refunded") return "failed";
  return "pending";
}

export async function pollPaynow(pollUrl: string): Promise<ProviderStatus> {
  const res = await fetch(pollUrl, { method: "POST" });
  return mapStatus(new URLSearchParams(await res.text()).get("status") ?? "");
}

export class PaynowProvider implements PaymentProvider {
  readonly name = "paynow";
  constructor(
    private resultUrl: string,
    private returnUrl: string,
    private authEmail: string,
  ) {}

  supports(_method: PayMethod, currency: Currency) {
    return integration(currency) !== null;
  }

  async initiate(req: PaymentRequest): Promise<InitiateResult> {
    const int = integration(req.currency);
    if (!int) return { ok: false, error: "paynow_not_configured" };
    const mobile = req.method !== "card";
    const fields: [string, string][] = [
      ["id", int.id],
      ["reference", req.reference],
      ["amount", req.amount.toFixed(2)],
      ["additionalinfo", req.description],
      ["returnurl", this.returnUrl],
      ["resulturl", `${this.resultUrl}?currency=${req.currency}`],
      ["authemail", this.authEmail],
      ...(mobile
        ? ([
            ["phone", "0" + req.payerPhone.slice(3)],
            ["method", req.method],
          ] as [string, string][])
        : []),
      ["status", "Message"],
    ];
    fields.push(["hash", await paynowHash(fields, int.key)]);

    const res = await fetch(mobile ? REMOTE : WEB, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(fields).toString(),
    });
    const out = Object.fromEntries([...new URLSearchParams(await res.text()).entries()].map(([k, v]) => [k.toLowerCase(), v]));
    if ((out.status ?? "").toLowerCase() !== "ok") return { ok: false, error: out.error ?? "paynow_error" };

    const providerRef = out.paynowreference ?? out.pollurl;
    if (req.method === "ecocash") return { ok: true, providerRef, pollUrl: out.pollurl, instruction: { kind: "ussd_push", phone: req.payerPhone } };
    if (req.method === "innbucks") {
      const code = out.authorizationcode ?? "";
      return {
        ok: true,
        providerRef,
        pollUrl: out.pollurl,
        instruction: { kind: "code", code, expiresAt: out.authorizationexpires ?? "", deepLink: code ? `com.innbucks.customer://purchase?paymentToken=${code}` : undefined },
      };
    }
    return { ok: true, providerRef, pollUrl: out.pollurl, instruction: { kind: "redirect", url: out.browserurl } };
  }

  poll(_ref: string, pollUrl?: string): Promise<ProviderStatus> {
    return pollUrl ? pollPaynow(pollUrl) : Promise.resolve("pending");
  }
}
