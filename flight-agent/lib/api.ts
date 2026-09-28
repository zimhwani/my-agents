/**
 * Framework-agnostic request handlers shared by the Next.js API routes and the
 * Supabase Edge Function. Keys can come from the server environment or, per
 * request, from the traveller's own browser (x-serpapi-key / x-anthropic-key).
 */
import Anthropic from "@anthropic-ai/sdk";
import { fallbackInterpretation, interpretWithClaude, type InterpretContext } from "./claude";
import { todayISO } from "./dates";
import { normalizeParams } from "./params";
import { getProvider, providerStatus } from "./providers";
import { runScan } from "./search";

export interface RequestKeys {
  serpApiKey?: string | null;
  anthropicKey?: string | null;
}

export interface ApiResult {
  status: number;
  body: unknown;
}

export function keysFromHeaders(headers: Headers): RequestKeys {
  const clean = (v: string | null) => (v && /^[A-Za-z0-9_\-]{8,200}$/.test(v.trim()) ? v.trim() : null);
  return { serpApiKey: clean(headers.get("x-serpapi-key")), anthropicKey: clean(headers.get("x-anthropic-key")) };
}

export function handleStatus(keys: RequestKeys, env: Record<string, string | undefined>): ApiResult {
  try {
    return { status: 200, body: providerStatus({ env, serpApiKey: keys.serpApiKey, anthropicKey: keys.anthropicKey }) };
  } catch (e) {
    return { status: 500, body: { error: e instanceof Error ? e.message : String(e) } };
  }
}

export async function handleSearch(body: unknown, keys: RequestKeys, env: Record<string, string | undefined>): Promise<ApiResult> {
  const params = normalizeParams(body);
  try {
    const provider = getProvider({ env, serpApiKey: keys.serpApiKey });
    const concurrency = Number(env.SCAN_CONCURRENCY ?? 3) || 3;
    const result = await runScan(params, provider, { concurrency });
    return { status: 200, body: result };
  } catch (e) {
    return { status: 500, body: { error: e instanceof Error ? e.message : String(e), params } };
  }
}

export async function handleInterpret(body: unknown, keys: RequestKeys, env: Record<string, string | undefined>): Promise<ApiResult> {
  const b = (body && typeof body === "object" ? body : {}) as { utterance?: unknown; params?: unknown; lastResult?: InterpretContext["lastResult"] };
  const utterance = typeof b.utterance === "string" ? b.utterance.slice(0, 500) : "";
  if (!utterance.trim()) return { status: 400, body: { error: "utterance is required" } };

  const ctx: InterpretContext = { params: normalizeParams(b.params), today: todayISO(), lastResult: b.lastResult };
  const apiKey = env.ANTHROPIC_API_KEY?.trim() || keys.anthropicKey?.trim();
  if (!apiKey) return { status: 200, body: fallbackInterpretation(utterance, ctx) };

  try {
    const client = new Anthropic({ apiKey });
    return { status: 200, body: await interpretWithClaude(utterance, ctx, client) };
  } catch (e) {
    // Degrade to the rule-based parser rather than failing the voice command.
    const reason =
      e instanceof Anthropic.AuthenticationError ? "invalid Anthropic API key"
      : e instanceof Anthropic.RateLimitError ? "rate limited"
      : e instanceof Anthropic.APIError ? `API error ${e.status}`
      : e instanceof Error ? e.message : String(e);
    console.warn(`[interpret] Claude unavailable (${reason}); using rules`);
    return { status: 200, body: { ...fallbackInterpretation(utterance, ctx), degraded: reason } };
  }
}

/** Route a Web-standard Request for the three API endpoints; null when the path is not an API path. */
export async function handleApiRequest(req: Request, env: Record<string, string | undefined>): Promise<Response | null> {
  const path = new URL(req.url).pathname.replace(/\/+$/, "");
  const route = /\/api\/(status|search|interpret)$/.exec(path)?.[1];
  if (!route) return null;
  const keys = keysFromHeaders(req.headers);
  let body: unknown = {};
  if (req.method === "POST") body = await req.json().catch(() => ({}));
  let result: ApiResult;
  if (route === "status") result = handleStatus(keys, env);
  else if (route === "search") result = await handleSearch(body, keys, env);
  else result = await handleInterpret(body, keys, env);
  return new Response(JSON.stringify(result.body), { status: result.status, headers: { "Content-Type": "application/json" } });
}
