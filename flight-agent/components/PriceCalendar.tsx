"use client";
import { money, shortDay } from "@/lib/format";
import type { DatePricePoint } from "@/lib/types";

/** Cheapest fare per sampled departure day, as a strip of small bars. Click to filter. */
export function PriceCalendar({ byDate, currency, active, onPick, stepDays }: { byDate: DatePricePoint[]; currency: string; active: string | null; onPick: (date: string | null) => void; stepDays: number }) {
  if (!byDate.length) return null;
  const prices = byDate.map((d) => d.cheapest).filter((p): p is number => p !== null);
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const h = (p: number) => (max === min ? 16 : 4 + ((p - min) / (max - min)) * 24);
  return (
    <section className="rail-card" aria-label="Cheapest by departure day">
      <div className="datestrip-head">
        <h2>Cheapest by departure day</h2>
        {byDate.length <= 5 && stepDays > 2 && (
          <span className="muted small">Only {byDate.length} dates checked. Say “check every 2 days” for more.</span>
        )}
      </div>
      <div className="datestrip">
        {byDate.map((d) => {
          const lowest = d.cheapest !== null && d.cheapest === min && prices.length > 1;
          return (
            <button
              key={d.date}
              className={`dcell${lowest ? " lowest" : ""}${active === d.date ? " active" : ""}${d.cheapest === null ? " none" : ""}`}
              onClick={() => onPick(active === d.date ? null : d.date)}
              title={d.error ?? `${d.offersFound} fares`}
              aria-pressed={active === d.date}
            >
              <span className="d">{shortDay(d.date)}</span>
              <span className="bar" aria-hidden>{d.cheapest !== null && <span style={{ height: `${h(d.cheapest)}px` }} />}</span>
              {d.cheapest !== null ? <span className="p">{money(d.cheapest, currency)}</span> : <span className={d.error ? "err" : "d"}>{d.error ? "Couldn’t check" : "No fares"}</span>}
              {lowest && <span className="d" style={{ color: "var(--good)" }}>Lowest</span>}
            </button>
          );
        })}
      </div>
    </section>
  );
}
