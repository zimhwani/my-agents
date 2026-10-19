// Sample pros for TestFlight (migration 0015). Called with the cron secret, like cleanup:
//   POST {}                     create the ten (again is harmless: anyone already there is kept)
//   POST {"action":"remove"}    delete every sample pro, her account, services, hours and photos
// Each is a real account (sample-pro-N@hairdonenailsdone.app, never signed into), verified, onboarded
// and payout-ready, so she can be found and booked. Work photos are the app's bundled Pexels set,
// copied into the `work` bucket. Bookings with her are charged to the platform only (payeeFor), and
// the autopilot in 0015 accepts requests and answers messages.
import { admin, json, isTestMode } from "../_shared/stripe.ts";

const PHOTOS = "https://raw.githubusercontent.com/zimhwani/my-agents/claude/youthful-wright-9n079z/hair-done/HairDone/Resources/Work";
const POOL: Record<string, number> = { nails: 4, hair: 4, makeup: 1, lashes: 2, brows: 4, theLot: 4 };
const FILE: Record<string, string> = { nails: "nails", hair: "hair", makeup: "makeup", lashes: "lashes", brows: "brows", theLot: "thelot" };

type Svc = [name: string, category: string, dollars: number, minutes: number, popular?: boolean];
type Sample = {
  first: string; initial: string; specialties: string[]; headline: string; bio: string;
  suburb: string; lat: number; lng: number; fee: number; years: number; instant: boolean;
  services: Svc[]; days: number[]; from: number; to: number;
};

const SAMPLES: Sample[] = [
  { first: "Amara", initial: "O", specialties: ["hair"], headline: "Knotless braids that last, done at your place.",
    bio: "Braids, cornrows and silk presses for all hair types. I bring everything, you bring a movie.",
    suburb: "Footscray", lat: -37.8000, lng: 144.9000, fee: 15, years: 8, instant: true,
    services: [["Knotless braids, mid-back", "hair", 280, 300, true], ["Cornrows", "hair", 90, 90], ["Silk press", "hair", 120, 120]],
    days: [2, 3, 4, 5, 6], from: 9 * 60, to: 18 * 60 },
  { first: "Lucia", initial: "R", specialties: ["nails"], headline: "BIAB and gel, neat as a pin.",
    bio: "Builder gel, gel manicures and nail art. Clean cuticles, shapes that suit your hands.",
    suburb: "Fitzroy", lat: -37.7980, lng: 144.9780, fee: 10, years: 6, instant: true,
    services: [["BIAB overlay", "nails", 85, 75, true], ["Gel manicure", "nails", 60, 60], ["Gel removal and manicure", "nails", 70, 75]],
    days: [1, 2, 3, 4, 5], from: 10 * 60, to: 19 * 60 },
  { first: "Priya", initial: "S", specialties: ["brows", "lashes"], headline: "Threading and tints, done gently.",
    bio: "Brow shaping by thread, tints and lamination. Quick, precise and kind to sensitive skin.",
    suburb: "Dandenong", lat: -37.9870, lng: 145.2150, fee: 10, years: 12, instant: false,
    services: [["Brow threading", "brows", 25, 20, true], ["Brow lamination and tint", "brows", 80, 60], ["Lash lift and tint", "lashes", 90, 60]],
    days: [1, 2, 3, 4, 5, 6], from: 9 * 60, to: 17 * 60 },
  { first: "Jess", initial: "T", specialties: ["makeup", "theLot"], headline: "Soft glam for weddings and big nights.",
    bio: "Bridal and event makeup that looks like you, only more rested. Lashes included.",
    suburb: "St Kilda", lat: -37.8676, lng: 144.9800, fee: 20, years: 9, instant: false,
    services: [["Soft glam", "makeup", 140, 75, true], ["Bridal makeup with trial", "makeup", 380, 180], ["Hair and makeup, event", "theLot", 260, 150]],
    days: [4, 5, 6, 0], from: 7 * 60, to: 19 * 60 },
  { first: "Mei", initial: "L", specialties: ["lashes"], headline: "Classic and hybrid sets, light on the eye.",
    bio: "Lash extensions and infills. I'll match the set to your eye shape, not the trend.",
    suburb: "Box Hill", lat: -37.8190, lng: 145.1220, fee: 10, years: 5, instant: true,
    services: [["Classic full set", "lashes", 150, 120, true], ["Hybrid full set", "lashes", 180, 135], ["Infill, two weeks", "lashes", 75, 60]],
    days: [2, 3, 4, 5, 6], from: 10 * 60, to: 18 * 60 },
  { first: "Zara", initial: "K", specialties: ["hair"], headline: "Blow-dries and colour that grows out well.",
    bio: "Bouncy blow-dries, gloss and root touch-ups at home. Ten years in salons, now mobile.",
    suburb: "Brunswick", lat: -37.7667, lng: 144.9600, fee: 15, years: 10, instant: true,
    services: [["Blow-dry", "hair", 70, 45, true], ["Root touch-up", "hair", 110, 90], ["Gloss and blow-dry", "hair", 130, 90]],
    days: [1, 2, 3, 4, 5, 6], from: 8 * 60, to: 17 * 60 },
  { first: "Hannah", initial: "W", specialties: ["nails"], headline: "Pedicures and gel toes, sit back.",
    bio: "Gel pedicures, manicures and simple art. I bring the footbath and the good towels.",
    suburb: "Richmond", lat: -37.8183, lng: 144.9980, fee: 10, years: 4, instant: false,
    services: [["Gel pedicure", "nails", 75, 60, true], ["Gel manicure", "nails", 60, 60], ["Mani and pedi", "nails", 125, 120]],
    days: [3, 4, 5, 6, 0], from: 10 * 60, to: 19 * 60 },
  { first: "Nia", initial: "A", specialties: ["hair"], headline: "Locs, twists and braids with care.",
    bio: "Loc retwists, starter locs, twists and protective styles. Patient with tender heads.",
    suburb: "Sunshine", lat: -37.7880, lng: 144.8330, fee: 15, years: 7, instant: false,
    services: [["Loc retwist", "hair", 120, 120, true], ["Two-strand twists", "hair", 150, 180], ["Kids' braids", "hair", 80, 90]],
    days: [1, 2, 4, 5, 6], from: 9 * 60, to: 18 * 60 },
  { first: "Sofia", initial: "M", specialties: ["theLot", "makeup"], headline: "Getting ready, the whole lot, at home.",
    bio: "Hair and makeup for formals, birthdays and bridal parties. Groups welcome.",
    suburb: "Moonee Ponds", lat: -37.7660, lng: 144.9190, fee: 20, years: 11, instant: true,
    services: [["Hair and makeup", "theLot", 220, 120, true], ["Event makeup", "makeup", 120, 60], ["Bridesmaid hair and makeup", "theLot", 200, 120]],
    days: [4, 5, 6, 0], from: 7 * 60, to: 18 * 60 },
  { first: "Grace", initial: "C", specialties: ["brows", "lashes"], headline: "Laminated brows and lifted lashes.",
    bio: "Brow lamination, tints and lash lifts. Fresh, natural, no daily makeup needed.",
    suburb: "Glen Waverley", lat: -37.8780, lng: 145.1640, fee: 10, years: 6, instant: true,
    services: [["Brow lamination", "brows", 75, 45, true], ["Lash lift", "lashes", 80, 60], ["Brow and lash package", "brows", 140, 90]],
    days: [1, 2, 3, 4, 5], from: 9 * 60, to: 17 * 60 },
];

const email = (i: number) => `sample-pro-${i + 1}@hairdonenailsdone.app`;

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);
  const body = await req.json().catch(() => ({}));
  return body.action === "remove" ? remove() : seed();
});

async function existingUsers(): Promise<Map<string, string>> {
  const byEmail = new Map<string, string>();
  for (let page = 1; page < 20; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    for (const u of data.users) if (u.email) byEmail.set(u.email, u.id);
    if (data.users.length < 1000) break;
  }
  return byEmail;
}

async function seed() {
  const users = await existingUsers();
  const out: Record<string, string> = {};
  for (const [i, s] of SAMPLES.entries()) {
    try {
      let id = users.get(email(i));
      if (!id) {
        const { data, error } = await admin.auth.admin.createUser({ email: email(i), email_confirm: true, user_metadata: { sample: true } });
        if (error) throw error;
        id = data.user.id;
      }
      const { data: already } = await admin.from("pros").select("id").eq("id", id).maybeSingle();
      if (already) { out[s.first] = "already there"; continue; }

      await must(admin.from("profiles").upsert({ id, first_name: s.first, last_name: "" }));
      await must(admin.from("pros").insert({
        id, last_initial: s.initial, specialties: s.specialties, headline: s.headline,
        bio: `${s.bio}\n\nA sample pro for testing: bookings are accepted automatically.`,
        suburb: s.suburb, location: `SRID=4326;POINT(${s.lng} ${s.lat})`, travel_radius_km: 40,
        travel_fee_cents: s.fee * 100, years_experience: s.years, response_minutes: 5,
        is_verified: true, id_checked_at: new Date().toISOString(), payouts_connected: true,
        onboarded_at: new Date().toISOString(), notice_minutes: 60, instant_book: s.instant, is_sample: true,
      }));
      await must(admin.from("services").insert(s.services.map(([name, category, dollars, minutes, popular], n) => ({
        pro_id: id, name, category, price_cents: dollars * 100, minutes, is_popular: !!popular, sort_order: n,
      }))));
      await must(admin.from("availability").insert(s.days.map((weekday) => ({
        pro_id: id, weekday, start_minutes: s.from, end_minutes: s.to,
      }))));

      // Four photos from her specialties' pools, a different start for each pro.
      const picks: { category: string; file: string }[] = [];
      for (let n = 0; picks.length < 4; n++) {
        const category = s.specialties[n % s.specialties.length];
        const count = POOL[category];
        picks.push({ category, file: `work-${FILE[category]}-${((i + n) % count) + 1}.jpg` });
      }
      for (const [n, p] of picks.entries()) {
        const res = await fetch(`${PHOTOS}/${p.file}`);
        if (!res.ok) throw new Error(`photo ${p.file}: ${res.status}`);
        const path = `${id}/sample-${n + 1}.jpg`;
        const { error } = await admin.storage.from("work").upload(path, new Uint8Array(await res.arrayBuffer()),
          { contentType: "image/jpeg", upsert: true });
        if (error) throw error;
        await must(admin.from("work_items").insert({ pro_id: id, category: p.category, image_path: path, sort_order: n, is_pinned: n === 0 }));
      }
      out[s.first] = "added";
    } catch (e) {
      out[s.first] = `failed: ${(e as Error).message}`;
    }
  }
  return json({ stripe_test_mode: isTestMode, pros: out });
}

async function remove() {
  const { data: pros } = await admin.from("pros").select("id").eq("is_sample", true);
  const removed: string[] = [];
  for (const { id } of (pros ?? []) as { id: string }[]) {
    const { data: files } = await admin.storage.from("work").list(id, { limit: 100 });
    if (files?.length) await admin.storage.from("work").remove(files.map((f) => `${id}/${f.name}`));
    const { error } = await admin.auth.admin.deleteUser(id); // cascades to her profile, pro row, services, hours, work
    if (error) console.error("remove", id, error.message); else removed.push(id);
  }
  return json({ removed: removed.length });
}

async function must<T extends { error: { message: string } | null }>(p: PromiseLike<T>): Promise<T> {
  const r = await p;
  if (r.error) throw new Error(r.error.message);
  return r;
}
