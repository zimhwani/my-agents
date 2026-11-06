// Pro pipeline: the pure part. Which ABN Lookup names look like a mobile pro worth messaging, how good a lead
// each is, what Keith could send them, and what's due this week. No network, no database: index.ts does that.
//
// It drafts; Keith sends, from his own account (docs/product-spec.md, "Recruiting the first 50 pros").

/** One match from ABN Lookup's name search (abr.business.gov.au/json/MatchingNames.aspx). */
export type AbnMatch = { Abn: string; AbnStatus?: string; IsCurrent?: boolean; Name: string; NameType?: string; Postcode?: string; State?: string; Score?: number };

export type Category = "hair" | "nails" | "makeup" | "lashes" | "brows";

export type Status = "new" | "messaged" | "followed_up" | "replied" | "signed_up" | "verified" | "quiet" | "declined" | "not_a_fit";

export type Prospect = {
  id: string; source: "abn" | "keith" | "referral"; status: Status; name: string; first_name?: string | null;
  abn?: string | null; email?: string | null; instagram?: string | null; postcode?: string | null; suburb?: string | null;
  categories?: Category[]; mobile?: boolean; note?: string | null; score?: number;
  messaged_at?: string | null; followed_up_at?: string | null; replied_at?: string | null; referral_asked_at?: string | null;
  pro_id?: string | null; created_at?: string;
};

export type Pro = { id: string; abn?: string | null; email?: string | null; is_verified?: boolean; first_name?: string | null };

// What Keith searches ABN Lookup for each week. Names with "mobile" in them say it outright; bridal and event
// pros nearly always travel.
export const SEARCHES = ["mobile hair", "mobile hairdresser", "mobile hairdressing", "mobile nails", "mobile nail",
  "mobile makeup", "mobile make up", "mobile beauty", "mobile lashes", "mobile lash", "mobile brows",
  "bridal hair", "bridal makeup", "hair and makeup", "makeup artistry"];

const WORDS: Record<Category, RegExp> = {
  hair: /\b(hair|hairdress\w*|blow ?dry|blowout|braid\w*|updo\w*|stylist)\b/i,
  nails: /\b(nail\w*|manicure\w*|pedicure\w*|mani|pedi)\b/i,
  makeup: /\b(make ?up|makeup\w*|mua)\b/i,
  lashes: /\b(lash\w*)\b/i,
  brows: /\b(brow\w*)\b/i,
};
const MOBILE = /\b(mobile|on the go|on the move|to you|at home|travelling|traveling)\b/i;
const EVENT = /\b(bridal|bride\w*|wedding\w*|event\w*)\b/i;

// The launch suburbs (docs/product-spec.md, "Launch area"), the suburbs next to them, and the rest of Melbourne.
export const LAUNCH: Record<string, "north" | "south"> = {
  "3053": "north", "3056": "north", "3057": "north", "3065": "north", "3066": "north", "3070": "north",
  "3141": "south", "3181": "south", "3182": "south", "3184": "south", "3205": "south",
};
const NEAR = new Set(["3000", "3002", "3003", "3006", "3008", "3051", "3052", "3054", "3055", "3058", "3067", "3068",
  "3071", "3072", "3078", "3121", "3142", "3143", "3144", "3183", "3185", "3206", "3207"]);
const METRO: [number, number][] = [[3000, 3210], [3335, 3341], [3427, 3442], [3750, 3810], [3910, 3944], [3975, 3978]];

export type Area = "north" | "south" | "near" | "melbourne" | "outside";
export function areaFor(postcode?: string | null): Area {
  const p = (postcode ?? "").trim();
  if (LAUNCH[p]) return LAUNCH[p];
  if (NEAR.has(p)) return "near";
  const n = Number(p);
  return METRO.some(([a, b]) => n >= a && n <= b) ? "melbourne" : "outside";
}
export const AREA_WORDS: Record<Area, string> = { north: "Inner north", south: "Inner south", near: "Next to the launch area",
  melbourne: "Melbourne, outside the launch area", outside: "Outside Melbourne" };

export const categoriesOf = (name: string): Category[] =>
  (Object.keys(WORDS) as Category[]).filter((c) => WORDS[c].test(name));

/** Higher is better. The launch suburbs matter most: that's where the first 50 pros have to be. */
export function score(p: { name: string; postcode?: string | null; categories?: Category[] }): number {
  const area = areaFor(p.postcode);
  const cats = p.categories ?? categoriesOf(p.name);
  return ({ north: 6, south: 6, near: 4, melbourne: 1, outside: 0 })[area]
    + (MOBILE.test(p.name) ? 3 : 0) + (EVENT.test(p.name) ? 1 : 0) + (cats.length ? 1 : 0);
}

/** "GLAM ON THE GO MOBILE MAKEUP PTY LTD" → "Glam on the Go Mobile Makeup". Trusts lose their "ATF ..." part. */
export function tidyName(raw: string): string {
  const cut = raw.replace(/\s+(atf|as trustee for|t\/a|trading as)\s.*$/i, "")
    .replace(/\b(pty\.?\s*ltd\.?|proprietary limited|limited|ltd\.?|p\/l)\b/gi, "").replace(/\s+/g, " ").trim().replace(/[,.&-]+$/, "").trim();
  // Someone chose the capitals ("Nails by Kiara"): keep them. Shouting, or mostly lowercase: title case.
  const words = cut.split(/\s+/).filter((w) => /^[a-z]{3,}/i.test(w));
  if (cut !== cut.toUpperCase() && words.filter((w) => /^[a-z]/.test(w)).length * 2 < words.length) return cut;
  const initials = new Set(cut.split(/\s+/).filter((w) => /^[A-Z]{2,3}$/.test(w) && !/[AEIOUY]/.test(w)));   // DC, MJ (not BY, MY)
  return cut.toLowerCase().replace(/(^|[\s(&/-])([a-z])/g, (_, a, b) => a + b.toUpperCase())
    .replace(/(?!^)\b(By|And|Of|On|At|To|For|In|With|The|A)\b/g, (w) => w.toLowerCase()).replace(/\bMua\b/g, "MUA")
    .split(" ").map((w) => (initials.has(w.toUpperCase()) ? w.toUpperCase() : w)).join(" ");
}

/**
 * ABN Lookup matches → new leads, best first. Keeps current names on active ABNs in Melbourne that name a
 * category, skips ABNs already in the pipeline or already a pro, and one lead per ABN.
 */
export function pickLeads(matches: AbnMatch[], known: Set<string>, limit: number) {
  const best = new Map<string, { abn: string; name: string; postcode: string; categories: Category[]; mobile: boolean; score: number }>();
  for (const m of matches) {
    const abn = String(m.Abn ?? "").replace(/\D/g, "");
    if (abn.length !== 11 || known.has(abn)) continue;
    if (m.IsCurrent === false || (m.AbnStatus && !/^(active|0000000001)$/i.test(m.AbnStatus))) continue;
    if ((m.State ?? "VIC") !== "VIC" || areaFor(m.Postcode) === "outside") continue;
    const name = tidyName(m.Name ?? "");
    const categories = categoriesOf(name);
    if (!name || !categories.length) continue;
    const lead = { abn, name, postcode: String(m.Postcode ?? ""), categories, mobile: MOBILE.test(name) || EVENT.test(name), score: 0 };
    lead.score = score(lead);
    if (!best.has(abn) || best.get(abn)!.score < lead.score) best.set(abn, lead);
  }
  return [...best.values()].sort((a, b) => b.score - a.score || a.name.localeCompare(b.name)).slice(0, limit);
}

// ---- What's due -----------------------------------------------------------------------------------
export const FOLLOW_UP_DAYS = 5;   // no reply this long after the first message: one follow-up
export const QUIET_DAYS = 10;      // no reply this long after the follow-up: leave them be

const days = (from: string | null | undefined, now: Date) => (from ? (now.getTime() - Date.parse(from)) / 86_400_000 : 0);

export type Action = "message" | "follow_up" | "quiet" | "ask_referral" | null;
export function nextAction(p: Prospect, now: Date): Action {
  if (p.status === "new") return "message";
  if (p.status === "messaged" && days(p.messaged_at, now) >= FOLLOW_UP_DAYS) return "follow_up";
  if (p.status === "followed_up" && days(p.followed_up_at, now) >= QUIET_DAYS) return "quiet";
  if (p.status === "verified" && !p.referral_asked_at) return "ask_referral";
  return null;
}

/** A prospect who's now a pro: matched on ABN or email. Returns the new status and pro, or null for no change. */
export function matchPro(p: Prospect, pros: Pro[]): { status: Status; pro_id: string } | null {
  if (p.status === "verified") return null;
  const abn = (p.abn ?? "").replace(/\D/g, ""), email = (p.email ?? "").trim().toLowerCase();
  const pro = pros.find((x) => (p.pro_id && x.id === p.pro_id) || (abn && (x.abn ?? "").replace(/\D/g, "") === abn)
    || (email && (x.email ?? "").trim().toLowerCase() === email));
  if (!pro) return null;
  const status: Status = pro.is_verified ? "verified" : "signed_up";
  return status === p.status && p.pro_id === pro.id ? null : { status, pro_id: pro.id };
}

// ---- The messages Keith sends ------------------------------------------------------------------------
// In the Hair Done voice (docs/build-brief.md, section 3) and the terms the spec promises: no joining fee, no
// monthly fee, 12% from the pro, $3 from the client, daily payouts, a "Founding pro" line, the first booking
// from the team. No promise of volume. Each one says how to stop the messages (the Spam Act wants a way out).
const WHAT: Record<Category, string> = { hair: "hair", nails: "nail", makeup: "makeup", lashes: "lash", brows: "brow" };
const hi = (p: Prospect) => (p.first_name ? `Hi ${p.first_name},` : "Hi,");

export function draft(p: Prospect, kind: "message" | "follow_up" | "ask_referral"): string {
  if (kind === "follow_up") return [
    `${hi(p)} following up on my message about Hair Done. If it's not for you, no worries at all, and I won't message again.`,
    "If you'd like to hear more, a 20-minute call is all it takes. Keith",
  ].join("\n\n");
  if (kind === "ask_referral") return [
    `${hi(p)} you're ID checked and live on Hair Done. Thank you for being one of the first.`,
    "Who else is good? If there's a nail tech, makeup artist, lash tech or stylist whose work you rate, send me their Instagram and I'll get in touch. Keith",
  ].join("\n\n");
  const cats = (p.categories ?? []).map((c) => WHAT[c]);
  const liked = p.note?.trim()
    ? sentence(p.note.trim())
    : `I came across ${p.name}${cats.length ? ` and your ${cats.join(" and ")} work` : ""}.`;
  return [
    `${hi(p)} I'm Keith. I'm starting Hair Done, a Melbourne app where clients book mobile pros and pay in the app. ${liked}`,
    "It's free to join: no joining fee and no monthly fee. Hair Done takes 12% of a booking and the client pays a $3 booking fee. Payouts land in your bank daily, and the first 50 pros keep a Founding pro line on their profile for good.",
    "Up for a 20-minute call this week? I'll be your first booking myself. And if you'd rather I didn't message again, just say so. Keith",
  ].join("\n\n");
}
const sentence = (s: string) => { const t = s.charAt(0).toUpperCase() + s.slice(1); return /[.!?]$/.test(t) ? t : `${t}.`; };

/** Where Keith looks them up: their Instagram if he has it, otherwise a web search for the name. */
export function findLink(p: Prospect): string {
  const handle = (p.instagram ?? "").trim().replace(/^@/, "").replace(/^https?:\/\/(www\.)?instagram\.com\//i, "").replace(/\/.*$/, "");
  if (handle) return `https://www.instagram.com/${encodeURIComponent(handle)}/`;
  return `https://www.google.com/search?q=${encodeURIComponent(`"${p.name}" Melbourne instagram`)}`;
}

/** The week in numbers, for the email and the page. */
export function tally(ps: Prospect[], now: Date) {
  const count = (f: (p: Prospect) => boolean) => ps.filter(f).length;
  const touched = (p: Prospect) => !!p.messaged_at;
  return {
    to_message: count((p) => nextAction(p, now) === "message"),
    follow_ups: count((p) => nextAction(p, now) === "follow_up"),
    referrals: count((p) => nextAction(p, now) === "ask_referral"),
    messaged: count(touched),
    replied: count((p) => !!p.replied_at || ["replied", "signed_up", "verified"].includes(p.status)),
    signed_up: count((p) => p.status === "signed_up" || p.status === "verified"),
    verified: count((p) => p.status === "verified"),
  };
}
