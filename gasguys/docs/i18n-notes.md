# Translation notes

All customer-facing text lives in [core/i18n/strings.json](../core/i18n/strings.json), keyed the same in English (`en`), Shona (`sn`) and Ndebele (`nd`). The web app and the WhatsApp bot both read it, so a fix there fixes both.

**Every Shona and Ndebele string is a draft and needs a native speaker's review before customers see it**, ideally one reviewer from Harare/Mashonaland and one from Bulawayo/Matabeleland, then a quick test with low-literacy users. The words to check first (open/closed, leak, history, credit) are listed in [ux-spec.md](ux-spec.md) §5.

These 27 strings were added while building the prototype, after the UX pass, and have had even less scrutiny:

| Key | English | Shona (draft) | Ndebele (draft) |
|---|---|---|---|
| `meter_label` | Meter | Mita | Imitha |
| `meter_taken` | This meter is already linked to someone else. | Mita iyi yakabatanidzwa kune mumwe munhu. | Imitha le isixhunywe komunye umuntu. |
| `bot_link_prompt` | Type the 11-digit number on your meter sticker. | Nyora nhamba ine manhamba 11 iri pachitambi chemita yako. | Bhala inombolo yamadijithi ali-11 esesitikheni semitha yakho. |
| `bot_choose_meter` | Choose meter | Sarudza mita | Khetha imitha |
| `bot_type_amount` | Type an amount, e.g. 3 or ZiG 50 | Nyora mari, semuenzaniso 3 kana ZiG 50 | Bhala imali, isibonelo 3 kumbe ZiG 50 |
| `bot_card_link` | Pay by card here: {url} | Bhadharai nekadhi pano: {url} | Bhadala ngekhadi lapha: {url} |
| `innbucks_code` | Your InnBucks code: {code}. Open InnBucks → Pay → enter the code. | Kodhi yenyu yeInnBucks: {code}. Vhurai InnBucks → Pay → isai kodhi. | Ikhodi yakho ye-InnBucks: {code}. Vula i-InnBucks → Pay → faka ikhodi. |
| `token_enter` | {kg} kg is ready. If your meter is offline, enter this token on it: | {kg} kg yagadzirira. Kana mita isina network, isai tokeni iyi pamita: | U-{kg} kg usulungile. Nxa imitha ingelayo inethiwekhi, faka ithokheni le emitheni: |
| `token_title` | Offline token | Tokeni (pasina network) | Ithokheni (kungela nethiwekhi) |
| `bot_agent_soon` | A person from Gasguys will reply here soon. | Mumwe wedu achakupindurai pano munguva pfupi. | Omunye wethu uzakuphendula lapha masinyane. |
| `bot_safe_thanks` | Thank you. Stay out until a technician has checked. | Tatenda. Musapinda mumba kusvikira technician atarisa. | Siyabonga. Lingangeni endlini uze uchwepheshe ahlole. |
| `refill_slot_today_pm` | Today afternoon | Nhasi masikati | Lamuhla ntambama |
| `refill_slot_tomorrow_am` | Tomorrow morning | Mangwana mangwanani | Kusasa ekuseni |
| `refill_slot_tomorrow_pm` | Tomorrow afternoon | Mangwana masikati | Kusasa ntambama |
| `bot_no_meter` | You don't have a meter linked yet. | Hamusati mabatanidza mita. | Kawukabi lemitha exhunyiweyo. |
| `bot_didnt_understand` | Sorry, I didn't get that. | Ndine urombo, handina kunzwisisa. | Uxolo, angizwisisanga. |
| `refill_status_requested` | Booked | Zvabhukwa | Kubhukiwe |
| `refill_status_scheduled` | Scheduled | Zvarongwa | Kuhleliwe |
| `refill_status_out_for_delivery` | On the way | Vari munzira | Basendleleni |
| `refill_status_delivered` | Delivered | Zvaunzwa | Kulethiwe |
| `cylinder` | Cylinder | Silinda | Isilinda |
| `see_all` | See all | Ona zvese | Bona konke |
| `gift_from_card` | Paying from abroad? Use a card. | Muri kunze kwenyika? Shandisai kadhi. | Ulaphandle kwelizwe? Sebenzisa ikhadi. |
| `your_name` | Your name | Zita renyu | Ibizo lakho |
| `sandbox_note` | Test mode: no real money moves. | Kuedza: hapana mari chaiyo inobhadharwa. | Ukuhlola: akulamali yangempela ethunyelwayo. |
| `sign_in` | Sign in | Pinda | Ngena |
| `meter_offline` | Your meter is offline. Gas you buy also comes as a token you can enter on it. | Mita yenyu haisi pa network. Gasi ramunotenga rinouyawo setokeni yamunogona kuisa pamita. | Imitha yakho ayikho enethiwekhini. Igesi oyithengayo ifika njengethokheni ongayifaka emitheni. |
