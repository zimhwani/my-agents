# Gasguys: Payments, WhatsApp and Regulatory Research (Zimbabwe)

Research date: 2026-09-29. Every claim cites a source number [n], listed at the end. **(Inferred)** marks my own judgement or synthesis that no source states directly. Some important pages (the EcoCash portal, ContiPay docs, ZERA) render with JavaScript or block bots, so parts of this come from secondary sources. Those parts are flagged.

## TL;DR recommendation
- **Prototype:** use **Paynow Express Checkout** (`sendMobile` with EcoCash, OneMoney) plus Paynow's hosted web checkout for cards. It has official SDKs in Node, PHP, .NET and Dart, a test mode, a poll URL and a result URL [3][4][6]. Fees are published: 2.5% on mobile money, 3.5% + 50c on cards [7].
- **Production:** add a **second rail**. That can be EcoCash direct through the EcoCash Developer Portal (a sandbox exists, and it supports USD and ZWG, refund and lookup [9]) for lower cost and more control over your largest channel. Or it can be **ContiPay/Pesepay** for InnBucks and broader wallet coverage [12][13]. **(Inferred)** Build a provider-agnostic `PaymentProvider` interface from day one.
- **WhatsApp:** WhatsApp Pay is **not available in Zimbabwe** [16]. The bot collects the meter and amount, then either **triggers an EcoCash USSD PIN push to the phone number** (server-side, through Paynow or EcoCash) or sends a **CTA-URL link to the web checkout**. Service replies inside the 24-hour window are free [14].

---

## 1. EcoCash merchant integration

**Direct EcoCash API**
- The official portal is **https://developers.ecocash.co.zw/portal**. It renders with JavaScript, so I could not scrape its contents [8]. A community guide (not affiliated with EcoCash, v1.0.0 published 2026-09-21) describes it as follows [9]:
  - "Instant Payment" C2B: `POST /transactions/amount/` (charge), `GET /{endUserId}/transactions/amount/{clientCorrelator}` (lookup), `POST /transactions/refund/`.
  - Sandbox base URL: `https://developers.ecocash.co.zw/sandbox/payment/v1`. Auth is HTTP Basic, with credentials delivered to the portal Inbox after you request sandbox access.
  - Flow is asynchronous. The server charges, the customer gets a **USSD PIN prompt**, and the status becomes SUCCESS or FAILED. The result arrives through an optional `notifyUrl` callback or by polling. The sandbox test PIN `0000` means success.
  - Currencies: **USD and ZWG (ZiG)**.
  - Onboarding: register, request sandbox, verify a test MSISDN, run the test scenarios, then submit signed test evidence for production approval (target of about 2 business days).
- The requirements for a merchant code, company registration or KYC documents, and EcoCash's own MDR, are **not publicly documented** in any source I could reach. **(Inferred)** Expect company registration (CR14/CR6), a tax clearance (ITF263), a bank account and a merchant code from EcoCash Holdings.
- EcoCash had an official API as far back as 2014 [10]. Several community SDKs exist (Dart `ecocash` package [11]).

**Paynow (aggregator, Webdev/Smatech)**
- **Express Checkout** posts to `https://www.paynow.co.zw/interface/remotetransaction`. Your app collects the payment method and completes the payment "without redirecting the customer to Paynow". Listed methods are Visa/Mastercard (tokenised), Zimswitch (tokenised), EcoCash, OneMoney, **InnBucks** and O'mari [3].
- SDK flow: `paynow.sendMobile(payment, '0777000000', 'ecocash')` returns `instructions` and a `pollUrl`. You then call `pollTransaction(pollUrl)` and check `status.paid()`. The integration ID and key come from env vars `PAYNOW_INTEGRATION_ID` and `PAYNOW_INTEGRATION_KEY` [4]. The PHP and Node SDK docs list only `ecocash` and `onemoney` for mobile [4][6].
- Paynow **POSTs status changes to your `resulturl`**, with a hash you verify using the integration key [5].
- Fees: **mobile money 2.5%, cards 3.5% + 50c**. The merchant can absorb the fee, pass it on or split it [7]. No InnBucks fee is published [7].
- Caveat: one 2026 review claims Paynow "supports EcoCash only" and that **IP whitelisting blocks serverless deployments** [12]. This conflicts with Paynow's own docs [3], so treat it as **unverified**. Test it before you pick Vercel, Supabase Edge or Lambda for callbacks.

**Pesepay**
- "Seamless" make-payment API at `https://api.pesepay.com/api/payments-engine/v2/payments/make-payment`. The payload is **encrypted** with the integration key. Method codes: `PZW211` EcoCash, `PZW212` **InnBucks**. It returns a `pollUrl`, and `resultUrl` is mandatory [13].

**ContiPay**
- A 2026 comparison lists Visa (3DS), Mastercard, EcoCash (USD/ZWL), InnBucks, OneMoney, TeleCash, ZIPIT, Zimswitch, O'mari and Mukuru, plus payouts [12]. Its docs are at docs.contipay.co.zw but the page is JavaScript-rendered and I could not verify it [14b]. A PHP library exists [14c].

**Recommendation.** **(Inferred)** Start the prototype on Paynow (published fees, SDKs, fastest go-live). Keep EcoCash direct as a production cost and reliability upgrade, because EcoCash will be most of your volume. Add Pesepay or ContiPay if InnBucks through Paynow proves unreliable.

## 2. InnBucks
- InnBucks (a Simbisa-linked microbank) has a **merchant API**, but its base URLs are issued privately to onboarded merchants. A community guide [15] describes it as follows:
  - `POST /api/code/generate` → a payment **code valid for 10 minutes**, plus a base64 **QR image**. Amounts are in integer cents, in USD or ZWG.
  - Deep link: `com.innbucks.customer://purchase?paymentToken={code}`.
  - There is **no webhook**. You poll `POST /api/code/inquiry`, at most once every 30 seconds.
  - Onboarding needs an InnBucks merchant or agent account, an API key, a username and password, and a funded test wallet.
- **The customer UX** is that the customer approves the code in the InnBucks app or USSD, or scans the QR [15]. There is a separate InnBucks Merchant app [15b].
- **Via Paynow:** InnBucks is listed in Express Checkout [3], but a Paynow forum thread reports that "InnBucks cannot be used in testing mode, your integration has to be live" [16b]. The Paynow homepage does not list InnBucks [17]. **Via Pesepay:** method `PZW212` [13].
- **(Inferred)** On WhatsApp, the InnBucks flow maps neatly to "bot sends a 6-digit code, QR image and deep link, then polls". This works well for cash-heavy customers who top up InnBucks at Chicken Inn and similar outlets.

## 3. WhatsApp Business Platform (Cloud API)
- **Pricing (per-message since 1 July 2025):** you are charged only when a **template** is delivered. Marketing templates are always charged. **Utility templates are free inside an open customer service window.** Non-template (free-form, interactive) messages are free inside the window, which is **24 hours from the user's last message**. Zimbabwe falls in the **"Rest of Africa"** rate group [18].
- **Indicative 2026 Rest of Africa rates** (secondary source, so check Meta's rate card [18]): marketing about **$0.0225**, utility **under $0.01**. Click-to-WhatsApp ads open a **72-hour free entry window** [19].
- **2026 changes:** a max-price cap on the Marketing Messages API, and a new AI Provider policy from 16 Feb 2026 [18]. **(Inferred)** Check that an LLM-driven Gasguys bot complies with that AI policy.
- **Interactive messages:** reply buttons, lists, CTA-URL buttons and **WhatsApp Flows** (multi-screen native forms, with optional endpoint data exchange) [20]. The Meta docs pages rate-limited me. **(Inferred, from widely documented Meta limits)** Up to 3 reply buttons and up to 10 list rows. Flows fit "Select meter → amount → payment method".
- **WhatsApp Pay:** business payments exist only in **India and Brazil** (plus a Singapore pilot). **Zimbabwe is not supported** and is not on the expansion list [16].
- **How Zimbabwean bots take payment:**
  - Steward Bank's "Sosholoza" WhatsApp banking (launched 23 Apr 2019; 37,000 profiles in 3 weeks) handles balances, transfers and airtime [21].
  - Econet's **Yamurai** (+263 781 222 000) uses button-guided self-service (SIM swap, bundles, airtime transfer). **No EcoCash payment through WhatsApp is documented** [22].
  - A 2018 Techzim piece covers a WhatsApp bot for airtime and ZESA [23] (page returned 403, so details are unverified).
  - The unofficial "WhatsEco" app triggered EcoCash USSD from WhatsApp and was later flagged as **malware** [24]. This is a trust lesson: use an official, verified business number and server-side USSD push.
  - **(Inferred)** The pattern that works is that the bot captures the MSISDN, the server calls EcoCash or Paynow `sendMobile`, the phone gets the USSD PIN prompt, the resulturl or webhook fires, and the bot sends a free-form "Paid, credit sent to valve" confirmation within the 24-hour window.
- **BSP vs direct:** **(Inferred)** Direct Cloud API has no markup and needs Meta Business verification. BSPs (360dialog at a flat monthly fee with no per-message markup [25]; Twilio and Infobip with per-message markups) add onboarding help and inboxes. I recommend direct Cloud API, or 360dialog for low cost.

## 4. The ZESA token UX Zimbabweans already know
- EcoCash USSD: dial `*151#` → 2 Make Payment → 5 Pay ZESA → 1 Buy Token → amount → **meter number** → confirm. The token arrives by **EcoCash notification and SMS**. Users report occasional delays [26].
- ZESA tokens are also sold through web and aggregator channels (Paynow Topup [27], Techzim Market, MukuruPay booths [28]).
- **(Inferred) UX mapping:** meter number is the Gasguys valve or meter ID, amount is in USD or ZiG, the EcoCash PIN confirms, and "token by SMS" becomes an automatic credit push to the ESP32. Still send a **receipt with a reference number and a fallback numeric token**, so a customer can key it in if the valve is offline. Users already understand the "enter token" mental model.

## 5. Diaspora gifting
- **Stripe does not support Zimbabwe merchant accounts**. Its African coverage is via Paystack for NG, GH, KE, ZA and CI only [29]. **(Inferred)** A Zimbabwe-registered Gasguys cannot use Stripe directly without a foreign entity.
- **Cards via local gateways:** Paynow cards cost 3.5% + 50c [7]. ContiPay offers 3DS Visa and Mastercard [12]. These take diaspora cards on the web checkout.
- **Remittance rails:** WorldRemit sends USD to **EcoCash wallets instantly, up to USD 2,000 per transfer** [30]. Remitly also supports EcoCash [30b]. Mukuru is Zimbabwe's largest remittance platform. Its **MukuruPay** pays electricity, airtime and DStv at more than 250 booths [28], and ContiPay lists Mukuru as a method [12].
- **(Inferred) Product options:**
  - (a) A "Gift gas" web link paid by international card through Paynow or ContiPay. This is the easiest path.
  - (b) The family receives an EcoCash remittance and pays through the normal flow.
  - (c) A later partnership: a Gasguys biller inside Mukuru or WorldRemit "bill pay".
  - The gifter can share a WhatsApp link that carries the meter ID pre-filled.

## 6. Regulatory
- **LPG (ZERA):** retail needs a ZERA licence under the Petroleum (LPG) Regulations, SI 57 of 2014 [31]. Fees are set by SI 78 of 2024 [32].
  - A secondary guide adds these steps: local-authority site approval, an **EMA hazardous-substance certificate**, **fire-brigade clearance**, a pre-licensing inspection, standard ZWS 960 Part 3, and a Gazette notice within 30 days [33].
  - **(Inferred)** Metering and dispensing LPG in customers' homes may also bring in installer certification (ZERA keeps an LPG installers database [34]) and weights-and-measures approval for the meter. Confirm both with ZERA.
- **Data protection:** under the Cyber and Data Protection Act [Chapter 12:07] and **SI 155 of 2024**, controllers processing data on 50 or more people need a **POTRAZ data controller licence**, tiered by volume (50–1k, 1k–10k, 10k–500k, above 500k). They must appoint a **certified DPO**. Breaches go to POTRAZ **within 24 hours** and to affected people within 72 hours [35].
  - **POTRAZ inspections start 1 Sep 2026** [36].
  - **(Inferred)** Gasguys holds phone numbers, home locations and consumption telemetry, so it needs a licence before launch. It must also disclose non-Zimbabwe hosting (Supabase or AWS region) [35].
- **Currency and RBZ:** the multi-currency regime (USD alongside ZiG) is extended to 2030 [37]. **SI 34 of 2025** repealed the penalties for pricing above the official rate, so businesses may price at market rates [38]. EcoCash and InnBucks both settle USD and ZWG [9][15].
  - **(Inferred)** Price in USD, show a ZiG equivalent from a daily rate, and accept both. Keep per-currency ledgers, because wallets and settlements are currency-specific.
  - **(Inferred)** Holding customer prepaid credit could look like e-money or stored value to the RBZ. Frame credit as **prepaid gas units (kg or m³), not money**, make it non-transferable and non-redeemable for cash, and get legal sign-off.

## Sources
1. Persona file: /home/claude/my-agents/product/product-trend-researcher.md
2. (unused)
3. https://developers.paynow.co.zw/docs/paynow/express_checkout_transactions/
4. https://github.com/paynow/Paynow-NodeJS-SDK
5. https://developers.paynow.co.zw/docs/paynow/status_update/
6. https://developers.paynow.co.zw/docs/paynow/php_quickstart/
7. https://www.paynow.co.zw/Home/Fees
8. https://developers.ecocash.co.zw/
9. https://github.com/67even/ecocash-instant-payment-api (community guide, unofficial)
10. https://www.techzim.co.zw/2014/06/official-ecocash-api-live-developers/
11. https://pub.dev/documentation/ecocash/latest/
12. https://www.nyuchi.com/blog/zimbabwe-payment-gateways-2026
13. https://developers.pesepay.com/api-reference/make-payment
14b. https://docs.contipay.co.zw/
14c. https://github.com/contitouchtechnologies/php-contipay-libray
15. https://github.com/67even/innbucks-merchant-api-integration (community guide, unofficial)
15b. https://play.google.com/store/apps/details?id=com.innbucks.merchant&hl=en
16. https://www.infobip.com/blog/whatsapp-payments
16b. https://forums.paynow.co.zw/t/innbucks-integration/5962
17. https://www.paynow.co.zw/
18. https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing (rate card: https://business.whatsapp.com/products/platform-pricing#rates)
19. https://bsg.world/blog/guides/whatsapp-api-pricing-in-2026-what-it-costs-how-to-optimize
20. https://developers.facebook.com/docs/whatsapp/flows
21. https://www.clickatell.com/press-center/zimbabwe-steward-bank-chat-banking-whatsapp/
22. https://www.econet.co.zw/customer-experience/
23. https://www.techzim.co.zw/2018/04/you-can-now-buy-airtime-and-electricity-on-whatsapp/
24. https://www.techzim.co.zw/2019/03/whatseco-allows-you-to-transact-on-ecocash-via-whatsapp/
25. https://360dialog.com/pricing
26. https://www.techzim.co.zw/2016/11/ecocash-buy-zesa-feature-now-avalaible-buy-prepaid-electricity-7-easy-steps/
27. https://www.topup.co.zw/pay/zesa-prepaid-electricity-token
28. https://www.mukuru.com/zw/services/mukuru-pay/
29. https://stripe.com/global
30. https://www.worldremit.com/en/zimbabwe/mobile-money
30b. https://www.remitly.com/us/en/providers-zimbabwe/send-money-to-ecocash
31. https://www.zera.co.zw/wp-content/uploads/simple-file-list/LPG-Guidelines-and-Regulations/SI_57_of_2014_LPG.pdf
32. https://www.zera.co.zw/wp-content/uploads/simple-file-list/Petroleum-Fees/S_I_-78-of-2024-Petroleum-Licence-Fees-Regulations-2024-Normal-Petroleum-Licence-Fees-1.pdf
33. https://motimagz.com/how-to-start-retail-lpg-business-in-zimbabwe/
34. https://www.zera.co.zw/lpg-installers-database/
35. https://www.dlapiperafrica.com/en/zimbabwe/insights/2024/A-Quick-Start-Guide-to-Zimbabwes-Data-Protection-Regulations
36. https://techpoint.africa/insight/techpoint-digest-1398/
37. https://www.herald.co.zw/multi-currency-regime-to-stay/
38. https://equityaxis.net/index.php/post/18378/2025/4/zimbabwe-s-statutory-instrument-34-of-2025-analysing-zig-and-exchange-rate-policy-shift
