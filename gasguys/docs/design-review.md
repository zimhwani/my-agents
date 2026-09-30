# Design review: why the prototype reads as AI-made, and what replaces it

Keith's note was that the web prototype "looks too much like it's been built by AI". He's right. The flows and the information architecture in `ux-spec.md` hold up. The visual layer is the problem: it's the default template that code generators produce for any product.

## The tells

1. **Everything is a white card with one radius.** The cylinder, history, gift, amount, payment and settings blocks are all white rectangles with a 16–20 px radius and a 1 px beige border, stacked with equal gaps. Nothing is more important than anything else, so the eye has nowhere to land.
2. **A dark navy hero with a radial orange glow**, used on both Home and Welcome. It's the stock "fintech dashboard" header. It has nothing to do with gas or Zimbabwe.
3. **A generic semicircle gauge with a flame emoji-style glyph in the middle.** It decorates rather than informs: it doesn't say what 100% means, and it duplicates the number beside it.
4. **Pill badges for everything**: status, connection, the money equivalent, even the language picker and the settings button. When everything is a pill, a pill carries no meaning.
5. **Glyphs standing in for icons**: `⚙︎` for settings, `→` after links, `✓` in text, 📲 and 💳 emoji on the payment screen, 🔥 📵 ⚠️ 🎁 in the simulators. They render differently on every phone, and they look improvised.
6. **Same-weight headings everywhere.** Every heading is Plus Jakarta Sans 700–800 at 16–24 px. The biggest number on Home was kg, but the spec says people plan in *days*.
7. **Template copy and layout**: "Hello Tendai" above the meter number, "Nothing here yet", "See all" in orange, and a 🎁 promo card at the bottom.
8. **An orange full-width button with white text.** It's the most generic CTA there is, and it fails WCAG AA: white on `#FF6B1A` is about 2.9:1.
9. **Fonts that did nothing.** Plus Jakarta Sans + Inter is the most common AI pairing, and it loaded from Google Fonts, so offline (and in the screenshots) the app fell back to whatever sans the phone had.
10. **A logo that's a flame in a rounded square**: the app-icon cliché. It also sat in the Studio bar, in the WhatsApp avatar and in the favicon without being adapted to any of them.
11. **The simulators and the Ops console were in a different visual world**: a navy "gamer" device, an emoji-strewn button grid, and KPI cards with pills.
12. **No brand idea.** The only things tying it to LPG were the colour orange and a flame, and neither says anything about how Gasguys actually works.

## The idea: read your gas like a meter, keep it like a receipt

Gasguys is a utility, and people in Harare and Bulawayo already know how prepaid utilities look: the ZESA token slip, the LCD on the meter box, the tuckshop price board, the EcoCash PIN prompt. The redesign borrows those *forms*, because they carry meaning users already have. It doesn't use their decoration, and it doesn't use "African" pattern motifs.

- **The readout.** Home leads with *days*, set huge in condensed figures ("6 days"), with the kg and the dollar value as a quieter second line. Under it sits a strip of the next 14 days, numbered by date and filled up to the day the gas runs out. It answers the real question ("will it last until Friday / month-end?") in a way no gauge can. It works like the segmented bar on a meter LCD or a phone battery.
- **The price board.** Amounts are a board of price → kg tiles ("$2 · 1.08 kg"), the way a tuckshop chalks up prices. Home carries the same board, so a top-up starts with one tap on a price.
- **The slip.** Success, the offline token and history are printed matter. The receipt has a torn edge, mono figures, dotted leaders, and the offline token boxed in 4-digit groups the way a ZESA slip prints it. History is a ledger, not a list of cards.
- **The prompt.** The payment waiting screen shows the EcoCash prompt the customer is about to see on their phone (amount, GASGUYS, ref, PIN field), so they recognise it and trust it, instead of an emoji of a phone.
- **The cylinder as an object.** The mark is a gas cylinder silhouette with its collar and a flame-orange fill line. The refill picker draws 9/14/19/48 kg cylinders at their relative sizes, and the home cylinder row uses the same drawing with its real fill level.

## System

- **Type:** **Archivo** (variable, width 62–125) does everything. Condensed heavy widths make signage-style numbers and headings; normal width at 400–600 is the body. **JetBrains Mono** is the receipt/token/meter-number face. Both are bundled locally with `@fontsource`, and the Google Fonts link is gone. Numbers use tabular figures throughout.
- **Colour:** warm near-black ink on paper (`#16140F` on `#F5F2EB`) for maximum sunlight contrast. Flame orange is kept, but it's used for three things only: the brand mark, the gas level, and the primary action. Primary buttons are orange with *ink* text (6.4:1) rather than white text (2.9:1). Links use a darker ember `#A63C07`. Green means only "gas is on / paid", amber only "running low", red only "leak / failed". The navy is retired as a surface colour. Navy plus orange is a large part of why §4 of the spec looked like every fintech app.
- **Shape:** a tight radius scale: 3 px (tags), 6 px (controls), 12 px (the readout and sheets). Hairline rules separate sections instead of cards. The only raised surfaces are the readout, the receipt and the leak sheet.
- **Spacing:** a 4-based scale (4/8/12/16/24/32/48). Sections get 24–32 px, and rows inside them get 12–16 px, so grouping comes from spacing, not boxes.
- **Icons:** a custom 24 px set with a 1.75 px stroke, drawn for this product: cylinder, valve, flame, gift, receipt, account, arrow, check, signal, window, no-flame and exit pictograms for the leak steps.
- **Accessibility:** every tap target is ≥ 44 px (most are 48–56). Body text is 16 px. State is always spelled out in words beside its colour. Layouts wrap for Shona/Ndebele strings about 40% longer than English, and headings use `text-wrap: balance`.

## Where this departs from ux-spec §4

- **"16 px radius cards and pill buttons"** and **"Deep Indigo for headers/dark surfaces"** were dropped. They're the root of the generic look. Indigo is retired, and warm ink does its job.
- **The "hero gauge: a semicircle"** is replaced by the day strip, for the reasons above.
- **Plus Jakarta Sans + Inter** are replaced by Archivo + JetBrains Mono. The fonts are bundled, and only 2 files load on first paint: about 90 KB for Archivo (all widths and weights) and about 21 KB for the mono. The latin-ext subset (~86 KB) downloads only if a page uses those characters, which en/sn/nd text doesn't. That's heavier than one static weight, but it replaces 5 Google font files and works offline and in the artifact build.
- **Flame orange** is no longer a text or active-nav colour. The active nav item is shown with ink plus an orange top bar, which avoids the AA failure.

## What changed, screen by screen

- **Onboarding:** the navy welcome hero is gone. In its place: a big condensed headline, the language question in all three languages, and radio rows that show each language's own "Buy gas" as a sample. There's a 6-cell OTP field, and the valve sticker is drawn with a QR and the number highlighted where it's printed.
- **Home:** the meter identity (suburb and number) replaces "Hello Tendai". The readout leads with *days*, then shows credit in kg and $, the 14-day strip, and the run-out date. Below that are the price board (tap $2 to start a $2 top-up), the cylinder row with the cylinder drawn at its real level, a 3-line ledger, and gifting as a single quiet row at the bottom.
- **Buy / Gift:** a price-board grid (the selected price is inverted to ink), a "gets you" line with an orange rule, payment methods as radio rows, and a sticky bar with the trust line and "Confirm · $2.00". Gift keeps the name check as a single confirm row.
- **Paying:** a rendering of the EcoCash prompt they're about to see, the instruction, a mm:ss countdown with a draining rule, and the receipt number in mono. InnBucks shows the code as 3+3 cells.
- **Success:** a torn-edge receipt with dotted leaders and the kg as the total. When the meter is offline, the offline token is boxed on the slip. **Failure:** the headline and "No money was taken" are split so the reassurance reads on its own line.
- **History:** a ledger grouped by day, with the time, what happened, and the method · ref, plus +kg on the right. Failed rows are struck through. The empty state is an outline receipt, a line of explanation and a Buy gas button.
- **Refill:** cylinder sizes drawn at relative heights (a 48 kg cylinder towers over a 9 kg one), delivery slots as radio rows, and a vertical tracking stepper.
- **Settings:** language as radio rows, support as list rows with icons, safety as a note, and the sandbox note in a dashed box so it can't be mistaken for product UI.
- **Leak alert:** a condensed 50 px headline, three steps with drawn pictograms (window, no flame, walk out), and the call button showing the number itself (993).
- **Studio / meter / ops:** the Studio bar moves from navy to paper, with underline tabs and mono captions. The valve is drawn as a cream plastic box with a framed LCD and physical keys, and its emoji are replaced with icons. Ops gets a ruled KPI strip, flat tables and small status tags. WhatsApp keeps WhatsApp's look, with a real verified badge, read ticks and a list icon in place of glyphs.
