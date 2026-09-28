"use client";
import { useEffect, useRef } from "react";
import { AIRPORTS, airportLabel } from "@/lib/airports";
import { dateRange, shortDay } from "@/lib/format";
import { passengerSummary } from "@/lib/params";
import type { Cabin, SearchParams, TripType } from "@/lib/types";
import type { EditField } from "./UnderstoodChips";

const STOPOVER_HUBS = ["CPT", "JNB", "DUR", "VFA", "DXB", "DOH", "AUH", "SIN", "MRU", "ADD", "NBO", "KGL", "WDH"];

function Stepper({ id, value, min, max, onChange, label }: { id: string; value: number; min: number; max: number; onChange: (n: number) => void; label: string }) {
  return (
    <div className="stepper" role="group" aria-label={label}>
      <button type="button" onClick={() => onChange(value - 1)} disabled={value <= min} aria-label={`Fewer ${label.toLowerCase()}`}>−</button>
      <output id={id} aria-live="polite">{value}</output>
      <button type="button" onClick={() => onChange(value + 1)} disabled={value >= max} aria-label={`More ${label.toLowerCase()}`}>+</button>
    </div>
  );
}

/** Collapsed: one editable sentence. Expanded: the full editor, grouped. */
export function TripSettings({ params: p, onChange, onSearch, loading, datesToScan, open, onOpenChange, focus, showLine }: {
  params: SearchParams;
  onChange: (patch: Partial<SearchParams>) => void;
  onSearch: () => void;
  loading: boolean;
  datesToScan: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  focus: EditField | null;
  /** Show the one-line summary (hidden once the understood chips carry it). */
  showLine: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open || !focus) return;
    const el = ref.current?.querySelector<HTMLElement>(`[data-group="${focus}"] input, [data-group="${focus}"] select, [data-group="${focus}"] button`);
    el?.focus();
    ref.current?.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }, [open, focus]);

  const back = p.tripType === "oneway" ? "one way" : p.returnDate ? `back ${shortDay(p.returnDate)}` : `${p.stayNights} nights away`;
  const parts = [
    `${p.origin} → ${p.destination}`,
    p.stopover ? `${p.stopover.nights} nights in ${airportLabel(p.stopover.airport)}${p.stopover.leg === "return" ? " on the way home" : ""}` : null,
    `leave ${p.windowStart === p.windowEnd ? shortDay(p.windowStart) : dateRange(p.windowStart, p.windowEnd)}`,
    back,
    passengerSummary(p),
    p.cabin === "ECONOMY" ? "Economy" : p.cabin === "BUSINESS" ? "Business" : "Premium economy",
    `max ${p.maxStops} stop${p.maxStops === 1 ? "" : "s"}`,
    `checking every ${p.stepDays === 1 ? "day" : `${p.stepDays} days`} (${datesToScan} dates)`,
  ].filter(Boolean) as string[];

  return (
    <section ref={ref} aria-label="Trip settings">
      {(showLine || open) && <div className="tripline">
        <p>
          {parts.map((t, i) => (
            <span key={t}>{i > 0 && <span className="sep">·</span>}{t}</span>
          ))}
        </p>
        <button className="btn small" onClick={() => onOpenChange(!open)} aria-expanded={open}>{open ? "Close" : "Edit"}</button>
      </div>}
      {open && (
        <form className="card editor" onSubmit={(e) => { e.preventDefault(); onSearch(); onOpenChange(false); }}>
          <div className="editor-groups">
            <div className="group" data-group="when">
              <h3>When</h3>
              <div className="seg" role="group" aria-label="Trip type">
                {(["return", "oneway"] as TripType[]).map((t) => (
                  <button key={t} type="button" aria-pressed={p.tripType === t} onClick={() => onChange({ tripType: t })}>{t === "return" ? "Return" : "One way"}</button>
                ))}
              </div>
              <div className="fields">
                <label className="field">Leave from
                  <input id="leave-from" type="date" value={p.windowStart} onChange={(e) => onChange({ windowStart: e.target.value })} />
                </label>
                <label className="field">Leave until
                  <input id="leave-until" type="date" value={p.windowEnd} onChange={(e) => onChange({ windowEnd: e.target.value })} />
                </label>
                <label className="field">Return on
                  <input id="return-on" type="date" value={p.returnDate ?? ""} disabled={p.tripType !== "return"} onChange={(e) => onChange({ returnDate: e.target.value || undefined })} />
                </label>
                <label className="field">or stay in Harare for (nights)
                  <input id="stay-nights" type="number" min={1} max={90} value={p.stayNights} disabled={p.tripType !== "return" || !!p.returnDate} onChange={(e) => onChange({ stayNights: Number(e.target.value) })} />
                </label>
                <label className="field">Check a date every
                  <select id="step-days" value={p.stepDays} onChange={(e) => onChange({ stepDays: Number(e.target.value) })}>
                    {[1, 2, 3, 5, 7, 14].map((d) => <option key={d} value={d}>{d === 1 ? "day" : `${d} days`}</option>)}
                  </select>
                  <span className="hint">More dates = better coverage, more searches.</span>
                </label>
              </div>
            </div>
            <div className="group" data-group="who">
              <h3>Who</h3>
              <div className="fields">
                <div className="field">Adults <Stepper id="adults" label="Adults" value={p.adults} min={1} max={9} onChange={(n) => onChange({ adults: n })} /></div>
                <div className="field">Children, 2–11 <Stepper id="children" label="Children" value={p.children} min={0} max={8} onChange={(n) => onChange({ children: n })} /></div>
                <div className="field">Infants, under 2 (on lap) <Stepper id="infants" label="Infants" value={p.infants} min={0} max={p.adults} onChange={(n) => onChange({ infants: n })} /></div>
              </div>
            </div>
            <div className="group" data-group="stopover">
              <h3>Stopover (multi-city)</h3>
              <div className="fields">
                <label className="field">Break the trip in
                  <select id="stopover-airport" value={p.stopover?.airport ?? ""} onChange={(e) => onChange({ stopover: e.target.value ? { airport: e.target.value, nights: p.stopover?.nights ?? 3, leg: p.stopover?.leg ?? "outbound" } : undefined })}>
                    <option value="">No stopover</option>
                    {STOPOVER_HUBS.map((c) => <option key={c} value={c}>{AIRPORTS[c].city} ({c})</option>)}
                  </select>
                </label>
                <div className="field">Nights there
                  <Stepper id="stopover-nights" label="Nights" value={p.stopover?.nights ?? 3} min={1} max={14} onChange={(n) => p.stopover && onChange({ stopover: { ...p.stopover, nights: n } })} />
                </div>
                <label className="field">When
                  <select id="stopover-leg" value={p.stopover?.leg ?? "outbound"} disabled={!p.stopover || p.tripType !== "return"} onChange={(e) => p.stopover && onChange({ stopover: { ...p.stopover, leg: e.target.value as "outbound" | "return" } })}>
                    <option value="outbound">On the way to Harare</option>
                    <option value="return">On the way home</option>
                  </select>
                </label>
              </div>
            </div>
            <div className="group" data-group="options">
              <h3>Options</h3>
              <div className="fields">
                <label className="field">Cabin
                  <select id="cabin" value={p.cabin} onChange={(e) => onChange({ cabin: e.target.value as Cabin })}>
                    <option value="ECONOMY">Economy</option>
                    <option value="PREMIUM_ECONOMY">Premium economy</option>
                    <option value="BUSINESS">Business</option>
                  </select>
                </label>
                <label className="field">Max stops each way
                  <select id="max-stops" value={p.maxStops} onChange={(e) => onChange({ maxStops: Number(e.target.value) })}>
                    <option value={1}>1</option>
                    <option value={2}>2</option>
                    <option value={3}>3</option>
                  </select>
                </label>
              </div>
            </div>
            <div className="group" data-group="where">
              <h3>Where</h3>
              <div className="fields">
                <label className="field">From
                  <input id="origin" value={p.origin} maxLength={3} onChange={(e) => onChange({ origin: e.target.value.toUpperCase() })} />
                </label>
                <label className="field">To
                  <input id="destination" value={p.destination} maxLength={3} onChange={(e) => onChange({ destination: e.target.value.toUpperCase() })} />
                </label>
              </div>
            </div>
          </div>
          <div className="editor-foot">
            <button className="btn primary" type="submit" disabled={loading}>{loading ? "Checking…" : `Search ${datesToScan} date${datesToScan === 1 ? "" : "s"}`}</button>
            <span className="muted small">Each date is one fare search.</span>
          </div>
        </form>
      )}
    </section>
  );
}
