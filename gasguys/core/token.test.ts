import { describe, expect, it } from "vitest";
import { freshCounterState, generateToken, markUsed, verifyToken } from "./token.ts";

const KEY = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";

describe("GG1 offline token", () => {
  it("round-trips value and counter", async () => {
    const t = await generateToken(KEY, 1, 2500);
    expect(t).toMatch(/^\d{12}$/);
    const d = await verifyToken(KEY, t, freshCounterState());
    expect(d?.grams).toBe(2500);
    expect(d?.counter).toBe(1);
  });

  it("rejects a replayed token", async () => {
    const t = await generateToken(KEY, 1, 500);
    const d = await verifyToken(KEY, t, freshCounterState());
    expect(await verifyToken(KEY, t, d!.state)).toBeNull();
  });

  it("accepts tokens out of order but only once each", async () => {
    const t3 = await generateToken(KEY, 3, 1000);
    const t2 = await generateToken(KEY, 2, 700);
    let s = freshCounterState();
    s = (await verifyToken(KEY, t3, s))!.state;
    const d2 = await verifyToken(KEY, t2, s);
    expect(d2?.grams).toBe(700);
    expect(await verifyToken(KEY, t2, d2!.state)).toBeNull();
  });

  it("won't reuse a token whose credit already arrived online", async () => {
    const t5 = await generateToken(KEY, 5, 1000);
    const s = markUsed(freshCounterState(), 5);
    expect(await verifyToken(KEY, t5, s)).toBeNull();
  });

  it("rejects a mistyped digit and a wrong key", async () => {
    const t = await generateToken(KEY, 7, 1230);
    const typo = t.slice(0, 11) + ((Number(t[11]) + 1) % 10);
    expect(await verifyToken(KEY, typo, markUsed(freshCounterState(), 6))).toBeNull();
    expect(await verifyToken(KEY.replace("00", "ff"), t, markUsed(freshCounterState(), 6))).toBeNull();
  });

  it("pins test vectors shared with the firmware", async () => {
    // If these change, firmware/src/token.cpp must change with them.
    const vectors = await Promise.all([
      generateToken(KEY, 1, 1000),
      generateToken(KEY, 2, 2500),
      generateToken(KEY, 42, 999990),
    ]);
    expect(vectors).toMatchSnapshot();
  });
});

describe("signed credit command", () => {
  it("pins a vector shared with the firmware", async () => {
    const { signCredit } = await import("./token.ts");
    expect(await signCredit(KEY, 1, 1000)).toMatchSnapshot();
  });
});
