// Pro vetting rules: one waiting pro (from vetting_queue, migration 0020) and what ABN Lookup said, in;
// a list of checks and a verdict, out. No I/O, so it can be tested: node vetting/assess.test.ts
// The checks never cover the ID photo or selfie themselves: Keith looks at those on the review page.

export type Status = "ok" | "warn" | "bad" | "skip";
export type Check = { key: string; label: string; status: Status; note: string };
export type Verdict = "pass" | "look_closer" | "problem";

/** The parts of ABN Lookup's AbnDetails answer the checks use. */
export type Abr = {
  Abn: string; AbnStatus: string; AbnStatusEffectiveFrom: string; EntityName: string; EntityTypeCode: string;
  EntityTypeName: string; BusinessName: string[]; AddressState: string; AddressPostcode: string; Message: string;
} | { error: string } | null;

type Row = Record<string, any>;

const money = (cents: number) => `$${Math.round(cents / 100)}`;

/** The ATO's ABN check digit rule: take 1 from the first digit, weight, and the sum divides by 89. */
export function abnValid(abn: string): boolean {
  const d = abn.replace(/\s/g, "");
  if (!/^\d{11}$/.test(d)) return false;
  const w = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
  const sum = [...d].reduce((n, c, i) => n + (Number(c) - (i === 0 ? 1 : 0)) * w[i], 0);
  return sum % 89 === 0;
}

const words = (s: string | null | undefined) =>
  (s ?? "").toUpperCase().normalize("NFD").replace(/[̀-ͯ]/g, "").split(/[^A-Z']+/).filter((w) => w.length > 1);

/** Does an individual's ABN name ("SMITH, JANE MARY") hold their first and last name? */
export function nameMatch(entity: string, first: string | null, last: string | null): "both" | "last" | "first" | "none" {
  const e = new Set(words(entity));
  const f = words(first).some((w) => e.has(w));
  const l = words(last).some((w) => e.has(w));
  return f && l ? "both" : l ? "last" : f ? "first" : "none";
}

export function assess(p: Row, abr: Abr): { verdict: Verdict; checks: Check[] } {
  const c: Check[] = [];
  const name = [p.first_name, p.last_name].filter(Boolean).join(" ") || "they";

  // ---- ID photos: are both there? (Keith looks at them himself.) -------------------------------
  const docs: Row[] = p.id_docs ?? [];
  const has = (file: string) => docs.find((d) => String(d.name).endsWith(`/${file}`));
  const id = has("photo-id.jpg"), selfie = has("selfie.jpg");
  if (!id || !selfie) {
    c.push({ key: "id_docs", label: "ID photos", status: "bad",
      note: `Missing: ${[!id && "photo ID", !selfie && "selfie"].filter(Boolean).join(" and ")}. Send it back so they can add it.` });
  } else {
    const small = [id, selfie].filter((d) => (d.size ?? 0) < 40_000);
    c.push({ key: "id_docs", label: "ID photos", status: small.length ? "warn" : "ok",
      note: small.length ? "Both there, but at least one is a very small file: it may be too blurry to read." : "Photo ID and selfie both there. Compare them yourself below." });
  }

  // ---- ABN ---------------------------------------------------------------------------------------
  const abn = p.abn ? String(p.abn).replace(/\s/g, "") : null;
  if (!abn) {
    c.push({ key: "abn", label: "ABN", status: "skip", note: "None given. It's optional in the app." });
  } else if (!abnValid(abn)) {
    c.push({ key: "abn", label: "ABN", status: "bad", note: `${abn} isn't a real ABN: the check digits don't add up. Probably a typo.` });
  } else if (!abr) {
    c.push({ key: "abn", label: "ABN", status: "warn", note: `${abn} is well formed, but ABN Lookup isn't connected, so it wasn't looked up. Check it at abr.business.gov.au.` });
  } else if ("error" in abr || abr.Message) {
    c.push({ key: "abn", label: "ABN", status: "warn", note: `ABN Lookup didn't answer: ${"error" in abr ? abr.error : abr.Message}` });
  } else if (!abr.Abn) {
    c.push({ key: "abn", label: "ABN", status: "bad", note: `ABN Lookup has no record of ${abn}.` });
  } else if (abr.AbnStatus !== "Active") {
    c.push({ key: "abn", label: "ABN", status: "bad", note: `ABN ${abn} is ${abr.AbnStatus.toLowerCase()} (since ${abr.AbnStatusEffectiveFrom}).` });
  } else {
    const where = [abr.AddressState, abr.AddressPostcode].filter(Boolean).join(" ");
    c.push({ key: "abn", label: "ABN", status: "ok",
      note: `Active since ${abr.AbnStatusEffectiveFrom}: ${abr.EntityName} (${abr.EntityTypeName}${where ? `, ${where}` : ""}).` });
    if (abr.EntityTypeCode === "IND") {
      const m = nameMatch(abr.EntityName, p.first_name, p.last_name);
      c.push({ key: "abn_name", label: "Name on the ABN", status: m === "both" ? "ok" : m === "none" ? "bad" : "warn",
        note: m === "both" ? `Matches ${name}.`
          : m === "none" ? `${abr.EntityName} doesn't match ${name}. Someone else's ABN, or a changed name.`
          : `Only the ${m} name matches ${name}. Could be a married or preferred name.` });
    } else {
      const trading = abr.BusinessName?.length ? ` Trading as ${abr.BusinessName.slice(0, 3).join(", ")}.` : "";
      c.push({ key: "abn_name", label: "Name on the ABN", status: "warn",
        note: `The ABN is a business, not a person.${trading} Check ${name} owns or works for it.` });
    }
  }
  if (!p.last_name) c.push({ key: "profile_name", label: "Profile name", status: "warn", note: "No last name on the profile, so the ID name can only be checked by eye." });

  // ---- Work photos -------------------------------------------------------------------------------
  const work: Row[] = p.work ?? [];
  const elsewhere = work.filter((w) => w.also_in > 0).length;
  const twice = work.filter((w) => w.copies > 1).length;
  if (!work.length) {
    c.push({ key: "work", label: "Work photos", status: "warn", note: "None yet. Clients book on these, so it's worth asking for a few." });
  } else if (elsewhere) {
    c.push({ key: "work", label: "Work photos", status: "bad",
      note: `${elsewhere} of ${work.length} ${elsewhere === 1 ? "is the same file as one" : "are the same files as ones"} in another account. Someone else's photos, or a second account.` });
  } else {
    c.push({ key: "work", label: "Work photos", status: twice ? "warn" : "ok",
      note: `${work.length} photo${work.length === 1 ? "" : "s"}, none found in anyone else's account.${twice ? " The same photo is uploaded more than once." : ""} Only exact copies are caught; check they look like their own work.` });
  }

  // ---- Prices and travel ---------------------------------------------------------------------------
  const services: Row[] = p.services ?? [];
  const odd = services.filter((s) => s.price_cents <= 0 ||
    (s.median_of >= 3 && (s.price_cents < 0.4 * s.median_cents || s.price_cents > 2.5 * s.median_cents)));
  if (!services.length) {
    c.push({ key: "prices", label: "Prices", status: "warn", note: "No services yet, so nobody can book them." });
  } else {
    c.push({ key: "prices", label: "Prices", status: odd.length ? "warn" : "ok",
      note: odd.length
        ? odd.slice(0, 4).map((s) => `${s.name} ${money(s.price_cents)}${s.median_of >= 3 ? ` (most charge about ${money(s.median_cents)})` : ""}`).join("; ") + ". Maybe a typo."
        : `${services.length} service${services.length === 1 ? "" : "s"}, priced in line with other pros.` });
  }
  const km = Number(p.travel_radius_km ?? 0), fee = Number(p.travel_fee_cents ?? 0);
  const far = km > 60, dear = fee > 6000;
  c.push({ key: "travel", label: "Travel", status: far || dear ? "warn" : "ok",
    note: `Comes up to ${km} km${p.suburb ? ` from ${p.suburb}` : ""}, ${fee ? `${money(fee)} travel fee` : "no travel fee"}.${far ? " That's a long way for one job." : ""}${dear ? " That fee is high." : ""}` });

  const verdict: Verdict = c.some((x) => x.status === "bad") ? "problem" : c.some((x) => x.status === "warn") ? "look_closer" : "pass";
  return { verdict, checks: c };
}

export const VERDICT_WORDS: Record<Verdict, string> = { pass: "looks good", look_closer: "look closer", problem: "problem" };
