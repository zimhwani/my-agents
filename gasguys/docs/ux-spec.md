# Gasguys: UX Spec (Customer Web App + WhatsApp Bot)

Strings live in `i18n.json` (en / sn / nd, 120 keys). Key names are shown in `code` below.

## 1. UX principles

Users already know the ZESA prepaid token model: pay, get units, the power stays on. Gasguys uses the same model, with one improvement: the credit reaches the meter by itself, so there is no 20-digit token to type in.

1. **Show one number.** Home leads with *Gas remaining in kg* and *about N days left*. Credit in money comes second. People plan in days ("will it last until month-end?"), so days get the biggest type.
2. **ZESA mental model, no token friction.** Use the words people know (top up, units → kg, balance). After a payment, show a big tick and the text "Gas is ON" within 10 s.
3. **Assume low literacy.** Every action has an icon, a short verb and a colour for its state. Key screens hold one decision each. Amount presets are large tappable chips. Show numbers as numerals, never spelled out. Offer voice notes in the WhatsApp bot for support. Leak and low-gas alerts also go out by SMS.
4. **Keep data light.** Target under 150 KB for the first load: an SSR/PWA shell, a system font fallback, inline SVG icons, and no photos on core screens. Cache the last known state and show it with "Updated {time}" (`last_updated`), plus an offline banner (`offline_banner`). Offer a data-saver toggle. Queue purchases and send them when the network comes back.
5. **Trust cues everywhere money moves.** "No extra fees" appears before payment. Name the EcoCash number being charged. Give a receipt number and an SMS receipt. Show the recipient's name before sending a gift (the pattern people know from EcoCash "send money"). Say "Valve installed free" plainly. Show a human support number on every error.
6. **Cultural fit.** Let people name meters in their own words ("Mama's house", "Kumusha"). Do not force first/last-name fields. Use one "Name" field that is optional. The diaspora gift flow puts the recipient's name first and uses warm copy, not transactional copy. Put the language switch on the very first screen and in the header. Never make Shona or Ndebele an afterthought: layouts must allow text that is about 40% longer (Ndebele strings run long).
7. **Accessibility.** Touch targets are at least 48 px. Contrast is AA or better. State is never shown by colour alone: "Gas is ON/OFF" is always spelled out with an icon. Body text is 16 px minimum. The layout supports large system font sizes.

## 2. Key web app screens (mobile first, 360 px baseline)

**Bottom nav (4 items):** Home · Buy gas · Gift · Help. History and Settings open from Home and from the header menu.

### Onboarding (3 steps plus language)
0. **Language**: three large buttons: English / chiShona / isiNdebele (`choose_language`).
1. **Phone**: +263 prefix locked, number field with a local-format hint (`phone_hint`). We send a 6-digit OTP by SMS, with WhatsApp as a fallback. The code auto-fills using the Android SMS Retriever API. "Resend" appears after 30 s.
2. **Link meter**: a primary "Scan the code on your meter" button (camera QR scan), and a secondary "Type meter number" option with an 11-digit field grouped as 3-4-4. The meter sticker is shown as an illustration so people know where to look.
3. **Name the meter**: optional, with suggested chips ("Home", "Kumusha", "Shop"). The flow ends on Home with a first-run coach mark on the gauge.

### Home
- **Header:** meter nickname with a switcher (for users with several meters), language pill, and the connection indicator.
- **Hero gauge:** a semicircle showing kg remaining ("4.2 kg"), with "About 12 days left" underneath.
- **Status row:** a valve pill (`valve_open` green / `valve_closed` grey / leak red) and the credit balance.
- **Primary CTA:** a full-width "Buy gas" button. When the cylinder is under 20%, a secondary "Request refill" card appears.
- **Last 3 transactions**, with a "See all" link to History.
- **Distinguish two cases:** *credit empty, so the valve is closed* versus *cylinder empty, so a refill is needed*. These are different problems with different CTAs.

### Buy gas (one screen, three blocks, sticky pay button)
1. **Currency toggle:** US$ | ZiG. The default is the user's last choice.
2. **Preset chips:** $1 · $2 · $5 · $10 · Other. ZiG equivalents use the current rate, rounded to friendly numbers. Each chip shows "≈ x kg". A live line underneath reads `amount_gets_you`.
3. **Pay with:** EcoCash (default, number prefilled), InnBucks, or Card (Visa/Mastercard, mainly for diaspora).
4. **Review sheet:** "{amount} of gas for meter {meter}" plus "No extra fees", then **Confirm**.
5. **Waiting screen:** a phone illustration with "Check your phone and enter your PIN" and a 90 s countdown. For InnBucks, show the 6-digit code with Copy and "Open InnBucks" buttons.
6. **Success:** a large tick, "{kg} kg sent to your meter. Gas is on.", the receipt number, and a Share-to-WhatsApp receipt button.
7. **Failure:** "No money was taken" (the most important reassurance), with Retry and "Talk to a person" options.

### History
A list grouped by month, with icons for purchase, gift in, gift out, refill and leak event. Filter chips sit at the top. Tap a row to see the receipt. Allow export or sharing of a single receipt, not a CSV.

### Refill request
Cylinder size (9 / 14 / 19 / 48 kg chips), time window (Today PM / Tomorrow AM / Tomorrow PM), and an address given as landmark text plus an optional GPS pin. Many peri-urban and rural addresses have no street number, so the landmark field is required and GPS is optional. The confirmation says the agent will call. Tracking has three states: Booked → On the way (agent name + call button) → Delivered.

### Gift gas (diaspora)
1. Choose a recipient: saved family meters, or enter a meter number or the recipient's phone.
2. **Name check:** "This meter belongs to T. Moyo. Correct?" Show the initial and surname only, for privacy.
3. Amount presets in US$ (card, EcoCash or InnBucks), plus an optional message and an optional "Make it monthly".
4. Success, with a notification to the recipient: "{name} sent you {kg} kg of gas".
- The flow must work without an account: guest checkout by card or a WhatsApp link. Diaspora payers often top up a relative's meter once and never onboard. Offer to save the recipient afterwards.

### Safety and leak alert (full-screen takeover)
- Red background, vibration, and the sound of the system alarm channel.
- Title "Gas leak detected", then "We have shut off your gas for safety."
- Three numbered steps with pictograms: open windows, no flames or switches, go outside.
- Buttons: **Call emergency line** (tel:) and **I am safe**.
- The valve stays locked until a technician clears it (`leak_tech_coming`).
- The same alert goes out by WhatsApp, by SMS, and to up to 2 emergency contacts.

### Support
WhatsApp chat (deep link), a call button, and an FAQ with 8 illustrated answers (how to read the gauge, what days-left means, EcoCash failed, meter offline).

### Agent/admin (brief)
A separate PWA with a job list (installs, refills, leak callouts), meter lookup by QR, and valve test and clear-lock actions. It works offline and syncs later.

## 3. WhatsApp bot script

Constraints: at most 3 reply buttons, lists of up to 10 rows, and titles of 20 characters or fewer. The bot replies in the user's saved language. The examples below are in English; the Shona and Ndebele versions use the matching `bot_*` and core keys. Business-initiated alerts use approved **utility templates**.

### 3.1 First contact / registration
```
User: Hi
Bot:  Welcome to Gasguys. Cook with gas, pay a little at a time from $1.
      Choose your language / Sarudza mutauro / Khetha ulimi
      [English] [chiShona] [isiNdebele]
User: [chiShona]
Bot:  Mauya! Tine nhamba yako: +263 77 123 4567. Batanidza mita yako.
      [Tumira mufananidzo]  [Nyora nhamba]  [Handina mita]
User: [Nyora nhamba] → 123 4567 8901
Bot:  Mita 12345678901 – Mbare, Harare. Ndeyako here?
      [Hongu]  [Kwete]
User: [Hongu]
Bot:  Tatumira kodhi ye6 neSMS. Inyore pano kuti tisimbise.
User: 482913
Bot:  Mita yabatanidzwa ✓  Gasi rasara: 3.1 kg (~9 mazuva).
      [Tenga gasi]  [Ona zvasara]  [Zvimwe]
```
Because WhatsApp has already verified the phone, the OTP is only needed to confirm meter ownership: the code goes to the SMS number registered at install. "Tumira mufananidzo" means "send a photo" (of the QR). The bot decodes the QR from the image. "Handina mita" ("I don't have a meter") routes to sales / request an install.

### 3.2 Check balance
```
User: balance   (or [Check balance])
Bot:  🏠 Home · meter …8901
      Gas remaining: 4.2 kg
      About 12 days left
      Credit: $1.40 · Gas is ON
      Updated 10 min ago
      [Buy gas]  [Request refill]  [Menu]
```
If the user has several meters, a list message is sent first ("Choose meter", up to 10 rows by nickname).

### 3.3 Buy gas with EcoCash (USSD push)
```
Bot:  How much gas? (list: "Choose amount")
      rows: $1 ≈ 0.6 kg | $2 ≈ 1.2 kg | $5 ≈ 3 kg | $10 ≈ 6 kg |
            ZiG 30 | ZiG 60 | ZiG 150 | Other amount
User: $2 ≈ 1.2 kg
Bot:  Pay with? [EcoCash] [InnBucks] [Card link]
User: [EcoCash]
Bot:  Pay $2.00 from EcoCash 077 123 4567? No extra fees.
      [Confirm]  [Other number]  [Cancel]
User: [Confirm]
Bot:  📲 Check your phone and enter your PIN to approve.
      (EcoCash prompt sent; waiting up to 90 s)
Bot:  ✅ Payment successful. 1.2 kg sent to your meter. Gas is ON.
      Receipt no. GG-7F3K2 · Now about 15 days left.
      [Check balance]  [Menu]
```
- **Timeout:** "We did not get approval in time. No money was taken." [Try again] [Pay with InnBucks]
- **InnBucks:** "Your code: 834 221. Open InnBucks → Pay → enter the code." The bot confirms automatically.
- **Card:** a short hosted-checkout link. The bot confirms when the webhook arrives.

### 3.4 Gift gas to another meter
```
User: [More options] → list: Gift gas | Request refill | History |
      Safety | Language | Talk to a person
User: Gift gas
Bot:  Send gas to family. Choose or type a meter number.
      (list: Mama – Gutu | Sekuru – Lupane | ➕ New meter)
User: ➕ New meter → 987 6543 2109
Bot:  This meter belongs to T. Moyo (Chitungwiza). Correct?
      [Yes]  [No]
User: [Yes]
Bot:  How much? [$5] [$10] [Other]
User: [$10]
Bot:  Pay with? [EcoCash] [InnBucks] [Card link]
…payment as 3.3…
Bot:  🎁 Gift sent. T. Moyo has been told. Save this meter?
      [Save as family]  [No thanks]
Recipient (template): 🎁 Tendai sent you 6 kg of gas. Gas is ON.
      [Say thank you]  [Check balance]
```
"Say thank you" sends a prewritten thank-you back to the giver. It is a small touch, but it matters for the relationship the gift is part of.

### 3.5 Request refill
```
User: Request refill
Bot:  Cylinder size? [9 kg] [14 kg] [Other size]  (Other → list 19/48)
User: [9 kg]
Bot:  When? [Today afternoon] [Tomorrow morning] [Choose day]
User: [Tomorrow morning]
Bot:  Where? Share your 📍 location or type a landmark
      (e.g. "Opposite Mbare Musika, gate 3").
User: (shares location)
Bot:  Refill booked for tomorrow 8–12. We will call 077 123 4567.
      Price: $17 (pay agent by EcoCash on delivery).
      [OK]  [Change]  [Cancel refill]
Later (template): 🚚 Farai is on the way with your cylinder. [Call Farai]
```

### 3.6 Leak alert (utility template, highest priority, plus SMS)
```
⚠️ GAS LEAK DETECTED – Home (…8901)
We have shut off your gas for safety.
1. Open doors and windows
2. No flames, no switches
3. Go outside
[I am safe]  [Call emergency]  [Talk to a person]
```
If nobody taps "I am safe" within 5 minutes, the system calls the user and alerts their emergency contacts. The valve stays locked until a technician visits.

### 3.7 Low gas (utility template)
There are two separate triggers:
- **Low credit** (fewer than 2 days left):
  "Gas is running low: about 2 days left on Home. Top up now?" [Buy $1] [Buy $5] [Other amount]
- **Low cylinder** (under 15% of the kg in the cylinder):
  "Your cylinder has 1.1 kg left. Request a refill?" [Request refill] [Remind me later]

Send at most one low-gas message a day, and never between 21:00 and 06:00. The footer reads `bot_reply_stop`.

## 4. Visual direction

**Positioning:** "modern utility that feels like ours". Friendly and confident, not a bank and not a charity. It avoids Afro-pattern clichés and safari imagery. Warmth comes from the colours, the copy and real neighbourhood names instead.

| Token | Hex | Use |
|---|---|---|
| Flame (primary) | `#FF6B1A` | CTAs, brand mark, active nav |
| Ember (primary dark) | `#D94E0F` | pressed state, text on light backgrounds (AA) |
| Deep Indigo | `#14213D` | headers, dark surfaces, body text |
| Msasa Green | `#1FA35C` | Gas ON, success |
| Maize | `#FFC53D` | low-gas warning |
| Alert Red | `#E0322B` | leak and errors only |
| Granite | `#6B7280` | secondary text, OFF state |
| Mist | `#F5F3EF` | app background (warm off-white) |
| White | `#FFFFFF` | cards |

Dark mode uses `#0E1628` as the background, `#1A2540` for cards, and Flame `#FF8A45`.

- **Typography:** **Plus Jakarta Sans** (600/700) for headings and big numbers, with tabular numerals for kg and days. Use **Inter** (400/500) for body text, or skip webfonts entirely in data-saver mode (system-ui). Load at most 2 weights per family using `font-display: swap`.
- **Iconography:** rounded 2 px-stroke line icons (Lucide or Phosphor, inline SVG sprite, under 8 KB). Core metaphors are the flame (gas), the cylinder (refill), a gift with a heart (diaspora), a shield (safety) and a phone with a tick (confirm on phone). Leak alerts use a filled warning icon, not a line icon.
- **Illustration:** flat 2-colour spot illustrations for empty states and onboarding (meter sticker, phone PIN prompt). Show Zimbabwean homes and kitchens as they actually look: a 2-plate stove, a cylinder by a cupboard, a rural kitchen hut. Use SVG only.
- **Shape and motion:** 16 px radius cards and pill buttons. The gauge fill animates only on change. Honour `prefers-reduced-motion`.
- **Tone:** plain, warm, and short. Use "we" and "you", with no jargon ("valve" appears only in the status pill). Be reassuring about money: always say what happened to it. Humour is fine in empty states and never appears in safety or payment messages. In Shona and Ndebele, use respectful plural forms when addressing adults in alerts ("Bikai", "Vulani").

## 5. Translation notes (native-speaker review needed)

All sn/nd strings are drafts. Review them with speakers from Harare/Mashonaland *and* Bulawayo/Matabeleland, and test them with low-literacy users. The strings below have lower confidence:

- **`valve_open` / `valve_closed` (sn "Gasi RAVHURWA/RAVHARWA", nd "IVULIWE/IVALIWE")**: vhura (open) and vhara (close) differ by one letter. Always pair them with an icon and colour, and test comprehension. In Shona, avoid "riri kubuda" for ON, because it reads as "leaking".
- **`leak_title` (sn "Gasi riri kubuda!", nd "Igesi iyavuza!")**: confirm that these are the natural words for a gas leak. Alternatives are sn "kudonha" and nd "iyaphuma".
- **`nav_history` (sn "Zvakaitika")**: literally "what happened". An alternative is "Nhoroondo", which may feel formal. The same question applies to nd "Umlando".
- **`nav_settings` (sn "Zvigadziriso", nd "Izilungiselelo")**: many users may prefer the loanword "Settings".
- **`credit_balance` (sn "Kiredhiti yegasi", nd "Ikhredithi yegesi")**: check whether "Mari yasara" or "Ibhalansi" reads more naturally.
- **`recipient_meter`, `recipient_name_check` (sn "ndeya{name}")**: the possessive concord may need adjusting depending on the name. Consider "Mita iyi ndeya: {name}".
- **`gift_received`, `gift_sent` (sn uses the honorific "vakutumira"/"vaziviswa")**: this is fine for elders but may sound odd for peers. Test it.
- **`leak_tech_coming` (nd "Uchwepheshe")**: consider "Itekhnishiyeni" instead, and check the verb agreement.
- **`err_meter_offline`, `payment_failed` (nd "Kakho imali ethethweyo")**: check the negative construction.
- **`app_tagline` (both)**: this is marketing copy, so a copywriter should adapt it rather than translate it literally.
- **`no` (nd "Hatshi")**: this is the Zimbabwean Ndebele form. Confirm it over "Cha".
- **Loanwords:** "gasi"/"igesi", "mita"/"imitha", "vharafu"/"ivalvu", "network", "data", "wallet" and "PIN" were kept on purpose, because they are the everyday usage. Validate them with users rather than replacing them with purist terms.
