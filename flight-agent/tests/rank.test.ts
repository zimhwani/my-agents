import { describe, expect, it } from "vitest";
import { buildItinerary, cheapestByDate, computeLayovers, rankOffers, sortOffers, wallClockDiffMinutes } from "@/lib/rank";
import type { FlightOffer, Segment } from "@/lib/types";

function seg(p: Partial<Segment> & Pick<Segment, "from" | "to" | "departure" | "arrival" | "durationMin">): Segment {
  return { carrier: "QR", carrierName: "Qatar Airways", flightNumber: "QR1", ...p };
}

function offer(id: string, total: number, outbound: Segment[], inbound?: Segment[]): FlightOffer {
  return {
    id, provider: "sample", price: { total, currency: "AUD" }, validatingCarrier: "QR", validatingCarrierName: "Qatar Airways",
    outbound: buildItinerary(outbound), inbound: inbound ? buildItinerary(inbound) : undefined, departureDate: outbound[0].departure.slice(0, 10),
  };
}

const smooth = [
  seg({ from: "MEL", to: "DOH", departure: "2026-12-03T22:15", arrival: "2026-12-04T05:35", durationMin: 860 }),
  seg({ from: "DOH", to: "HRE", departure: "2026-12-04T08:05", arrival: "2026-12-04T15:55", durationMin: 530 }),
];
const tight = [
  seg({ from: "MEL", to: "DOH", departure: "2026-12-03T22:15", arrival: "2026-12-04T05:35", durationMin: 860 }),
  seg({ from: "DOH", to: "HRE", departure: "2026-12-04T06:20", arrival: "2026-12-04T14:10", durationMin: 530 }),
];
const overnight = [
  seg({ from: "MEL", to: "DXB", departure: "2026-12-03T03:35", arrival: "2026-12-03T11:45", durationMin: 850 }),
  seg({ from: "DXB", to: "HRE", departure: "2026-12-04T09:20", arrival: "2026-12-04T16:00", durationMin: 520 }),
];

describe("layovers", () => {
  it("computes minutes at the same airport and flags overnights", () => {
    expect(wallClockDiffMinutes("2026-12-04T05:35", "2026-12-04T08:05")).toBe(150);
    expect(computeLayovers(smooth)).toEqual([{ airport: "DOH", minutes: 150, overnight: false }]);
    expect(computeLayovers(overnight)[0]).toMatchObject({ airport: "DXB", overnight: true });
    expect(computeLayovers(overnight)[0].minutes).toBe(21 * 60 + 35);
  });
  it("sums flying time and layovers when no total is given", () => {
    expect(buildItinerary(smooth).durationMin).toBe(860 + 150 + 530);
  });
});

describe("rankOffers", () => {
  it("prefers the smooth itinerary over a cheaper but nasty one when prices are close", () => {
    const ranked = rankOffers([
      offer("a", 5200, smooth),
      offer("b", 5100, overnight), // early departure + overnight layover
      offer("c", 5150, tight),
    ]);
    const best = sortOffers(ranked, "best");
    expect(best[0].id).toBe("a");
    expect(sortOffers(ranked, "cheapest")[0].id).toBe("b");
    const b = ranked.find((o) => o.id === "b")!;
    expect(b.badges).toContain("Cheapest");
    expect(b.warnings.join(" ")).toMatch(/Overnight layover in Dubai/);
    expect(b.warnings.join(" ")).toMatch(/Departs Melbourne at 03:35/);
    expect(ranked.find((o) => o.id === "c")!.warnings.join(" ")).toMatch(/Tight connection in Doha/);
    expect(ranked.find((o) => o.id === "a")!.badges).toContain("Family-friendly times");
  });
  it("lets a big enough saving win the best ranking", () => {
    const ranked = rankOffers([offer("a", 6500, smooth), offer("b", 4200, tight)]);
    expect(sortOffers(ranked, "best")[0].id).toBe("b");
    expect(ranked.find((o) => o.id === "a")!.scores.cheapest).toBeLessThan(ranked.find((o) => o.id === "b")!.scores.cheapest);
  });
  it("builds a cheapest-per-date map", () => {
    const ranked = rankOffers([offer("a", 5200, smooth), offer("b", 5100, tight)]);
    expect(cheapestByDate(ranked).get("2026-12-03")!.id).toBe("b");
  });
  it("handles an empty set", () => {
    expect(rankOffers([])).toEqual([]);
  });
});
