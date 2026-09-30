// Runs every few minutes from pg_cron: re-polls pending payments whose webhook never came, and marks
// valves that have gone quiet as offline (their customers then get tokens instead of online credit).
import { service } from "../_shared/gasguys.ts";

const QUIET_MS = 30 * 60 * 1000;

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) return new Response("forbidden", { status: 403 });
  const svc = await service();
  await svc.pollPending();
  for (const m of await svc.store.allMeters())
    if (m.online && Date.now() - Date.parse(m.lastSeen) > QUIET_MS) await svc.markOffline(m.id);
  return new Response("ok");
});
