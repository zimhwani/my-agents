import { describe, expect, it } from "vitest";
import { defaultParams } from "@/lib/params";
import { AmadeusProvider, mapAmadeusOffer, parseIsoDuration } from "@/lib/providers/amadeus";
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

describe("amadeus mapping", () => {
  it("parses ISO durations", () => {
    expect(parseIsoDuration("PT14H20M")).toBe(860);
    expect(parseIsoDuration("PT9H")).toBe(540);
    expect(parseIsoDuration("P1DT2H5M")).toBe(1565);
    expect(parseIsoDuration(undefined)).toBe(0);
  });
  it("maps a flight offer", () => {
    const raw = {
      id: "7",
      numberOfBookableSeats: 4,
      itineraries: [
        { duration: "PT25H40M", segments: [
          { departure: { iataCode: "MEL", at: "2026-12-03T22:15:00" }, arrival: { iataCode: "DOH", at: "2026-12-04T05:35:00" }, carrierCode: "QR", number: "905", duration: "PT14H20M", aircraft: { code: "77W" } },
          { departure: { iataCode: "DOH", at: "2026-12-04T08:05:00" }, arrival: { iataCode: "HRE", at: "2026-12-04T15:55:00" }, carrierCode: "QR", number: "1363", duration: "PT8H50M" },
        ] },
      ],
      price: { grandTotal: "5320.40", total: "5320.40", currency: "AUD" },
      validatingAirlineCodes: ["QR"],
      travelerPricings: [{ travelerType: "ADULT", price: { total: "1600.20" } }, { travelerType: "CHILD", price: { total: "1060.00" } }],
    };
    const p = defaultParams(NOW);
    const o = mapAmadeusOffer(raw, p, "2026-12-03", undefined, { carriers: { QR: "QATAR AIRWAYS" }, aircraft: { "77W": "BOEING 777-300ER" } });
    expect(o.price).toEqual({ total: 5320.4, currency: "AUD", perAdult: 1600.2, perChild: 1060 });
    expect(o.validatingCarrierName).toBe("Qatar Airways");
    expect(o.outbound.durationMin).toBe(1540);
    expect(o.outbound.layovers).toEqual([{ airport: "DOH", minutes: 150, overnight: false }]);
    expect(o.outbound.segments[0].aircraft).toBe("BOEING 777-300ER");
    expect(o.bookingUrl).toMatch(/google\.com\/travel\/flights/);
  });
  it("sends the right request and surfaces API errors", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fakeFetch = (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init: init ?? {} });
      if (String(url).includes("oauth2/token")) return new Response(JSON.stringify({ access_token: "tok", expires_in: 1799 }), { status: 200 });
      return new Response(JSON.stringify({ errors: [{ status: 400, code: 477, title: "INVALID FORMAT", detail: "bad date" }] }), { status: 400 });
    }) as typeof fetch;
    const prov = new AmadeusProvider({ clientId: "id", clientSecret: "secret", env: "test" }, fakeFetch);
    await expect(prov.search(defaultParams(NOW), "2026-12-03", "2026-12-24")).rejects.toThrow(/INVALID FORMAT: bad date/);
    expect(calls[0].url).toBe("https://test.api.amadeus.com/v1/security/oauth2/token");
    const body = JSON.parse(String(calls[1].init.body));
    expect(body.originDestinations).toHaveLength(2);
    expect(body.travelers.map((t: { travelerType: string }) => t.travelerType)).toEqual(["ADULT", "ADULT", "CHILD", "CHILD"]);
    expect(body.currencyCode).toBe("AUD");
  });
});
