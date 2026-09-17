import { describe, expect, it } from "vitest";
import { addDays, daysBetween, endOfNextJanuary, isValidISODate, sampleDates } from "@/lib/dates";

describe("dates", () => {
  it("adds days across month boundaries", () => {
    expect(addDays("2026-12-25", 10)).toBe("2027-01-04");
    expect(daysBetween("2026-09-17", "2027-01-31")).toBe(136);
  });
  it("finds the end of the following January", () => {
    expect(endOfNextJanuary("2026-09-17")).toBe("2027-01-31");
    expect(endOfNextJanuary("2027-01-10")).toBe("2027-01-31");
  });
  it("samples the window including both edges", () => {
    const d = sampleDates("2026-09-17", "2026-10-10", 7);
    expect(d).toEqual(["2026-09-17", "2026-09-24", "2026-10-01", "2026-10-08", "2026-10-10"]);
    expect(sampleDates("2026-09-17", "2026-09-17", 7)).toEqual(["2026-09-17"]);
    expect(sampleDates("2026-09-18", "2026-09-17", 7)).toEqual([]);
  });
  it("validates ISO dates", () => {
    expect(isValidISODate("2026-02-30")).toBe(false);
    expect(isValidISODate("2026-12-01")).toBe(true);
    expect(isValidISODate("tomorrow")).toBe(false);
  });
});
