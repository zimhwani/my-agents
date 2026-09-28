import type { FlightProvider } from "../types";
import { SampleProvider } from "./sample";
import { SerpApiProvider, serpApiConfigFromEnv } from "./serpapi";

export interface ProviderOptions {
  /** A key supplied by the browser (the traveller's own SerpApi key). Env wins when set. */
  serpApiKey?: string | null;
  env?: Record<string, string | undefined>;
}

/**
 * FLIGHT_PROVIDER=auto (default) uses Google Flights via SerpApi when a key is
 * available (from the environment, or passed per request) and otherwise falls
 * back to the offline sample data. Force with "serpapi" or "sample".
 */
export function getProvider(opts: ProviderOptions = {}): FlightProvider {
  const env = opts.env ?? process.env;
  const mode = (env.FLIGHT_PROVIDER ?? "auto").toLowerCase();
  const cfg = serpApiConfigFromEnv(env) ?? (opts.serpApiKey?.trim() ? { apiKey: opts.serpApiKey.trim() } : null);
  if (mode === "sample") return new SampleProvider();
  if (mode === "serpapi" && !cfg) throw new Error("FLIGHT_PROVIDER=serpapi but no SERPAPI_KEY is set");
  return cfg ? new SerpApiProvider(cfg) : new SampleProvider();
}

export function providerStatus(opts: ProviderOptions & { anthropicKey?: string | null } = {}) {
  const env = opts.env ?? process.env;
  const p = getProvider(opts);
  return {
    provider: p.name,
    isSample: p.isSample,
    liveSource: p.name === "serpapi" ? "Google Flights via SerpApi" : null,
    claude: Boolean(env.ANTHROPIC_API_KEY?.trim() || opts.anthropicKey?.trim()),
  };
}
