const pptxgen = require("pptxgenjs");

// ============================================================
// PALETTE — "Heritage Mutual": Forest-ink · Brass · Warm ivory
// An education-sector mutual (teachers, nurses): trusted, patient,
// purpose-led. Deep forest-ink dominates; warm ivory carries the
// content; a single brass accent does all the emphasis.
// ============================================================
const INK      = "13221C";
const INK2     = "1C3227"; // tonal watermark on dark
const BRASS    = "C69A5B"; // accent on dark grounds
const BRASS_DK = "9C7538"; // accent for small text on ivory
const PAPER    = "F4F1EA";
const PAPER2   = "EAE4D7"; // panel tint on paper
const HAIR     = "D6CFBF";
const HAIR_D   = "2E4438";
const HEAD     = "16271F";
const BODY_C   = "31403A";
const MUTED    = "78857C";
const GREY_TO  = "9AA49C"; // "from/vanilla" muted serif
const IVORY    = "EFE9DA";
const IVORY_M  = "A6B0A6";
const FOOT_D   = "6E7C74";

const DISPLAY = "Century Schoolbook";
const BODY    = "Calibri";

const W = 13.333, H = 7.5, ML = 0.9;
const P = new pptxgen();
P.defineLayout({ name: "W", width: W, height: H });
P.layout = "W";
P.author = "[Bank Name]";
P.title = "Core Banking Platform Transformation";
const R = P.ShapeType;

// ---------- helpers ----------
function inkBg(s) { s.background = { color: INK }; }
function paperBg(s) { s.background = { color: PAPER }; }
function kicker(s, t, dark, y) {
  s.addText(t.toUpperCase(), { x: ML, y: y == null ? 0.7 : y, w: 11.4, h: 0.3, fontFace: BODY, fontSize: 11.5, bold: true, color: dark ? BRASS : BRASS_DK, charSpacing: 4 });
}
function headline(s, t, dark, y, size) {
  s.addText(t, { x: ML - 0.03, y: y == null ? 1.12 : y, w: 11.7, h: 1.0, fontFace: DISPLAY, fontSize: size || 33, color: dark ? IVORY : HEAD, lineSpacingMultiple: 1.0 });
}
function subhead(s, t, y) {
  s.addText(t, { x: ML, y: y, w: 11.5, h: 0.4, fontFace: BODY, fontSize: 13.5, italic: true, color: MUTED, lineSpacingMultiple: 1.1 });
}
function hair(s, x, y, w, color) {
  s.addShape(R.rect, { x, y, w, h: 0.015, fill: { color: color || HAIR }, line: { type: "none" } });
}
function vrule(s, x, y, h, color) {
  s.addShape(R.rect, { x, y, w: 0.014, h, fill: { color: color || HAIR }, line: { type: "none" } });
}
function foot(s, n, dark) {
  s.addText("[Bank Name]  ·  Core Banking Platform Transformation", { x: ML, y: 7.04, w: 8.5, h: 0.3, fontFace: BODY, fontSize: 9, color: dark ? FOOT_D : MUTED, charSpacing: 1 });
  s.addText(String(n).padStart(2, "0"), { x: 11.85, y: 7.0, w: 0.6, h: 0.32, fontFace: DISPLAY, fontSize: 12, color: dark ? BRASS : BRASS_DK, align: "right" });
}
function ghost(s, txt, x, w) {
  s.addText(txt, { x, y: 0.9, w, h: 5.7, fontFace: DISPLAY, fontSize: 400, bold: true, color: INK2, align: "right", valign: "middle" });
}

// ============================================================
// S1 — Title (dark)  · the transformation
// ============================================================
function s1() {
  const s = P.addSlide(); inkBg(s);
  s.addText("→", { x: 7.7, y: 0.1, w: 5.55, h: 7.3, fontFace: BODY, fontSize: 300, color: INK2, align: "right", valign: "middle" });
  kicker(s, "Executive Briefing  ·  [Bank Name]", true, 0.9);
  s.addText("Core Banking\nPlatform\nTransformation", { x: 0.86, y: 2.15, w: 9.6, h: 2.9, fontFace: DISPLAY, fontSize: 48, color: IVORY, lineSpacingMultiple: 1.02 });
  s.addText("Reshaping the product portfolio — from a product-led catalogue to a proposition-led architecture, delivered on the new Infosys core platform.", { x: 0.9, y: 5.15, w: 8.4, h: 0.9, fontFace: BODY, fontSize: 15, color: IVORY_M, lineSpacingMultiple: 1.2 });
  s.addText([
    { text: "01", options: { fontFace: DISPLAY, fontSize: 15, color: BRASS, bold: true } },
    { text: "   Current state — a broad, product-led catalogue", options: { fontFace: BODY, fontSize: 13, color: IVORY } },
  ], { x: 0.9, y: 6.35, w: 8.2, h: 0.32 });
  s.addText([
    { text: "02", options: { fontFace: DISPLAY, fontSize: 15, color: BRASS, bold: true } },
    { text: "   Target state — a simplified, proposition-led architecture", options: { fontFace: BODY, fontSize: 13, color: IVORY } },
  ], { x: 0.9, y: 6.72, w: 9.0, h: 0.32 });
  s.addText("Prepared for the Executive & Leadership Team  ·  [Month Year]", { x: 8.9, y: 7.02, w: 3.55, h: 0.3, fontFace: BODY, fontSize: 10, color: FOOT_D, align: "right" });
  s.addNotes("Opening frame. This is about the product portfolio dimension of the core platform transformation. The whole story is one shift: from a product-led catalogue to a proposition-led architecture, enabled by the new Infosys platform. Everything today leads to four executive decisions.");
}

// ============================================================
// S2 — Executive summary (light)  · the 48 / 10 stat moment
// ============================================================
function s2() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Executive summary", false);
  headline(s, "From a product-led catalogue to a proposition-led architecture", false, 1.12, 28);
  subhead(s, "The shift reduces product complexity, improves member clarity, and creates flexibility for segment-based propositions.", 1.78);

  const y0 = 2.45;
  s.addText("CURRENT PORTFOLIO", { x: ML, y: y0, w: 5, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: MUTED, charSpacing: 3 });
  s.addText("Broad and product-led — a catalogue built to differentiate through the number and variety of products we offer.", { x: ML, y: y0 + 0.4, w: 5.05, h: 1.55, fontFace: DISPLAY, fontSize: 18.5, color: HEAD, lineSpacingMultiple: 1.12 });

  s.addShape(R.roundRect, { x: 6.55, y: y0 - 0.25, w: 5.9, h: 2.35, rectRadius: 0.06, fill: { color: INK }, line: { type: "none" } });
  s.addText("THE TARGET STATE", { x: 6.95, y: y0 + 0.05, w: 5, h: 0.3, fontFace: BODY, fontSize: 11, bold: true, color: BRASS, charSpacing: 3 });
  s.addText("A simplified, proposition-led architecture — fewer core products, far greater configurability, and clearer member propositions.", { x: 6.95, y: y0 + 0.45, w: 5.1, h: 1.5, fontFace: DISPLAY, fontSize: 18.5, color: IVORY, lineSpacingMultiple: 1.12 });

  hair(s, ML, 4.8, 11.53);
  const stats = [
    { n: "48", l: "owned, on-sale products in the current catalogue" },
    { n: "10", l: "third-party products, adding further complexity" },
    { n: "4",  l: "executive decisions required to move forward" },
  ];
  const cw = 3.84;
  stats.forEach((st, i) => {
    const x = ML + i * cw;
    if (i > 0) vrule(s, x - 0.02, 5.15, 1.2);
    s.addText(st.n, { x: x, y: 5.0, w: 1.55, h: 1.25, fontFace: DISPLAY, fontSize: 58, bold: true, color: BRASS_DK, valign: "middle" });
    s.addText(st.l, { x: x + 1.6, y: 5.08, w: cw - 1.8, h: 1.12, fontFace: BODY, fontSize: 12, color: BODY_C, lineSpacingMultiple: 1.1, valign: "middle" });
  });
  foot(s, 2, false);
  s.addNotes("The setup, and the stat that lands it: 48 owned on-sale products plus 10 third-party products is the scale of today's complexity. Left is where we are; the ink panel is the destination. The 4 previews the executive decisions on the closing slide — product consolidation, migration treatment, member impact, and Infosys platform capability.");
}

// ============================================================
// Divider (dark)
// ============================================================
function divider(num, word1, word2, blurb, pageN, note) {
  const s = P.addSlide(); inkBg(s);
  ghost(s, num, 6.0, 7.0);
  kicker(s, "Element " + (num === "01" ? "One" : "Two"), true, 2.35);
  s.addText(word1 + "\n" + word2, { x: 0.86, y: 2.8, w: 11.5, h: 2.1, fontFace: DISPLAY, fontSize: 46, color: IVORY, lineSpacingMultiple: 1.0 });
  s.addText(blurb, { x: 0.9, y: 5.05, w: 8.6, h: 1.0, fontFace: BODY, fontSize: 15.5, color: IVORY_M, lineSpacingMultiple: 1.2 });
  foot(s, pageN, true);
  s.addNotes(note);
}

// ============================================================
// S4 — Current state: product-led portfolio (2x2 grid)
// ============================================================
function s4() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Current state  ·  The portfolio", false);
  headline(s, "A broad, product-led portfolio", false);
  subhead(s, "Breadth built to differentiate through product variety — across lending, deposits, transaction accounts, cards, education-sector banking and third-party offers.", 1.72);

  const items = [
    { n: "01", h: "A broad catalogue", d: "Lending, deposits, transaction accounts, credit cards, education-sector banking and third-party offers." },
    { n: "02", h: "Concentrated complexity", d: "Most visible in home lending, savings, term deposits and education-sector products." },
    { n: "03", h: "Product-based differentiation", d: "Differentiation comes from products, not from segment, behaviour, relationship or life stage." },
    { n: "04", h: "Limited-value products", d: "Some products carry low usage, limited strategic value or overlapping propositions." },
  ];
  const colW = 5.35, gap = 0.83, y0 = 2.55, rowH = 2.02;
  items.forEach((p, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = ML + col * (colW + gap), y = y0 + row * rowH;
    hair(s, x, y - 0.2, colW);
    s.addText(p.n, { x: x, y: y, w: 1.0, h: 0.9, fontFace: DISPLAY, fontSize: 40, bold: true, color: BRASS });
    s.addText(p.h, { x: x + 1.05, y: y + 0.02, w: colW - 1.05, h: 0.55, fontFace: DISPLAY, fontSize: 20, color: HEAD });
    s.addText(p.d, { x: x + 1.05, y: y + 0.62, w: colW - 1.05, h: 1.05, fontFace: BODY, fontSize: 13, color: BODY_C, lineSpacingMultiple: 1.14 });
  });
  foot(s, 4, false);
  s.addNotes("The diagnosis of today. The catalogue is broad and built to differentiate through product count. Complexity concentrates in home lending, savings, term deposits and education-sector products. Crucially, differentiation is product-based rather than member-based — and some products earn their keep only marginally.");
}

// ============================================================
// S5 — Current state challenges (asymmetric: thesis + 5 rows)
// ============================================================
function s5() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Current state  ·  The challenges", false);
  headline(s, "Why the product-led model holds us back", false);

  s.addText("Breadth has become a barrier — to clarity, to focus, and to serving our core members well.", { x: ML, y: 2.35, w: 3.35, h: 3.0, fontFace: DISPLAY, fontSize: 22, color: HEAD, lineSpacingMultiple: 1.14 });
  vrule(s, 4.55, 2.2, 4.25);

  const pts = [
    "Limited differentiation for our core segments — teachers, nurses, education-sector organisations and early-career members.",
    "Product proliferation drives operational complexity and a member proposition that is harder to explain.",
    "Savings and deposit pricing are largely product-led, rather than relationship- or behaviour-led.",
    "Gaps in rewards, financial wellbeing, salary packaging, partner benefits, everyday features and life-stage propositions.",
    "Some capabilities are better suited to Day 2, once the new platform and partner ecosystem are established.",
  ];
  const px = 4.85, pw = 7.58, y0 = 2.2, rowH = 0.88;
  pts.forEach((t, i) => {
    const y = y0 + i * rowH;
    hair(s, px, y - 0.02, pw);
    s.addText(String(i + 1).padStart(2, "0"), { x: px, y: y + 0.14, w: 0.55, h: 0.4, fontFace: DISPLAY, fontSize: 15, bold: true, color: BRASS_DK });
    s.addText(t, { x: px + 0.6, y: y + 0.12, w: pw - 0.6, h: 0.72, fontFace: DISPLAY, fontSize: 14.5, color: HEAD, valign: "middle", lineSpacingMultiple: 1.05 });
  });
  foot(s, 5, false);
  s.addNotes("The conflict. Five challenges, anchored by the thesis on the left: breadth has become a barrier. Note the member framing — teachers, nurses, education-sector organisations, early-career members. Point five sets up the Day 1 / Day 2 sequencing: some value is deliberately deferred until the platform and partner ecosystem mature.");
}

// ============================================================
// S7 — Target state ambition (thesis banner + 4 columns)
// ============================================================
function s7() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Target state  ·  The ambition", false);
  headline(s, "From product-led to proposition-led", false);

  s.addText([
    { text: "Fewer core products. ", options: { color: HEAD } },
    { text: "Greater configurability. ", options: { color: BRASS_DK } },
    { text: "Clearer propositions.", options: { color: HEAD } },
  ], { x: ML, y: 1.95, w: 11.5, h: 0.7, fontFace: DISPLAY, fontSize: 25, valign: "middle" });
  hair(s, ML, 2.85, 11.53);

  const cols = [
    { n: "01", h: "Fewer core products", d: "Supported by configurable features, pricing, eligibility, controls and communications." },
    { n: "02", h: "Clearer propositions", d: "Built for priority segments and life stages — not product variety." },
    { n: "03", h: "Day 1 ready", d: "Platform capability preserved for proposition-led design, with room for Day 2 evolution." },
    { n: "04", h: "No legacy replication", d: "Avoid re-creating unnecessary legacy product structures on the new platform." },
  ];
  const cw = 2.88, y0 = 3.2;
  cols.forEach((c, i) => {
    const x = ML + i * cw;
    if (i > 0) vrule(s, x - 0.06, y0 + 0.1, 3.15);
    s.addText(c.n, { x: x, y: y0, w: cw - 0.2, h: 0.85, fontFace: DISPLAY, fontSize: 42, bold: true, color: BRASS, valign: "top" });
    s.addText(c.h, { x: x, y: y0 + 1.0, w: cw - 0.3, h: 0.75, fontFace: DISPLAY, fontSize: 17, color: HEAD, lineSpacingMultiple: 1.0 });
    s.addText(c.d, { x: x, y: y0 + 1.75, w: cw - 0.35, h: 1.4, fontFace: BODY, fontSize: 12, color: BODY_C, lineSpacingMultiple: 1.14 });
  });
  foot(s, 7, false);
  s.addNotes("The ambition, in one line: fewer core products, greater configurability, clearer propositions. The four columns make it concrete. Day 1 ready is the key platform message — configurability is preserved from launch, with Day 2 evolution intentional, not accidental. And we will not replicate legacy complexity on the new core.");
}

// ============================================================
// S8 — Target state product architecture (hairline table, 6 rows)
// ============================================================
function s8() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Target state  ·  Product architecture", false);
  headline(s, "Fewer core products, configured to the member", false);

  const rows = [
    ["Home lending", "Core owner-occupier and investor products, with basic and offset variants."],
    ["Personal lending", "Secured and unsecured lending; pricing and policy attributes replace product proliferation."],
    ["Transaction accounts", "Everyday Account and Pension Account, with segment-based features and controls."],
    ["Savings", "A smaller product set, with configurable pricing, eligibility and campaign settings."],
    ["Term deposits", "Consolidated around configurable terms, rates and interest-payment frequencies."],
    ["Education-sector banking", "Repositioned onto core products, with additional controls and service-model settings."],
  ];
  const tX = ML, tY = 2.05, aW = 3.4, bW = 8.13, rowH = 0.68;
  s.addText("PRODUCT FAMILY", { x: tX, y: tY, w: aW, h: 0.35, fontFace: BODY, fontSize: 11, bold: true, color: MUTED, charSpacing: 2 });
  s.addText("TARGET-STATE SIMPLIFICATION", { x: tX + aW, y: tY, w: bW, h: 0.35, fontFace: BODY, fontSize: 11, bold: true, color: BRASS_DK, charSpacing: 2 });
  hair(s, tX, tY + 0.44, aW + bW, INK);
  rows.forEach((r, i) => {
    const y = tY + 0.56 + i * rowH;
    s.addText(r[0], { x: tX, y, w: aW - 0.15, h: rowH, fontFace: DISPLAY, fontSize: 15.5, color: HEAD, valign: "middle" });
    s.addText(r[1], { x: tX + aW, y, w: bW - 0.1, h: rowH, fontFace: BODY, fontSize: 13.5, color: BODY_C, valign: "middle", lineSpacingMultiple: 1.05 });
    if (i < rows.length - 1) hair(s, tX, y + rowH, aW + bW);
  });
  s.addText("Illustrative target-state architecture — subject to confirmed product decisions.", { x: ML, y: 6.75, w: 11, h: 0.28, fontFace: BODY, fontSize: 9.5, italic: true, color: MUTED });
  foot(s, 8, false);
  s.addNotes("The architecture. Read left as the product family; right as how it simplifies. The pattern is consistent: what used to be separate products becomes configurable attributes — variants, pricing, eligibility, controls and service settings — on a smaller core. Education-sector banking is repositioned onto core products rather than kept as a separate product set. Illustrative, pending confirmed decisions.");
}

// ============================================================
// S9 — Proposition-led model (layered stack diagram + focus)
// ============================================================
function s9() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "Target state  ·  The operating model", false);
  headline(s, "Propositions sit above the product catalogue", false);

  // ---- left: layered stack ----
  const bx = ML, bw = 5.3;
  // Propositions (top, ink)
  s.addShape(R.roundRect, { x: bx, y: 2.2, w: bw, h: 1.02, rectRadius: 0.05, fill: { color: INK }, line: { type: "none" } });
  s.addText("PROPOSITIONS", { x: bx + 0.35, y: 2.36, w: bw - 0.7, h: 0.34, fontFace: BODY, fontSize: 13, bold: true, color: BRASS, charSpacing: 2 });
  s.addText("Segment & life-stage propositions", { x: bx + 0.35, y: 2.72, w: bw - 0.7, h: 0.32, fontFace: BODY, fontSize: 11.5, color: IVORY_M });
  // Configurable layer (middle, tint)
  s.addShape(R.roundRect, { x: bx, y: 3.42, w: bw, h: 1.35, rectRadius: 0.05, fill: { color: PAPER2 }, line: { type: "none" } });
  s.addText("CONFIGURABLE LAYER", { x: bx + 0.35, y: 3.56, w: bw - 0.7, h: 0.34, fontFace: BODY, fontSize: 13, bold: true, color: BRASS_DK, charSpacing: 2 });
  s.addText("Features · Pricing · Eligibility\nControls · Communications", { x: bx + 0.35, y: 3.92, w: bw - 0.7, h: 0.78, fontFace: BODY, fontSize: 12.5, color: BODY_C, lineSpacingMultiple: 1.12 });
  // Core products (bottom, outlined)
  s.addShape(R.roundRect, { x: bx, y: 4.97, w: bw, h: 1.02, rectRadius: 0.05, fill: { color: PAPER }, line: { color: HAIR, width: 1.25 } });
  s.addText("CORE PRODUCTS", { x: bx + 0.35, y: 5.13, w: bw - 0.7, h: 0.34, fontFace: BODY, fontSize: 13, bold: true, color: HEAD, charSpacing: 2 });
  s.addText("Fewer, standardised, on the new core platform", { x: bx + 0.35, y: 5.49, w: bw - 0.7, h: 0.32, fontFace: BODY, fontSize: 11.5, color: MUTED });

  // ---- right: focus areas + future ----
  vrule(s, 6.5, 2.25, 3.85);
  const rx = 6.85, rw = 5.55;
  s.addText("PRIORITY FOCUS AREAS", { x: rx, y: 2.2, w: rw, h: 0.32, fontFace: BODY, fontSize: 11, bold: true, color: BRASS_DK, charSpacing: 2 });
  const focus = ["Teachers", "Nurses & healthcare workers", "Education-sector organisations", "Youth & early-career members"];
  focus.forEach((f, i) => {
    const y = 2.62 + i * 0.5;
    s.addText(String(i + 1).padStart(2, "0"), { x: rx, y: y, w: 0.5, h: 0.4, fontFace: DISPLAY, fontSize: 14, bold: true, color: BRASS });
    s.addText(f, { x: rx + 0.55, y: y - 0.02, w: rw - 0.55, h: 0.42, fontFace: DISPLAY, fontSize: 15.5, color: HEAD, valign: "middle" });
  });
  s.addText("FUTURE PROPOSITIONS", { x: rx, y: 4.78, w: rw, h: 0.32, fontFace: BODY, fontSize: 11, bold: true, color: MUTED, charSpacing: 2 });
  s.addText("First home buyers, family builders, wealth builders, pre-retirement members — and deeper relationship-based propositions.", { x: rx, y: 5.12, w: rw, h: 0.85, fontFace: BODY, fontSize: 12.5, color: BODY_C, lineSpacingMultiple: 1.15 });

  s.addText("Partner benefits, Doshi financial wellbeing and salary packaging extend value beyond core banking products.", { x: ML, y: 6.5, w: 11.5, h: 0.4, fontFace: DISPLAY, fontSize: 14, italic: true, color: HEAD });
  foot(s, 9, false);
  s.addNotes("The conceptual model, and the heart of the shift. Read the stack bottom-up: fewer standardised core products, wrapped in a configurable layer of features, pricing, eligibility, controls and communications, with propositions sitting on top. Propositions — not products — are what members experience. Priority focus is our core membership; future propositions extend by life stage; and partner benefits, Doshi and salary packaging widen value beyond banking.");
}

// ============================================================
// S10 — Current -> Target shift (From/To table, 5 rows)
// ============================================================
function s10() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "The shift  ·  Current to target", false);
  headline(s, "The same balance sheet, reframed", false);

  const rows = [
    ["Differentiation", "Many products create differentiation", "Fewer products with configurable value"],
    ["Conversations", "Product-led member conversations", "Segment and life-stage propositions"],
    ["Pricing", "Broad headline pricing and product variants", "Relationship, behavioural and eligibility-based pricing"],
    ["Migration", "Legacy migration as lift-and-shift", "Migration as simplification and member value"],
    ["Operating model", "A complex operating model", "Reduced operational and system complexity"],
  ];
  const tX = ML, tY = 2.2, aW = 2.7, bW = 4.4, cW = 4.43, rowH = 0.78;
  s.addText("FROM — TODAY", { x: tX + aW, y: tY, w: bW, h: 0.35, fontFace: BODY, fontSize: 11.5, bold: true, color: MUTED, charSpacing: 2 });
  s.addText("TO — TARGET STATE", { x: tX + aW + bW, y: tY, w: cW, h: 0.35, fontFace: BODY, fontSize: 11.5, bold: true, color: BRASS_DK, charSpacing: 2 });
  hair(s, tX, tY + 0.46, aW + bW + cW, INK);
  rows.forEach((r, i) => {
    const y = tY + 0.58 + i * rowH;
    s.addText(r[0], { x: tX, y, w: aW - 0.1, h: rowH, fontFace: BODY, fontSize: 12, bold: true, color: MUTED, valign: "middle", charSpacing: 1 });
    s.addText(r[1], { x: tX + aW, y, w: bW - 0.2, h: rowH, fontFace: DISPLAY, fontSize: 15.5, color: GREY_TO, valign: "middle", lineSpacingMultiple: 1.02 });
    s.addText(r[2], { x: tX + aW + bW, y, w: cW - 0.15, h: rowH, fontFace: DISPLAY, fontSize: 15.5, color: HEAD, valign: "middle", lineSpacingMultiple: 1.02 });
    if (i < rows.length - 1) hair(s, tX, y + rowH, aW + bW + cW);
  });
  s.addText("The shift is in architecture and proposition — not in the products members hold today.", { x: ML, y: 6.72, w: 11.5, h: 0.3, fontFace: BODY, fontSize: 11.5, italic: true, color: MUTED });
  foot(s, 10, false);
  s.addNotes("The pivot, dimension by dimension. Left is where we are, right is where we're going, across differentiation, conversations, pricing, migration and operating model. The caption is the reassurance for members: this is an architecture and proposition change, not a disruption to the products people hold today.");
}

// ============================================================
// S11 — Legacy migration principles (full-width, 5 rows)
// ============================================================
function s11() {
  const s = P.addSlide(); paperBg(s);
  kicker(s, "The path  ·  Legacy migration", false);
  headline(s, "Principles for migrating the portfolio", false);

  const pts = [
    "No member detriment.",
    "Consolidate where differences are features, pricing settings or eligibility rules — rather than true products.",
    "Grandfather products only where required for member, contractual, regulatory or operational reasons.",
    "Retire unnecessary complexity where products have low usage, limited strategic value or avoidable operational burden.",
    "Validate every migration decision through member-impact, compliance, pricing, operational and communication assessments.",
  ];
  const y0 = 2.25, rowH = 0.9;
  pts.forEach((t, i) => {
    const y = y0 + i * rowH;
    hair(s, ML, y - 0.16, 11.53);
    s.addText(String(i + 1).padStart(2, "0"), { x: ML, y: y, w: 0.9, h: 0.7, fontFace: DISPLAY, fontSize: 30, bold: true, color: BRASS_DK, valign: "middle" });
    s.addText(t, { x: ML + 1.05, y: y, w: 10.45, h: 0.7, fontFace: DISPLAY, fontSize: 16, color: HEAD, valign: "middle", lineSpacingMultiple: 1.05 });
  });
  foot(s, 11, false);
  s.addNotes("The rules of the road for migration. Principle one is non-negotiable: no member detriment. The rest are the decision logic — consolidate features masquerading as products, grandfather only where genuinely required, retire avoidable complexity, and validate every call across member impact, compliance, pricing, operations and communications.");
}

// ============================================================
// S12 — Key decisions & next steps (dark close)  · the ask
// ============================================================
function s12() {
  const s = P.addSlide(); inkBg(s);
  s.addText("→", { x: 8.4, y: 0.3, w: 4.9, h: 7.0, fontFace: BODY, fontSize: 260, color: INK2, align: "right", valign: "middle" });
  kicker(s, "Key decisions & next steps", true);
  s.addText("Four decisions to move\nfrom catalogue to architecture", { x: 0.86, y: 1.2, w: 11.2, h: 1.5, fontFace: DISPLAY, fontSize: 34, color: IVORY, lineSpacingMultiple: 1.02 });

  const asks = [
    { n: "01", h: "Product consolidation", d: "How far to simplify the catalogue into fewer configurable core products." },
    { n: "02", h: "Migration treatment", d: "Consolidate, grandfather or retire — decided by member and operational impact." },
    { n: "03", h: "Member impact", d: "How we protect members and communicate change with no detriment." },
    { n: "04", h: "Infosys platform capability", d: "Confirm Day 1 configurability and the Day 2 evolution roadmap." },
  ];
  const y0 = 3.1;
  asks.forEach((a, i) => {
    const y = y0 + i * 0.85;
    hair(s, ML, y - 0.13, 11.0, HAIR_D);
    s.addText(a.n, { x: ML, y: y, w: 0.9, h: 0.65, fontFace: DISPLAY, fontSize: 21, bold: true, color: BRASS, valign: "middle" });
    s.addText(a.h, { x: ML + 0.95, y: y, w: 5.15, h: 0.65, fontFace: DISPLAY, fontSize: 17.5, color: IVORY, valign: "middle" });
    s.addText(a.d, { x: ML + 6.35, y: y, w: 5.15, h: 0.65, fontFace: BODY, fontSize: 12.5, color: IVORY_M, valign: "middle", lineSpacingMultiple: 1.05 });
  });
  s.addText("Fewer products, greater configurability — a proposition-led portfolio, delivered on the new core platform.", { x: ML, y: 6.6, w: 11.4, h: 0.4, fontFace: DISPLAY, fontSize: 15.5, italic: true, color: BRASS });
  foot(s, 12, true);
  s.addNotes("The close, framed as decisions rather than discussion. Four calls the executive team must make: how far to consolidate, how to treat migration, how to protect and communicate to members, and confirmation of Infosys Day 1 configurability plus the Day 2 roadmap. The italic brass line restates the destination in one sentence.");
}

// ---------- build ----------
s1(); s2();
divider("01", "Current state", "A product-led portfolio",
  "A broad catalogue built to differentiate through product variety — and the complexity that has come with it.", 3,
  "Element 1 divider. We first examine today: a broad, product-led portfolio and the challenges it creates for members and operations.");
s4(); s5();
divider("02", "Target state", "A proposition-led architecture",
  "Fewer core products, greater configurability, and clearer propositions for the members we exist to serve.", 6,
  "Element 2 divider. From today to the destination: a proposition-led architecture on the new Infosys core platform, with Day 1 capability and Day 2 evolution.");
s7(); s8(); s9(); s10(); s11(); s12();

P.writeFile({ fileName: "Target-State-Product-and-Proposition.pptx" }).then(() => console.log("written"));
