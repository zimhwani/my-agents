/** Date helpers working purely on YYYY-MM-DD strings so no timezone drifts. */

export function todayISO(now: Date = new Date()): string {
  return formatISODate(now);
}

export function formatISODate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function parseISODate(s: string): Date {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function addDays(iso: string, days: number): string {
  const d = parseISODate(iso);
  d.setDate(d.getDate() + days);
  return formatISODate(d);
}

export function daysBetween(a: string, b: string): number {
  const ms = parseISODate(b).getTime() - parseISODate(a).getTime();
  return Math.round(ms / 86_400_000);
}

export function isValidISODate(s: unknown): s is string {
  if (typeof s !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = parseISODate(s);
  return formatISODate(d) === s;
}

/** End of January following `from` (or the same year if we're still before it). */
export function endOfNextJanuary(fromISO: string): string {
  const d = parseISODate(fromISO);
  const year = d.getMonth() === 0 ? d.getFullYear() : d.getFullYear() + 1;
  return `${year}-01-31`;
}

/**
 * Departure dates to sample across the window. Always includes the first and last
 * day so the edges of the window are covered.
 */
export function sampleDates(windowStart: string, windowEnd: string, stepDays: number): string[] {
  const step = Math.max(1, Math.floor(stepDays));
  const out: string[] = [];
  if (daysBetween(windowStart, windowEnd) < 0) return out;
  let cur = windowStart;
  while (daysBetween(cur, windowEnd) >= 0) {
    out.push(cur);
    cur = addDays(cur, step);
  }
  if (out[out.length - 1] !== windowEnd) out.push(windowEnd);
  return out;
}

export function weekdayName(iso: string): string {
  return parseISODate(iso).toLocaleDateString("en-AU", { weekday: "short" });
}

export function humanDate(iso: string): string {
  return parseISODate(iso).toLocaleDateString("en-AU", { weekday: "short", day: "numeric", month: "short", year: "numeric" });
}

export function spokenDate(iso: string): string {
  return parseISODate(iso).toLocaleDateString("en-AU", { weekday: "long", day: "numeric", month: "long" });
}

/** "2026-12-03T22:15" -> minutes since midnight (local wall clock). */
export function wallClockMinutes(localDateTime: string): number {
  const t = localDateTime.slice(11, 16);
  const [h, m] = t.split(":").map(Number);
  return h * 60 + m;
}

export function formatDuration(min: number): string {
  const h = Math.floor(min / 60);
  const m = min % 60;
  if (h === 0) return `${m}m`;
  return m ? `${h}h ${m}m` : `${h}h`;
}

export function spokenDuration(min: number): string {
  const h = Math.floor(min / 60);
  const m = min % 60;
  const parts: string[] = [];
  if (h) parts.push(`${h} hour${h === 1 ? "" : "s"}`);
  if (m) parts.push(`${m} minute${m === 1 ? "" : "s"}`);
  return parts.join(" and ") || "0 minutes";
}

export function formatTime(localDateTime: string): string {
  return localDateTime.slice(11, 16);
}
