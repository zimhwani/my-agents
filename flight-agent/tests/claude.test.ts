import { describe, expect, it } from "vitest";
import { fallbackInterpretation, speechFor } from "@/lib/claude";
import { defaultParams } from "@/lib/params";

describe("fallback interpretation", () => {
  it("maps the brief's phrasing to intents with spoken replies", () => {
    const ctx = { params: defaultParams(new Date(2026, 8, 17)), today: "2026-09-17" };
    const r = fallbackInterpretation("find the cheapest flights between now and the end of january", ctx);
    expect(r.source).toBe("rules");
    expect(r.intent).toEqual({ type: "set_dates", windowStart: "2026-09-17", windowEnd: "2027-01-31" });
    expect(r.speech).toMatch(/Sunday,? 31 January/);
    expect(speechFor({ type: "unknown", utterance: "x" })).toMatch(/help/);
  });
});
