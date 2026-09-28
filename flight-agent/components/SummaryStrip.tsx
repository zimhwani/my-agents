"use client";
import { formatDuration } from "@/lib/dates";
import { money, shortDay } from "@/lib/format";
import { connectionCount, sortOffers } from "@/lib/rank";
import type { RankedOffer, SortMode } from "@/lib/types";

const TILES: { mode: SortMode; label: string }[] = [
  { mode: "best", label: "Best overall" },
  { mode: "cheapest", label: "Cheapest" },
  { mode: "fastest", label: "Fastest" },
];

export function Price({ value, currency }: { value: number; currency: string }) {
  const text = money(value, currency);
  const m = /^([^\d]*)(.*)$/.exec(text)!;
  return <span className="price num"><span className="cur">{m[1]}</span>{m[2]}</span>;
}

function stopsText(n: number): string {
  return n === 0 ? "nonstop" : `${n} stop${n === 1 ? "" : "s"}`;
}

export function SummaryStrip({ offers, sort, onPick, isSample }: { offers: RankedOffer[]; sort: SortMode; onPick: (m: SortMode) => void; isSample: boolean }) {
  if (!offers.length) return null;
  return (
    <section className="summary" aria-label="Headline fares">
      {TILES.map(({ mode, label }) => {
        const o = sortOffers(offers, mode)[0];
        return (
          <button key={mode} className={`tile ${mode}`} aria-pressed={sort === mode} onClick={() => onPick(mode)}>
            <span className="label">{label}</span>
            <Price value={o.price.total} currency={o.price.currency} />
            <span className="sub">{shortDay(o.departureDate)} · {o.validatingCarrierName}</span>
            <span className="sub">{formatDuration(o.outbound.durationMin)} there · {stopsText(connectionCount(o.outbound))}{isSample ? " · sample" : ""}</span>
          </button>
        );
      })}
    </section>
  );
}
