// The API behind the pipeline page (site/pipeline/index.html on hairdonenailsdone.app). Public, because the
// signed link in Keith's Monday email is the key: it lasts 8 days (migration 0027).
//   POST { token, action: "view" }                         every prospect, what's due, and the drafted message
//   POST { token, action: "change", id, status?, fields? } Sent, Replied, Not a fit... and edits to their details
//   POST { token, action: "add", fields }                  someone Keith found himself, or a pro's referral
// Nothing here sends a message to anyone: Keith copies the draft and sends it himself.
import { admin } from "../_shared/stripe.ts";
import { AREA_WORDS, areaFor, draft, findLink, nextAction, tally, type Prospect } from "../pipeline/assess.ts";

const ORIGIN = "https://hairdonenailsdone.app";
const cors = { "Access-Control-Allow-Origin": ORIGIN, "Access-Control-Allow-Methods": "POST, OPTIONS",
               "Access-Control-Allow-Headers": "content-type", "Cache-Control": "no-store", Vary: "Origin" };
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", ...cors } });
const STATUSES = ["new", "messaged", "followed_up", "replied", "signed_up", "verified", "quiet", "declined", "not_a_fit", "referral_asked"];
const HAND_PICKED = 12;   // above any ABN Lookup lead: Keith has already seen their work

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply({ error: "post_only" }, 405);
  const body = await req.json().catch(() => ({}));
  const { data: ok } = await admin.rpc("pipeline_check", { p_token: typeof body.token === "string" ? body.token : "" });
  if (!ok) return reply({ error: "link_expired" }, 404);

  if (body.action === "change") {
    const status = typeof body.status === "string" ? body.status : null;
    if (status && !STATUSES.includes(status)) return reply({ error: "bad_status" }, 400);
    const { data, error } = await admin.rpc("pipeline_change", { p_id: String(body.id ?? ""), p_status: status,
      p_fields: fields(body.fields), p_pro: null });
    if (error) return reply({ error: error.message }, 500);
    if (!data) return reply({ error: "not_found" }, 404);
    return reply({ ok: true, prospect: card(data, new Date()) });
  }

  if (body.action === "add") {
    const f = fields(body.fields);
    if (!String(f.name ?? "").trim()) return reply({ error: "name_needed" }, 400);
    const { data: id, error } = await admin.rpc("pipeline_add", { p: { ...f, score: HAND_PICKED } });
    if (error) return reply({ error: error.message }, 500);
    return reply({ ok: true, id });
  }

  const { data: snap, error } = await admin.rpc("pipeline_snapshot");
  if (error) return reply({ error: error.message }, 500);
  const now = new Date();
  const prospects = (snap?.prospects ?? []) as Prospect[];
  return reply({
    tally: tally(prospects, now),
    id_checked_pros: (snap?.pros ?? []).filter((p: any) => p.is_verified).length,
    prospects: prospects.map((p) => card(p, now)),
    // For "referred by": real pros, first names only.
    pros: (snap?.pros ?? []).filter((p: any) => p.first_name).map((p: any) => ({ id: p.id, first_name: p.first_name })),
  });
});

/** What the page shows for one prospect: who, where, what's next, and the message for it. */
function card(p: Prospect, now: Date) {
  const next = nextAction(p, now);
  const kind = next === "follow_up" ? "follow_up" : next === "ask_referral" ? "ask_referral" : p.status === "new" ? "message" : null;
  return {
    id: p.id, source: p.source, status: p.status, name: p.name, first_name: p.first_name ?? null, abn: p.abn ?? null,
    email: p.email ?? null, instagram: p.instagram ?? null, suburb: p.suburb ?? null, postcode: p.postcode ?? null,
    area: p.suburb || AREA_WORDS[areaFor(p.postcode)], categories: p.categories ?? [], note: p.note ?? null, score: p.score ?? 0,
    messaged_at: p.messaged_at ?? null, followed_up_at: p.followed_up_at ?? null, replied_at: p.replied_at ?? null,
    next, draft: kind ? draft(p, kind) : null, find: findLink(p),
  };
}

/** Only the fields Keith can set, as strings (categories as a list). */
function fields(f: unknown): Record<string, unknown> {
  const src = (f && typeof f === "object" ? f : {}) as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const k of ["name", "first_name", "email", "instagram", "suburb", "postcode", "note", "abn", "referred_by"])
    if (k in src) out[k] = src[k] == null ? "" : String(src[k]).slice(0, 1000);
  if (Array.isArray(src.categories)) out.categories = src.categories.map(String);
  if (!/^[0-9a-f-]{36}$/.test(String(out.referred_by ?? ""))) delete out.referred_by;
  return out;
}
