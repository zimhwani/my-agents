// A software model of the Gasguys valve: the same rules as firmware/src/main.cpp, in TypeScript,
// so the sandbox (and tests) exercise the logic the ESP32 runs. If a rule changes here, change it
// in the firmware too.

import { freshCounterState, markUsed, verifyToken, type CounterState } from "./token.ts";
import type { Telemetry, ValveState } from "./types.ts";

/** A two-plate stove burner on medium draws roughly 150 g of LPG an hour. */
export const BURNER_GRAMS_PER_MIN = 2.5;
/** Wrong tokens allowed before the keypad locks for LOCKOUT_MIN minutes (slows brute force). */
export const MAX_BAD_TOKENS = 5;
export const LOCKOUT_MIN = 30;

export type DeviceState = {
  meterId: string;
  gasGrams: number;
  creditGrams: number;
  valve: ValveState;
  leak: boolean;
  tamper: boolean;
  batteryPct: number;
  counters: CounterState;
  burnerOn: boolean;
  online: boolean;
  badTokens: number;
  lockedUntilMin: number; // simulated minutes; keypad lockout
  clockMin: number; // simulated minutes since boot
};

export type DeviceLog = { at: number; tag: string; text: string };

export function newDevice(meterId: string, gasGrams: number, creditGrams: number, counter = 0): DeviceState {
  const d: DeviceState = {
    meterId,
    gasGrams,
    creditGrams,
    valve: "closed",
    leak: false,
    tamper: false,
    batteryPct: 92,
    counters: counter > 0 ? markUsed(freshCounterState(), counter) : freshCounterState(),
    burnerOn: false,
    online: true,
    badTokens: 0,
    lockedUntilMin: 0,
    clockMin: 0,
  };
  d.valve = shouldOpen(d) ? "open" : "closed";
  return d;
}

/** Fail-closed: the valve opens only when every condition says it may. */
export const shouldOpen = (d: DeviceState) =>
  d.creditGrams > 0 && d.gasGrams > 0 && !d.leak && !d.tamper && d.batteryPct > 5;

export class ValveDevice {
  logs: DeviceLog[] = [];
  constructor(
    public s: DeviceState,
    private keyHex: string,
  ) {}

  private log(tag: string, text: string) {
    this.logs.push({ at: this.s.clockMin, tag, text });
    if (this.logs.length > 200) this.logs.shift();
  }

  private settleValve() {
    const want: ValveState = shouldOpen(this.s) ? "open" : "closed";
    if (want !== this.s.valve) {
      this.s.valve = want;
      this.log("valve", want === "open" ? "OPEN (motor 0.4 s)" : "CLOSED (motor 0.4 s)");
    }
  }

  /** Online credit from the backend over MQTT. The counter burns the matching offline token. */
  applyCredit(grams: number, counter: number): boolean {
    const c = this.s.counters;
    const used = counter === c.max || (counter < c.max && c.max - counter < 32 && ((c.usedMask >>> (c.max - counter)) & 1) === 1);
    if (used || counter <= c.max - 32) {
      this.log("mqtt", `credit ctr=${counter} already applied → ACK (no-op)`);
      return true;
    }
    this.s.counters = markUsed(c, counter);
    this.s.creditGrams += grams;
    this.log("mqtt", `cmd credit +${grams} g ctr=${counter} → ACK`);
    this.settleValve();
    return true;
  }

  /** Customer keys in a 12-digit token on the keypad (or taps it in over Bluetooth). */
  async enterToken(token: string): Promise<{ ok: boolean; grams?: number; reason?: string }> {
    if (this.s.clockMin < this.s.lockedUntilMin) {
      this.log("token", "keypad locked, try later");
      return { ok: false, reason: "locked" };
    }
    const res = await verifyToken(this.keyHex, token, this.s.counters);
    if (!res) {
      this.s.badTokens += 1;
      if (this.s.badTokens >= MAX_BAD_TOKENS) {
        this.s.lockedUntilMin = this.s.clockMin + LOCKOUT_MIN;
        this.s.badTokens = 0;
      }
      this.log("token", `${token} rejected (wrong, used or mistyped)`);
      return { ok: false, reason: "invalid" };
    }
    this.s.badTokens = 0;
    this.s.counters = res.state;
    this.s.creditGrams += res.grams;
    this.log("token", `${token} accepted +${res.grams} g (ctr ${res.counter})`);
    this.settleValve();
    return { ok: true, grams: res.grams };
  }

  setBurner(on: boolean) {
    this.s.burnerOn = on;
    this.log("flow", on ? "burner lit" : "burner off");
  }
  setLeak(on: boolean) {
    this.s.leak = on;
    this.log("safety", on ? "LPG sensor over threshold → shutting valve" : "leak cleared by technician");
    this.settleValve();
  }
  setTamper(on: boolean) {
    this.s.tamper = on;
    this.log("safety", on ? "enclosure opened → shutting valve" : "tamper cleared");
    this.settleValve();
  }
  setOnline(on: boolean) {
    this.s.online = on;
    this.log("modem", on ? "registered on network, MQTT connected" : "no network (queued telemetry)");
  }
  refill(cylinderKg: number) {
    this.s.gasGrams = cylinderKg * 1000;
    this.log("scale", `new cylinder detected: ${cylinderKg} kg`);
    this.settleValve();
  }

  /** Advances the clock. Gas only flows while the valve is open and the burner is lit. */
  tick(minutes: number) {
    this.s.clockMin += minutes;
    if (this.s.valve === "open" && this.s.burnerOn) {
      const used = Math.min(BURNER_GRAMS_PER_MIN * minutes, this.s.creditGrams, this.s.gasGrams);
      this.s.creditGrams = round1(this.s.creditGrams - used);
      this.s.gasGrams = round1(this.s.gasGrams - used);
      if (this.s.creditGrams <= 0) this.log("credit", "credit used up");
      if (this.s.gasGrams <= 0) this.log("scale", "cylinder empty");
    }
    this.s.batteryPct = Math.max(0, this.s.batteryPct - minutes * 0.0005);
    this.settleValve();
  }

  telemetry(at: string): Telemetry {
    return {
      meterId: this.s.meterId,
      gasGrams: Math.round(this.s.gasGrams),
      creditGrams: Math.round(this.s.creditGrams),
      valve: this.s.valve,
      batteryPct: Math.round(this.s.batteryPct),
      leak: this.s.leak,
      tamper: this.s.tamper,
      tokenCounter: this.s.counters.max,
      at,
    };
  }
}

const round1 = (n: number) => Math.round(n * 10) / 10;
