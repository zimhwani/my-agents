// Wires the core service to the real providers. Each provider no-ops or answers 503 until its
// secrets are set with `supabase secrets set`, so functions can be deployed before credentials exist.

import { GasguysService } from "./core/service.ts";
import { DEFAULT_TARIFF, type Tariff } from "./core/pricing.ts";
import { MqttHttpGateway } from "./mqtt.ts";
import { PaynowProvider } from "./paynow.ts";
import { admin, SupabaseStore } from "./store.ts";
import { WhatsAppCloudMessenger } from "./whatsapp.ts";

const FN = `${Deno.env.get("SUPABASE_URL")}/functions/v1`;

export async function service(): Promise<GasguysService> {
  const store = new SupabaseStore();
  const { data } = await admin.from("settings").select("value").eq("key", "tariff").maybeSingle();
  const tariff = { ...DEFAULT_TARIFF, ...((data?.value as Partial<Tariff>) ?? {}) };
  return new GasguysService({
    store,
    tariff,
    payments: [new PaynowProvider(`${FN}/paynow-result`, Deno.env.get("APP_URL") ?? "https://gasguys.app", Deno.env.get("PAYNOW_AUTH_EMAIL") ?? "")],
    gateway: new MqttHttpGateway((id) => store.meterKey(id)),
    messenger: new WhatsAppCloudMessenger(async (phone) => (await store.customerByPhone(phone))?.lang ?? "en"),
  });
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "access-control-allow-origin": "*" } });

export const cors = () =>
  new Response(null, {
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type, apikey, x-client-info",
      "access-control-allow-methods": "POST, OPTIONS",
    },
  });
