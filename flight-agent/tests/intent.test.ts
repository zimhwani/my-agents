import { describe, expect, it } from "vitest";
import { parseDateWindow, parseIntent } from "@/lib/intent";

const TODAY = "2026-09-17";

describe("parseDateWindow", () => {
  it("handles month names and parts", () => {
    expect(parseDateWindow("flights in december", TODAY)).toEqual({ windowStart: "2026-12-01", windowEnd: "2026-12-31" });
    expect(parseDateWindow("early january", TODAY)).toEqual({ windowStart: "2027-01-01", windowEnd: "2027-01-10" });
    expect(parseDateWindow("late december", TODAY)).toEqual({ windowStart: "2026-12-20", windowEnd: "2026-12-31" });
  });
  it("handles explicit ranges", () => {
    expect(parseDateWindow("between 10 december and 20 january", TODAY)).toEqual({ windowStart: "2026-12-10", windowEnd: "2027-01-20" });
    expect(parseDateWindow("from december 3rd to january 15th", TODAY)).toEqual({ windowStart: "2026-12-03", windowEnd: "2027-01-15" });
    expect(parseDateWindow("between october and december", TODAY)).toEqual({ windowStart: "2026-10-01", windowEnd: "2026-12-31" });
  });
  it("handles 'between now and end of january' (the brief)", () => {
    expect(parseDateWindow("between now and the end of january", TODAY)).toEqual({ windowStart: TODAY, windowEnd: "2027-01-31" });
    expect(parseDateWindow("anytime", TODAY)).toEqual({ windowStart: TODAY, windowEnd: "2027-01-31" });
  });
  it("handles single dates and holidays", () => {
    expect(parseDateWindow("on 3 december", TODAY)).toEqual({ windowStart: "2026-12-03", windowEnd: "2026-12-03" });
    expect(parseDateWindow("around christmas", TODAY)).toEqual({ windowStart: "2026-12-18", windowEnd: "2026-12-26" });
  });
  it("returns null when there is no date", () => {
    expect(parseDateWindow("show me the cheapest", TODAY)).toBeNull();
  });
});

describe("parseIntent", () => {
  it("recognises searches with and without dates", () => {
    expect(parseIntent("search for flights", TODAY)).toEqual({ type: "search" });
    expect(parseIntent("find me the cheapest flights in december", TODAY)).toEqual({ type: "set_dates", windowStart: "2026-12-01", windowEnd: "2026-12-31" });
    expect(parseIntent("search between 10 december and 20 january", TODAY)).toEqual({ type: "set_dates", windowStart: "2026-12-10", windowEnd: "2027-01-20" });
  });
  it("recognises sorting and reading", () => {
    expect(parseIntent("show me the cheapest options", TODAY)).toEqual({ type: "read_results", count: undefined, sort: "cheapest" });
    expect(parseIntent("read me the top three", TODAY)).toMatchObject({ type: "read_results", count: 3 });
    expect(parseIntent("what's the fastest", TODAY)).toMatchObject({ type: "read_results", sort: "fastest" });
    expect(parseIntent("sort by best", TODAY)).toEqual({ type: "set_sort", sort: "best" });
  });
  it("recognises selection", () => {
    expect(parseIntent("tell me about option two", TODAY)).toEqual({ type: "select_offer", index: 2 });
    expect(parseIntent("more details on number 3", TODAY)).toEqual({ type: "select_offer", index: 3 });
  });
  it("recognises passengers and trip settings", () => {
    expect(parseIntent("two adults and two children", TODAY)).toEqual({ type: "set_passengers", adults: 2, children: 2, infants: undefined });
    expect(parseIntent("make it one way", TODAY)).toEqual({ type: "set_trip", tripType: "oneway" });
    expect(parseIntent("return trip staying for three weeks", TODAY)).toEqual({ type: "set_trip", tripType: "return", stayNights: 21 });
    expect(parseIntent("fly business class", TODAY)).toEqual({ type: "set_cabin", cabin: "BUSINESS" });
  });
  it("recognises tracking, help and stop", () => {
    expect(parseIntent("start tracking prices every 6 hours", TODAY)).toEqual({ type: "track", enabled: true, intervalHours: 6 });
    expect(parseIntent("track the fares daily", TODAY)).toEqual({ type: "track", enabled: true, intervalHours: 24 });
    expect(parseIntent("stop tracking", TODAY)).toEqual({ type: "track", enabled: false });
    expect(parseIntent("help", TODAY)).toEqual({ type: "help" });
    expect(parseIntent("stop", TODAY)).toEqual({ type: "stop" });
    expect(parseIntent("blah blah", TODAY)).toEqual({ type: "unknown", utterance: "blah blah" });
  });
});
