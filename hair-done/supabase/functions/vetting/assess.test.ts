// Run: node vetting/assess.test.ts   (Node 23.6+ runs TypeScript directly)
import assert from "node:assert/strict";
import { abnValid, assess, nameMatch } from "./assess.ts";

// ABN check digits: the ATO's published example, Hair Done's own, and one-digit typos of each.
assert.equal(abnValid("51 824 753 556"), true);
assert.equal(abnValid("45281131814"), true);
assert.equal(abnValid("51 824 753 557"), false);
assert.equal(abnValid("45281131815"), false);
assert.equal(abnValid("1234"), false);

assert.equal(nameMatch("SMITH, JANE MARY", "Jane", "Smith"), "both");
assert.equal(nameMatch("NGUYEN, THI MAI", "Mai", "Tran"), "first");
assert.equal(nameMatch("O'BRIEN, SIOBHAN", "Siobhán", "O'Brien"), "both");
assert.equal(nameMatch("CITIZEN, JOHN", "Ivy", "Kaur"), "none");

const good = {
  id: "p1", first_name: "Ivy", last_name: "Kaur", last_initial: "K", specialties: ["lashes"], suburb: "Brunswick",
  abn: "51 824 753 556", travel_radius_km: 20, travel_fee_cents: 2000, submitted: "2026-10-27T01:00:00Z",
  id_docs: [{ name: "p1/photo-id.jpg", size: 210_000 }, { name: "p1/selfie.jpg", size: 180_000 }],
  work: [{ path: "p1/a.jpg", size: 90_000, also_in: 0, copies: 1 }, { path: "p1/b.jpg", size: 95_000, also_in: 0, copies: 1 }],
  services: [{ name: "Classic lashes", category: "lashes", price_cents: 12000, median_cents: 11000, median_of: 6 }],
};
const abrOk = { Abn: "51824753556", AbnStatus: "Active", AbnStatusEffectiveFrom: "2019-03-01", EntityName: "KAUR, IVY",
  EntityTypeCode: "IND", EntityTypeName: "Individual/Sole Trader", BusinessName: [], AddressState: "VIC", AddressPostcode: "3056", Message: "" };
const levels = (r: ReturnType<typeof assess>) => Object.fromEntries(r.checks.map((c) => [c.key, c.status]));

// Everything right: pass.
let r = assess(good, abrOk);
assert.equal(r.verdict, "pass", JSON.stringify(r.checks));
assert.deepEqual(levels(r), { id_docs: "ok", abn: "ok", abn_name: "ok", work: "ok", prices: "ok", travel: "ok" });

// No ABN given (it's optional) and ABN Lookup not connected: neither is a problem on its own.
assert.equal(assess({ ...good, abn: null }, null).verdict, "pass");
assert.equal(levels(assess(good, null)).abn, "warn");

// Each thing that should make Keith look harder, or call it a problem.
const cases: [string, any, any, string, string][] = [
  ["selfie missing", { ...good, id_docs: [good.id_docs[0]] }, abrOk, "id_docs", "bad"],
  ["tiny ID photo", { ...good, id_docs: [{ name: "p1/photo-id.jpg", size: 9_000 }, good.id_docs[1]] }, abrOk, "id_docs", "warn"],
  ["ABN typo", { ...good, abn: "51 824 753 557" }, null, "abn", "bad"],
  ["ABN cancelled", good, { ...abrOk, AbnStatus: "Cancelled", AbnStatusEffectiveFrom: "2024-06-30" }, "abn", "bad"],
  ["ABN unknown", good, { ...abrOk, Abn: "", AbnStatus: "" }, "abn", "bad"],
  ["ABN Lookup error", good, { ...abrOk, Message: "The GUID entered is not recognised as a Registered Party" }, "abn", "warn"],
  ["someone else's ABN", good, { ...abrOk, EntityName: "CITIZEN, JOHN" }, "abn_name", "bad"],
  ["married name", good, { ...abrOk, EntityName: "SINGH, IVY" }, "abn_name", "warn"],
  ["company ABN", good, { ...abrOk, EntityTypeCode: "PRV", EntityName: "LASH CO PTY LTD", BusinessName: ["Lash Co"] }, "abn_name", "warn"],
  ["no work photos", { ...good, work: [] }, abrOk, "work", "warn"],
  ["photo from another account", { ...good, work: [{ ...good.work[0], also_in: 1 }, good.work[1]] }, abrOk, "work", "bad"],
  ["same photo twice", { ...good, work: [{ ...good.work[0], copies: 2 }] }, abrOk, "work", "warn"],
  ["price typo", { ...good, services: [{ ...good.services[0], price_cents: 1200 }] }, abrOk, "prices", "warn"],
  ["free service", { ...good, services: [{ ...good.services[0], price_cents: 0 }] }, abrOk, "prices", "warn"],
  ["no services", { ...good, services: [] }, abrOk, "prices", "warn"],
  ["150 km radius", { ...good, travel_radius_km: 150 }, abrOk, "travel", "warn"],
  ["no last name", { ...good, last_name: null }, { ...abrOk, EntityName: "KAUR, IVY" }, "profile_name", "warn"],
];
for (const [what, p, abr, key, status] of cases) {
  const got = assess(p, abr);
  assert.equal(levels(got)[key], status, `${what}: ${key} should be ${status}, got ${levels(got)[key]}`);
  assert.equal(got.verdict, status === "bad" ? "problem" : "look_closer", `${what}: verdict`);
}
// Few other pros in a category: no price comparison, so no false alarm.
assert.equal(levels(assess({ ...good, services: [{ ...good.services[0], price_cents: 1200, median_of: 2 }] }, abrOk)).prices, "ok");
// They/them, and no checking of the ID photos themselves.
const all = JSON.stringify(cases.map(([, p, abr]) => assess(p, abr)));
assert.ok(!/\b(she|her)\b/i.test(all), "they/them for pros");

console.log(`ok: ${cases.length + 3} vetting cases, 5 ABNs, 4 name matches`);
for (const c of assess({ ...good, work: [{ ...good.work[0], also_in: 1 }] }, { ...abrOk, EntityName: "SINGH, IVY" }).checks) {
  console.log(`  ${c.status.padEnd(4)} ${c.label}: ${c.note}`);
}
