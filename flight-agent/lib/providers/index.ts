import type { FlightProvider } from "../types";
import { AmadeusProvider, amadeusConfigFromEnv } from "./amadeus";
import { SampleProvider } from "./sample";

let cached: FlightProvider | null = null;

/**
 * FLIGHT_PROVIDER=auto (default) picks Amadeus when credentials exist and
 * otherwise falls back to the offline sample data. Force with "amadeus" or "sample".
 */
export function getProvider(env: NodeJS.ProcessEnv = process.env): FlightProvider {
  if (cached) return cached;
  const mode = (env.FLIGHT_PROVIDER ?? "auto").toLowerCase();
  const cfg = amadeusConfigFromEnv(env);
  if (mode === "sample") cached = new SampleProvider();
  else if (mode === "amadeus") {
    if (!cfg) throw new Error("FLIGHT_PROVIDER=amadeus but AMADEUS_CLIENT_ID / AMADEUS_CLIENT_SECRET are not set");
    cached = new AmadeusProvider(cfg);
  } else cached = cfg ? new AmadeusProvider(cfg) : new SampleProvider();
  return cached;
}

export function providerStatus(env: NodeJS.ProcessEnv = process.env) {
  const p = getProvider(env);
  return {
    provider: p.name,
    isSample: p.isSample,
    amadeusEnv: p.name === "amadeus" ? (env.AMADEUS_ENV === "production" ? "production" : "test") : null,
    claude: Boolean(env.ANTHROPIC_API_KEY?.trim()),
  };
}
