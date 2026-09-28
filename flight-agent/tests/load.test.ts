import { beforeEach, describe, expect, it } from "vitest";
import { load } from "@/lib/storage";

const store = new Map<string, string>();
beforeEach(() => {
  store.clear();
  (globalThis as unknown as { localStorage: Storage }).localStorage = {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
    clear: () => store.clear(),
    key: () => null,
    length: 0,
  };
});

describe("load saved state", () => {
  it("keeps saved arrays as arrays (the blank-page bug)", () => {
    store.set("h", JSON.stringify([{ at: "x", window: ["a", "b"] }]));
    const h = load<unknown[]>("h", []);
    expect(Array.isArray(h)).toBe(true);
    expect(h).toHaveLength(1);
  });
  it("merges saved objects over defaults", () => {
    store.set("p", JSON.stringify({ theme: "dark" }));
    expect(load("p", { theme: "system", handsFree: false })).toEqual({ theme: "dark", handsFree: false });
  });
  it("ignores values of the wrong shape or corrupt JSON", () => {
    store.set("h", JSON.stringify({ not: "a list" }));
    expect(load("h", [])).toEqual([]);
    store.set("p", "{oops");
    expect(load("p", { a: 1 })).toEqual({ a: 1 });
    store.set("p", JSON.stringify([1, 2]));
    expect(load("p", { a: 1 })).toEqual({ a: 1 });
  });
});
