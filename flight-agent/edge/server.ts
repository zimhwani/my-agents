/**
 * Supabase Edge Function: serves the single-page app and its API from one URL.
 * Built by `npm run build:edge` into edge/dist/index.js (see edge/build.mjs).
 */
import { handleApiRequest } from "../lib/api";
// The built page is inlined here by esbuild's text loader (empty in the "remote" build,
// which fetches the page from PAGE_URL instead so the deployed function stays small).
import inlinePage from "./dist/page.html";

declare const DEFAULT_PAGE_URL: string;
declare const Deno: { env: { toObject(): Record<string, string> }; serve(handler: (req: Request) => Promise<Response> | Response): void };

const env = Deno.env.toObject();

let pageCache: { at: number; html: string } | null = null;
async function page(): Promise<string> {
  if (inlinePage) return inlinePage;
  if (pageCache && Date.now() - pageCache.at < 5 * 60_000) return pageCache.html;
  const url = env.PAGE_URL || DEFAULT_PAGE_URL;
  if (!url) return "<!doctype html><title>Harare Flight Agent</title><p>PAGE_URL is not configured.</p>";
  const res = await fetch(url, { headers: { "Cache-Control": "no-cache" } });
  if (!res.ok) return pageCache?.html ?? `<!doctype html><title>Harare Flight Agent</title><p>Could not load the page (${res.status}).</p>`;
  pageCache = { at: Date.now(), html: await res.text() };
  return pageCache.html;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "content-type, x-serpapi-key, x-anthropic-key", "Access-Control-Allow-Methods": "GET, POST, OPTIONS" } });
  }
  const api = await handleApiRequest(req, env);
  if (api) {
    api.headers.set("Access-Control-Allow-Origin", "*");
    api.headers.set("Cache-Control", "no-store");
    return api;
  }
  return new Response(await page(), { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-cache" } });
});
