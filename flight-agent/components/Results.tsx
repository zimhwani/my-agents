"use client";
import { sortLabel } from "@/lib/format";
import type { RankedOffer, SortMode } from "@/lib/types";
import { OfferCard } from "./OfferCard";

const MODES: SortMode[] = ["best", "cheapest", "fastest"];

export function Results({
  offers, sort, onSort, selectedId, onSelect, dateFilter, onClearDate,
}: {
  offers: RankedOffer[];
  sort: SortMode;
  onSort: (m: SortMode) => void;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  dateFilter: string | null;
  onClearDate: () => void;
}) {
  return (
    <section className="panel" id="results">
      <h2>Results{dateFilter ? ` · departing ${dateFilter}` : ""}</h2>
      <div className="tabs">
        {MODES.map((m) => (
          <button key={m} className={`tab${sort === m ? " active" : ""}`} onClick={() => onSort(m)}>
            {sortLabel(m)}
          </button>
        ))}
        {dateFilter && <button className="tab" onClick={onClearDate}>✕ all dates</button>}
      </div>
      {offers.length === 0 ? (
        <div className="empty">No offers yet. Press the mic and say “search for flights”, or use the form above.</div>
      ) : (
        <div className="offers">
          {offers.slice(0, 20).map((o, i) => (
            <OfferCard key={o.id} offer={o} position={i + 1} selected={selectedId === o.id} onSelect={() => onSelect(selectedId === o.id ? null : o.id)} />
          ))}
        </div>
      )}
    </section>
  );
}
