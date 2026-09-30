# WhatsApp templates to submit

Messages Gasguys sends first (not as a reply) need a template approved in WhatsApp Manager, in the **Utility** category. Inside the 24-hour window after a customer writes, the bot replies with free-form and interactive messages instead, which are free. Submit each template in English, Shona and Ndebele if Meta accepts those language codes for templates; if it doesn't, submit English and keep the Shona and Ndebele versions for in-window replies. The names below are what [core/service.ts](../core/service.ts) sends; if a template isn't approved yet, [whatsapp.ts](../supabase/functions/_shared/whatsapp.ts) falls back to plain text, which only arrives inside the window.

| Name | When | Body (English) | Buttons |
|---|---|---|---|
| `gift_received` | A relative paid gas onto your meter | 🎁 {{1}} sent you {{2}} kg of gas. Gas is on. | Say thank you · Check balance |
| `refill_on_way` | Ops dispatches a cylinder | 🚚 {{1}} is on the way with your cylinder. | Call {{1}} |
| `leak_alert` | Valve's leak sensor trips | ⚠️ GAS LEAK DETECTED on meter {{1}}. We have shut off your gas. Open doors and windows. No flames, no switches. Go outside. | I am safe · Talk to a person |
| `low_credit` | Less than 2 days of credit left | Gas is running low: about {{1}} days left on meter {{2}}. Top up now? | Buy $1 · Buy $5 · Other amount |
| `low_cylinder` | Cylinder under 15% | Your cylinder has {{1}} kg left. We've booked a refill; reply to change the time. | Request refill |
| `payment_receipt` | Payment settles after the window closed (e.g. a slow card) | ✅ Payment {{1}} received. {{2}} kg sent to meter {{3}}. | Check balance |

### Sign-in code (Authentication category)

Sent by the `auth-send-sms` function, which Supabase Auth calls as its *Send SMS hook* whenever a customer signs in to the web app. Create it in WhatsApp Manager as an **Authentication** template, not Utility: Meta supplies the wording, and you pick options.

| Name | When | Body | Button |
|---|---|---|---|
| `gasguys_login_code` | Customer asks for a sign-in code on the web app | Meta's preset: "{{1}} is your verification code." Tick *Add security recommendation* ("For your security, do not share this code.") and set the expiry to 10 minutes to match Supabase's OTP lifetime. | Copy code |

The function sends the code as the body parameter and again as the copy-code button's parameter ([whatsapp.ts](../supabase/functions/_shared/whatsapp.ts) `authCodeMessage`). Authentication templates only come in Meta's languages, so this one is English for everyone; the code is the part that matters. The name can be changed with the `WHATSAPP_OTP_TEMPLATE` secret; if you submit it as `en_US` rather than `en`, change the language code in `authCodeMessage` too.

Rules from the UX spec: at most one low-gas message a day, none between 21:00 and 06:00, and leak alerts also go by SMS.
