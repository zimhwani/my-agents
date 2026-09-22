# Hair Done brand

This answers to `build-brief.md`. Where the two disagree, the brief wins.

## Essence

Your most put-together friend. The one who knows a nail tech in every suburb and sends you the number before you've finished asking.
Hair Done is the number.

## Promise

A vetted pro comes to you, does the job properly, and you pay in the app. You know the price, the time and who's coming before you tap Book.
If she cancels, every dollar comes back. If she's good, you book her again in two taps.

## Who she is

### Clients

**Ruby, 31, Brunswick East.** Producer at a small agency, mostly from the kitchen table. Her sister's wedding is in Daylesford in March and she's the one organising four bridesmaids in an Airbnb with one bathroom. Three nail techs on Instagram have left her on read this month. She wants to see the work, see the price and be done with it.

**Anita, 44, Glen Waverley.** Two kids, a dog, a Saturday that starts at 6am. She has not sat in a salon chair for two hours since 2019 and does not intend to start. What she wants is a blow-dry at 4 on a Friday while the kids are at swimming, and to pay without finding her wallet.

### Pros

**Kiara, 27, Coburg, nail tech.** Six years in. Left the salon in 2024 because she was clearing $28 an hour on $90 sets. Her French tip is genuinely very good. Her bookings live in her DMs, her deposits live in her PayID history, and she lost two clients last month to messages she found too late.

**Mel, 38, Werribee, hair stylist.** Bridal and event hair, 15 years, a kit that fits in the back of a Corolla. Her clients are loyal and found by word of mouth, which means October is full and June is empty. She wants the empty weeks filled by women in her area, not another reason to post.

## Personality in three words

Warm. Direct. Cheeky.

In that order. Warm first: she's on your side. Direct second: she says the price and the time. Cheeky last, and least: one raised eyebrow per screen, never a wink.

## The wordmark

`hair done, nails done, everything done.`

- All lowercase, always. Including the first letter. Including on the App Store page.
- Serif: `Font.system(.largeTitle, design: .serif).fontWeight(.medium)`. Never bold. Never italic; the one italic word is for headlines, not the mark.
- The full stop at the end is part of the mark. It stays.
- One line: commas between clauses and one full stop at the end, exactly as above. Use on the about screen, receipts and anywhere the mark sits in running layout.
- Stacked: one clause per line, each ending in its own full stop.

  ```
  hair done.
  nails done.
  everything done.
  ```

  Use on the splash and welcome screens. Never break mid-clause, never two clauses on one line and one on the next.
- Colour: `ink` on `paper`. `paper` on `lacquer` on the welcome hero and nowhere else. Never `lacquer` type.
- Tracking: default. Don't letterspace a serif.
- Short form in running copy and as the home-screen label: `Hair Done`. Never "HairDone", "HAIR DONE" or "hair done" mid-sentence.

## Where the name comes from

Drake, "Fancy": *nails done, hair done, everything did.* The app flips the order
and finishes the verb, but the meaning is the lyric's: a woman who is
completely put together, every single thing ticked off, and unbothered about
it. Everything in the brand should feel like the second half of that line.
Nod to it; don't quote the verse, and don't use "Fancy" as a name. It's his.

## The mark

**hd. nd.** Two lines of lowercase serif italic, the initials of *hair done*
and *nails done*, each finished with a lacquer-red full stop. It's the wordmark
compressed to four letters, so the icon and the first screen are the same
object, and a stacked lowercase monogram reads as fashion, not banking.

The full stops are the point. They're the "done".

History, so nobody repeats it: v1 was a red nail-polish drop (read as blood).
v2 was a single red full stop (read as nothing). v3 was three stacked full stops
(read as the "more" menu). A nail-polish bottle came second in the designer's
scoring and is a good alternate icon later; see docs/design/icon-concepts.md.

Geometry, on a 1024 canvas: type at 31% of the height per line, lines set
solid (line height 98% of the size), block centred, italic New York medium.
Each full stop is a circle of diameter 6.2% of the canvas, sitting on the
baseline just after the *d*, in `lacquer`. Light: ink on paper. Dark: paper on
ink, lacquer at its dark value. Tinted: everything white as a mask.

`tools/render-icon.swift` draws it with the real New York on a Mac. The
committed PNGs were drawn with a stand-in serif and should be regenerated once.

Rules:
- The in-app mark is `DropMark` (now a dot) only where a small glyph is needed;
  prefer the wordmark. On the welcome screen the `hd. nd.` line sits above the
  full wordmark.
- Never set it in roman, never all-caps, never add a third line, never let the
  dots be anything but lacquer.
- Minimum clear space: the height of the *h* on all sides.

## Colour

Tokens are in the brief, section 4. Rules for using them:

1. One accent. `lacquer` goes on the primary button, the selected chip, the active tab, a link in body copy. If two things on one screen are lacquer, one of them is wrong.
2. `paper` is the background. Not white. `card` (white) is for cards and sheets sitting on paper, and for nothing else.
3. Text is `ink` or `inkSoft`. Never lacquer body text. Never `inkSoft` on `lacquerSoft`, the contrast fails.
4. `honey` is stars. Only stars. Not warnings, not highlights, not a third accent.
5. `success` and `warn` are for status and nothing else. Confirmed, done and paid are `success`. Requested and pending are `warn`. Cancelled and declined are `inkSoft`. A cancelled booking isn't an emergency and shouldn't be red.
6. `lacquerSoft` sits behind lacquer text or icons: the Instant book chip, a selected category. Small areas only.
7. Category tints go on tiles and chips as backgrounds. Text on them is `ink`. A category tint is never a button and never a status.
8. Dark mode swaps the tokens and changes nothing else. No pure black, no pure white.
9. Contrast: `ink` on `paper` is about 15:1, `inkSoft` on `paper` about 5.3:1, `paper` on `lacquer` about 4.7:1. All pass AA at body size. Don't go smaller than `sub` on a lacquer button.

## Type

- Two faces. Serif for display (`hero`, `title`, `heading`). SF Pro for everything else. There is no third.
- Serif is for words a person would say out loud: greetings, pro names, "You're booked.", the wordmark. Not labels, not prices, not buttons, not table headers.
- Buttons: `body` 17, semibold, SF. Never serif on a button.
- Prices: `.monospacedDigit()`, `ink`. Dollar sign always. No cents on whole dollars ($180, not $180.00). Cents when they exist ($47.50). Totals at `title`, line items at `body`.
- One italic word per screen, at most, inside a serif headline, on the word you'd lean on if you said it. "Kiara does a *very* good French tip."
- `label` (12, uppercase, tracked 0.08em) is for section eyebrows only: NEAR YOU, THIS WEEK. If it's tempting on a button or a chip, no.
- Sentence case everywhere. Full stops on sentences, none on labels or buttons.
- Never letterspace the serif. Never fake-bold it. Never set it in all caps.
- Dynamic Type stays on. The serif scales; give it room rather than clamping it.

## Photography

Direction:

- Real work by real pros. Every photo on a profile was taken by the pro whose profile it is, of a job she did. No stock, no product shots.
- Natural light. A window, a balcony, a kitchen bench at 4pm. A ring light is fine because that's what she owns; the photo just shouldn't look like one.
- Hands and hair. Nails on a hand holding a coffee, a phone, a car key. Hair from behind, from the side, mid-curl, being pinned. A face is optional, and when there's a face it's there because the client wanted to be in it.
- Close. Crop in until the work fills the frame, not the room.
- Warm. Placeholders are the warm procedural gradient with grain from the brief, tinted by category. Never a grey box, never a broken-image icon.
- Photos do the talking. Text sits beside them, not on them. No captions burned into images, no overlays, no rounded-corner-with-drop-shadow treatment.

We never show:

- Stock photography. No woman laughing at nothing.
- Salons. Chairs, mirrors, basins, reception desks. She comes to you; that's the point.
- Before shots without the client's say-so, and never as a split-screen.
- Clients' faces where they didn't tick the box.
- Kids, even at the bride's mum's place.
- Another brand's logo in focus.
- Heavy retouching. No skin smoothing, no teeth whitening, no waist edits.
- Product. There isn't one.
- A pro's photo on anyone's profile but hers.

## Tone by moment

**Onboarding.** Quick and low-key. One thing per screen, and say why we're asking. "First name's fine. It's what she'll see when you book." Not "Complete your profile".

**Booking.** Concrete and calm. Price, time and suburb on every step. The button says what it does: `Book`, `Pay $180`. No "Continue".

**Waiting** (requested, not yet confirmed). Reassuring, no promises we can't keep. "Kiara usually replies within an hour." Never "Hang tight!". Never a spinner with a slogan.

**Done.** One clean moment, then the detail. "You're booked." on its own line, the lacquer check draws itself, then "Sit tight, she's on her way at 6:15." That's the whole celebration. No confetti.

**Something went wrong.** What happened, what we did, what she can do. In that order, in three short sentences or fewer. "That card didn't go through. Nothing's been charged. Try another, or Apple Pay." No "oops", no apology loops.

**Money.** Plain and complete. Every fee has its own line. The hold is explained in one sentence before the pay button, not after. The cancellation policy is on the review screen, in full, in the brief's words. Nothing is revealed on a receipt that wasn't on the review screen.

## How to tell if copy is off

- Could a bank have written it? Off.
- Is a word from the banned list in section 3 of the brief in there? Off. Check every time, not from memory.
- Could you swap in "customer" without it reading any differently? Then it isn't talking to her. Off.
- Does it say the price, the time or the suburb when it could? If not, off.
- Is the headline a question she didn't ask? Off.
- Would you text it to a friend? If you'd be a bit embarrassed, off.
- Is there an exclamation mark? Is there a second one anywhere on the screen? Off.
- Does the button say what happens next? "Continue" where it could say "Pay $180" is off.
- Title case? Off. Emoji? Off.
- Does it say "we" where it could say "she"? The pro is the hero; Hair Done is the friend who introduced you. If we're centre stage, off.
- Read it out loud. If you ran out of breath, cut it in half.
