# Gasguys

Pay-as-you-cook LPG for Zimbabwe. A smart valve on the customer's cylinder holds gas credit in grams; customers top up from $1 with EcoCash, InnBucks or a card, on WhatsApp or the web app, in English, Shona or Ndebele. Relatives abroad can gift gas straight to a family meter.

This folder is a working prototype: the real business logic, WhatsApp bot and token engine, running against simulated payments, valves and WhatsApp so the whole journey can be tested before any credentials exist. The adapters for the real services (Paynow, WhatsApp Cloud API, an MQTT broker, Supabase) and the ESP32 firmware are written behind the same interfaces.

**Start with [docs/integration-map.md](docs/integration-map.md)**: what connects to what, what's real vs simulated, and what to get before launch.

## Try it

```bash
cd gasguys
npm install
npm run dev        # open the URL it prints
```

The **Studio** view shows the customer app, a WhatsApp phone and the valve side by side, all sharing one sandbox. Things to try:

1. **Buy on the web.** Sign in as Tendai (`77 123 4567`, code `123456`), tap Buy gas, pick $2, pay with EcoCash. The WhatsApp phone pops up the EcoCash PIN prompt; any 4 digits approves. Watch the valve's credit jump and its serial log print the signed MQTT command.
2. **Buy on WhatsApp.** Type `hi` in the WhatsApp phone and follow the menu. Try InnBucks or a ZiG amount. Switch to "New customer" to go through registration and link the spare meter `370 5550 1234`.
3. **Offline token.** On the valve, press *Lose network*, then buy $1. The receipt shows a 12-digit token; key it into the valve's keypad and press OK. Key it again and it's refused.
4. **Gift gas.** In the app, tap Gift: Gogo Ncube's meter is prefilled. Pay by card. Switch the WhatsApp phone to Gogo to see her notification in isiNdebele.
5. **Safety and refills.** *Light the stove* and turn up the cooking speed in the header to watch credit burn down; *Simulate leak* to see the valve lock, the app's red alert and the WhatsApp warning. The **Ops** tab clears leaks and moves refill orders along.

`#/app` opens the customer app on its own, full screen, for trying on a real phone. *Reset* in the header restores the starting data.

## Layout

| Path | What |
|---|---|
| [core/](core/) | Shared, dependency-free TypeScript used by the browser and the edge functions: [service.ts](core/service.ts) (buying, crediting, refills, alerts), [bot.ts](core/bot.ts) (WhatsApp conversation), [token.ts](core/token.ts) (offline tokens and signed credit), [device.ts](core/device.ts) (valve rules), [pricing.ts](core/pricing.ts), [providers.ts](core/providers.ts) (the interfaces), [i18n/](core/i18n/) |
| [src/](src/) | The web app (React + Vite): customer app, WhatsApp simulator, valve simulator, ops console, and the in-browser [sandbox](src/sandbox/) that fakes every provider. The customer app reads and writes through [src/backend/](src/backend/): `SandboxBackend` by default, `SupabaseBackend` in live mode |
| [supabase/](supabase/) | Postgres schema with row-level security, and edge functions: `payments-start`, `paynow-result`, `whatsapp-webhook`, `meter-telemetry`, `sweep`; for the web app `me`, `link-meter`, `gift-lookup`, `refill-request`; and `auth-send-sms`, which delivers sign-in codes on WhatsApp |
| [firmware/](firmware/) | ESP32 valve firmware (PlatformIO): valve, load cell, leak sensor, keypad tokens, MQTT |
| [docs/](docs/) | Integration map, UX spec, WhatsApp templates, translation notes, and the research behind them |

## Checks

```bash
npm test            # token maths, replay protection, and the WhatsApp → payment → valve flow
npm run build       # typecheck + production build
g++ -std=c++17 -Ifirmware/include firmware/test/token_host_test.cpp firmware/src/token.cpp -lcrypto -o /tmp/tok && /tmp/tok
                    # firmware token code against the same test vectors
```

## Going live

Nothing here needs a secret to run the sandbox. To connect real services, create a Supabase project, then:

```bash
supabase link --project-ref <ref>
supabase db push                         # migrations 0001, 0002 and 0003
supabase secrets set PAYNOW_USD_INTEGRATION_ID=… PAYNOW_USD_INTEGRATION_KEY=… \
  PAYNOW_ZWG_INTEGRATION_ID=… PAYNOW_ZWG_INTEGRATION_KEY=… PAYNOW_AUTH_EMAIL=… \
  WHATSAPP_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=… WHATSAPP_APP_SECRET=… WHATSAPP_VERIFY_TOKEN=… \
  MQTT_API_URL=… MQTT_API_KEY=… MQTT_API_SECRET=… BROKER_WEBHOOK_SECRET=… CRON_SECRET=… APP_URL=… \
  SEND_SMS_HOOK_SECRET=…                  # from the Send SMS hook, below
supabase functions deploy
```

Then point the WhatsApp app's webhook at `…/functions/v1/whatsapp-webhook`, add a broker rule that forwards `gg/+/telemetry` to `…/functions/v1/meter-telemetry` with the `x-gasguys-broker` header, and schedule `sweep` every 5 minutes with pg_cron. The edge functions import `core/` through the `supabase/functions/_shared/core` symlink.

At that point the **WhatsApp bot is fully live**: real customers, real EcoCash prompts through Paynow, real valves over MQTT.

### The web app in live mode

The customer app runs on the sandbox unless it is built with a Supabase project's URL and anon (publishable) key. Copy [.env.example](.env.example) to `.env.local` (or set the two variables in Vercel) and build:

```bash
VITE_SUPABASE_URL=https://<ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<anon or publishable key>   # safe in the browser; never the service_role key
```

With both set, every route is the customer app, full screen, with no Studio, simulators, approve/decline buttons or sandbox hints, and the sandbox code isn't even downloaded. Without them, nothing changes: the Studio and `#/app` run on the sandbox as before. In live mode ([src/backend/supabase.ts](src/backend/supabase.ts)):

- **Sign-in** is Supabase phone OTP (`signInWithOtp` / `verifyOtp`, type `sms`). The `me` function then creates the customer, or adopts the row the WhatsApp bot already made for that number, and links it to the login (`customers.auth_user`), which is what row-level security keys on.
- **Reads** are plain SELECTs that RLS narrows to the customer's own rows; **Realtime** on `meters`, `payments` and `refill_orders` keeps the gauge, receipts and refill tracker live.
- **Writes** all go through edge functions: `payments-start`, `link-meter`, `gift-lookup`, `refill-request`, `me` (language and name).
- **Card payments** go to Paynow's hosted page; when Paynow sends the customer back to `APP_URL`, the app reopens the payment and polls it until it settles. So set `APP_URL` to the deployed web app's address.

**Sign-in codes go by WhatsApp, not SMS.** SMS through Supabase's built-in providers delivers poorly in Zimbabwe, so the `auth-send-sms` function is a Supabase *Send SMS hook* that sends the code with a WhatsApp Authentication template (`gasguys_login_code`, see [docs/whatsapp-templates.md](docs/whatsapp-templates.md)). To enable it: Dashboard → Authentication → Hooks → Send SMS hook → HTTPS, URL `https://<ref>.supabase.co/functions/v1/auth-send-sms`; generate the secret there and `supabase secrets set SEND_SMS_HOOK_SECRET='v1,whsec_…'`. Phone sign-in must also be enabled (Authentication → Providers → Phone). Locally, the same hook is the `[auth.hook.send_sms]` section of [supabase/config.toml](supabase/config.toml). Customers without WhatsApp on their number can't receive a code yet; an SMS fallback in the hook is the next step if that matters.

Each meter needs a row in `meters` and a 32-byte key in `private.meter_keys`, and the same key flashed into its firmware (`firmware/include/config.h`).

## Status

- Sandbox, bot, tokens and valve rules: working, tested (`npm test`, and clicked through end to end in a browser).
- Edge functions: typecheck under Deno; not yet run against live Paynow, Meta or a broker.
- Web app live mode: builds, loads to sign-in with no sandbox UI, and its sign-in → home → card redirect → return flow was clicked through against mocked Supabase responses. Not yet run against a real project (none exists yet), so Auth, RLS, Realtime and the hook are untested live.
- Firmware: token code tested on the host against the backend's vectors; the rest has not been flashed to hardware. The cellular build connects without TLS until the modem's TLS stack is wired up (see the TODO in `main.cpp`).
- Shona and Ndebele copy: drafts, need native-speaker review ([docs/i18n-notes.md](docs/i18n-notes.md)).
