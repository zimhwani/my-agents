// Receives valve telemetry forwarded by the MQTT broker's rule engine (gg/+/telemetry → HTTP).
// The broker authenticates with a shared secret header; valves themselves authenticate to the broker
// with per-device TLS certificates.
import type { Telemetry } from "../_shared/core/types.ts";
import { service } from "../_shared/gasguys.ts";

Deno.serve(async (req) => {
  if (req.headers.get("x-gasguys-broker") !== Deno.env.get("BROKER_WEBHOOK_SECRET")) return new Response("forbidden", { status: 403 });
  const t = (await req.json()) as Telemetry;
  const svc = await service();
  const m = await svc.ingestTelemetry({ ...t, at: new Date().toISOString() });
  return new Response(m ? "ok" : "unknown meter", { status: m ? 200 : 404 });
});
