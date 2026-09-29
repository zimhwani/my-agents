import { describe, expect, it } from "vitest";
import { defaultParams, legsFor, normalizeParams, returnDateFor } from "../lib/params";
import { SampleProvider } from "../lib/providers/sample";
import { SerpApiProvider } from "../lib/providers/serpapi";
import { rankOffers } from "../lib/rank";

const route = [
  { from: "MEL", to: "JNB", offset: 0 },
  { from: "JNB", to: "CPT", offset: 1 },
  { from: "CPT", to: "HRE", offset: 5 },
  { from: "HRE", to: "MEL", offset: 34 },
];
const mc = () => normalizeParams({ ...defaultParams(new Date(2026, 8, 29)), tripType: "multicity", route, windowStart: "2026-12-02", windowEnd: "2026-12-02" });

describe("multi-city", () => {
  it("keeps a valid route and dates every flight from the first", () => {
    const p = mc();
    expect(p.tripType).toBe("multicity");
    expect(p.route).toHaveLength(4);
    expect(returnDateFor(p, "2026-12-02")).toBeUndefined();
    expect(legsFor(p, "2026-12-02")).toEqual([
      { from: "MEL", to: "JNB", date: "2026-12-02" },
      { from: "JNB", to: "CPT", date: "2026-12-03" },
      { from: "CPT", to: "HRE", date: "2026-12-07" },
      { from: "HRE", to: "MEL", date: "2027-01-05" },
    ]);
  });

  it("falls back to a return trip when the route is unusable", () => {
    const p = normalizeParams({ ...defaultParams(), tripType: "multicity", route: [{ from: "MEL", to: "MEL", offset: 0 }] });
    expect(p.tripType).toBe("return");
    expect(p.route).toBeUndefined();
  });

  it("never lets a later flight go before an earlier one", () => {
    const p = normalizeParams({ ...mc(), route: [{ from: "MEL", to: "JNB", offset: 3 }, { from: "JNB", to: "HRE", offset: 1 }] });
    expect(p.route!.map((l) => l.offset)).toEqual([0, 0]);
  });

  it("asks SerpApi for every flight in multi_city_json", () => {
    const q = new SerpApiProvider({ apiKey: "k" }).buildQuery(mc(), "2026-12-02");
    expect(q.get("type")).toBe("3");
    expect(JSON.parse(q.get("multi_city_json")!)).toHaveLength(4);
  });

  it("sample fares cover every flight in order", async () => {
    const offers = await new SampleProvider().search(mc(), "2026-12-02");
    expect(offers.length).toBeGreaterThan(0);
    for (const o of offers) {
      expect(o.legs).toHaveLength(4);
      expect(o.legs!.map((l) => `${l.segments[0].from}-${l.segments.at(-1)!.to}`)).toEqual(["MEL-JNB", "JNB-CPT", "CPT-HRE", "HRE-MEL"]);
      expect(o.legs![3].segments[0].departure.slice(0, 10)).toBe("2027-01-05");
    }
    const ranked = rankOffers(offers);
    expect(ranked[0].scores.best).toBeGreaterThan(0);
  });
});

import { parseIntent } from "../lib/intent";
import { withRoute } from "../lib/params";
import { speechFor } from "../lib/speech";
import { spokenUnderstood } from "../lib/format";

describe("multi-city by voice", () => {
  const today = "2026-09-29";

  it("hears four flights with their dates", () => {
    const i = parseIntent("Melbourne to Joburg on 2 December, Joburg to Cape Town on 3 December, Cape Town to Harare on 7 December and Harare to Melbourne on 5 January", today);
    expect(i).toEqual({ type: "set_route", legs: [
      { from: "MEL", to: "JNB", date: "2026-12-02" },
      { from: "JNB", to: "CPT", date: "2026-12-03" },
      { from: "CPT", to: "HRE", date: "2026-12-07" },
      { from: "HRE", to: "MEL", date: "2027-01-05" },
    ] });
    expect(speechFor(i)).toMatch(/^Planning 4 flights: Melbourne to Johannesburg on/);
  });

  it("chains cities, relative dates and 'home'", () => {
    const i = parseIntent("fly to Johannesburg on the 2nd of December then Cape Town the next day, stay 4 nights, then Harare, then back home on 5 January", today);
    expect(i.type).toBe("set_route");
    if (i.type !== "set_route") return;
    expect(i.legs.map((l) => `${l.from ?? "?"}-${l.to} ${l.date ?? ""}`)).toEqual([
      "?-JNB 2026-12-02", "JNB-CPT 2026-12-03", "CPT-HRE 2026-12-07", "HRE-HOME 2027-01-05",
    ]);
    const p = withRoute(defaultParams(new Date(2026, 8, 29)), i.legs);
    expect(legsFor(p, p.windowStart)).toEqual([
      { from: "MEL", to: "JNB", date: "2026-12-02" },
      { from: "JNB", to: "CPT", date: "2026-12-03" },
      { from: "CPT", to: "HRE", date: "2026-12-07" },
      { from: "HRE", to: "MEL", date: "2027-01-05" },
    ]);
    expect(p.windowEnd).toBe("2026-12-02");
    expect(spokenUnderstood(p)).toBe("Looking at 4 flights: Melbourne, Johannesburg, Cape Town, Harare and back to Melbourne, 2 December to 5 January, for two adults and two children.");
  });

  it("needs 'multi city' for just two flights, and leaves stopovers alone", () => {
    expect(parseIntent("multi city Melbourne to Harare on 1 December and Harare to Cape Town on 20 December", today).type).toBe("set_route");
    expect(parseIntent("stop over in Dubai for 3 nights", today).type).toBe("set_stopover");
    expect(parseIntent("stop in Cape Town for 3 nights from 2 December", today).type).toBe("set_stopover");
    expect(parseIntent("Melbourne to Harare in early December returning mid January", today).type).toBe("set_dates");
    expect(parseIntent("add a child", today).type).toBe("set_passengers");
  });

  it("fills undated flights with sensible gaps", () => {
    const base = defaultParams(new Date(2026, 8, 29));
    const p = withRoute({ ...base, windowStart: "2026-12-01", windowEnd: "2026-12-01" }, [{ to: "JNB" }, { to: "CPT" }, { to: "HOME" }]);
    expect(legsFor(p, p.windowStart)!.map((l) => `${l.from}-${l.to} ${l.date}`)).toEqual([
      "MEL-JNB 2026-12-01", "JNB-CPT 2026-12-04", "CPT-MEL 2026-12-22",
    ]);
  });
});
