import { describe, expect, it } from "vitest";
import { handleApiRequest, keysFromHeaders } from "@/lib/api";

describe("api handlers", () => {
  it("reads keys from headers and rejects junk", () => {
    const h = new Headers({ "x-serpapi-key": "abcdefgh12345678", "x-anthropic-key": "bad key with spaces" });
    expect(keysFromHeaders(h)).toEqual({ serpApiKey: "abcdefgh12345678", anthropicKey: null });
  });
  it("serves status, search and interpret on sample data with no keys", async () => {
    const env = {};
    const status = await handleApiRequest(new Request("https://x.test/functions/v1/flight-agent/api/status"), env);
    expect(await status!.json()).toMatchObject({ provider: "sample", isSample: true, claude: false });

    const search = await handleApiRequest(new Request("https://x.test/api/search", { method: "POST", body: JSON.stringify({ windowStart: "2026-11-01", windowEnd: "2026-11-08", stepDays: 7 }) }), env);
    const body = (await search!.json()) as { datesScanned: number; offers: unknown[] };
    expect(search!.status).toBe(200);
    expect(body.datesScanned).toBe(2);
    expect(body.offers.length).toBeGreaterThan(0);

    const interp = await handleApiRequest(new Request("https://x.test/api/interpret", { method: "POST", body: JSON.stringify({ utterance: "read me the top three" }) }), env);
    expect(await interp!.json()).toMatchObject({ source: "rules", intent: { type: "read_results", count: 3 } });

    expect(await handleApiRequest(new Request("https://x.test/"), env)).toBeNull();
  });
  it("rejects an empty utterance", async () => {
    const r = await handleApiRequest(new Request("https://x.test/api/interpret", { method: "POST", body: "{}" }), {});
    expect(r!.status).toBe(400);
  });
});
