// Daily photo cleanup, called by pg_cron with the cron secret (migration 0013):
// removes files left by deleted accounts and verified pros' ID photos, as the privacy policy says.
import { admin, json } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  const { data: ok } = await admin.rpc("check_cron_secret", { s: req.headers.get("x-cron-secret") ?? "" });
  if (!ok) return json({ error: "forbidden" }, 403);

  const { data: rows, error } = await admin.rpc("photo_cleanup_candidates", { limit_n: 500 });
  if (error) return json({ error: error.message }, 500);

  const byBucket = new Map<string, string[]>();
  for (const r of (rows ?? []) as { bucket_id: string; name: string }[]) {
    byBucket.set(r.bucket_id, [...(byBucket.get(r.bucket_id) ?? []), r.name]);
  }
  const removed: Record<string, number> = {};
  for (const [bucket, names] of byBucket) {
    for (let i = 0; i < names.length; i += 100) {
      const { data, error: e } = await admin.storage.from(bucket).remove(names.slice(i, i + 100));
      if (e) console.error("cleanup", bucket, e.message);
      removed[bucket] = (removed[bucket] ?? 0) + (data?.length ?? 0);
    }
  }
  console.log("cleanup removed", JSON.stringify(removed));
  return json({ removed });
});
