/**
 * Entry point for the single-file static demo (see demo/build.mjs).
 * Runs the same React page as the Next.js app, but serves the three API routes
 * from inside the browser using the sample provider and the rule-based parser,
 * so the page works with no server at all.
 */
import { createRoot } from "react-dom/client";
import Page from "../app/page";
import { todayISO } from "../lib/dates";
import { normalizeParams } from "../lib/params";
import { SampleProvider } from "../lib/providers/sample";
import { runScan } from "../lib/search";
import { fallbackInterpretation } from "../lib/speech";
import "../app/globals.css";

const provider = new SampleProvider();
const realFetch = window.fetch.bind(window);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
  const body = init?.body ? (JSON.parse(String(init.body)) as Record<string, unknown>) : {};
  if (url.endsWith("/api/status")) return json({ provider: "sample", isSample: true, amadeusEnv: null, claude: false });
  if (url.endsWith("/api/search")) return json(await runScan(normalizeParams(body), provider, { concurrency: 4 }));
  if (url.endsWith("/api/interpret")) {
    const utterance = typeof body.utterance === "string" ? body.utterance : "";
    return json(fallbackInterpretation(utterance, { params: normalizeParams(body.params), today: todayISO() }));
  }
  return realFetch(input, init);
};

createRoot(document.getElementById("root")!).render(<Page />);
