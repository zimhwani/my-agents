"use client";
import { passengerSummary } from "@/lib/params";
import { humanDate } from "@/lib/dates";
import type { Cabin, SearchParams, TripType } from "@/lib/types";

export function SearchForm({ params, onChange, onSearch, loading, datesToScan }: {
  params: SearchParams;
  onChange: (patch: Partial<SearchParams>) => void;
  onSearch: () => void;
  loading: boolean;
  datesToScan: number;
}) {
  const p = params;
  return (
    <section className="panel">
      <h2>Search</h2>
      <div className="summary-line" style={{ marginBottom: 10 }}>
        {p.origin} → {p.destination} · {p.tripType === "return" ? `return, ${p.stayNights} nights away` : "one way"} · {passengerSummary(p)} · departing {humanDate(p.windowStart)} to {humanDate(p.windowEnd)} · {datesToScan} dates to scan
      </div>
      <form
        className="form"
        onSubmit={(e) => {
          e.preventDefault();
          onSearch();
        }}
      >
        <label className="field">From
          <input value={p.origin} maxLength={3} onChange={(e) => onChange({ origin: e.target.value.toUpperCase() })} />
        </label>
        <label className="field">To
          <input value={p.destination} maxLength={3} onChange={(e) => onChange({ destination: e.target.value.toUpperCase() })} />
        </label>
        <label className="field">Trip
          <select value={p.tripType} onChange={(e) => onChange({ tripType: e.target.value as TripType })}>
            <option value="return">Return</option>
            <option value="oneway">One way</option>
          </select>
        </label>
        <label className="field">Nights away
          <input type="number" min={1} max={90} value={p.stayNights} disabled={p.tripType !== "return"} onChange={(e) => onChange({ stayNights: Number(e.target.value) })} />
        </label>
        <label className="field">Depart from
          <input type="date" value={p.windowStart} onChange={(e) => onChange({ windowStart: e.target.value })} />
        </label>
        <label className="field">Depart until
          <input type="date" value={p.windowEnd} onChange={(e) => onChange({ windowEnd: e.target.value })} />
        </label>
        <label className="field">Check every (days)
          <input type="number" min={1} max={31} value={p.stepDays} onChange={(e) => onChange({ stepDays: Number(e.target.value) })} />
        </label>
        <label className="field">Adults
          <input type="number" min={1} max={9} value={p.adults} onChange={(e) => onChange({ adults: Number(e.target.value) })} />
        </label>
        <label className="field">Children (2–11)
          <input type="number" min={0} max={8} value={p.children} onChange={(e) => onChange({ children: Number(e.target.value) })} />
        </label>
        <label className="field">Infants
          <input type="number" min={0} max={4} value={p.infants} onChange={(e) => onChange({ infants: Number(e.target.value) })} />
        </label>
        <label className="field">Cabin
          <select value={p.cabin} onChange={(e) => onChange({ cabin: e.target.value as Cabin })}>
            <option value="ECONOMY">Economy</option>
            <option value="PREMIUM_ECONOMY">Premium economy</option>
            <option value="BUSINESS">Business</option>
          </select>
        </label>
        <label className="field">Max stops
          <select value={p.maxStops} onChange={(e) => onChange({ maxStops: Number(e.target.value) })}>
            <option value={1}>1</option>
            <option value={2}>2</option>
            <option value={3}>3</option>
          </select>
        </label>
        <div className="form-actions">
          <button className="btn primary" type="submit" disabled={loading}>{loading ? "Scanning…" : "Search flights"}</button>
          <span className="summary-line">Scans one search per sampled date; lower “check every” for finer coverage (more API calls).</span>
        </div>
      </form>
      {loading && <div className="progress"><div style={{ width: "100%", animation: "pulse 1.2s infinite" }} /></div>}
    </section>
  );
}
