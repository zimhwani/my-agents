const pptxgen = require("pptxgenjs");

// ============================================================
// PALETTE — "Heritage Mutual": Forest-ink · Brass · Warm ivory
// A member-owned bank is old, trusted, community-rooted — not a
// fintech. The palette says heritage without saying "old-fashioned":
// a deep forest-ink dominates (60-70%), warm ivory carries the
// content, and a single brass accent does all the emphasis.
// ============================================================
const INK      = "13221C"; // near-black forest — dominant dark
const INK2     = "1C3227"; // tonal watermark on dark (ghost numerals)
const BRASS    = "C69A5B"; // accent for display / dark grounds
const BRASS_DK = "9C7538"; // accent for small text on ivory (contrast)
const PAPER    = "F4F1EA"; // warm ivory — light content bg
const PAPER2   = "EAE4D7"; // panel tint on paper
const HAIR     = "D6CFBF"; // hairline on paper
const HAIR_D   = "2E4438"; // hairline on ink
const HEAD     = "16271F"; // headline on paper
const BODY_C   = "31403A"; // body on paper
const MUTED    = "78857C"; // muted on paper
const IVORY    = "EFE9DA"; // text on ink
const IVORY_M  = "A6B0A6"; // muted on ink
const FOOT_D   = "6E7C74"; // footer on ink

const DISPLAY = "Century Schoolbook"; // safe-list serif (headlines, numerals)
const BODY    = "Calibri";            // safe-list sans (body)

const W = 13.333, H = 7.5, ML = 0.9;
const P = new pptxgen();
P.defineLayout({ name: "W", width: W, height: H });
P.layout = "W";
P.author = "[Bank Name]";
P.title = "Target State Product & Proposition";
const R = P.ShapeType;

// ---------- helpers ----------
function inkBg(s) { s.background = { color: INK }; }
function paperBg(s) { s.background = { color: PAPER }; }

function kicker(s, t, dark, y) {
  s.addText(t.toUpperCase(), { x: ML, y: y == null ? 0.7 : y, w: 11, h: 0.3, fontFace: BODY, fontSize: 11.5, bold: true, color: dark ? BRASS : BRASS_DK, charSpacing: 4 });
}
function headline(s, t, dark, y, size) {
  s.addText(t, { x: ML - 0.03, y: y == null ? 1.12 : y, w: 11.7, h: 1.0, fontFace: DISPLAY, fontSize: size || 33, color: dark ? IVORY : HEAD, lineSpacingMultiple: 1.0 });
}
function subhead(s, t, y) {
  s.addText(t, { x: ML, y: y, w: 11.4, h: 0.35, fontFace: BODY, fontSize: 13.5, italic: true, color: MUTED });
}
function hair(s, x, y, w, color) {
  s.addShape(R.rect, { x, y, w, h: 0.015, fill: { color: color || HAIR }, line: { type: "none" } });
}
function vrule(s, x, y, h, color) {
  s.addShape(R.rect, { x, y, w: 0.014, h, fill: { color: color || HAIR }, line: { type: "none" } });
}
function foot(s, n, dark) {
  s.addText("[Bank Name]  ·  Target State Product & Proposition", { x: ML, y: 7.04, w: 8, h: 0.3, fontFace: BODY, fontSize: 9, color: dark ? FOOT_D : MUTED, charSpacing: 1 });
  s.addText(String(n).padStart(2, "0"), { x: 11.85, y: 7.0, w: 0.6, h: 0.32, fontFace: DISPLAY, fontSize: 12, color: dark ? BRASS : BRASS_DK, align: "right" });
}
function ghost(s, txt, x, w) {
  s.addText(txt, { x, y: 0.9, w, h: 5.7, fontFace: DISPLAY, fontSize: 400, bold: true, color: INK2, align: "right", valign: "middle" });
}
function fresh(o) { return Object.assign({}, o); }

// ============================================================
// S1 — Title (ink)  · SETUP begins
// ============================================================
function s1() {
  const s = P.addSlide(); inkBg(s);
  s.addText("&", { x: 6.6, y: 0.1, w: 6.7, h: 7.3, fontFace: DISPLAY, fontSize: 460, color: INK2, align: "right", valign: "middle" });
  kicker(s, "Target State  ·  Executive Briefing", true, 0.9);
  s.addText("The target state\nfor product\n& proposition", { x: 0.86, y: 2.5, w: 9.2, h: 2.7, fontFace: DISPLAY, fontSize: 50, color: IVORY, lineSpacingMultiple: 1.02 });
  s.addText("Where our retail product suite stands today — and how we intend to show up in the market as a member-owned bank.", { x: 0.9, y: 5.4, w: 8.1, h: 0.8, fontFace: BODY, fontSize: 15, color: IVORY_M, lineSpacingMultiple: 1.2 });
  s.addText([
    { text: "01", options: { fontFace: DISPLAY, fontSize: 15, color: BRASS, bold: true } },
    { text: "   The retail product suite", options: { fontFace: BODY, fontSize: 13.5, color: IVORY } },
  ], { x: 0.9, y: 6.42, w: 5.4, h: 0.35 });
  s.addText([
    { text: "02", options: { fontFace: DISPLAY, fontSize: 15, color: BRASS, bold: true } },
    { text: "   How we show up in the market", options: { fontFace: BODY, fontSize: 13.5, color: IVORY } },
  ], { x: 0.9, y: 6.78, w: 6.6, h: 0.35 });
  s.addText("Prepared for the Executive & Leadership Team  ·  [Month Year]", { x: 8.9, y: 7.02, w: 3.55, h: 0.3, fontFace: BODY, fontSize: 10, color: FOOT_D, align: "right" });
  s.addNotes("Opening frame. This is a target-state view, not a project plan. The whole story is two elements: (1) the retail product suite we sell, and (2) how we show up in the market. Everything today builds to a single decision for leaders.");
}

// ============================================================
// S2 — Executive summary  · where we are -> where we're headed
// ============================================================
function s2() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Executive summary", false);
  headline(s, "Where we are, and where we're headed", false);

  const y0 = 2.05;
  s.addText("TODAY", { x: ML, y: y0, w: 5, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: MUTED, charSpacing: 3 });
  s.addText("A sound but largely undifferentiated retail bank — competing on rate and feature parity, with a suite that covers the basics.", { x: ML, y: y0 + 0.4, w: 5.05, h: 1.5, fontFace: DISPLAY, fontSize: 19, color: HEAD, lineSpacingMultiple: 1.12 });

  s.addShape(R.roundRect, { x: 6.55, y: y0 - 0.25, w: 5.9, h: 2.5, rectRadius: 0.06, fill: { color: INK }, line: { type: "none" } });
  s.addText("THE TARGET STATE", { x: 6.95, y: y0 + 0.05, w: 5, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: BRASS, charSpacing: 3 });
  s.addText("A member-led bank with a complete, digitally-native suite and a proposition that is unmistakably ours — value returned to members, not extracted from them.", { x: 6.95, y: y0 + 0.45, w: 5.1, h: 1.7, fontFace: DISPLAY, fontSize: 19, color: IVORY, lineSpacingMultiple: 1.12 });

  hair(s, ML, 4.75, 11.53);
  const stats = [
    { n: "2", l: "elements frame the target state — the product suite, and how we show up in the market" },
    { n: "5", l: "member types served across the full life-stage journey" },
    { n: "3", l: "horizons to move from vanilla banking to a differentiated leader" },
  ];
  const cw = 3.84;
  stats.forEach((st, i) => {
    const x = ML + i * cw;
    if (i > 0) vrule(s, x - 0.02, 5.15, 1.35);
    s.addText(st.n, { x: x, y: 5.0, w: 1.2, h: 1.35, fontFace: DISPLAY, fontSize: 66, bold: true, color: BRASS_DK, valign: "middle" });
    s.addText(st.l, { x: x + 1.25, y: 5.12, w: cw - 1.45, h: 1.3, fontFace: BODY, fontSize: 12.5, color: BODY_C, lineSpacingMultiple: 1.1, valign: "middle" });
  });
  foot(s, 2, false);
  s.addNotes("The setup. Left is honest about today: sound, trusted, but undifferentiated. Right is the destination. The three numerals preview the architecture of the whole deck — two elements, five members, three horizons.");
}

// ============================================================
// S3 — The framework  · two elements, two lenses
// ============================================================
function s3() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "The framework", false);
  headline(s, "Two elements, seen through two lenses", false);

  const els = [
    { n: "01", h: "The retail product suite", d: "What we look like as a product house — the on-sale catalogue, and how completely it serves each member type." },
    { n: "02", h: "How we show up in the market", d: "Our proposition — moving from vanilla, basic banking to a distinctive, member-owned point of view." },
  ];
  const y0 = 2.2;
  els.forEach((e, i) => {
    const x = ML + i * 6.0;
    s.addText(e.n, { x: x - 0.05, y: y0, w: 1.9, h: 1.2, fontFace: DISPLAY, fontSize: 74, bold: true, color: BRASS, valign: "top" });
    s.addText(e.h, { x: x + 0.02, y: y0 + 1.35, w: 5.2, h: 0.6, fontFace: DISPLAY, fontSize: 22, color: HEAD });
    s.addText(e.d, { x: x + 0.02, y: y0 + 2.0, w: 5.15, h: 1.0, fontFace: BODY, fontSize: 13.5, color: BODY_C, lineSpacingMultiple: 1.15 });
  });
  vrule(s, ML + 5.7, y0 + 0.05, 3.05);

  hair(s, ML, 5.7, 11.53);
  s.addText("SEEN THROUGH TWO LENSES", { x: ML, y: 5.9, w: 11, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: MUTED, charSpacing: 3 });
  s.addText([
    { text: "On-sale products", options: { fontFace: DISPLAY, fontSize: 16, color: HEAD, bold: true } },
    { text: "   the catalogue as it stands today", options: { fontFace: BODY, fontSize: 13, color: MUTED, italic: true } },
  ], { x: ML, y: 6.28, w: 6.0, h: 0.35 });
  s.addText([
    { text: "Member types", options: { fontFace: DISPLAY, fontSize: 16, color: HEAD, bold: true } },
    { text: "   how it serves each life stage", options: { fontFace: BODY, fontSize: 13, color: MUTED, italic: true } },
  ], { x: 6.9, y: 6.28, w: 5.5, h: 0.35 });
  foot(s, 3, false);
  s.addNotes("The map for the rest of the deck. Two elements down the page; two lenses across the bottom. Inside Element 1 we look first at the on-sale products, then re-read the same suite through the five member types.");
}

// ============================================================
// Divider (ink)
// ============================================================
function divider(num, word1, word2, blurb, pageN, note) {
  const s = P.addSlide(); inkBg(s);
  ghost(s, num, 6.0, 7.0);
  kicker(s, "Element " + (num === "01" ? "One" : "Two"), true, 2.35);
  s.addText(word1 + "\n" + word2, { x: 0.86, y: 2.8, w: 9.5, h: 2.1, fontFace: DISPLAY, fontSize: 48, color: IVORY, lineSpacingMultiple: 1.0 });
  s.addText(blurb, { x: 0.9, y: 4.95, w: 8.3, h: 1.0, fontFace: BODY, fontSize: 15.5, color: IVORY_M, lineSpacingMultiple: 1.2 });
  foot(s, pageN, true);
  s.addNotes(note);
}

// ============================================================
// S5 — On-sale catalogue (editorial two-column list)
// ============================================================
function s5() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 01  ·  The product suite", false);
  headline(s, "Our on-sale product catalogue today", false);
  subhead(s, "Everything a member can buy from us right now, grouped by need — the starting point for the target state.", 1.72);

  const cats = [
    { n: "01", h: "Everyday banking", d: "Transaction accounts · Offset · Debit & digital wallet" },
    { n: "02", h: "Savings & deposits", d: "Bonus saver · Term deposits · Kids & goal saver" },
    { n: "03", h: "Home lending", d: "Owner-occupier · Investor · Construction · Guarantor" },
    { n: "04", h: "Personal lending", d: "Personal & car loans · Green / EV loan · Overdraft" },
    { n: "05", h: "Cards & protection", d: "Low-rate & rewards cards · Insurance · CCI" },
    { n: "06", h: "Digital & servicing", d: "App & online banking · PayTo / Osko · Open banking" },
  ];
  const colW = 5.35, gap = 0.83, y0 = 2.45, rowH = 1.35;
  cats.forEach((c, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = ML + col * (colW + gap), y = y0 + row * rowH;
    hair(s, x, y - 0.16, colW);
    s.addText(c.n, { x: x, y: y + 0.02, w: 0.62, h: 0.5, fontFace: DISPLAY, fontSize: 17, bold: true, color: BRASS_DK });
    s.addText(c.h, { x: x + 0.62, y: y - 0.05, w: colW - 0.62, h: 0.5, fontFace: DISPLAY, fontSize: 19.5, color: HEAD });
    s.addText(c.d, { x: x + 0.62, y: y + 0.5, w: colW - 0.62, h: 0.5, fontFace: BODY, fontSize: 12.5, color: BODY_C });
  });
  s.addText("Illustrative — replace category contents with the current on-sale product list.", { x: ML, y: 6.7, w: 11, h: 0.3, fontFace: BODY, fontSize: 10.5, italic: true, color: MUTED });
  foot(s, 5, false);
  s.addNotes("The inventory. Six need-based groups covering everything on sale today. Grouping by member need (not product type) is deliberate — it sets up the coverage read a few slides on. Replace the illustrative contents with the live catalogue.");
}

// ============================================================
// S6 — Strengths vs gaps  · first tension surfaces
// ============================================================
function s6() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 01  ·  The product suite", false);
  headline(s, "Strong on the basics, thin at the edges", false);

  const colW = 5.35, y0 = 2.15;
  s.addText("STRONG TODAY", { x: ML, y: y0, w: colW, h: 0.35, fontFace: BODY, fontSize: 12, bold: true, color: BRASS_DK, charSpacing: 3 });
  const strong = [
    "Core deposit and everyday banking at competitive rates",
    "A credible home-lending range for mainstream borrowers",
    "Digital banking parity for day-to-day servicing",
    "A trusted, member-owned brand with high satisfaction",
  ];
  strong.forEach((t, i) => {
    const y = y0 + 0.6 + i * 1.02;
    s.addText(String(i + 1).padStart(2, "0"), { x: ML, y: y, w: 0.55, h: 0.4, fontFace: DISPLAY, fontSize: 15, bold: true, color: MUTED });
    s.addText(t, { x: ML + 0.55, y: y - 0.05, w: colW - 0.55, h: 0.9, fontFace: DISPLAY, fontSize: 16.5, color: HEAD, lineSpacingMultiple: 1.05 });
  });

  const gx = 6.6;
  s.addShape(R.roundRect, { x: gx - 0.35, y: y0 - 0.3, w: colW + 0.7, h: 4.75, rectRadius: 0.06, fill: { color: PAPER2 }, line: { type: "none" } });
  s.addText("GAPS TO CLOSE", { x: gx, y: y0, w: colW, h: 0.35, fontFace: BODY, fontSize: 12, bold: true, color: BRASS_DK, charSpacing: 3 });
  const gaps = [
    "Segment-specific products (first home buyer, small business) are limited",
    "Wealth, advice and protection are referral-only, not integrated",
    "Sustainability and values-based products are early and narrow",
    "Onboarding and origination lag digital-first challengers",
  ];
  gaps.forEach((t, i) => {
    const y = y0 + 0.6 + i * 1.02;
    s.addText(String(i + 1).padStart(2, "0"), { x: gx, y: y, w: 0.55, h: 0.4, fontFace: DISPLAY, fontSize: 15, bold: true, color: BRASS_DK });
    s.addText(t, { x: gx + 0.55, y: y - 0.05, w: colW - 0.55, h: 0.9, fontFace: DISPLAY, fontSize: 16.5, color: HEAD, lineSpacingMultiple: 1.05 });
  });
  foot(s, 6, false);
  s.addNotes("The conflict inside Element 1. We are genuinely strong on the basics — say so with confidence. But the edges are thin: segment products, integrated wealth and advice, values-based lending, and origination speed. The tint panel gives the gaps quiet weight without alarm.");
}

// ============================================================
// S7 — Member types (5-column numeral rhythm)
// ============================================================
function s7() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 01  ·  The member lens", false);
  headline(s, "The member types we serve", false);
  subhead(s, "The same catalogue must work across the whole life-stage journey. Each segment has a different centre of gravity.", 1.72);

  const segs = [
    { h: "Starting out", d: "Young transactors and savers building their first relationship" },
    { h: "First home buyers", d: "Deposit-builders and new borrowers entering the market" },
    { h: "Families & builders", d: "Home owners growing wealth, borrowing and protecting" },
    { h: "Established members", d: "Pre-retirees consolidating, de-risking and seeking advice" },
    { h: "Community & business", d: "Cause-aligned members and small-business owners" },
  ];
  const cw = 2.3, y0 = 2.55;
  segs.forEach((sg, i) => {
    const x = ML + i * cw;
    if (i > 0) vrule(s, x - 0.06, y0 + 0.1, 3.1);
    s.addText(String(i + 1).padStart(2, "0"), { x: x, y: y0, w: cw - 0.2, h: 0.9, fontFace: DISPLAY, fontSize: 46, bold: true, color: BRASS, valign: "top" });
    s.addText(sg.h, { x: x, y: y0 + 1.15, w: cw - 0.25, h: 0.9, fontFace: DISPLAY, fontSize: 18, color: HEAD, lineSpacingMultiple: 1.0 });
    s.addText(sg.d, { x: x, y: y0 + 2.1, w: cw - 0.3, h: 1.3, fontFace: BODY, fontSize: 12, color: BODY_C, lineSpacingMultiple: 1.12 });
  });
  s.addText("Illustrative segmentation — align to your member taxonomy.", { x: ML, y: 6.55, w: 11, h: 0.3, fontFace: BODY, fontSize: 10.5, italic: true, color: MUTED });
  foot(s, 7, false);
  s.addNotes("The second lens. Same suite, now read through five life stages. Each segment's centre of gravity differs, which is exactly why a one-size catalogue leaves gaps. This slide sets up the coverage matrix that follows.");
}

// ============================================================
// S8 — Coverage matrix (elegant hairline table + data viz)
// ============================================================
function s8() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 01  ·  Suite × members", false);
  headline(s, "How completely the suite serves each member", false);

  const segNames = ["Starting out", "First home", "Families", "Established", "Community"];
  const rows = [
    ["Everyday banking",  "F", "F", "F", "F", "P"],
    ["Savings & deposits", "F", "F", "F", "F", "P"],
    ["Home lending",       "N", "P", "F", "F", "N"],
    ["Personal lending",   "P", "P", "F", "P", "P"],
    ["Cards & protection", "P", "P", "P", "F", "P"],
    ["Wealth & advice",    "N", "N", "P", "P", "N"],
  ];
  const sym  = { F: "●", P: "◐", N: "○" };
  const symC = { F: BRASS_DK, P: "8A948C", N: "BEB6A5" };
  const score = { F: 1, P: 0.5, N: 0 };
  const tX = ML, tY = 1.95, labelW = 2.75, colW = 1.755, rowH = 0.495;

  segNames.forEach((nm, c) => {
    const x = tX + labelW + c * colW;
    s.addText(nm.toUpperCase(), { x, y: tY, w: colW, h: 0.4, fontFace: BODY, fontSize: 9.5, bold: true, color: MUTED, align: "center", charSpacing: 1 });
  });
  hair(s, tX, tY + 0.42, labelW + 5 * colW, INK);
  rows.forEach((r, ri) => {
    const y = tY + 0.52 + ri * rowH;
    s.addText(r[0], { x: tX, y, w: labelW - 0.1, h: rowH, fontFace: DISPLAY, fontSize: 14, color: HEAD, valign: "middle" });
    for (let c = 0; c < 5; c++) {
      const x = tX + labelW + c * colW;
      const code = r[c + 1];
      s.addText(sym[code], { x, y, w: colW, h: rowH, fontFace: BODY, fontSize: 15, color: symC[code], align: "center", valign: "middle" });
    }
    if (ri < rows.length - 1) hair(s, tX, y + rowH, labelW + 5 * colW);
  });

  // Data-viz payoff: completeness read per segment (share of "full")
  const barY = tY + 0.52 + rows.length * rowH + 0.12;
  hair(s, tX, barY, labelW + 5 * colW, INK);
  s.addText("COVERAGE", { x: tX, y: barY + 0.14, w: labelW - 0.1, h: 0.5, fontFace: BODY, fontSize: 9.5, bold: true, color: MUTED, charSpacing: 2, valign: "middle" });
  for (let c = 0; c < 5; c++) {
    let sum = 0; rows.forEach(r => sum += score[r[c + 1]]);
    const pct = sum / rows.length; // 0..1
    const x = tX + labelW + c * colW;
    const barMaxW = colW - 0.5;
    const bx = x + 0.25;
    const by = barY + 0.28;
    s.addShape(R.rect, { x: bx, y: by, w: barMaxW, h: 0.09, fill: { color: HAIR }, line: { type: "none" } });
    s.addShape(R.rect, { x: bx, y: by, w: Math.max(0.04, barMaxW * pct), h: 0.09, fill: { color: BRASS_DK }, line: { type: "none" } });
    s.addText(Math.round(pct * 100) + "%", { x: x, y: barY + 0.41, w: colW, h: 0.28, fontFace: DISPLAY, fontSize: 12, bold: true, color: HEAD, align: "center" });
  }

  // legend
  const ly = barY + 0.78;
  const leg = [["●", BRASS_DK, "Full — competitive, integrated"], ["◐", "8A948C", "Partial — exists but thin"], ["○", "BEB6A5", "Gap — referral-only or absent"]];
  leg.forEach((l, i) => {
    const x = tX + i * 3.9;
    s.addText([{ text: l[0] + "   ", options: { color: l[1], fontSize: 13 } }, { text: l[2], options: { color: BODY_C, fontSize: 11.5 } }], { x, y: ly, w: 3.8, h: 0.3, fontFace: BODY, valign: "middle" });
  });
  s.addText("Illustrative coverage assessment — replace with your product-to-segment mapping.", { x: ML, y: 6.72, w: 11, h: 0.28, fontFace: BODY, fontSize: 9.5, italic: true, color: MUTED });
  foot(s, 8, false);
  s.addNotes("The evidence slide. Read down a column to see how completely we serve one member; read across a row to see a product's reach. The coverage bars at the foot turn the pattern into a number — Community and the early life stages are least well served, and wealth & advice is the weakest row. This is the case for closing the gaps.");
}

// ============================================================
// S9 — What a complete suite looks like (2x2 grid)  · resolution of Element 1
// ============================================================
function s9() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 01  ·  Target state", false);
  headline(s, "What a complete suite looks like", false);

  const pil = [
    { n: "01", h: "Complete", d: "Every core need met in-house across all five member types — no structural gaps." },
    { n: "02", h: "Connected", d: "Wealth, advice and protection integrated into banking, not bolted on by referral." },
    { n: "03", h: "Digital-native", d: "Originate, service and switch in-app, at parity with the best challengers." },
    { n: "04", h: "Purpose-built", d: "Values-based and sustainable options only a member-owned bank can lead on." },
  ];
  const colW = 5.35, gap = 0.83, y0 = 2.35, rowH = 2.1;
  pil.forEach((p, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = ML + col * (colW + gap), y = y0 + row * rowH;
    hair(s, x, y - 0.2, colW);
    s.addText(p.n, { x: x, y: y, w: 1.0, h: 0.9, fontFace: DISPLAY, fontSize: 40, bold: true, color: BRASS });
    s.addText(p.h, { x: x + 1.05, y: y + 0.02, w: colW - 1.05, h: 0.55, fontFace: DISPLAY, fontSize: 21, color: HEAD });
    s.addText(p.d, { x: x + 1.05, y: y + 0.62, w: colW - 1.05, h: 1.0, fontFace: BODY, fontSize: 13, color: BODY_C, lineSpacingMultiple: 1.14 });
  });
  foot(s, 9, false);
  s.addNotes("Resolution of Element 1. Four tests a complete suite must pass: complete, connected, digital-native, purpose-built. The last two are where a mutual can genuinely lead rather than follow. This closes the product half of the story.");
}

// ============================================================
// S11 — Vanilla banking (pull-quote)  · CONFLICT of Element 2
// ============================================================
function s11() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 02  ·  The market view", false);
  headline(s, "Today we show up as vanilla banking", false);

  // left column: the commodity trap
  s.addText("THE COMMODITY TRAP", { x: ML, y: 2.15, w: 5, h: 0.35, fontFace: BODY, fontSize: 12, bold: true, color: BRASS_DK, charSpacing: 3 });
  const pts = [
    "We compete on rate and fees — the same battleground as everyone else",
    "Products look interchangeable with the majors and the challengers",
    "Our member-owned difference is felt, but not expressed in the offer",
    "Choice is driven by price comparison, not by what we stand for",
  ];
  pts.forEach((t, i) => {
    const y = 2.78 + i * 0.92;
    s.addText(String(i + 1).padStart(2, "0"), { x: ML, y: y, w: 0.5, h: 0.4, fontFace: DISPLAY, fontSize: 14, bold: true, color: MUTED });
    s.addText(t, { x: ML + 0.5, y: y - 0.04, w: 4.55, h: 0.85, fontFace: DISPLAY, fontSize: 15.5, color: HEAD, lineSpacingMultiple: 1.05 });
  });

  vrule(s, 6.25, 2.2, 4.0);

  // right column: pull-quote, stacked cleanly under a brass quote mark
  s.addText("“", { x: 7.5, y: 1.72, w: 2.0, h: 1.2, fontFace: DISPLAY, fontSize: 120, bold: true, color: BRASS, valign: "top" });
  s.addText("If a member can't tell us apart from a big-four product page, we compete only on price — and a mutual can't win a race to the bottom.", { x: 7.55, y: 2.98, w: 4.85, h: 2.3, fontFace: DISPLAY, fontSize: 24, color: HEAD, lineSpacingMultiple: 1.14 });
  s.addText("Vanilla banking commoditises our balance sheet, erodes margin, and leaves our purpose invisible at the point of choice.", { x: 7.55, y: 5.45, w: 4.85, h: 1.0, fontFace: BODY, fontSize: 13.5, color: MUTED, italic: true, lineSpacingMultiple: 1.15 });
  foot(s, 11, false);
  s.addNotes("The conflict of Element 2, stated plainly. If we are indistinguishable, the only lever left is price — and a member-owned balance sheet cannot win a race to the bottom. The left column diagnoses the trap; the pull-quote lands the stakes emotionally.");
}

// ============================================================
// S12 — Two views comparison (hairline table)
// ============================================================
function s12() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 02  ·  The second view", false);
  headline(s, "Two ways to show up — the choice we're making", false);

  const rows = [
    ["Basis of choice", "Rate & fees", "Value & values"],
    ["Product framing", "Feature checklists", "Member outcomes"],
    ["Relationship", "Transactional", "Lifetime & advised"],
    ["Profit story", "Extracted for shareholders", "Returned to members"],
    ["Brand role", "A safe utility", "A bank with a point of view"],
  ];
  const tX = ML, tY = 2.25, aW = 3.1, bW = 4.2, cW = 4.23, rowH = 0.82;
  s.addText("VANILLA BANKING", { x: tX + aW, y: tY - 0.05, w: bW, h: 0.4, fontFace: BODY, fontSize: 11.5, bold: true, color: MUTED, charSpacing: 2 });
  s.addText("THE DIFFERENTIATED VIEW", { x: tX + aW + bW, y: tY - 0.05, w: cW, h: 0.4, fontFace: BODY, fontSize: 11.5, bold: true, color: BRASS_DK, charSpacing: 2 });
  hair(s, tX, tY + 0.42, aW + bW + cW, INK);
  rows.forEach((r, i) => {
    const y = tY + 0.55 + i * rowH;
    s.addText(r[0], { x: tX, y, w: aW - 0.1, h: rowH, fontFace: BODY, fontSize: 12, bold: true, color: MUTED, valign: "middle", charSpacing: 1 });
    s.addText(r[1], { x: tX + aW, y, w: bW - 0.2, h: rowH, fontFace: DISPLAY, fontSize: 16.5, color: "9AA49C", valign: "middle" });
    s.addText(r[2], { x: tX + aW + bW, y, w: cW - 0.2, h: rowH, fontFace: DISPLAY, fontSize: 16.5, color: HEAD, valign: "middle" });
    if (i < rows.length - 1) hair(s, tX, y + rowH, aW + bW + cW);
  });
  s.addText("Same products can sit behind either column — the difference is the proposition we wrap around them.", { x: ML, y: 6.72, w: 11.5, h: 0.3, fontFace: BODY, fontSize: 11.5, italic: true, color: MUTED });
  foot(s, 12, false);
  s.addNotes("The pivot. Same balance sheet, two ways to present it. The left column is where we are; the right is the choice. The key line is the caption: the products need not change — the proposition wrapped around them does.");
}

// ============================================================
// S13 — The differentiated proposition (4 pillars, asymmetric hero)
// Distinct composition from S9's grid: a left thesis, and four
// stacked pillars on the right carried by oversized brass numerals.
// ============================================================
function s13() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Element 02  ·  Target state", false);
  headline(s, "The proposition that is unmistakably ours", false);

  // Left thesis column
  s.addText("THE MUTUAL DIFFERENCE", { x: ML, y: 2.45, w: 3.7, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: BRASS_DK, charSpacing: 3 });
  s.addText("Four things a shareholder bank cannot say — and mean.", { x: ML, y: 2.85, w: 3.55, h: 2.0, fontFace: DISPLAY, fontSize: 25, color: HEAD, lineSpacingMultiple: 1.12 });
  s.addText("Made visible at the point of choice, not buried in the annual report.", { x: ML, y: 5.35, w: 3.5, h: 1.0, fontFace: BODY, fontSize: 13, color: MUTED, italic: true, lineSpacingMultiple: 1.18 });

  vrule(s, 4.95, 2.3, 4.35);

  // Right stacked pillars
  const pil = [
    { n: "01", h: "Member value", d: "Profits returned as better rates, lower fees and shared rewards — the mutual dividend, made visible." },
    { n: "02", h: "Trusted advice", d: "Guidance across life stages, not just product sales — banking that acts in the member's interest." },
    { n: "03", h: "Purpose & community", d: "Values-aligned lending and local impact members can see and feel proud of." },
    { n: "04", h: "Effortless service", d: "Human when it matters, digital when it's faster — a relationship, not a call queue." },
  ];
  const px = 5.45, pw = 6.98, y0 = 2.2, rowH = 1.13;
  pil.forEach((p, i) => {
    const y = y0 + i * rowH;
    if (i > 0) hair(s, px, y - 0.12, pw);
    s.addText(p.n, { x: px, y: y - 0.02, w: 1.05, h: 0.95, fontFace: DISPLAY, fontSize: 42, bold: true, color: BRASS, valign: "top" });
    s.addText(p.h, { x: px + 1.15, y: y - 0.03, w: pw - 1.15, h: 0.42, fontFace: DISPLAY, fontSize: 19.5, color: HEAD });
    s.addText(p.d, { x: px + 1.15, y: y + 0.42, w: pw - 1.15, h: 0.62, fontFace: BODY, fontSize: 12.5, color: BODY_C, lineSpacingMultiple: 1.12 });
  });
  foot(s, 13, false);
  s.addNotes("The emotional peak. Four pillars that only a member-owned bank can claim credibly: member value, trusted advice, purpose and community, effortless service. The asymmetric layout — thesis on the left, pillars carried by big brass numerals on the right — deliberately breaks the grid rhythm to mark this as the hero of the deck.");
}

// ============================================================
// S14 — Target state on a page (ink synthesis)  · RESOLUTION
// ============================================================
function s14() {
  const s = P.addSlide(); inkBg(s);
  kicker(s, "Bringing it together", true);
  headline(s, "The target state on a page", true);

  const y1 = 2.35;
  s.addText("01", { x: ML - 0.03, y: y1, w: 1.6, h: 1.4, fontFace: DISPLAY, fontSize: 60, bold: true, color: BRASS });
  s.addText("A complete, connected suite", { x: ML + 1.5, y: y1 + 0.02, w: 10.4, h: 0.5, fontFace: DISPLAY, fontSize: 23, color: IVORY });
  s.addText("Every core need served in-house across all five member types — complete, connected, digital-native and purpose-built. The gaps in wealth, advice, protection and segment products are closed.", { x: ML + 1.5, y: y1 + 0.6, w: 10.3, h: 1.0, fontFace: BODY, fontSize: 14, color: IVORY_M, lineSpacingMultiple: 1.2 });

  hair(s, ML, 4.5, 11.53, HAIR_D);
  const y2 = 4.75;
  s.addText("02", { x: ML - 0.03, y: y2, w: 1.6, h: 1.4, fontFace: DISPLAY, fontSize: 60, bold: true, color: BRASS });
  s.addText("A proposition that is unmistakably ours", { x: ML + 1.5, y: y2 + 0.02, w: 10.4, h: 0.5, fontFace: DISPLAY, fontSize: 23, color: IVORY });
  s.addText("We stop competing on rate alone and show up on member value, trusted advice, purpose and effortless service — the mutual difference, made visible at the point of choice.", { x: ML + 1.5, y: y2 + 0.6, w: 10.3, h: 1.0, fontFace: BODY, fontSize: 14, color: IVORY_M, lineSpacingMultiple: 1.2 });

  s.addText("A complete suite gives us the right to compete; a distinctive proposition is why members choose us.", { x: ML, y: 6.5, w: 11.5, h: 0.4, fontFace: DISPLAY, fontSize: 15, italic: true, color: BRASS });
  foot(s, 14, true);
  s.addNotes("Synthesis. The two elements resolved into one page and back onto the dark ground of the title — the visual bookend. The italic brass line is the thesis of the entire deck: the suite earns the right to compete; the proposition is why members choose us.");
}

// ============================================================
// S15 — Three horizons
// ============================================================
function s15() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "The path", false);
  headline(s, "Three horizons to get there", false);

  const hor = [
    { n: "1", w: "0–12 months", h: "Fix the basics", d: "Complete the core on-sale suite, close obvious segment gaps, reach digital origination parity." },
    { n: "2", w: "12–24 months", h: "Differentiate", d: "Integrate wealth, advice and protection; launch member-value and segment-led propositions." },
    { n: "3", w: "24 months +", h: "Lead", d: "Purpose-led, ecosystem-enabled banking where the member-owned model is our edge at scale." },
  ];
  const cw = 3.84, y0 = 2.4;
  hor.forEach((hr, i) => {
    const x = ML + i * cw;
    if (i > 0) vrule(s, x - 0.06, y0 + 0.1, 3.5);
    s.addText(hr.n, { x: x, y: y0, w: 1.2, h: 1.3, fontFace: DISPLAY, fontSize: 72, bold: true, color: BRASS });
    s.addText(hr.w.toUpperCase(), { x: x, y: y0 + 1.45, w: cw - 0.4, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: BRASS_DK, charSpacing: 2 });
    s.addText(hr.h, { x: x, y: y0 + 1.75, w: cw - 0.4, h: 0.55, fontFace: DISPLAY, fontSize: 23, color: HEAD });
    s.addText(hr.d, { x: x, y: y0 + 2.4, w: cw - 0.5, h: 1.3, fontFace: BODY, fontSize: 13, color: BODY_C, lineSpacingMultiple: 1.15 });
  });
  s.addText("Illustrative sequencing — confirm scope and timing with the executive team.", { x: ML, y: 6.6, w: 11, h: 0.3, fontFace: BODY, fontSize: 10.5, italic: true, color: MUTED });
  foot(s, 15, false);
  s.addNotes("The path. Fix the basics, then differentiate, then lead. Horizon 1 is table stakes and fundable now; Horizons 2 and 3 are where the mutual model becomes the edge. Sequencing is illustrative — confirm scope and timing with the executive team.");
}

// ============================================================
// S16 — Closing / the ask (ink)  · CLOSE
// ============================================================
function s16() {
  const s = P.addSlide(); inkBg(s);
  s.addText("&", { x: 7.4, y: 0.3, w: 6.0, h: 7.0, fontFace: DISPLAY, fontSize: 420, color: INK2, align: "right", valign: "middle" });
  kicker(s, "What we're asking of leaders", true);
  s.addText("Back the shift from\nvanilla to distinctive", { x: 0.86, y: 1.2, w: 11, h: 1.6, fontFace: DISPLAY, fontSize: 40, color: IVORY, lineSpacingMultiple: 1.0 });

  const asks = [
    { n: "01", h: "Endorse the two-element target state", d: "A complete product suite and a differentiated, member-owned proposition." },
    { n: "02", h: "Prioritise closing the gaps", d: "Fund the Horizon 1 moves that bring the on-sale suite to completeness." },
    { n: "03", h: "Commit to the proposition", d: "Agree to compete on member value, not just rate — across every segment." },
  ];
  const y0 = 3.35;
  asks.forEach((a, i) => {
    const y = y0 + i * 0.98;
    hair(s, ML, y - 0.14, 11.0, HAIR_D);
    s.addText(a.n, { x: ML, y: y, w: 0.9, h: 0.7, fontFace: DISPLAY, fontSize: 22, bold: true, color: BRASS });
    s.addText(a.h, { x: ML + 0.95, y: y - 0.02, w: 5.4, h: 0.7, fontFace: DISPLAY, fontSize: 18, color: IVORY, valign: "middle" });
    s.addText(a.d, { x: ML + 6.5, y: y - 0.02, w: 5.0, h: 0.7, fontFace: BODY, fontSize: 12.5, color: IVORY_M, valign: "middle", lineSpacingMultiple: 1.05 });
  });
  s.addText("The suite earns us the right to compete. The proposition is why members choose us — and stay.", { x: ML, y: 6.5, w: 11.4, h: 0.4, fontFace: DISPLAY, fontSize: 16, italic: true, color: BRASS });
  foot(s, 16, true);
  s.addNotes("The close. Three decisions, not a discussion: endorse the target state, fund the Horizon 1 gap-closing, and commit to competing on member value. Return to the dark ground and the ampersand motif to bookend the story.");
}

// ---------- build ----------
s1(); s2(); s3();
divider("01", "The retail", "product suite",
  "What we look like as a product house — the on-sale catalogue, and how completely it serves every member type.", 4,
  "Element 1 divider. We now go inside the product suite: first the on-sale catalogue, then the same suite re-read through the five member types.");
s5(); s6(); s7(); s8(); s9();
divider("02", "How we show up", "in the market",
  "From vanilla, basic banking to a distinctive, member-owned proposition — the second, differentiated view.", 10,
  "Element 2 divider. From what we sell to how we show up. This is the harder, more valuable half — the proposition that makes the suite matter.");
s11(); s12(); s13(); s14(); s15(); s16();

P.writeFile({ fileName: "Target-State-Product-and-Proposition.pptx" }).then(() => console.log("written"));
