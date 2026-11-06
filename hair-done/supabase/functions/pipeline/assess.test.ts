// Run: node pipeline/assess.test.ts   (Node 23.6+ runs TypeScript directly)
import assert from "node:assert/strict";
import { areaFor, categoriesOf, draft, findLink, matchPro, nextAction, pickLeads, score, tally, tidyName,
  type AbnMatch, type Prospect } from "./assess.ts";

// Areas: the spec's launch postcodes, their neighbours, the rest of Melbourne, and everywhere else.
assert.equal(areaFor("3065"), "north"); assert.equal(areaFor("3182"), "south");
assert.equal(areaFor("3068"), "near"); assert.equal(areaFor("3150"), "melbourne");   // Glen Waverley
assert.equal(areaFor("3220"), "outside"); assert.equal(areaFor(""), "outside");      // Geelong, nothing

// Names: categories come from the words, legal suffixes go, shouting becomes title case.
assert.deepEqual(categoriesOf("Glam On The Go Mobile Makeup"), ["makeup"]);
assert.deepEqual(categoriesOf("Hair and Make Up by Tess"), ["hair", "makeup"]);
assert.deepEqual(categoriesOf("Lash & Brow Bar"), ["lashes", "brows"]);
assert.deepEqual(categoriesOf("Mobile Dog Grooming"), []);
assert.equal(tidyName("GLAM ON THE GO MOBILE MAKEUP PTY LTD"), "Glam on the Go Mobile Makeup");
assert.equal(tidyName("Nails by Kiara Pty. Ltd."), "Nails by Kiara");
assert.equal(tidyName("THE MOBILE MUA"), "The Mobile MUA");
assert.equal(tidyName("DC HAIR & MAKEUP ATF ALDERGATE TRUST"), "DC Hair & Makeup");
assert.equal(tidyName("Jo's mobile hairdressing"), "Jo's Mobile Hairdressing");
assert.equal(tidyName("Lans Mobile Nails"), "Lans Mobile Nails");

// Scores: a mobile nail tech in Fitzroy beats a salon-sounding name in Glen Waverley.
assert.ok(score({ name: "Mobile Nails Fitzroy", postcode: "3065" }) > score({ name: "Nail Studio", postcode: "3150" }));
assert.equal(score({ name: "Mobile Nails Fitzroy", postcode: "3065" }), 6 + 3 + 1);

// Picking leads from ABN Lookup: active, current, Victorian, Melbourne, a category, not known, one per ABN.
const m = (Abn: string, Name: string, Postcode: string, extra: Partial<AbnMatch> = {}): AbnMatch =>
  ({ Abn, Name, Postcode, State: "VIC", AbnStatus: "Active", IsCurrent: true, Score: 90, ...extra });
const matches = [
  m("51 824 753 556", "MOBILE NAILS BY IVY", "3056"),
  m("51824753556", "IVY K NAILS", "3056"),                                   // same ABN, worse name
  m("11111111111", "Bridal Hair Melbourne", "3150"),
  m("22222222222", "Mobile Makeup Sydney", "2000", { State: "NSW" }),
  m("33333333333", "Mobile Lashes Geelong", "3220"),                         // outside Melbourne
  m("44444444444", "Mobile Brows", "3182", { AbnStatus: "Cancelled" }),
  m("55555555555", "Mobile Hair Co", "3065", { IsCurrent: false }),          // an old name
  m("66666666666", "Mobile Car Wash", "3065"),                               // no category
  m("77777777777", "Mobile Makeup Elwood", "3184"),                          // already in the pipeline
  m("123", "Mobile Nails", "3065"),                                          // not an ABN
];
const picked = pickLeads(matches, new Set(["77777777777"]), 10);
assert.deepEqual(picked.map((l) => l.abn), ["51824753556", "11111111111"]);
assert.equal(picked[0].name, "Mobile Nails by Ivy"); assert.ok(picked[0].mobile);
assert.equal(pickLeads(matches, new Set(), 1).length, 1);

// What's due: message the new, follow up once after 5 days, then leave them; ask the ID checked for a referral.
const now = new Date("2026-11-09T00:00:00Z");
const p = (extra: Partial<Prospect>): Prospect => ({ id: "x", source: "abn", status: "new", name: "Mobile Nails by Ivy", categories: ["nails"], ...extra });
assert.equal(nextAction(p({}), now), "message");
assert.equal(nextAction(p({ status: "messaged", messaged_at: "2026-11-06T00:00:00Z" }), now), null);
assert.equal(nextAction(p({ status: "messaged", messaged_at: "2026-11-04T00:00:00Z" }), now), "follow_up");
assert.equal(nextAction(p({ status: "followed_up", followed_up_at: "2026-11-01T00:00:00Z" }), now), null);
assert.equal(nextAction(p({ status: "followed_up", followed_up_at: "2026-10-30T00:00:00Z" }), now), "quiet");
assert.equal(nextAction(p({ status: "verified" }), now), "ask_referral");
assert.equal(nextAction(p({ status: "verified", referral_asked_at: "2026-11-08T00:00:00Z" }), now), null);
assert.equal(nextAction(p({ status: "declined" }), now), null);

// Sign-ups: matched on ABN (spaces don't matter) or email; ID checked moves them on; no change, no update.
const pros = [{ id: "pro1", abn: "51 824 753 556", is_verified: false }, { id: "pro2", email: "Tess@Example.com", is_verified: true }];
assert.deepEqual(matchPro(p({ abn: "51824753556", status: "messaged" }), pros), { status: "signed_up", pro_id: "pro1" });
assert.deepEqual(matchPro(p({ email: "tess@example.com", status: "replied" }), pros), { status: "verified", pro_id: "pro2" });
assert.equal(matchPro(p({ abn: "51824753556", status: "signed_up", pro_id: "pro1" }), pros), null);
assert.equal(matchPro(p({ abn: "99999999999" }), pros), null);

// Drafts: the spec's terms, a way to stop, Keith's own note when he has one, and the brief's voice.
const first = draft(p({}), "message");
for (const s of ["no joining fee", "12%", "$3 booking fee", "daily", "Founding pro", "rather I didn't message again", "Mobile Nails by Ivy and your nail work", "be your first booking"])
  assert.ok(first.includes(s), `first message says "${s}"`);
const noted = draft(p({ first_name: "Ivy", note: "your chrome French tips are very good" }), "message");
assert.ok(noted.startsWith("Hi Ivy,") && noted.includes("Your chrome French tips are very good."));
assert.ok(draft(p({}), "follow_up").includes("won't message again"));
assert.ok(draft(p({ first_name: "Ivy" }), "ask_referral").startsWith("Hi Ivy, you're ID checked"));
const BANNED = /elevate|unlock|seamless|effortless|journey|empower|curated|discover|explore|experience|indulge|pamper|treat yourself|vibe|bespoke|premium|hassle-free|stress-free|fingertips|comfort of your own home|look no further|got you covered|welcome to|platform|vendor|provider|gig|—|–|!|~/i;
for (const kind of ["message", "follow_up", "ask_referral"] as const)
  for (const who of [p({}), p({ first_name: "Ivy", note: "love your bridal hair" })])
    assert.ok(!BANNED.test(draft(who, kind)), `${kind} keeps to the brief: ${draft(who, kind).match(BANNED)}`);

// Find links: their Instagram (however it was pasted), or a search.
assert.equal(findLink(p({ instagram: "@ivy.nails" })), "https://www.instagram.com/ivy.nails/");
assert.equal(findLink(p({ instagram: "https://instagram.com/ivy.nails/?hl=en" })), "https://www.instagram.com/ivy.nails/");
assert.ok(findLink(p({})).startsWith("https://www.google.com/search?q=%22Mobile%20Nails%20by%20Ivy%22"));

// The week in numbers.
const t = tally([p({}), p({ status: "messaged", messaged_at: "2026-11-01T00:00:00Z" }), p({ status: "replied", messaged_at: "2026-11-01T00:00:00Z", replied_at: "2026-11-02T00:00:00Z" }),
  p({ status: "verified", messaged_at: "2026-10-20T00:00:00Z" }), p({ status: "declined", messaged_at: "2026-10-20T00:00:00Z" })], now);
assert.deepEqual(t, { to_message: 1, follow_ups: 1, referrals: 1, messaged: 4, replied: 2, signed_up: 1, verified: 1 });

console.log("pipeline assess: all passed");
