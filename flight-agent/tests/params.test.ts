import { describe, expect, it } from "vitest";
import { defaultParams, normalizeParams } from "@/lib/params";

const NOW = new Date(2026, 8, 17);

describe("params", () => {
  it("defaults to the brief: MEL->HRE, 2+2, now to end of January", () => {
    const p = defaultParams(NOW);
    expect(p).toMatchObject({ origin: "MEL", destination: "HRE", adults: 2, children: 2, windowStart: "2026-09-17", windowEnd: "2027-01-31", tripType: "return" });
  });
  it("clamps and sanitises untrusted input", () => {
    const p = normalizeParams({ adults: "40", children: -3, windowStart: "2020-01-01", windowEnd: "2030-01-01", origin: "mel", cabin: "FIRST", stepDays: 0 }, NOW);
    expect(p.adults).toBe(9);
    expect(p.children).toBe(0);
    expect(p.windowStart).toBe("2026-09-17");
    expect(p.windowEnd).toBe("2026-09-17"); // window > a year collapses to the start
    expect(p.origin).toBe("MEL");
    expect(p.cabin).toBe("ECONOMY");
    expect(p.stepDays).toBe(1);
  });
  it("keeps a valid custom window", () => {
    const p = normalizeParams({ windowStart: "2026-12-10", windowEnd: "2026-12-20", tripType: "oneway" }, NOW);
    expect(p).toMatchObject({ windowStart: "2026-12-10", windowEnd: "2026-12-20", tripType: "oneway" });
  });
});
