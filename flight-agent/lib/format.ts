import { airportLabel } from "./airports";
import { formatDuration, formatTime, humanDate, spokenDate, spokenDuration } from "./dates";
import type { Itinerary, RankedOffer, ScanResult, SortMode } from "./types";

export function money(n: number, currency = "AUD"): string {
  return new Intl.NumberFormat("en-AU", { style: "currency", currency, maximumFractionDigits: 0 }).format(n);
}

export function spokenMoney(n: number, currency = "AUD"): string {
  const rounded = Math.round(n);
  const unit = currency === "AUD" ? "dollars" : currency;
  return `${rounded.toLocaleString("en-AU")} ${unit}`;
}

export function routeLabel(it: Itinerary): string {
  const via = it.layovers.map((l) => `${airportLabel(l.airport)}${l.sameFlight ? " (stop)" : ""}`);
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

/** One spoken sentence per offer, tight enough for a voice assistant. */
export function spokenOffer(o: RankedOffer, position: number): string {
  const out = o.outbound;
  const parts = [
    `Option ${position}: ${spokenMoney(o.price.total, o.price.currency)} total with ${o.validatingCarrierName}`,
    `${routeLabel(out)}, leaving ${spokenDate(o.departureDate)} at ${formatTime(out.segments[0].departure)}`,
    `${spokenDuration(out.durationMin)} to ${airportLabel(out.segments.at(-1)!.to)}`,
  ];
  if (o.inbound) parts.push(`back on ${spokenDate(o.returnDate!)}`);
  if (o.warnings.length) parts.push(`note: ${o.warnings.slice(0, 2).join("; ").toLowerCase()}`);
  return parts.join(", ") + ".";
}

export function spokenScanSummary(result: ScanResult, sorted: RankedOffer[], mode: SortMode, count = 3): string {
  if (!sorted.length) return "I could not find any flights for those dates. Try widening the window or allowing more stops.";
  const cheapest = [...result.offers].sort((a, b) => a.price.total - b.price.total)[0];
  const p = result.params;
  const trip = p.tripType !== "return" ? ", one way" : p.returnDate ? `, returning ${spokenDate(p.returnDate)}` : `, ${p.stayNights} nights away`;
  const intro = `I scanned ${result.datesScanned} departure date${result.datesScanned === 1 ? "" : "s"} from ${spokenDate(p.windowStart)} to ${spokenDate(p.windowEnd)}${trip}. ` +
    `The cheapest fare is ${spokenMoney(cheapest.price.total, cheapest.price.currency)} on ${spokenDate(cheapest.departureDate)} with ${cheapest.validatingCarrierName}. `;
  const list = sorted.slice(0, count).map((o, i) => spokenOffer(o, i + 1)).join(" ");
  const sample = result.isSample ? " These are sample fares, not live prices." : "";
  return `${intro}Here are the ${sortLabel(mode)} options. ${list}${sample}`;
}

export function offerHeadline(o: RankedOffer): string {
  return `${money(o.price.total, o.price.currency)} · ${o.validatingCarrierName} · ${routeLabel(o.outbound)} · ${humanDate(o.departureDate)}`;
}
