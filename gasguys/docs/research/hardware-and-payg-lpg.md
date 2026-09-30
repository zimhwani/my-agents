# Gasguys: Hardware and PAYG LPG research

Research date: 29 Sep 2026. Every claim has a source number, listed at the end. **[Inferred]** marks my own analysis or engineering judgement, which no source confirms.

---

## 0. Key correction up front

**Bboxx's Smart Cooking Valve does not meter gas. It is a time-based lock.** Bboxx told the Clean Cooking Alliance that the valve "simply switches gas on and off based on payment status". The customer gets a full 12 kg cylinder on a 30-day contract with daily payments. The valve stays open while they are paid up and closes when they fall behind [1]. It works like a solar-home-system PAYG lock, not a gram-by-gram prepaid meter.

Bboxx does not say what is inside the valve (MCU, radio, battery) in any public source [2][3]. **The ESP32 assumption cannot be verified. Treat it as unknown.**

The gram-metered model Keith describes ("credit buys gas") matches **PayGo Energy / Sun King** and **Circle Gas / M-Gas / KopaGas** [5][9][10], not Bboxx.

---

## 1. Bboxx Smart Cooking Valve, Bboxx Cook and Pulse

**Hardware (public facts only)**
- A "digitally connected gas locking device" that locks onto the LPG cylinder and controls gas access based on mobile money payments [2][4].
- 3 models by valve size: 20 mm (CK-B01), 21 mm (CK-B02), 27 mm (CK-B03). Size W15 × L20 × H14 cm, weight 1 kg, **CE-ATEX certified** [3].
- No public details on connectivity, battery, tamper design or sensing [3].
- **[Inferred]** It is almost certainly cellular (2G/LTE). Bboxx's solar units are remotely switched through Pulse [7], and nothing mentions a keypad or tokens. This is not confirmed.

**Commercial model**
- Launched Aug 2023 in Rwanda and DRC, with a plan to roll out across all 10 Bboxx markets in 2024 [2].
- Rwanda "Bboxx Cook": stove, cylinder and gas with a small down payment. The equipment is paid off over 6–12 months through a share of each refill payment [4b].
  - Setup cost is 100k–200k RWF.
  - Monthly gas costs 12k–20k RWF [4b].
- Numbers reported to the Clean Cooking Alliance [1]:
  - DRC (Goma): 25,000 customers in 1.5 years, with USAID support.
  - Rwanda: about 2,500 new customers a month.
  - Pakistan: 50,000 valves planned.
  - Customers mostly earn under $250 a month, with daily income patterns.
- Partners:
  - TotalEnergies Marketing Rwanda: target of 1M people, announced 10 Jul 2024 [4].
  - SP Rwanda [1].
  - World Bank / Government of Rwanda subsidy of about $40 per sale [1].
  - GCI / Blue Carbon for Article 6 carbon finance in Pakistan [11].
  - Gold Standard carbon programme across 5 countries [12].
- An earlier Bboxx PAYG LPG pilot in Rwanda (2019–20, studied by MECS) found [13]:
  - Customers topped up about 4 times a month, averaging 2,530 RWF (about £2).
  - Monthly spend was 10,500 RWF, about 4.2% of household income.
  - LPG was used on 85% of days.
  - Pain points: **slow credit top-ups**, **Bboxx closed evenings and weekends**, stove quality, manual processes.

**Pulse platform and third-party access**
- Pulse is Bboxx's operating system. It covers the live device map and remote on/off switching, payments, KPIs, portfolio management, and an "IoT & actions engine" [7].
- **Jan 2026:** holding company Abci‑Nexus spun Pulse out into **Asopo Technologies** as a **B2B SaaS platform for asset-financed products** in new geographies [8].
- So a partnership or licence is plausible: Keith could use Pulse as the back office or buy valves through it. **No public API documentation exists.** Keith would have to contact them directly [7][8].

---

## 2. Comparable PAYG LPG systems

| Company | Meter architecture | How credit reaches the meter | Payment rails | Status / lessons |
|---|---|---|---|---|
| **PayGo Energy** (Kenya) → **Sun King** | Cylinder Smart Meter (CSM): measures gas "by the gram", shuts off flow when credit runs out; ATEX Zone 2, first to comply with the Kenya LPG smart-metering standard (KEBS, 2019) [5][6] | Cloud or remote over GPRS. Also uses a phone app, QR tags and smart scales in the supply chain [14] | M-Pesa. 85% of transactions are under $3; the average top-up is about $1 [6] | Acquired by Sun King in 2023 [15]. Lessons [14]: cylinder visibility is the hidden cost; 99% cylinder return rate with stainless QR tags; tags cost under $2.50; staff needed heavy training |
| **KopaGas** (Tanzania) → **Circle Gas** | Low-cost smart meter on the cylinder [16] | IoT/mobile-money triggered [16][17] | M-Pesa and other wallets | Circle Gas bought it for $25M in Jan 2020 [17] |
| **Circle Gas / M-Gas** (Kenya, Tanzania) | Gram-metered meter with a balance display. Uses **Safaricom NB-IoT** and sends low-gas alerts [9]. Meters were first built in East Africa, then China, now **Italy** [10] | Online over NB-IoT | M-Pesa, from KES 1 [9] | About 400k households [10]. Kit capex is about **$140** against about **$8–9 a month** of revenue, so heavy funding needs [10]. Relies on carbon credits ($8.5M received by Dec 2024, needs Kenyan government approval) [18] |
| **Envirofit SmartGas** (Kenya, Ghana) | SIM/GPS smart meter with an electronic valve [19] | Mobile money payment remotely activates the valve [19] | Mobile money: 3,500 transactions, $2–3 every 4–5 days [19] | Pilot of about 600 installs and about 300 active users. A 20-minute in-home safety training raised comfort by 97% [19] |
| **KOKO Networks** (Kenya, ethanol, not LPG) | Fuel "ATMs" plus smart canisters | Online | M-Pesa | 1M+ customers, but went into **administration Feb 2026** after Kenya did not authorise its carbon credits [20]. **Lesson: do not rely on carbon credits for unit economics.** |
| **Angaza** | PAYG SaaS with keypad tokens, mainly solar. No LPG product found [21] | Offline keypad codes | Many wallets | Useful as a model for off-network token entry |
| **Zimbabwe** | **No PAYG LPG pilot found in public sources** (searched Sep 2026) | – | – | Greenfield **[Inferred from absence]** |

**Cross-cutting lessons**
- **Cash flow is the barrier, not price per meal** [10].
- Each household needs **$100–150 of capex** in cylinder, stove and meter [10], so plan for asset finance.
- Credit top-ups must be **instant and available 24/7** [13].
- Invisible cylinder logistics destroy margin, so tag the cylinders [14].
- Carbon finance carries regulatory risk [18][20].

---

## 3. Token and credit mechanics

**OpenPAYGO Token (EnAccess, Apache‑2.0)** [22][23][24]
- Device and server share a **32-hex (128-bit) secret key** and a **counter**. Tokens are **9 digits** (an extended mode handles larger values up to 999,999).
- Each token is derived from SipHash‑2‑4 of (starting code, value, count), truncated to about 29.5 bits.
- The device accepts only a count **higher than its last one, and at most 30 ahead**. Replaying a used token does nothing.
- Token types: add credit, set credit, and disable/enable PAYG. "Unordered" entry (added in v2.1) lets tokens be entered out of sequence.
- Implementations: Python library (`openpaygo`) and a device-neutral **C reference** for embedded use [23][24]. The old repo was archived in Oct 2023 and moved to OpenPAYGO‑python [22].
- It is **one-way**: the customer types the token into a keypad, or it arrives over SMS or Bluetooth. **No network is needed at the meter.**

**STS (IEC 62055‑41)**, the system ZESA prepaid electricity uses [25][26]
- 20-digit encrypted one-way tokens. Each token carries a Token Identifier (TID, a timestamp from a base date) to block replay.
- The **TID rollover of Nov 2024** forced key-change tokens across about 70M meters.
- Heavier than OpenPAYGO and needs STS Association licensing and a certified key-management vendor.
- **[Inferred]** Zimbabweans already know the "buy a 20-digit token, type it in" pattern from ZESA. That familiarity helps UX even if Gasguys uses OpenPAYGO rather than STS.

**Online commands** (MQTT or cellular)
- Instant, two-way, gives telemetry.
- Fails when there is no network coverage, the SIM data runs out, or the operator has an outage.

**Recommended Gasguys design: hybrid [Inferred]**
1. **Credit is a gram balance held on the meter**, kept in flash and protected against rollback by a monotonic counter.
2. **Online path:** payment webhook (EcoCash, InnBucks, card, diaspora) → server → MQTT over TLS → meter.
   - The server does not send "open the valve". It sends a **signed credit command** (Ed25519 or HMAC‑SHA256 over device_id + counter + grams).
   - The meter checks the signature, credits the balance, and replies with an ACK.
3. **Offline path:** the same payment also issues an **OpenPAYGO-style token**.
   - Use the extended token, where the value is in 10 g units, for example.
   - The token goes to the customer by SMS or WhatsApp. They type it on the meter's keypad, or tap it in over BLE from a phone app.
   - Both paths use **one shared counter**, so a credit can never be applied twice. The online path marks that counter as used, and the later token is then rejected as a replay.
4. **Store-and-forward telemetry:** the meter logs data locally and uploads it when it reconnects. Include an **emergency credit** of about 200 g, and optionally a "friendly hours" rule so the valve never closes at night mid-cook.
5. **Server-side ledger in both grams and money.** Price is locked at purchase in USD or ZiG, so exchange-rate moves do not change credit already bought.

---

## 4. ESP32-based smart LPG valve: reference design [Inferred engineering, cited where possible]

**Actuation**
- Prefer a **motorised ball valve**, or a **latching (bistable) solenoid** rated for LPG.
  - Both use power only while switching, which suits a battery device.
  - A normal solenoid draws current the whole time it is held open, which drains the battery.
- Mount it on the regulator outlet, or on a clamp-on cylinder-valve lock like Bboxx's [3].
- **Fail-closed** in these cases:
  - Low battery: close while there is still enough energy for one closing stroke.
  - Leak alarm.
  - Tamper.
  - Watchdog reset.
- Add a **manual close** knob, and never have a "fail-open" state.

**Metering options**
1. **Load cell under or around the cylinder** (HX711 or an ADS1232-class ADC).
   - Cheapest and needs no gas-path certification, since it touches no gas.
   - Weakness: can be bypassed with another cylinder, and suffers temperature drift.
   - Gives the "grams remaining" figure directly.
2. **In-line gas flow meter**: a thermal-mass MEMS sensor, or a diaphragm meter with a pulse output.
   - Accurate integration of what flows, but adds a certified part to the gas path. Used by PayGo and Circle Gas style meters [5][9].
3. **Ultrasonic**: accurate but costly and more common in utility gas meters. Overkill for a v1.

- **Recommendation:** v1 uses a load cell plus the valve, plus a flow/pressure sensor to detect "valve open but no drop in weight".
- Treat any calibration drift in customers' favour.

**Connectivity in Zimbabwe**
- Econet shows 2G/3G on IoT roaming SIMs and Telecel shows 2G/3G/LTE. **No commercial LTE-M or NB-IoT is listed yet** [27].
- **Econet plans to switch off 3G in Dec 2027.** No 2G sunset date has been announced [28].
- **SIM7070G** supports Cat‑M, NB‑IoT **and GSM/EGPRS fallback** [29]. It works on Zimbabwe 2G today and is ready for NB-IoT later.
  - SIM7080G has **no 2G**, so avoid it for Zimbabwe **[Inferred from SIMCom product line]**.
  - An LTE Cat‑1bis module with 2G fallback (e.g. A7670 class) is the alternative.
- Use a **multi-network IoT SIM** (Econet plus Telecel roaming) [27] with a local NetOne or Econet SIM as backup.
- Add **BLE on the ESP32** for pairing, the offline token tap-in and diagnostics.

**Sensors and safety**
- Gas leak sensing:
  - **MQ‑6** works for a prototype, but it draws about 150 mA for its heater, so it cannot run continuously on battery.
  - For production, use a low-power catalytic or MEMS LPG sensor, or duty-cycle the sensor while the valve is open.
- Leak detected → close the valve, sound a buzzer and send an alert.
- **Tamper detection:**
  - Enclosure switch or hall-effect sensor.
  - Load-cell anomaly, such as a sudden +12 kg with no refill event.
  - Accelerometer for movement.
  - Valve-position feedback.
  - Report "flow while valve closed".
  - Tamper → close the valve and lock it until an agent visits.
- **Certification:**
  - Competitors hold ATEX Zone 2 for anything near the gas [3][5], plus the relevant national LPG standard (KEBS in Kenya).
  - In Zimbabwe, expect **SAZ** (Standards Association of Zimbabwe) and **ZERA** LPG licensing to apply **[Inferred; confirm with regulators]**.
  - Keep the electronics outside the gas path, or use intrinsically safe design. Pressure-test the valve body.

**Power**
- Li‑SOCl₂ primary cell or Li‑ion with a small solar panel. Aim for a 12–18 month battery life.
- ESP32 in deep sleep. Wake on the valve button, BLE, a scheduled report, or cellular PSM/eDRX where supported.

**Firmware and protocol**
- ESP-IDF with **signed OTA and rollback**. Enable secure boot and flash encryption so the device keys cannot be extracted.
- **MQTT over TLS** with a per-device certificate.
  - Topics: `gg/{id}/telemetry`, `gg/{id}/cmd`, `gg/{id}/ack`.
  - Use QoS 1 with idempotent command IDs.

**Telemetry to report:**
- `grams_remaining`, `credit_grams`, `valve_state`
- `flow_or_weight_delta`, `battery_mv`
- `leak_ppm` and alarm, `tamper_flags`
- `rssi` and `network`, `fw_version`
- `last_token_count`, `temperature`

---

## 5. Where Gasguys could beat Bboxx in Zimbabwe [Inferred, grounded in cited gaps]

1. **Meter by the gram, not a time lock.**
   - Bboxx charges per day, whatever is used [1]. Gram metering is fairer and fits irregular incomes.
   - It also enables predictive refills, because the meter knows grams remaining.
2. **Works offline.** Hybrid online plus OpenPAYGO tokens (section 3) cover network gaps and the Econet 3G switch-off [27][28].
3. **Instant top-up at any hour.** This targets the specific complaints from Bboxx's own pilot [13].
4. **Diaspora gifting.**
   - A relative abroad pays by card or remittance and the gas credit goes to a family member's meter by phone number.
   - The Zimbabwean diaspora is a large source of remittances **[Inferred; quantify in market research]**.
5. **Pay in USD or ZiG.**
   - ZERA sets LPG prices in both currencies. It was $1.61/kg, or ZiG41.63/kg, from Jan 2025 [30].
   - Store credit as grams, so exchange-rate swings do not hit credit the customer already bought.
6. **WhatsApp-first.** Balance, low-gas alerts, top-up links and token delivery by WhatsApp and SMS, with USSD as fallback.
7. **Predictive refill and cylinder logistics.**
   - Swap the cylinder automatically at about 15% remaining.
   - Put QR or NFC tags on cylinders, which achieved 99% returns in Kenya [14].
8. **Agent and "community champion" network.** Champions do installs, safety training [19], collect cash and raise tamper alerts, earning commission.
9. **Capital-light model.**
   - Partner with existing LPG distributors, as Bboxx does with TotalEnergies and SP [1][4].
   - Consider licensing Asopo Pulse [8] rather than building the whole back office.
   - Treat carbon credits as upside, never as the core model [18][20].
10. **Timing.**
    - Zimbabwe's LPG use grew **17% from 2022 to 2024**, driven by power cuts and the removal of VAT on LPG (SI 195 of 2024) [30].
    - No local PAYG LPG competitor was found in public sources.

---

## Sources
1. https://cleancooking.org/news/bboxx-scaling-lpg-access-across-africa-and-beyond/
2. https://www.bboxx.com/news/bboxx-innovative-new-technology-smart-cooking-valve/
3. https://www.bboxx.com/products/smart-cooking-valve/
4. https://www.bboxx.com/news/bboxx-partners-with-totalenergies-marketing-rwanda-to-scale-clean-cooking-access-to-1-million-people-across-rwanda/
4b. https://www.bboxx.com/local-news/bboxx-rwanda-launches-bboxx-cook/
5. https://www.paygoenergy.co/cylinder-smart-meter
6. https://techcabal.com/2020/06/16/paygo-energy-cylinder-gas-meter-saisan-japan/
7. https://www.bboxx.com/technology/
8. https://www.bboxx.com/press-releases/abci-nexus-launches-software-company-asopo-technologies-to-power-africa-s-financed-future/
9. https://www.safaricom.co.ke/media-center-landing/press-releases/safaricom-m-gas-empower-millions-of-kenyan-homes-with-affordable-prepaid-gas
10. https://businessfocusmagazine.com/2026/09/10/circle-gas-pay-as-you-cook/
11. https://www.bboxx.com/press-releases/gci-bboxx-launch-clean-cooking-initiative-in-pakistan/
12. https://www.renewableenergymagazine.com/panorama/bboxx-launches-panafrican-carbon-credit-program-for-20240924
13. https://mecs.org.uk/wp-content/uploads/2021/04/Understanding-Pay-As-You-Go-LPG-Customer-Behaviour.pdf
14. https://mecs.org.uk/wp-content/uploads/2020/12/MECS-TRIID-PayGo-Energy-Final-Project-Report.pdf
15. https://www.engineeringforchange.org/news/paygo-joins-sun-king-scale-clean-cooking-africa/
16. https://www.gsma.com/solutions-and-impact/connectivity-for-good/mobile-for-development/gsma_resources/kopagas-mobile-enabled-pay-as-you-cook-service-in-tanzania/
17. https://circlegas.co.uk/kopagas-acquisition/
18. https://www.businessdailyafrica.com/bd/corporate/industry/m-gas-parent-firm-eyes-sh3-4bn-carbon-credits-5354832
19. https://shellfoundation.org/wp-content/uploads/2024/08/SF-ENvirofit-SmartGas-Report-5MB.pdf
20. https://en.wikipedia.org/wiki/KOKO_Networks
21. https://www.angaza.com/home-solar-system/
22. https://github.com/EnAccess/OpenPAYGO-Token
23. https://github.com/EnAccess/OpenPAYGO-python
24. https://enaccess.github.io/OpenPAYGO-docs/docs/openpaygo-token/setting_up_openpaygo
25. https://www.esi-africa.com/international/sts-compliant-prepaid-meters-tid-rollover-three-years-to-go/
26. https://standards.iteh.ai/catalog/standards/iec/a9fbe141-a607-402e-9652-07b0c4639dac/iec-62055-41-2018
27. https://onomondo.com/iot-sim/the-best-iot-sim-cards-for-zimbabwe/
28. https://fingaz.co.zw/2026/09/11/econet-set-to-sunset-3g-network/
29. https://www.dfrobot.com/product-2870.html
30. https://www.heraldonline.co.zw/lpg-gas-usage-jumps-1714pc-over-three-years/
