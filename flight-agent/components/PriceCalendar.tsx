"use client";
import { humanDate } from "@/lib/dates";
import { money } from "@/lib/format";
import type { DatePricePoint } from "@/lib/types";

/** Cheapest fare for each sampled departure date. Click a date to filter results. */
export function PriceCalendar({ byDate, currency, active, onPick }: { byDate: DatePricePoint[]; currency: string; active: string | null; onPick: (date: string | null) => void }) {
  const prices = byDate.map((d) => d.cheapest).filter((p): p is number => p !== null);
  if (!byDate.length) return null;
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const tier = (p: number | null) => {
    if (p === null || max === min) return p === null ? "none" : "tier-0";
    const r = (p - min) / (max - min);
    return r < 0.1 ? "tier-0" : r < 0.35 ? "tier-1" : r < 0.7 ? "tier-2" : "tier-3";
  };
  return (
    <section className="panel">
      <h2>Cheapest fare by departure date</h2>
      <div className="cal">
        {byDate.map((d) => (
          <button
            key={d.date}
            className={`cal-cell ${tier(d.cheapest)}${active === d.date ? " active" : ""}`}
            onClick={() => onPick(active === d.date ? null : d.date)}
            title={d.error ?? `${d.offersFound} offers`}
          >
            <small>{humanDate(d.date).replace(/ \d{4}$/, "")}</small>
            <span className="p">{d.cheapest === null ? (d.error ? "error" : "—") : money(d.cheapest, currency)}</span>
            <small>{d.cheapest === min && prices.length > 1 ? "lowest" : d.offersFound ? `${d.offersFound} fares` : "no fares"}</small>
          </button>
        ))}
      </div>
    </section>
  );
}
