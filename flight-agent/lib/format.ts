import { airportLabel } from "./airports";
import { daysBetween, formatDuration, formatTime, humanDate, parseISODate, spokenDate, spokenDuration } from "./dates";
import { sortOffers } from "./rank";
import { whyNoDates } from "./params";
import type { Itinerary, RankedOffer, ScanResult, SearchParams, SortMode } from "./types";

export function money(n: number, currency = "AUD"): string {
  return new Intl.NumberFormat("en-AU", { style: "currency", currency, maximumFractionDigits: 0 }).format(n);
}

export function spokenMoney(n: number, currency = "AUD"): string {
  const rounded = Math.round(n);
  const unit = currency === "AUD" ? "dollars" : currency;
  return `${rounded.toLocaleString("en-AU")} ${unit}`;
}

export function routeLabel(it: Itinerary): string {
  const via = it.layovers.map((l) => `${airportLabel(l.airport)}${l.stopover ? " (stopover)" : l.sameFlight ? " (stop)" : ""}`);
  return via.length ? `via ${via.join(" and ")}` : "nonstop";
}

export function legSummary(it: Itinerary): string {
  const first = it.segments[0];
  const last = it.segments[it.segments.length - 1];
  return `${formatTime(first.departure)} ${airportLabel(first.from)} → ${formatTime(last.arrival)} ${airportLabel(last.to)} · ${formatDuration(it.durationMin)} · ${routeLabel(it)}`;
}

export function sortLabel(mode: SortMode): string {
  return mode === "cheapest" ? "cheapest" : mode === "fastest" ? "fastest" : "best overall";
}

/** Days between departure and arrival calendar dates of a leg (for "+1"). */
export function dayOffset(it: Itinerary): number {
  const dep = it.segments[0].departure.slice(0, 10);
  const arr = it.segments[it.segments.length - 1].arrival.slice(0, 10);
  return Math.max(0, daysBetween(dep, arr));
}

const MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const MONTH_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

/** "11–30 Nov" or "28 Nov – 5 Dec" (long: "11 to 30 November"). */
export function dateRange(a: string, b: string, long = false): string {
  const da = parseISODate(a);
  const db = parseISODate(b);
  const names = long ? MONTH_LONG : MONTH_SHORT;
  if (a === b) return `${da.getDate()} ${names[da.getMonth()]}`;
  if (da.getMonth() === db.getMonth() && da.getFullYear() === db.getFullYear()) {
    return long ? `${da.getDate()} to ${db.getDate()} ${names[da.getMonth()]}` : `${da.getDate()}–${db.getDate()} ${names[da.getMonth()]}`;
  }
  return long ? `${da.getDate()} ${names[da.getMonth()]} to ${db.getDate()} ${names[db.getMonth()]}` : `${da.getDate()} ${names[da.getMonth()]} – ${db.getDate()} ${names[db.getMonth()]}`;
}

/** "Tue 5 Jan" */
export function shortDay(iso: string): string {
  const d = parseISODate(iso);
  return `${d.toLocaleDateString("en-AU", { weekday: "short" })} ${d.getDate()} ${MONTH_SHORT[d.getMonth()]}`;
}

const WORDS = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
function countWord(n: number, one: string, many: string): string {
  return `${WORDS[n] ?? n} ${n === 1 ? one : many}`;
}

export function travellersSpoken(p: SearchParams): string {
  const parts = [countWord(p.adults, "adult", "adults")];
  if (p.children) parts.push(countWord(p.children, "child", "children"));
  if (p.infants) parts.push(countWord(p.infants, "infant", "infants"));
  return parts.length > 1 ? `${parts.slice(0, -1).join(", ")} and ${parts.at(-1)}` : parts[0];
}

/** One sentence: what the agent understood. */
export function spokenUnderstood(p: SearchParams): string {
  const when = p.windowStart === p.windowEnd ? spokenDate(p.windowStart) : dateRange(p.windowStart, p.windowEnd, true);
  const nights = (n: number) => `${n} night${n === 1 ? "" : "s"}`;
  const so = p.stopover ? `, with ${nights(p.stopover.nights)} in ${airportLabel(p.stopover.airport)} on the way${p.stopover.leg === "return" ? " home" : ""}` : "";
  const back = p.tripType !== "return"
    ? ", one way"
    : p.returnDate
      ? `, back on ${spokenDate(p.returnDate)}`
      : p.stopover ? ` and ${nights(p.stayNights)} in ${airportLabel(p.destination)}` : `, staying ${nights(p.stayNights)}`;
  return p.stopover && !p.returnDate && p.tripType === "return"
    ? `Looking at ${when}${so}${back}, for ${travellersSpoken(p)}.`
    : `Looking at ${when}${back}${so}, for ${travellersSpoken(p)}.`;
}

/**
 * The short reply after a search: what was understood, the headline fares, and
 * how to hear more. Under ~45 words, no clock times, no stop lists.
 */
export function spokenBrief(result: ScanResult): string {
  const p = result.params;
  const understood = spokenUnderstood(p);
  if (!result.offers.length) {
    const why = result.datesScanned === 0 ? whyNoDates(p) : null;
    if (why) return why;
    return `I found nothing for ${dateRange(p.windowStart, p.windowEnd, true)}. Try allowing more stops or a wider window.`;
  }
  const cheapest = sortOffers(result.offers, "cheapest")[0];
  const best = sortOffers(result.offers, "best")[0];
  const fare = (o: RankedOffer) => `${money(o.price.total, o.price.currency)} with ${o.validatingCarrierName}`;
  const headline =
    cheapest.id === best.id
      ? `Cheapest and best: ${fare(cheapest)}, leaving ${spokenDate(cheapest.departureDate)}.`
      : `Cheapest is ${fare(cheapest)}, leaving ${spokenDate(cheapest.departureDate)}. Best overall is ${fare(best)}.`;
  const sample = result.isSample ? " (Sample fares.)" : "";
  return `${understood} ${headline}${sample}`;
}

/** One sentence per offer for "read me the top three". */
export function spokenOffer(o: RankedOffer, position: number): string {
  const out = o.outbound;
  const parts = [
    `Option ${position}: ${money(o.price.total, o.price.currency)} with ${o.validatingCarrierName}`,
    `${routeLabel(out)}, leaving ${spokenDate(o.departureDate)}`,
    `${spokenDuration(o.totalDurationMin)} in total`,
  ];
  if (o.warnings.length) parts.push(`heads-up: ${o.warnings[0].toLowerCase()}`);
  return parts.join(", ") + ".";
}

/** "Tell me about option two": about 50 words. */
export function spokenOfferDetail(o: RankedOffer, position: number): string {
  const out = o.outbound;
  const first = out.segments[0];
  const last = out.segments[out.segments.length - 1];
  const back = o.returnDate ? ` Coming back ${spokenDate(o.returnDate)}.` : "";
  const note = o.warnings.length ? ` Heads-up: ${o.warnings[0].toLowerCase()}.` : "";
  return `Option ${position} is ${money(o.price.total, o.price.currency)} for the family with ${o.validatingCarrierName}, ${routeLabel(out)}. ` +
    `It leaves ${airportLabel(first.from)} ${spokenDate(o.departureDate)} at ${formatTime(first.departure)} and reaches ${airportLabel(last.to)} after ${spokenDuration(out.durationMin)}.${back}${note}`;
}

export function spokenScanSummary(result: ScanResult, sorted: RankedOffer[], mode: SortMode, count = 3): string {
  if (!sorted.length) return "I could not find any flights for those dates. Try widening the window or allowing more stops.";
  const list = sorted.slice(0, count).map((o, i) => spokenOffer(o, i + 1)).join(" ");
  const sample = result.isSample ? " These are sample fares." : "";
  return `Here are the ${sortLabel(mode)} options. ${list}${sample}`;
}

export function offerHeadline(o: RankedOffer): string {
  return `${money(o.price.total, o.price.currency)} · ${o.validatingCarrierName} · ${routeLabel(o.outbound)} · ${humanDate(o.departureDate)}`;
}
