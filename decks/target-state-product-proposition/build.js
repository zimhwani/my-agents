const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const Fi = require("react-icons/fi");

// ---------- Palette ----------
const NAVY   = "0A2A38"; // dominant dark
const NAVY2  = "103A4C";
const TEAL   = "1C7293";
const TEAL_DK= "0E4C63";
const AMBER  = "E8A93C"; // accent
const AMBER_DK="C4871F";
const INK    = "1C2B33";
const SLATE  = "5E7885"; // muted text
const LIGHT  = "F2F7F9"; // light bg
const CARD   = "FFFFFF";
const LINE   = "D8E4E9";
const WHITE  = "FFFFFF";
const MINT   = "3FA796";

const HEAD = "Cambria";     // hero serif
const BODY = "Calibri";     // body sans

// ---------- Icon rasterizer ----------
const iconCache = {};
async function icon(Comp, hex) {
  const key = (Comp.name || "i") + hex;
  if (iconCache[key]) return iconCache[key];
  const svg = ReactDOMServer.renderToStaticMarkup(
    React.createElement(Comp, { color: "#" + hex, size: 256, strokeWidth: 2 })
  );
  const png = await sharp(Buffer.from(svg)).resize(256, 256).png().toBuffer();
  const data = "image/png;base64," + png.toString("base64");
  iconCache[key] = data;
  return data;
}

const P = new pptxgen();
P.defineLayout({ name: "W", width: 13.333, height: 7.5 });
P.layout = "W";
const W = 13.333, H = 7.5;

// ---------- helpers ----------
function darkBg(s) { s.background = { color: NAVY }; }
function lightBg(s) { s.background = { color: LIGHT }; }

function pageFoot(s, n, dark) {
  s.addText("[Bank Name]  ·  Target State Product & Proposition", {
    x: 0.6, y: 7.08, w: 8, h: 0.3, fontFace: BODY, fontSize: 9,
    color: dark ? "7FA0AD" : SLATE, align: "left",
  });
  s.addText(String(n), {
    x: 12.4, y: 7.08, w: 0.5, h: 0.3, fontFace: BODY, fontSize: 9,
    color: dark ? "7FA0AD" : SLATE, align: "right",
  });
}

function kicker(s, txt, dark) {
  s.addText(txt.toUpperCase(), {
    x: 0.62, y: 0.55, w: 11, h: 0.32, fontFace: BODY, fontSize: 12, bold: true,
    color: dark ? AMBER : TEAL, charSpacing: 3, align: "left",
  });
}

function title(s, txt, dark) {
  s.addText(txt, {
    x: 0.6, y: 0.86, w: 12.1, h: 0.9, fontFace: HEAD, fontSize: 32, bold: true,
    color: dark ? WHITE : NAVY, align: "left",
  });
}

async function iconChip(s, Comp, x, y, d, bg, ic) {
  s.addShape(P.ShapeType.roundRect, {
    x, y, w: d, h: d, rectRadius: d / 2, fill: { color: bg }, line: { type: "none" },
  });
  s.addImage({ data: await icon(Comp, ic), x: x + d * 0.24, y: y + d * 0.24, w: d * 0.52, h: d * 0.52 });
}

function card(s, x, y, w, h, fill) {
  s.addShape(P.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.09, fill: { color: fill || CARD },
    line: { color: LINE, width: 1 },
    shadow: { type: "outer", color: "9FB4BD", blur: 7, offset: 3, angle: 90, opacity: 0.28 },
  });
}

// ============================================================
// SLIDE 1 — Title (dark)
// ============================================================
{
  const s = P.addSlide(); darkBg(s);
  s.addShape(P.ShapeType.rect, { x: 0, y: 0, w: W, h: H, fill: { color: NAVY }, line: { type: "none" } });
  // motif: concentric rings top-right
  s.addShape(P.ShapeType.roundRect, { x: 9.7, y: -1.7, w: 5.2, h: 5.2, rectRadius: 2.6, fill: { type: "none" }, line: { color: TEAL, width: 1.5, transparency: 55 } });
  s.addShape(P.ShapeType.roundRect, { x: 10.7, y: -0.7, w: 3.2, h: 3.2, rectRadius: 1.6, fill: { type: "none" }, line: { color: AMBER, width: 1.5, transparency: 40 } });
  s.addShape(P.ShapeType.roundRect, { x: 11.35, y: 4.9, w: 3.6, h: 3.6, rectRadius: 1.8, fill: { type: "none" }, line: { color: TEAL, width: 1.5, transparency: 60 } });

  s.addText("STRATEGY  ·  EXECUTIVE BRIEFING", {
    x: 0.75, y: 1.55, w: 10, h: 0.4, fontFace: BODY, fontSize: 13, bold: true, color: AMBER, charSpacing: 4,
  });
  s.addText("Target State Product\n& Proposition", {
    x: 0.7, y: 2.05, w: 10.5, h: 2.1, fontFace: HEAD, fontSize: 52, bold: true, color: WHITE, lineSpacingMultiple: 0.98,
  });
  s.addText("Where our retail product suite stands today — and how we intend to show up in the market as a member-owned bank.", {
    x: 0.75, y: 4.35, w: 9.2, h: 0.9, fontFace: BODY, fontSize: 16, color: "C7DBE3", lineSpacingMultiple: 1.15,
  });
  // two-element pill footer
  s.addShape(P.ShapeType.roundRect, { x: 0.75, y: 5.7, w: 5.4, h: 0.72, rectRadius: 0.36, fill: { color: NAVY2 }, line: { color: TEAL, width: 1 } });
  s.addText([
    { text: "01  ", options: { bold: true, color: AMBER } },
    { text: "The retail product suite", options: { color: WHITE } },
  ], { x: 0.95, y: 5.7, w: 5.1, h: 0.72, fontFace: BODY, fontSize: 14, valign: "middle" });
  s.addShape(P.ShapeType.roundRect, { x: 6.35, y: 5.7, w: 5.4, h: 0.72, rectRadius: 0.36, fill: { color: NAVY2 }, line: { color: TEAL, width: 1 } });
  s.addText([
    { text: "02  ", options: { bold: true, color: AMBER } },
    { text: "How we show up in the market", options: { color: WHITE } },
  ], { x: 6.55, y: 5.7, w: 5.1, h: 0.72, fontFace: BODY, fontSize: 14, valign: "middle" });

  s.addText("Prepared for the Executive & Leadership Team  ·  [Month Year]", {
    x: 0.75, y: 6.75, w: 10, h: 0.3, fontFace: BODY, fontSize: 11, color: "7FA0AD",
  });
}

// ============================================================
// SLIDE 2 — Executive summary: where we are / where we're headed
// ============================================================
async function slide2() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Executive summary", false);
  title(s, "Where we are, and where we're headed", false);

  // From -> To band
  const fromToY = 1.95;
  card(s, 0.6, fromToY, 5.75, 1.55, CARD);
  s.addText("WHERE WE ARE TODAY", { x: 0.85, y: fromToY + 0.16, w: 5.2, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: SLATE, charSpacing: 2 });
  s.addText("A sound but largely undifferentiated retail bank — competing on rate and feature parity, with a product suite that covers the basics.", { x: 0.85, y: fromToY + 0.5, w: 5.25, h: 0.95, fontFace: BODY, fontSize: 13.5, color: INK, lineSpacingMultiple: 1.05 });

  // arrow
  await iconChip(s, Fi.FiArrowRight, 6.5, fromToY + 0.4, 0.72, AMBER, WHITE);

  card(s, 7.35, fromToY, 5.35, 1.55, NAVY);
  s.addShape(P.ShapeType.roundRect, { x: 7.35, y: fromToY, w: 5.35, h: 1.55, rectRadius: 0.09, fill: { color: NAVY }, line: { type: "none" } });
  s.addText("WHERE WE'RE HEADED", { x: 7.6, y: fromToY + 0.16, w: 4.9, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: AMBER, charSpacing: 2 });
  s.addText("A member-led bank with a complete, digitally-native suite and a proposition that is unmistakably ours — value returned to members, not extracted from them.", { x: 7.6, y: fromToY + 0.5, w: 4.85, h: 1.0, fontFace: BODY, fontSize: 13.5, color: "E7F1F5", lineSpacingMultiple: 1.05 });

  // three stat callouts
  const stats = [
    { n: "2", l: "elements frame the target state:\nproduct suite + market proposition", ic: Fi.FiLayers },
    { n: "5", l: "member types we serve across the\nlife-stage journey", ic: Fi.FiUsers },
    { n: "3", l: "horizons to move from vanilla\nbanking to a differentiated leader", ic: Fi.FiFlag },
  ];
  const sy = 3.95, sw = 3.9, gap = 0.31;
  for (let i = 0; i < 3; i++) {
    const x = 0.6 + i * (sw + gap);
    card(s, x, sy, sw, 2.55, CARD);
    await iconChip(s, stats[i].ic, x + 0.32, sy + 0.34, 0.78, LIGHT, TEAL);
    s.addText(stats[i].n, { x: x + 1.3, y: sy + 0.16, w: 2.4, h: 1.1, fontFace: HEAD, fontSize: 54, bold: true, color: TEAL, valign: "middle" });
    s.addText(stats[i].l, { x: x + 0.34, y: sy + 1.35, w: sw - 0.66, h: 1.0, fontFace: BODY, fontSize: 13, color: INK, lineSpacingMultiple: 1.06 });
  }
  s.addText("Read this deck as two connected elements: what our product suite must become, and how that suite lets us show up differently in the market.", { x: 0.6, y: 6.65, w: 12.1, h: 0.35, fontFace: BODY, fontSize: 12, italic: true, color: SLATE });
  pageFoot(s, 2, false);
}

// ============================================================
// SLIDE 3 — How to read this: the framework
// ============================================================
async function slide3() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "The framework", false);
  title(s, "Two elements, seen through two lenses", false);

  // two big element cards
  const ey = 1.95, ew = 6.0, eh = 2.5;
  const els = [
    { t: "Element 01", h: "The retail product suite", d: "What we look like as a product house — the on-sale catalogue and how completely it serves each member type.", ic: Fi.FiGrid, c: TEAL },
    { t: "Element 02", h: "How we show up in the market", d: "Our proposition — moving from vanilla, basic banking to a distinctive, member-owned point of view.", ic: Fi.FiCompass, c: AMBER_DK },
  ];
  for (let i = 0; i < 2; i++) {
    const x = 0.6 + i * (ew + 0.55);
    card(s, x, ey, ew, eh, CARD);
    await iconChip(s, els[i].ic, x + 0.34, ey + 0.34, 0.9, LIGHT, els[i].c);
    s.addText(els[i].t.toUpperCase(), { x: x + 1.45, y: ey + 0.4, w: 4.3, h: 0.3, fontFace: BODY, fontSize: 12, bold: true, color: els[i].c, charSpacing: 2 });
    s.addText(els[i].h, { x: x + 1.45, y: ey + 0.68, w: 4.35, h: 0.55, fontFace: HEAD, fontSize: 20, bold: true, color: NAVY });
    s.addText(els[i].d, { x: x + 0.36, y: ey + 1.5, w: ew - 0.7, h: 0.9, fontFace: BODY, fontSize: 14, color: INK, lineSpacingMultiple: 1.1 });
  }

  // two lenses band
  const ly = 4.75;
  s.addText("SEEN THROUGH TWO LENSES", { x: 0.6, y: ly, w: 12, h: 0.3, fontFace: BODY, fontSize: 12, bold: true, color: SLATE, charSpacing: 2 });
  const lenses = [
    { h: "On-sale products", d: "The catalogue as it stands — every product a member can buy today.", ic: Fi.FiShoppingBag },
    { h: "Member types", d: "How that catalogue serves each segment across their life stage.", ic: Fi.FiUsers },
  ];
  for (let i = 0; i < 2; i++) {
    const x = 0.6 + i * (ew + 0.55);
    card(s, x, ly + 0.4, ew, 1.35, LIGHT);
    await iconChip(s, lenses[i].ic, x + 0.3, ly + 0.72, 0.7, WHITE, NAVY);
    s.addText(lenses[i].h, { x: x + 1.2, y: ly + 0.62, w: ew - 1.4, h: 0.4, fontFace: BODY, fontSize: 16, bold: true, color: NAVY });
    s.addText(lenses[i].d, { x: x + 1.2, y: ly + 1.02, w: ew - 1.4, h: 0.6, fontFace: BODY, fontSize: 12.5, color: SLATE, lineSpacingMultiple: 1.05 });
  }
  pageFoot(s, 3, false);
}

// ============================================================
// SLIDE 4 — Element 1 divider (dark)
// ============================================================
async function divider(num, label, blurb, pageN, Comp) {
  const s = P.addSlide(); darkBg(s);
  s.addShape(P.ShapeType.rect, { x: 0, y: 0, w: W, h: H, fill: { color: NAVY }, line: { type: "none" } });
  s.addShape(P.ShapeType.roundRect, { x: 10.2, y: 1.5, w: 4.5, h: 4.5, rectRadius: 2.25, fill: { type: "none" }, line: { color: TEAL, width: 1.5, transparency: 55 } });
  await iconChip(s, Comp, 0.75, 2.15, 1.15, NAVY2, AMBER);
  s.addText(("Element " + num).toUpperCase(), { x: 0.78, y: 3.55, w: 8, h: 0.4, fontFace: BODY, fontSize: 15, bold: true, color: AMBER, charSpacing: 4 });
  s.addText(label, { x: 0.72, y: 3.95, w: 10.5, h: 1.3, fontFace: HEAD, fontSize: 44, bold: true, color: WHITE });
  s.addText(blurb, { x: 0.78, y: 5.35, w: 9.5, h: 0.9, fontFace: BODY, fontSize: 16, color: "C7DBE3", lineSpacingMultiple: 1.15 });
  pageFoot(s, pageN, true);
  return s;
}

// ============================================================
// SLIDE 5 — On-sale products (catalogue grid)
// ============================================================
async function slide5() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 01 · The product suite", false);
  title(s, "Our on-sale product catalogue today", false);
  s.addText("Everything a member can buy from us right now, grouped by need. This is the starting point for the target state.", { x: 0.62, y: 1.62, w: 12, h: 0.35, fontFace: BODY, fontSize: 13.5, color: SLATE });

  const cats = [
    { h: "Everyday banking", ic: Fi.FiCreditCard, items: "Transaction accounts · Offset · Debit & digital wallet" },
    { h: "Savings & deposits", ic: Fi.FiTrendingUp, items: "Bonus saver · Term deposits · Kids & goal saver" },
    { h: "Home lending", ic: Fi.FiHome, items: "Owner-occupier · Investor · Construction · Guarantor" },
    { h: "Personal lending", ic: Fi.FiDollarSign, items: "Personal & car loans · Green / EV loan · Overdraft" },
    { h: "Cards & protection", ic: Fi.FiShield, items: "Low-rate & rewards cards · Insurance · CCI" },
    { h: "Digital & servicing", ic: Fi.FiSmartphone, items: "App & online banking · PayTo / Osko · Open banking" },
  ];
  const gy = 2.1, cw = 3.87, ch = 2.0, gx = 0.35;
  for (let i = 0; i < 6; i++) {
    const col = i % 3, row = Math.floor(i / 3);
    const x = 0.6 + col * (cw + gx), y = gy + row * (ch + 0.25);
    card(s, x, y, cw, ch, CARD);
    await iconChip(s, cats[i].ic, x + 0.3, y + 0.28, 0.82, LIGHT, TEAL);
    s.addText(cats[i].h, { x: x + 1.28, y: y + 0.38, w: cw - 1.45, h: 0.55, fontFace: BODY, fontSize: 16.5, bold: true, color: NAVY, valign: "middle" });
    s.addText(cats[i].items, { x: x + 0.32, y: y + 1.2, w: cw - 0.6, h: 0.72, fontFace: BODY, fontSize: 12.5, color: INK, lineSpacingMultiple: 1.06 });
  }
  s.addText("Illustrative catalogue — replace category contents with the current on-sale product list.", { x: 0.6, y: 6.62, w: 12, h: 0.3, fontFace: BODY, fontSize: 11, italic: true, color: SLATE });
  pageFoot(s, 5, false);
}

// ============================================================
// SLIDE 6 — Current strengths vs gaps
// ============================================================
async function slide6() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 01 · The product suite", false);
  title(s, "Strong on the basics, thin at the edges", false);

  const colW = 5.95, cy = 1.9, colH = 4.75;
  // strengths
  card(s, 0.6, cy, colW, colH, CARD);
  await iconChip(s, Fi.FiCheckCircle, 0.9, cy + 0.3, 0.7, "E4F1EC", MINT);
  s.addText("Strong today", { x: 1.75, y: cy + 0.38, w: 4, h: 0.5, fontFace: HEAD, fontSize: 21, bold: true, color: NAVY, valign: "middle" });
  const strong = [
    "Core deposit and everyday banking products at competitive rates",
    "A credible home-lending range for mainstream borrowers",
    "Digital banking parity for day-to-day servicing",
    "Trusted, member-owned brand with high satisfaction",
  ];
  strong.forEach((t, i) => {
    const y = cy + 1.2 + i * 0.85;
    s.addShape(P.ShapeType.roundRect, { x: 0.95, y: y + 0.07, w: 0.16, h: 0.16, rectRadius: 0.08, fill: { color: MINT }, line: { type: "none" } });
    s.addText(t, { x: 1.25, y: y - 0.05, w: colW - 0.85, h: 0.75, fontFace: BODY, fontSize: 13.5, color: INK, lineSpacingMultiple: 1.03, valign: "top" });
  });

  // gaps
  const x2 = 0.6 + colW + 0.55;
  card(s, x2, cy, colW, colH, CARD);
  await iconChip(s, Fi.FiAlertCircle, x2 + 0.3, cy + 0.3, 0.7, "FBEFD8", AMBER_DK);
  s.addText("Gaps to close", { x: x2 + 1.15, y: cy + 0.38, w: 4, h: 0.5, fontFace: HEAD, fontSize: 21, bold: true, color: NAVY, valign: "middle" });
  const gaps = [
    "Segment-specific products (first home buyer, small business) are limited",
    "Wealth, advice and protection are referral-only, not integrated",
    "Sustainability / values-based products are early and narrow",
    "Onboarding and origination lag digital-first challengers",
  ];
  gaps.forEach((t, i) => {
    const y = cy + 1.2 + i * 0.85;
    s.addShape(P.ShapeType.roundRect, { x: x2 + 0.35, y: y + 0.07, w: 0.16, h: 0.16, rectRadius: 0.08, fill: { color: AMBER_DK }, line: { type: "none" } });
    s.addText(t, { x: x2 + 0.65, y: y - 0.05, w: colW - 0.85, h: 0.75, fontFace: BODY, fontSize: 13.5, color: INK, lineSpacingMultiple: 1.03, valign: "top" });
  });
  pageFoot(s, 6, false);
}

// ============================================================
// SLIDE 7 — Member types (segments)
// ============================================================
async function slide7() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 01 · The member lens", false);
  title(s, "The member types we serve", false);
  s.addText("The same catalogue must work across the whole life-stage journey. Each segment has a different centre of gravity.", { x: 0.62, y: 1.62, w: 12, h: 0.35, fontFace: BODY, fontSize: 13.5, color: SLATE });

  const segs = [
    { h: "Starting out", d: "Young transactors & savers building their first relationship", ic: Fi.FiZap },
    { h: "First home buyers", d: "Deposit-builders and new borrowers entering the market", ic: Fi.FiHome },
    { h: "Families & builders", d: "Home owners growing wealth, borrowing and protecting", ic: Fi.FiUsers },
    { h: "Established members", d: "Pre-retirees consolidating, de-risking and advising", ic: Fi.FiAward },
    { h: "Community & business", d: "Cause-aligned members and small-business owners", ic: Fi.FiHeart },
  ];
  const cw = 2.29, gap = 0.28, gy = 2.2, ch = 3.9;
  for (let i = 0; i < 5; i++) {
    const x = 0.6 + i * (cw + gap);
    card(s, x, gy, cw, ch, CARD);
    await iconChip(s, segs[i].ic, x + (cw - 0.9) / 2, gy + 0.35, 0.9, LIGHT, TEAL);
    s.addText(String(i + 1).padStart(2, "0"), { x: x, y: gy + 1.35, w: cw, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: AMBER_DK, align: "center", charSpacing: 2 });
    s.addText(segs[i].h, { x: x + 0.15, y: gy + 1.65, w: cw - 0.3, h: 0.75, fontFace: BODY, fontSize: 15.5, bold: true, color: NAVY, align: "center", valign: "top" });
    s.addText(segs[i].d, { x: x + 0.2, y: gy + 2.45, w: cw - 0.4, h: 1.3, fontFace: BODY, fontSize: 11.5, color: SLATE, align: "center", lineSpacingMultiple: 1.06 });
  }
  s.addText("Illustrative segmentation — align to your member taxonomy.", { x: 0.6, y: 6.35, w: 12, h: 0.3, fontFace: BODY, fontSize: 11, italic: true, color: SLATE });
  pageFoot(s, 7, false);
}

// ============================================================
// SLIDE 8 — Product x member matrix
// ============================================================
function slide8() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 01 · Suite × members", false);
  title(s, "How completely the suite serves each member", false);

  const segNames = ["Starting\nout", "First home\nbuyers", "Families &\nbuilders", "Established\nmembers", "Community\n& business"];
  const rows = [
    ["Everyday banking", "F", "F", "F", "F", "P"],
    ["Savings & deposits", "F", "F", "F", "F", "P"],
    ["Home lending",       "N", "P", "F", "F", "N"],
    ["Personal lending",   "P", "P", "F", "P", "P"],
    ["Cards & protection",  "P", "P", "P", "F", "P"],
    ["Wealth & advice",     "N", "N", "P", "P", "N"],
  ];
  const glyph = { F: "●  Full", P: "◐  Partial", N: "○  Gap" };
  const gc = { F: MINT, P: AMBER_DK, N: "B0343E" };

  const tblX = 0.6, tblY = 1.9, labelW = 2.35, colW = 1.95, rowH = 0.56;
  // header row
  s.addShape(P.ShapeType.rect, { x: tblX, y: tblY, w: labelW, h: 0.72, fill: { color: NAVY }, line: { color: WHITE, width: 1 } });
  s.addText("Product need", { x: tblX + 0.12, y: tblY, w: labelW - 0.2, h: 0.72, fontFace: BODY, fontSize: 12.5, bold: true, color: WHITE, valign: "middle" });
  for (let c = 0; c < 5; c++) {
    const x = tblX + labelW + c * colW;
    s.addShape(P.ShapeType.rect, { x, y: tblY, w: colW, h: 0.72, fill: { color: NAVY }, line: { color: WHITE, width: 1 } });
    s.addText(segNames[c], { x, y: tblY, w: colW, h: 0.72, fontFace: BODY, fontSize: 11, bold: true, color: WHITE, align: "center", valign: "middle", lineSpacingMultiple: 0.92 });
  }
  // body
  rows.forEach((r, ri) => {
    const y = tblY + 0.72 + ri * rowH;
    const rowFill = ri % 2 === 0 ? CARD : "E9F1F4";
    s.addShape(P.ShapeType.rect, { x: tblX, y, w: labelW, h: rowH, fill: { color: rowFill }, line: { color: LINE, width: 1 } });
    s.addText(r[0], { x: tblX + 0.12, y, w: labelW - 0.2, h: rowH, fontFace: BODY, fontSize: 12, bold: true, color: INK, valign: "middle" });
    for (let c = 0; c < 5; c++) {
      const x = tblX + labelW + c * colW;
      const code = r[c + 1];
      s.addShape(P.ShapeType.rect, { x, y, w: colW, h: rowH, fill: { color: rowFill }, line: { color: LINE, width: 1 } });
      s.addText(glyph[code], { x, y, w: colW, h: rowH, fontFace: BODY, fontSize: 11.5, bold: code === "F", color: gc[code], align: "center", valign: "middle" });
    }
  });
  // legend
  const ly = tblY + 0.72 + rows.length * rowH + 0.28;
  const leg = [["●", MINT, "Full — competitive, integrated"], ["◐", AMBER_DK, "Partial — exists but thin"], ["○", "B0343E", "Gap — referral-only or absent"]];
  leg.forEach((l, i) => {
    const x = tblX + i * 4.0;
    s.addText([{ text: l[0] + "  ", options: { color: l[1], bold: true } }, { text: l[2], options: { color: INK } }], { x, y: ly, w: 3.9, h: 0.3, fontFace: BODY, fontSize: 12 });
  });
  s.addText("Illustrative coverage assessment — replace with your product-to-segment mapping.", { x: 0.6, y: 6.66, w: 12, h: 0.3, fontFace: BODY, fontSize: 11, italic: true, color: SLATE });
  pageFoot(s, 8, false);
}

// ============================================================
// SLIDE 9 — Target-state suite ambition (pillars)
// ============================================================
async function slide9() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 01 · Target state", false);
  title(s, "What a complete suite looks like", false);

  const pil = [
    { h: "Complete", d: "Every core need met in-house across all five member types — no structural gaps.", ic: Fi.FiCheckSquare },
    { h: "Connected", d: "Wealth, advice and protection integrated into banking, not bolted on by referral.", ic: Fi.FiLink },
    { h: "Digital-native", d: "Originate, service and switch in-app, at parity with the best challengers.", ic: Fi.FiSmartphone },
    { h: "Purpose-built", d: "Values-based and sustainable options that only a member-owned bank can lead on.", ic: Fi.FiHeart },
  ];
  const cw = 2.85, gap = 0.3, gy = 2.15, ch = 3.9;
  for (let i = 0; i < 4; i++) {
    const x = 0.6 + i * (cw + gap);
    card(s, x, gy, cw, ch, CARD);
    await iconChip(s, pil[i].ic, x + 0.32, gy + 0.35, 0.95, LIGHT, i % 2 ? AMBER_DK : TEAL);
    s.addText(pil[i].h, { x: x + 0.32, y: gy + 1.55, w: cw - 0.6, h: 0.55, fontFace: HEAD, fontSize: 20, bold: true, color: NAVY });
    s.addText(pil[i].d, { x: x + 0.32, y: gy + 2.15, w: cw - 0.6, h: 1.6, fontFace: BODY, fontSize: 13, color: INK, lineSpacingMultiple: 1.12 });
  }
  pageFoot(s, 9, false);
}

// ============================================================
// SLIDE 11 — Where we are: vanilla, basic banking
// ============================================================
async function slide11() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 02 · The market view", false);
  title(s, "Today we show up as vanilla banking", false);

  card(s, 0.6, 1.95, 6.05, 4.6, CARD);
  await iconChip(s, Fi.FiBox, 0.9, 2.25, 0.75, LIGHT, SLATE);
  s.addText("The commodity trap", { x: 1.8, y: 2.32, w: 4.6, h: 0.6, fontFace: HEAD, fontSize: 20, bold: true, color: NAVY, valign: "middle" });
  const traps = [
    "We compete on rate and fees — the same battleground as everyone else",
    "Products look interchangeable with the majors and challengers",
    "Our member-owned difference is felt, but not expressed in the offer",
    "Choice is driven by price comparison, not by what we stand for",
  ];
  traps.forEach((t, i) => {
    const y = 3.25 + i * 0.8;
    s.addShape(P.ShapeType.roundRect, { x: 0.95, y: y + 0.06, w: 0.16, h: 0.16, rectRadius: 0.08, fill: { color: SLATE }, line: { type: "none" } });
    s.addText(t, { x: 1.25, y: y - 0.05, w: 5.15, h: 0.72, fontFace: BODY, fontSize: 13.5, color: INK, lineSpacingMultiple: 1.03 });
  });

  // right: the cost, dark card
  const x2 = 7.0;
  card(s, x2, 1.95, 5.7, 4.6, NAVY);
  s.addShape(P.ShapeType.roundRect, { x: x2, y: 1.95, w: 5.7, h: 4.6, rectRadius: 0.09, fill: { color: NAVY }, line: { type: "none" } });
  s.addText("WHY IT MATTERS", { x: x2 + 0.4, y: 2.3, w: 5, h: 0.35, fontFace: BODY, fontSize: 12, bold: true, color: AMBER, charSpacing: 3 });
  s.addText("“If a member can't tell us apart from a big-four product page, we compete only on price — and a mutual can't win a race to the bottom.”", { x: x2 + 0.4, y: 2.75, w: 5.0, h: 1.7, fontFace: HEAD, fontSize: 21, italic: true, color: WHITE, lineSpacingMultiple: 1.1 });
  s.addText("Vanilla banking commoditises our balance sheet, erodes margin, and leaves our purpose invisible at the point of choice.", { x: x2 + 0.4, y: 4.75, w: 5.0, h: 1.3, fontFace: BODY, fontSize: 14, color: "C7DBE3", lineSpacingMultiple: 1.15 });
  pageFoot(s, 11, false);
}

// ============================================================
// SLIDE 12 — Two views: vanilla vs differentiated
// ============================================================
async function slide12() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 02 · The second view", false);
  title(s, "Two ways to show up — the choice we're making", false);

  const rows = [
    ["Basis of choice", "Rate & fees", "Value & values"],
    ["Product framing", "Feature checklists", "Member outcomes"],
    ["Relationship", "Transactional", "Lifetime & advised"],
    ["Profit story", "Extracted for shareholders", "Returned to members"],
    ["Brand role", "A safe utility", "A bank with a point of view"],
  ];
  const tX = 0.6, tY = 2.0, aW = 3.0, bW = 4.55, cW = 4.55, rH = 0.78;
  // header
  s.addShape(P.ShapeType.rect, { x: tX, y: tY, w: aW, h: 0.6, fill: { color: LIGHT }, line: { type: "none" } });
  s.addShape(P.ShapeType.rect, { x: tX + aW, y: tY, w: bW, h: 0.6, fill: { color: "8FA3AD" }, line: { color: WHITE, width: 1.5 } });
  s.addText("Vanilla banking", { x: tX + aW, y: tY, w: bW, h: 0.6, fontFace: BODY, fontSize: 15, bold: true, color: WHITE, align: "center", valign: "middle" });
  s.addShape(P.ShapeType.rect, { x: tX + aW + bW, y: tY, w: cW, h: 0.6, fill: { color: TEAL }, line: { color: WHITE, width: 1.5 } });
  s.addText("The differentiated view", { x: tX + aW + bW, y: tY, w: cW, h: 0.6, fontFace: BODY, fontSize: 15, bold: true, color: WHITE, align: "center", valign: "middle" });

  rows.forEach((r, i) => {
    const y = tY + 0.6 + i * rH;
    s.addText(r[0], { x: tX + 0.05, y, w: aW - 0.1, h: rH, fontFace: BODY, fontSize: 13, bold: true, color: SLATE, valign: "middle" });
    s.addShape(P.ShapeType.rect, { x: tX + aW, y, w: bW, h: rH, fill: { color: i % 2 ? "EDF2F4" : CARD }, line: { color: LINE, width: 1 } });
    s.addText(r[1], { x: tX + aW + 0.25, y, w: bW - 0.4, h: rH, fontFace: BODY, fontSize: 14, color: INK, valign: "middle" });
    s.addShape(P.ShapeType.rect, { x: tX + aW + bW, y, w: cW, h: rH, fill: { color: i % 2 ? "E1EEF1" : "EAF4F6" }, line: { color: LINE, width: 1 } });
    s.addText(r[2], { x: tX + aW + bW + 0.25, y, w: cW - 0.4, h: rH, fontFace: BODY, fontSize: 14, bold: true, color: TEAL_DK, valign: "middle" });
  });
  s.addText("Same products can sit behind either column. The difference is the proposition we wrap around them.", { x: 0.6, y: 6.65, w: 12, h: 0.3, fontFace: BODY, fontSize: 12, italic: true, color: SLATE });
  pageFoot(s, 12, false);
}

// ============================================================
// SLIDE 13 — Differentiated proposition pillars
// ============================================================
async function slide13() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Element 02 · Target state", false);
  title(s, "The proposition that is unmistakably ours", false);

  const pil = [
    { h: "Member value", d: "Profits returned as better rates, lower fees and shared rewards — the mutual dividend, made visible.", ic: Fi.FiGift },
    { h: "Trusted advice", d: "Guidance across life stages, not just product sales — banking that acts in the member's interest.", ic: Fi.FiCompass },
    { h: "Purpose & community", d: "Values-aligned lending and local impact that members can see and feel proud of.", ic: Fi.FiHeart },
    { h: "Effortless service", d: "Human when it matters, digital when it's faster — a relationship, not a call queue.", ic: Fi.FiSmile },
  ];
  const cw = 2.85, gap = 0.3, gy = 2.15, ch = 4.0;
  for (let i = 0; i < 4; i++) {
    const x = 0.6 + i * (cw + gap);
    card(s, x, gy, cw, ch, i === 0 ? NAVY : CARD);
    if (i === 0) s.addShape(P.ShapeType.roundRect, { x, y: gy, w: cw, h: ch, rectRadius: 0.09, fill: { color: NAVY }, line: { type: "none" } });
    await iconChip(s, pil[i].ic, x + 0.32, gy + 0.35, 0.95, i === 0 ? NAVY2 : LIGHT, AMBER);
    s.addText(pil[i].h, { x: x + 0.32, y: gy + 1.55, w: cw - 0.6, h: 0.55, fontFace: HEAD, fontSize: 19, bold: true, color: i === 0 ? WHITE : NAVY });
    s.addText(pil[i].d, { x: x + 0.32, y: gy + 2.15, w: cw - 0.6, h: 1.7, fontFace: BODY, fontSize: 12.5, color: i === 0 ? "C7DBE3" : INK, lineSpacingMultiple: 1.12 });
  }
  pageFoot(s, 13, false);
}

// ============================================================
// SLIDE 14 — Target state on a page (synthesis)
// ============================================================
async function slide14() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "Bringing it together", false);
  title(s, "The target state on a page", false);

  // Element 1 band
  card(s, 0.6, 1.95, 12.1, 1.75, CARD);
  await iconChip(s, Fi.FiGrid, 0.9, 2.28, 0.9, LIGHT, TEAL);
  s.addText([{ text: "ELEMENT 01   ", options: { bold: true, color: TEAL, charSpacing: 2 } }, { text: "A complete, connected suite", options: { bold: true, color: NAVY } }], { x: 1.95, y: 2.2, w: 10.5, h: 0.4, fontFace: BODY, fontSize: 16 });
  s.addText("Every core need served in-house across all five member types — complete, connected, digital-native and purpose-built. Gaps in wealth, advice, protection and segment products are closed.", { x: 1.95, y: 2.68, w: 10.4, h: 0.9, fontFace: BODY, fontSize: 13.5, color: INK, lineSpacingMultiple: 1.1 });

  // connector
  await iconChip(s, Fi.FiPlus, 6.35, 3.82, 0.55, AMBER, WHITE);

  // Element 2 band
  card(s, 0.6, 4.5, 12.1, 1.75, NAVY);
  s.addShape(P.ShapeType.roundRect, { x: 0.6, y: 4.5, w: 12.1, h: 1.75, rectRadius: 0.09, fill: { color: NAVY }, line: { type: "none" } });
  await iconChip(s, Fi.FiCompass, 0.9, 4.83, 0.9, NAVY2, AMBER);
  s.addText([{ text: "ELEMENT 02   ", options: { bold: true, color: AMBER, charSpacing: 2 } }, { text: "A proposition that is unmistakably ours", options: { bold: true, color: WHITE } }], { x: 1.95, y: 4.75, w: 10.5, h: 0.4, fontFace: BODY, fontSize: 16 });
  s.addText("We stop competing on rate alone and show up on member value, trusted advice, purpose and effortless service — the mutual difference, made visible at the point of choice.", { x: 1.95, y: 5.23, w: 10.4, h: 0.9, fontFace: BODY, fontSize: 13.5, color: "C7DBE3", lineSpacingMultiple: 1.1 });

  s.addText("A complete suite gives us the right to compete; a distinctive proposition is why members choose us.", { x: 0.6, y: 6.5, w: 12.1, h: 0.35, fontFace: BODY, fontSize: 13, italic: true, bold: true, color: TEAL_DK, align: "center" });
  pageFoot(s, 14, false);
}

// ============================================================
// SLIDE 15 — Roadmap horizons
// ============================================================
async function slide15() {
  const s = P.addSlide(); lightBg(s);
  kicker(s, "The path", false);
  title(s, "Three horizons to get there", false);

  const hor = [
    { t: "Horizon 1", w: "0–12 months", h: "Fix the basics", d: "Complete the core on-sale suite, close obvious segment gaps, reach digital origination parity.", ic: Fi.FiTool, c: TEAL },
    { t: "Horizon 2", w: "12–24 months", h: "Differentiate", d: "Integrate wealth, advice & protection; launch member-value and segment-led propositions.", ic: Fi.FiTrendingUp, c: AMBER_DK },
    { t: "Horizon 3", w: "24 months +", h: "Lead", d: "Purpose-led, ecosystem-enabled banking where the member-owned model is our edge at scale.", ic: Fi.FiFlag, c: NAVY },
  ];
  const cw = 3.87, gap = 0.35, gy = 2.15, ch = 4.25;
  for (let i = 0; i < 3; i++) {
    const x = 0.6 + i * (cw + gap);
    card(s, x, gy, cw, ch, CARD);
    s.addText(hor[i].w.toUpperCase(), { x: x + 0.34, y: gy + 0.35, w: cw - 0.6, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: hor[i].c, charSpacing: 2 });
    s.addText(hor[i].t, { x: x + 0.34, y: gy + 0.62, w: cw - 0.6, h: 0.4, fontFace: BODY, fontSize: 13, color: SLATE });
    await iconChip(s, hor[i].ic, x + 0.34, gy + 1.15, 0.95, LIGHT, hor[i].c);
    s.addText(hor[i].h, { x: x + 0.34, y: gy + 2.3, w: cw - 0.6, h: 0.5, fontFace: HEAD, fontSize: 22, bold: true, color: NAVY });
    s.addText(hor[i].d, { x: x + 0.34, y: gy + 2.9, w: cw - 0.6, h: 1.2, fontFace: BODY, fontSize: 13, color: INK, lineSpacingMultiple: 1.12 });
    // number badge
    s.addText(String(i + 1), { x: x + cw - 0.95, y: gy + 0.25, w: 0.7, h: 0.7, fontFace: HEAD, fontSize: 30, bold: true, color: LINE, align: "right" });
  }
  s.addText("Illustrative sequencing — confirm scope and timing with the executive team.", { x: 0.6, y: 6.65, w: 12, h: 0.3, fontFace: BODY, fontSize: 11, italic: true, color: SLATE });
  pageFoot(s, 15, false);
}

// ============================================================
// SLIDE 16 — Closing / the ask (dark)
// ============================================================
async function slide16() {
  const s = P.addSlide(); darkBg(s);
  s.addShape(P.ShapeType.rect, { x: 0, y: 0, w: W, h: H, fill: { color: NAVY }, line: { type: "none" } });
  s.addShape(P.ShapeType.roundRect, { x: 9.9, y: 3.4, w: 5.0, h: 5.0, rectRadius: 2.5, fill: { type: "none" }, line: { color: TEAL, width: 1.5, transparency: 55 } });
  s.addText("WHAT WE'RE ASKING OF LEADERS", { x: 0.75, y: 0.95, w: 11, h: 0.4, fontFace: BODY, fontSize: 14, bold: true, color: AMBER, charSpacing: 4 });
  s.addText("Back the shift from vanilla to distinctive", { x: 0.7, y: 1.4, w: 11.5, h: 1.0, fontFace: HEAD, fontSize: 36, bold: true, color: WHITE });

  const asks = [
    { h: "Endorse the two-element target state", d: "A complete product suite and a differentiated, member-owned proposition.", ic: Fi.FiCheckCircle },
    { h: "Prioritise closing the gaps", d: "Fund the Horizon 1 moves that bring the on-sale suite to completeness.", ic: Fi.FiTarget },
    { h: "Commit to the proposition", d: "Agree to compete on member value, not just rate — across every segment.", ic: Fi.FiCompass },
  ];
  const gy = 2.9, cw = 3.9, gap = 0.3;
  for (let i = 0; i < 3; i++) {
    const x = 0.72 + i * (cw + gap);
    s.addShape(P.ShapeType.roundRect, { x, y: gy, w: cw, h: 2.75, rectRadius: 0.09, fill: { color: NAVY2 }, line: { color: TEAL, width: 1 } });
    // build icon synchronously via await outside — handled below
    s.addText(asks[i].h, { x: x + 0.3, y: gy + 1.15, w: cw - 0.6, h: 0.85, fontFace: BODY, fontSize: 16, bold: true, color: WHITE, valign: "top" });
    s.addText(asks[i].d, { x: x + 0.3, y: gy + 1.95, w: cw - 0.6, h: 0.75, fontFace: BODY, fontSize: 12.5, color: "C7DBE3", lineSpacingMultiple: 1.08 });
  }
  // icons after
  for (let i = 0; i < 3; i++) {
    const x = 0.72 + i * (cw + gap);
    await iconChip(s, asks[i].ic, x + 0.3, gy + 0.32, 0.7, NAVY, AMBER);
    s.addText(String(i + 1), { x: x + cw - 0.85, y: gy + 0.28, w: 0.6, h: 0.6, fontFace: HEAD, fontSize: 26, bold: true, color: "2E5567", align: "right" });
  }
  s.addText("The suite earns us the right to compete. The proposition is why members choose us — and stay.", { x: 0.75, y: 6.15, w: 11.5, h: 0.5, fontFace: HEAD, fontSize: 17, italic: true, color: AMBER });
  pageFoot(s, 16, true);
}

// ---------- build ----------
(async () => {
  await slide2();
  await slide3();
  await divider("01", "The retail product suite", "What we look like as a product house — the on-sale catalogue, and how completely it serves every member type.", 4, Fi.FiGrid);
  await slide5();
  await slide6();
  await slide7();
  slide8();
  await slide9();
  await divider("02", "How we show up in the market", "From vanilla, basic banking to a distinctive, member-owned proposition — the second, differentiated view.", 10, Fi.FiCompass);
  await slide11();
  await slide12();
  await slide13();
  await slide14();
  await slide15();
  await slide16();
  await P.writeFile({ fileName: "Target-State-Product-and-Proposition.pptx" });
  console.log("written");
})();
