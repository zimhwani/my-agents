// Gasguys offline credit token (GG1).
//
// Every purchase produces a 12-digit token even when the credit also goes to the meter online, so a
// customer whose valve is out of network coverage can still cook: they key the token in (or the app
// passes it over Bluetooth) and the valve verifies it locally with its own secret. The firmware in
// firmware/src/token.cpp implements the same maths; core/token.test.ts pins shared test vectors.
//
//   high7 = (value * 100 + counter % 100 + pad(counter)) mod 10^7
//   mac5  = u32(HMAC-SHA256(key, "mac:<counter>:<value>")) mod 10^5
//   token = high7 ‖ mac5          value is credit in 10 g units (0..99999 ⇒ up to ~1 t)
//
// pad(c) = u32(HMAC-SHA256(key, "pad:<c>")) mod 10^7 hides the value; u32 is the first four bytes
// big-endian. The meter remembers which counters it has used (no replay) and accepts a window around
// the highest one (tokens can arrive out of order). This mirrors how OpenPAYGO Token and STS work;
// for production, switch to the OpenPAYGO Token standard if the valve vendor supports it (see
// docs/integration-map.md).

export const TOKEN_UNIT_GRAMS = 10;
export const MAX_VALUE = 99_999;
export const LOOKAHEAD = 30;

const enc = new TextEncoder();

function hexToBytes(hex: string): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

async function hmacU32(keyHex: string, msg: string): Promise<number> {
  const key = await crypto.subtle.importKey("raw", hexToBytes(keyHex), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(msg)));
  return ((sig[0] << 24) | (sig[1] << 16) | (sig[2] << 8) | sig[3]) >>> 0;
}

export function randomKeyHex(): string {
  const b = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

export async function generateToken(keyHex: string, counter: number, grams: number): Promise<string> {
  const value = Math.floor(grams / TOKEN_UNIT_GRAMS);
  if (counter < 1 || !Number.isInteger(counter)) throw new Error("counter must be a positive integer");
  if (value < 0 || value > MAX_VALUE) throw new Error("value out of range");
  const pad = (await hmacU32(keyHex, `pad:${counter}`)) % 10_000_000;
  const high = (value * 100 + (counter % 100) + pad) % 10_000_000;
  const mac = (await hmacU32(keyHex, `mac:${counter}:${value}`)) % 100_000;
  return String(high).padStart(7, "0") + String(mac).padStart(5, "0");
}

export type Decoded = { counter: number; grams: number };

/** The valve's replay memory: the highest counter it has applied and which of the 32 below it were used. */
export type CounterState = { max: number; usedMask: number };
export const freshCounterState = (): CounterState => ({ max: 0, usedMask: 0 });

const isUsed = (s: CounterState, c: number) =>
  c === s.max || (c < s.max && s.max - c < 32 && ((s.usedMask >>> (s.max - c)) & 1) === 1);

/** Marks a counter as used. Online credit commands call this too, so their fallback token can't be spent twice. */
export function markUsed(s: CounterState, c: number): CounterState {
  if (c > s.max) {
    const shift = c - s.max;
    const mask = shift >= 32 ? 0 : ((s.usedMask << shift) | (s.max > 0 ? 1 << shift : 0)) >>> 0;
    return { max: c, usedMask: mask };
  }
  if (s.max - c >= 32) return s; // older than the window; the verifier never accepts it anyway
  return { max: s.max, usedMask: (s.usedMask | (1 << (s.max - c))) >>> 0 };
}

/**
 * What the valve does when a token is keyed in. Accepts any unused counter from 31 below the highest
 * applied to LOOKAHEAD above it, so tokens can arrive out of order (an online top-up that landed
 * before an older token was typed in doesn't burn the older one). Returns null for a wrong, used or
 * mistyped token.
 */
export async function verifyToken(
  keyHex: string,
  token: string,
  state: CounterState,
): Promise<(Decoded & { state: CounterState }) | null> {
  const digits = token.replace(/\D/g, "");
  if (digits.length !== 12) return null;
  const high = Number(digits.slice(0, 7));
  const mac = Number(digits.slice(7));
  for (let c = Math.max(1, state.max - 31); c <= state.max + LOOKAHEAD; c++) {
    if (isUsed(state, c)) continue;
    const pad = (await hmacU32(keyHex, `pad:${c}`)) % 10_000_000;
    const plain = (((high - pad) % 10_000_000) + 10_000_000) % 10_000_000;
    if (plain % 100 !== c % 100) continue;
    const value = Math.floor(plain / 100);
    if ((await hmacU32(keyHex, `mac:${c}:${value}`)) % 100_000 !== mac) continue;
    return { counter: c, grams: value * TOKEN_UNIT_GRAMS, state: markUsed(state, c) };
  }
  return null;
}

export const formatToken = (t: string) => t.replace(/(\d{4})(?=\d)/g, "$1 ");

/**
 * Online credit commands carry a signature the valve checks with its own key, so a compromised MQTT
 * broker still can't mint gas: sig = hex(HMAC-SHA256(key, "cmd:credit:<counter>:<grams>"))[0..16].
 */
export async function signCredit(keyHex: string, counter: number, grams: number): Promise<string> {
  const key = await crypto.subtle.importKey("raw", hexToBytes(keyHex), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(`cmd:credit:${counter}:${grams}`)));
  return Array.from(sig.slice(0, 8), (x) => x.toString(16).padStart(2, "0")).join("");
}
