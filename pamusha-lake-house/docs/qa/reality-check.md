# Reality check — Pamusha Lake House site

**Reviewers:** Reality Checker + Brand Guardian · **Date:** 2026-09-17
**Verdict:** NEEDS WORK. Structure, voice and safety framing are mostly good; the site is not launchable until the Must-fix items are cleared, because a public visitor can currently see placeholder credentials and a fabricated review.

**Evidence:** every page read in full; `grep` for `TODO`, `!`, banned words and placeholder values; `.todo` styling checked in `main.css` (apricot highlight, weight 500 — visually obvious). No exclamation marks anywhere. No "nestled", "stunning" or "paradise". Facts cross-checked against `docs/research/property-facts.md` and `research-brief.md`.

---

## Must fix

1. **Fabricated review — index.html #reviews.**
   Now: *"Room for all of us, and the hot tub by the lake was the highlight of the weekend."*
   No source in property-facts.md (only two paraphrases exist). Delete it.
   Also soften the second: *"The deck at night is something else. We sat out with blankets and just watched the stars."* → *"A lovely deck for stargazing."* ("blankets", "something else" are invented.)

2. **Placeholder secrets look real — house-manual.html.** `0000` (lockbox), `changeme` (Wi-Fi) and `+61400000000` (three `tel:`/`sms:` hrefs) sit in `<code>` with working Copy buttons and are NOT inside `.todo`; only a separate small note is highlighted. If the owner fills the note and misses the value, guests copy "0000". Wrap the values themselves: `<code><span class="todo">TODO code</span></code>`, and give the buttons `href="#"` until set.

3. **Lockbox code must never be on a public URL.** The manual is linked from every footer and the 404 page; `noindex` and robots.txt do not stop sharing. Replace the lockbox card with: *"We'll message you the lockbox code the day before you arrive."* Same logic for Wi-Fi: keep a guest network only (the TODO already says so).

4. **Hospital phone number is unsourced — house-manual.html #emergency.** `03 5143 8000` appears in neither research doc. A wrong number on an emergency card is real harm. Verify on cghs.com.au or remove, leaving name, "24-hour ED", "about 40 min" and the Directions link.

5. **`"petsAllowed": false` — index.html JSON-LD.** Not in the fact sheet, and the manual says *"Keep pets on a lead in the Coastal Park."* Remove the property until the owner decides; align the manual line.

6. **Enquiry form goes to hello@example.com — main.js.** `WEB3FORMS_KEY` is blank, so every public submission opens `mailto:hello@example.com` and the status text prints that address. Either set the key or set `ENQUIRY_EMAIL` before deploy; add a guard that hides the form and shows "Email us on Airbnb" if both are unset.

7. **"Book on Airbnb" sends visitors to a competitor search — main.js.** Fallback `AIRBNB_URL` is a search for all Honeysuckles homes. Until the listing URL is pasted, point the buttons at `/#enquire` instead.

8. **Unsourced safety claim — house-manual.html #safety.**
   Now: *"Smoke alarms are hard-wired."* → *"Smoke alarms are <span class="todo">TODO: hard-wired / battery, and where the test button is</span>."*

## Should fix

9. **Beach advice contradicts itself.** explore.html: *"swim between the flags at Seaspray in patrol season and paddle rather than swim elsewhere."* The manual says *"never at the unpatrolled beach near the house."* "Paddle" at an unpatrolled rip beach is still an invitation. Rewrite explore: *"It's an open surf beach with strong rips. Life Saving Victoria's advice is simple: swim only between the flags, which means Seaspray in patrol season. Near the house, walk it."*

10. **Rating attributed to the wrong platform — index.html.** *"10 / 10 · 'Exceptional' on our booking listing"* sits beside *"Read every review on Airbnb."* Airbnb uses 5 stars; 10/10 Exceptional is the Vrbo/Expedia-syndicated listing. Change to *"10/10 'Exceptional' on Vrbo"* only if confirmed; otherwise *"Rated 'Exceptional' by guests on our booking listings"* and the button *"Read our reviews on Airbnb."*

11. **Assumed policies stated as fact on marketing pages** (index #enquire "Good to know"): *check-in 3 pm / check-out 10 am* [ASSUMED], *"Hot tub and fire pit are included in every stay"* (invented; firewood supply/charge unknown), *"We reply within a day"* (also in the JS success message). Owner confirms times; change to *"Firewood for the hot tub and fire pit is <TODO: provided / available for $>"* on the manual only, and *"We usually reply within a day."*

12. **Invented household facts in the manual** — each should become a `.todo`: *"Blankets are in the second living room"* (also contradicts the Linen card's TODO); *"Detergent is under the sink"*; *"Wood is with the hot tub supply"*; *"the bucket beside it"* (fire pit — a safety fixture that may not exist); *"Quiet hours 10:00 pm – 8:00 am"*; *"Beds are made for the number of guests booked."*

13. **Hot tub steps are generic** (*"Open the air vent… stir… thermometer"*). Add one line at the top: *"These are our notes; the instructions on the stove itself take precedence. Never leave the fire unattended."* Owner confirms vent, thermometer and target temperature.

14. **Snake card lacks first aid.** Append: *"If anyone is bitten: call 000, keep them still, and apply a firm pressure bandage over the bite and up the limb (Ambulance Victoria guidance)."*

15. **Over-claims vs. fact sheet (Plausible-but-unverified — soften or owner confirms):**
    - the-house.html hero: *"…a long undercover deck, all facing the water."* The garden room "looks into the bush" two screens later. → *"…and a long undercover deck facing the water."*
    - *"Kookaburras at dawn"* / *"the first kookaburra of the morning"* (index, the-house). Not in the wildlife research (cockatoos, eagles, robins are). → *"Cockatoos at dawn"* or owner confirms.
    - *"linen bedding"* (alt text, index bed-2 and the-house bed-1); *"deep sofas"* (alt). Drop the material words.
    - Amenities: *"Cookware for a crowd"*, *"Linen & towels provided"* — not in facts. Owner confirms, else cut.
    - *"Gas cooktop & oven"* (two chips) — fact sheet says "gas appliances"; oven fuel unknown. → *"Gas cooktop"*.
    - Room names and orientations (*"The lake room… soft morning light… close to the main bathroom"*, *"The garden room… bushland outlook… quietest corner"*, *"enough bench for two"*, *"a table long enough for everyone"*, *"Native garden running into the Coastal Park"*, *"films"* in the second lounge implying a TV). All invented colour. Keep the names if the owner confirms which queen room faces which way; otherwise neutral copy.
    - explore.html: *"One of the longest uninterrupted beaches in the world"* → *"One of the longest beaches in Australia"*; *"the wreck of the Trinculo a walk down the sand"* → *"about 6 km down the beach"* (research); *"Golden Beach café… the general store next door"* — name and "next door" unverified; *"cool-climate wines, long lunches"* unverified; *"Black swans, pelicans"* not in research (common, low risk); *"Clearest skies of the year"* invented.
    - explore.html **Criterion Hotel, Sale**: the research line carries **[UNVERIFIED names — confirm before publishing]**. Either confirm it exists as described or replace the card with *"Sale pubs — ask us for this week's pick."*
    - Seaspray General Store *"fish and chips at the beach in the evening"* — evening hours unverified → *"fish and chips to take to the beach."*

## Nice

16. **Voice.** Clean on the hard rules. Small trims:
    - index: *"Perfect for kids, cousins, or the one who always draws the short straw."* → *"For kids, cousins, or whoever draws the short straw."*
    - the-house: *"A calm queen room with soft morning light."* → *"A queen room with morning light."* index: *"A quiet queen room with soft light and space to unpack for a long stay."* → *"A quiet queen room, with space to unpack."*
    - the-house CTA *"Ready for lake time?"* → *"Check dates."* (brand CTA list).
    - index tile *"Lake / Front"* is OTA-speak; *"Walk / to the beach"* names the place.
    - explore: *"the hot tub at midnight"* vs. manual quiet hours 10 pm → *"the hot tub after dark."*
17. Geo coordinates in JSON-LD are approximate; fine for a locality, note for the owner.
18. Lake Wellington *"near Sale… an easy day trip"* — nearest ramp unverified; harmless but say "via Sale".

## Reviews — recommended treatment

The `<cite>` label *"Guest review, paraphrased from our listing"* exists but the blockquote styling reads as verbatim. Use two paraphrases only, in prose rather than quote marks, under one clear label:

> **What guests said, in our words.** Guests describe a beautiful property and a relaxing stay, and keep mentioning the deck for stargazing. Read the originals on Airbnb.

## Owner TODO inventory

| Location | Visible to public? | Obvious? |
|---|---|---|
| house-manual: host mobile (×4), address (×2), landmark, lockbox location + code, parking, Wi-Fi name + password, router, heating, TV, laundry, water, hot water, switchboard, linen, firewood, tub temperature, drain rule, oven, gas bottle, dishwasher tablets, coffee/pantry, BBQ, bin alternation, bin location, snake catcher, extinguisher, first-aid kit | Yes — footer link on every page | Notes yes (apricot); the values `0000`, `changeme`, `+61400000000` **no** (see #2) |
| main.js: `AIRBNB_URL`, `WEB3FORMS_KEY`, `ENQUIRY_EMAIL` | Effects are public (#6, #7) | Comment only — invisible to owner in the browser |
| index/the-house/explore | None found — clean | — |

**Rating:** B- copy, C+ launch-readiness. One revision cycle after the owner supplies facts, then re-check the manual with the placeholders filled.
