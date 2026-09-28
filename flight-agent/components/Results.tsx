"use client";
import { shortDay } from "@/lib/format";
import type { RankedOffer, SortMode } from "@/lib/types";
import { CloseIcon } from "./Icons";
import { OfferCard } from "./OfferCard";

const MODES: { mode: SortMode; label: string }[] = [
  { mode: "best", label: "Best overall" },
  { mode: "cheapest", label: "Cheapest" },
  { mode: "fastest", label: "Fastest" },
];

export function Results({ offers, sort, onSort, selectedId, onSelect, dateFilter, onClearDate, isSample, hasSearched }: {
  offers: RankedOffer[];
  sort: SortMode;
  onSort: (m: SortMode) => void;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  dateFilter: string | null;
  onClearDate: () => void;
  isSample: boolean;
  hasSearched: boolean;
}) {
  return (
    <section id="results" aria-label="Flights">
      <div className="results-head">
        <h2>Flights</h2>
        <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
          {dateFilter && (
            <button className="filter-chip" onClick={onClearDate}>Leaving {shortDay(dateFilter)} <CloseIcon size={14} /></button>
          )}
          <div className="seg" role="group" aria-label="Sort flights">
            {MODES.map(({ mode, label }) => (
              <button key={mode} aria-pressed={sort === mode} onClick={() => onSort(mode)}>{label}</button>
            ))}
          </div>
        </div>
      </div>
      {offers.length === 0 ? (
        <div className="card empty">
          {hasSearched ? "No flights matched. Try a wider window, more stops, or no stopover." : "Ask me something like “flights mid to late November, back early January”."}
        </div>
      ) : (
        <div className="offers">
          {offers.slice(0, 20).map((o, i) => (
            <OfferCard key={o.id} offer={o} position={i + 1} selected={selectedId === o.id} onSelect={() => onSelect(selectedId === o.id ? null : o.id)} isSample={isSample} />
          ))}
        </div>
      )}
    </section>
  );
}

export function ResultsSkeleton() {
  return (
    <div aria-hidden style={{ display: "grid", gap: 12 }}>
      <div className="summary">
        {[0, 1, 2].map((i) => <div key={i} className="sk" style={{ height: 104 }} />)}
      </div>
      {[0, 1, 2].map((i) => <div key={i} className="sk" style={{ height: 150, borderRadius: 16 }} />)}
    </div>
  );
}
