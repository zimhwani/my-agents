import { describe, expect, it } from "vitest";
import { spokenBrief, spokenUnderstood } from "@/lib/format";
import { parseIntent } from "@/lib/intent";
import { defaultParams, legsFor, normalizeParams } from "@/lib/params";
import { SampleProvider } from "@/lib/providers/sample";
import { SerpApiProvider } from "@/lib/providers/serpapi";
import { runScan } from "@/lib/search";

const NOW = new Date(2026, 8, 17);
const TODAY = "2026-09-17";

describe("stopover params and legs", () => {
  it("validates the stopover", () => {
    expect(normalizeParams({ stopover: { airport: "dxb", nights: 40 } }, NOW).stopover).toEqual({ airport: "DXB", nights: 14, leg: "outbound" });
    expect(normalizeParams({ stopover: { airport: "HRE", nights: 3 } }, NOW).stopover).toBeUndefined();
    expect(normalizeParams({ tripType: "oneway", stopover: { airport: "DOH", nights: 2, leg: "return" } }, NOW).stopover).toEqual({ airport: "DOH", nights: 2, leg: "outbound" });
  });
  it("builds multi-city legs", () => {
    const p = normalizeParams({ stopover: { airport: "DXB", nights: 3 } }, NOW);
    expect(legsFor(p, "2026-11-12", "2027-01-05")).toEqual([
      { from: "MEL", to: "DXB", date: "2026-11-12" },
      { from: "DXB", to: "HRE", date: "2026-11-16" },
      { from: "HRE", to: "MEL", date: "2027-01-05" },
    ]);
    const r = normalizeParams({ stopover: { airport: "SIN", nights: 2, leg: "return" } }, NOW);
    expect(legsFor(r, "2026-11-12", "2027-01-05")).toEqual([
      { from: "MEL", to: "HRE", date: "2026-11-12" },
      { from: "HRE", to: "SIN", date: "2027-01-05" },
      { from: "SIN", to: "MEL", date: "2027-01-07" },
    ]);
    expect(legsFor(p, "2027-01-03", "2027-01-05")).toBeNull();
  });
});

describe("stopover fares", () => {
  it("splits sample itineraries at the stopover and does not penalise it", async () => {
    const p = { ...defaultParams(NOW), windowStart: "2026-11-12", windowEnd: "2026-11-12", returnDate: "2027-01-05", stopover: { airport: "DXB", nights: 3, leg: "outbound" as const } };
    const r = await runScan(p, new SampleProvider());
    expect(r.offers.length).toBeGreaterThan(0);
    for (const o of r.offers) {
      expect(o.validatingCarrier).toBe("EK");
      const stop = o.outbound.layovers.find((l) => l.airport === "DXB")!;
      expect(stop.stopover).toBe(true);
      expect(stop.minutes).toBeGreaterThan(2.5 * 24 * 60);
      expect(o.outbound.durationMin).toBeLessThan(40 * 60);
      // The multi-day stop itself is never flagged (a connection home via Dubai still can be).
      const flaggedHours = o.warnings.map((w) => /Dubai \((\d+)h/.exec(w)?.[1]).filter(Boolean).map(Number);
      expect(flaggedHours.every((h) => h < 24)).toBe(true);
      expect(o.outbound.layovers.filter((l) => !l.stopover)).toEqual([]);
    }
  });
  it("sends a multi-city query to Google Flights", async () => {
    const urls: string[] = [];
    const fakeFetch = (async (u: string | URL | Request) => {
      urls.push(String(u));
      return new Response(JSON.stringify({ best_flights: [] }), { status: 200 });
    }) as typeof fetch;
    const p = normalizeParams({ stopover: { airport: "DXB", nights: 3 } }, NOW);
    await new SerpApiProvider({ apiKey: "k" }, fakeFetch).search(p, "2026-11-12", "2027-01-05");
    const q = new URL(urls[0]).searchParams;
    expect(q.get("type")).toBe("3");
    expect(JSON.parse(q.get("multi_city_json")!)).toEqual([
      { departure_id: "MEL", arrival_id: "DXB", date: "2026-11-12" },
      { departure_id: "DXB", arrival_id: "HRE", date: "2026-11-16" },
      { departure_id: "HRE", arrival_id: "MEL", date: "2027-01-05" },
    ]);
    expect(q.get("outbound_date")).toBeNull();
  });
});

describe("voice commands", () => {
  it("understands stopovers", () => {
    expect(parseIntent("stop over in Dubai for 3 nights", TODAY)).toEqual({ type: "set_stopover", airport: "DXB", nights: 3, leg: "outbound" });
    expect(parseIntent("make it multi city via Doha", TODAY)).toEqual({ type: "set_stopover", airport: "DOH", leg: "outbound" });
    expect(parseIntent("stopover in Singapore for two nights on the way home", TODAY)).toEqual({ type: "set_stopover", airport: "SIN", nights: 2, leg: "return" });
    expect(parseIntent("no stopover", TODAY)).toEqual({ type: "set_stopover", airport: null });
  });
  it("understands check every N days and flags an inferred return", () => {
    expect(parseIntent("check every 2 days", TODAY)).toEqual({ type: "set_step", stepDays: 2 });
    expect(parseIntent("check every day", TODAY)).toEqual({ type: "set_step", stepDays: 1 });
    expect(parseIntent("mid to late november, back early january", TODAY)).toMatchObject({ type: "set_dates", returnDate: "2027-01-05", returnInferred: true });
  });
});

describe("short reply", () => {
  it("says what was understood and the headline in under ~60 words", async () => {
    const p = { ...defaultParams(NOW), windowStart: "2026-11-11", windowEnd: "2026-11-30", returnDate: "2027-01-05" };
    const r = await runScan(p, new SampleProvider());
    const text = spokenBrief(r);
    expect(text).toMatch(/^Looking at 11 to 30 November, back on Tuesday,? 5 January, for two adults and two children\./);
    expect(text).toMatch(/Cheapest/);
    expect(text).toMatch(/Sample fares/);
    expect(text.split(/\s+/).length).toBeLessThan(45);
    expect(text).not.toMatch(/\d\d:\d\d/);
  });
  it("mentions a stopover", () => {
    const p = normalizeParams({ windowStart: "2026-11-11", windowEnd: "2026-11-30", stopover: { airport: "DXB", nights: 3 } }, NOW);
    expect(spokenUnderstood(p)).toMatch(/with 3 nights in Dubai on the way/);
  });
});
