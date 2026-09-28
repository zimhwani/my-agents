import { describe, expect, it } from "vitest";
import { defaultParams } from "@/lib/params";
import { getProvider } from "@/lib/providers";
import { SerpApiProvider, mapSerpItinerary } from "@/lib/providers/serpapi";
import { SampleProvider, seasonMultiplier } from "@/lib/providers/sample";
import { runScan } from "@/lib/search";

const NOW = new Date(2026, 8, 17);

describe("sample provider", () => {
  it("is deterministic and prices a family of four", async () => {
    const p = { ...defaultParams(NOW), maxStops: 2 };
    const s = new SampleProvider();
    const a = await s.search(p, "2026-12-03", "2026-12-24");
    const b = await s.search(p, "2026-12-03", "2026-12-24");
    expect(a).toEqual(b);
    expect(a.length).toBeGreaterThan(3);
    for (const o of a) {
      expect(o.price.total).toBe(o.price.perAdult! * 2 + o.price.perChild! * 2);
      expect(o.inbound).toBeDefined();
      expect(o.outbound.segments[0].from).toBe("MEL");
      expect(o.outbound.segments.at(-1)!.to).toBe("HRE");
      expect(o.inbound!.segments.at(-1)!.to).toBe("MEL");
      for (const l of [...o.outbound.layovers, ...o.inbound!.layovers]) expect(l.minutes).toBeGreaterThan(0);
    }
  });
  it("respects maxStops and one-way", async () => {
    const s = new SampleProvider();
    const one = await s.search({ ...defaultParams(NOW), maxStops: 1, tripType: "oneway" }, "2026-11-05");
    expect(one.every((o) => o.outbound.segments.length === 2 && !o.inbound)).toBe(true);
  });
  it("peaks in mid December", () => {
    expect(seasonMultiplier("2026-12-15")).toBeGreaterThan(seasonMultiplier("2026-11-10"));
    expect(seasonMultiplier("2027-01-20")).toBeGreaterThan(1);
  });
});

describe("scan", () => {
  it("uses a fixed return date and skips departures on or after it", async () => {
    const p = { ...defaultParams(NOW), windowStart: "2026-11-11", windowEnd: "2026-11-30", stepDays: 7, returnDate: "2026-11-26" };
    const r = await runScan(p, new SampleProvider(), { concurrency: 2 });
    expect(r.byDate.map((d) => d.date)).toEqual(["2026-11-11", "2026-11-18", "2026-11-25"]);
    expect(r.offers.every((o) => o.returnDate === "2026-11-26")).toBe(true);
  });
  it("scans every sampled date and ranks the pool", async () => {
    const p = { ...defaultParams(NOW), windowStart: "2026-11-01", windowEnd: "2026-11-15", stepDays: 7 };
    const r = await runScan(p, new SampleProvider(), { concurrency: 2 });
    expect(r.datesScanned).toBe(3);
    expect(r.byDate.map((d) => d.date)).toEqual(["2026-11-01", "2026-11-08", "2026-11-15"]);
    expect(r.byDate.every((d) => d.cheapest !== null)).toBe(true);
    expect(r.offers[0].badges.length).toBeGreaterThan(0);
    expect(r.isSample).toBe(true);
    expect(r.warnings[0]).toMatch(/sample/i);
  });
});

describe("serpapi mapping", () => {
  const raw = {
    flights: [
      { departure_airport: { name: "Melbourne Airport", id: "MEL", time: "2026-12-03 22:15" }, arrival_airport: { name: "Hamad International", id: "DOH", time: "2026-12-04 05:35" }, duration: 860, airplane: "Boeing 777", airline: "Qatar Airways", flight_number: "QR 905" },
      { departure_airport: { name: "Hamad International", id: "DOH", time: "2026-12-04 08:05" }, arrival_airport: { name: "Harare", id: "HRE", time: "2026-12-04 15:55" }, duration: 530, airplane: "Boeing 787", airline: "Qatar Airways", flight_number: "QR 1363" },
    ],
    layovers: [{ duration: 150, name: "Hamad International", id: "DOH" }],
    total_duration: 1540,
    price: 5320,
    departure_token: "abc",
  };
  it("maps an itinerary", () => {
    const p = defaultParams(NOW);
    const o = mapSerpItinerary(raw, p, "2026-12-03", "2026-12-24", "https://www.google.com/travel/flights?x", 0)!;
    expect(o.price).toEqual({ total: 5320, currency: "AUD" });
    expect(o.validatingCarrier).toBe("QR");
    expect(o.validatingCarrierName).toBe("Qatar Airways");
    expect(o.outbound.segments[0].flightNumber).toBe("QR905");
    expect(o.outbound.segments[0].departure).toBe("2026-12-03T22:15");
    expect(o.outbound.durationMin).toBe(1540);
    expect(o.outbound.layovers).toEqual([{ airport: "DOH", minutes: 150, overnight: false }]);
    expect(o.inbound).toBeUndefined();
    expect(o.returnDate).toBe("2026-12-24");
    expect(o.bookingUrl).toBe("https://www.google.com/travel/flights?x");
  });
  it("skips itineraries without a price", () => {
    expect(mapSerpItinerary({ ...raw, price: undefined }, defaultParams(NOW), "2026-12-03", undefined)).toBeNull();
  });
  it("builds the right query and surfaces API errors", async () => {
    const calls: string[] = [];
    const fakeFetch = (async (url: string | URL | Request) => {
      calls.push(String(url));
      return new Response(JSON.stringify({ error: "Invalid API key." }), { status: 401 });
    }) as typeof fetch;
    const prov = new SerpApiProvider({ apiKey: "k" }, fakeFetch);
    await expect(prov.search(defaultParams(NOW), "2026-12-03", "2026-12-24")).rejects.toThrow(/Invalid API key/);
    const q = new URL(calls[0]).searchParams;
    expect(q.get("engine")).toBe("google_flights");
    expect(q.get("departure_id")).toBe("MEL");
    expect(q.get("arrival_id")).toBe("HRE");
    expect(q.get("outbound_date")).toBe("2026-12-03");
    expect(q.get("return_date")).toBe("2026-12-24");
    expect(q.get("type")).toBe("1");
    expect(q.get("adults")).toBe("2");
    expect(q.get("children")).toBe("2");
    expect(q.get("currency")).toBe("AUD");
    expect(q.get("stops")).toBe("3");
    expect(q.get("api_key")).toBe("k");
  });
  it("returns mapped offers from best and other flights", async () => {
    const fakeFetch = (async () => new Response(JSON.stringify({ best_flights: [raw], other_flights: [{ ...raw, price: 6000 }], search_metadata: { google_flights_url: "https://g/x" } }), { status: 200 })) as typeof fetch;
    const prov = new SerpApiProvider({ apiKey: "k" }, fakeFetch);
    const offers = await prov.search({ ...defaultParams(NOW), tripType: "oneway" }, "2026-12-03");
    expect(offers.map((o) => o.price.total)).toEqual([5320, 6000]);
    expect(offers[0].returnDate).toBeUndefined();
  });
});

describe("provider selection", () => {
  it("uses the browser key when the environment has none, and env first otherwise", () => {
    expect(getProvider({ env: {} }).name).toBe("sample");
    expect(getProvider({ env: {}, serpApiKey: "browserkey" }).name).toBe("serpapi");
    expect(getProvider({ env: { SERPAPI_KEY: "envkey" } }).name).toBe("serpapi");
    expect(getProvider({ env: { FLIGHT_PROVIDER: "sample", SERPAPI_KEY: "envkey" } }).name).toBe("sample");
    expect(() => getProvider({ env: { FLIGHT_PROVIDER: "serpapi" } })).toThrow(/SERPAPI_KEY/);
  });
});
