// Meter gateway over an MQTT broker's HTTP API. Edge functions can't hold an MQTT connection, so
// commands go through the broker's REST publish endpoint (EMQX v5 shape below; HiveMQ and others
// have equivalents). Telemetry comes the other way: a broker rule forwards gg/+/telemetry to the
// meter-telemetry function. Secrets: MQTT_API_URL, MQTT_API_KEY, MQTT_API_SECRET.

import type { CommandResult, MeterCommand, MeterGateway } from "./core/providers.ts";
import { signCredit } from "./core/token.ts";

export class MqttHttpGateway implements MeterGateway {
  constructor(private keyFor: (meterId: string) => Promise<string | null>) {}

  private async api(path: string, init?: RequestInit) {
    const url = Deno.env.get("MQTT_API_URL");
    if (!url) return null;
    const auth = btoa(`${Deno.env.get("MQTT_API_KEY")}:${Deno.env.get("MQTT_API_SECRET")}`);
    return fetch(`${url}${path}`, { ...init, headers: { authorization: `Basic ${auth}`, "content-type": "application/json" } });
  }

  async send(meterId: string, cmd: MeterCommand): Promise<CommandResult> {
    // Is the valve connected right now? If not, the customer gets the offline token instead.
    const client = await this.api(`/api/v5/clients/${meterId}`);
    if (!client) return { delivered: false, reason: "offline" };
    if (!client.ok || !(await client.json()).connected) return { delivered: false, reason: "offline" };

    const payload: Record<string, unknown> = { id: crypto.randomUUID(), ...cmd };
    if (cmd.type === "credit") {
      const key = await this.keyFor(meterId);
      if (!key) return { delivered: false, reason: "rejected" };
      payload.sig = await signCredit(key, cmd.counter, cmd.grams);
    }
    const res = await this.api("/api/v5/publish", {
      method: "POST",
      body: JSON.stringify({ topic: `gg/${meterId}/cmd`, payload: JSON.stringify(payload), qos: 1, retain: false }),
    });
    // QoS 1 to a connected client: the broker holds it until the valve acks. The valve reports the
    // counter it applied in its next telemetry, which is the real confirmation.
    return res?.ok ? { delivered: true } : { delivered: false, reason: "timeout" };
  }
}
