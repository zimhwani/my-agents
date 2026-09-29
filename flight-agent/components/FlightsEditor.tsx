"use client";
import { useEffect, useState } from "react";
import { AIRPORTS, airportLabel, resolveAirport } from "@/lib/airports";
import { addDays, daysBetween } from "@/lib/dates";
import type { RouteLeg, SearchParams } from "@/lib/types";
import { TrashIcon } from "./Icons";

const MAX_FLIGHTS = 6;

function label(code: string): string {
  const a = AIRPORTS[code];
  return a ? `${a.city} (${code})` : code;
}

/** Free text with suggestions: "Joburg", "cpt" or "Cape Town (CPT)" all work. */
function AirportInput({ id, value, onPick, placeholder }: { id: string; value: string; onPick: (code: string) => void; placeholder: string }) {
  const [text, setText] = useState(label(value));
  useEffect(() => setText(label(value)), [value]);
  return (
    <input
      id={id}
      list="airport-options"
      value={text}
      placeholder={placeholder}
      autoComplete="off"
      onFocus={(e) => e.target.select()}
      onChange={(e) => {
        setText(e.target.value);
        const code = resolveAirport(e.target.value);
        if (code && (AIRPORTS[code] || /\(\w{3}\)$/.test(e.target.value) || e.target.value.length === 3)) onPick(code);
      }}
      onBlur={() => setText(label(value))}
    />
  );
}

/** Multi-city: one row per flight (From, To, Depart), like the airline sites. */
export function FlightsEditor({ params: p, onChange }: { params: SearchParams; onChange: (patch: Partial<SearchParams>) => void }) {
  const route = p.route ?? [];
  const dates = route.map((l) => addDays(p.windowStart, l.offset));
  const exact = p.windowStart === p.windowEnd;

  // Rebuild offsets from absolute dates so moving one flight never drags the others.
  const commit = (legs: { from: string; to: string; date: string }[]) => {
    const first = legs[0].date;
    const next: RouteLeg[] = legs.map((l) => ({ from: l.from, to: l.to, offset: Math.max(0, daysBetween(first, l.date)) }));
    const windowEnd = exact || p.windowEnd < first ? first : p.windowEnd;
    onChange({ tripType: "multicity", route: next, windowStart: first, windowEnd });
  };
  const legs = route.map((l, i) => ({ from: l.from, to: l.to, date: dates[i] }));
  // Changing where a flight lands also moves the next departure, when it was chained.
  const set = (i: number, patch: Partial<{ from: string; to: string; date: string }>) =>
    commit(legs.map((l, k) => (k === i ? { ...l, ...patch } : k === i + 1 && patch.to && l.from === legs[i].to ? { ...l, from: patch.to } : l)));

  return (
    <div className="flights">
      <datalist id="airport-options">
        {Object.values(AIRPORTS).map((a) => <option key={a.code} value={`${a.city} (${a.code})`} />)}
      </datalist>
      <ol className="flight-rows">
        {legs.map((l, i) => (
          <li key={i} className="flight-row">
            <span className="flight-no" aria-hidden="true">{i + 1}</span>
            <label className="field">From
              <AirportInput id={`flight-${i}-from`} value={l.from} placeholder="City or airport" onPick={(c) => set(i, { from: c })} />
            </label>
            <label className="field">To
              <AirportInput id={`flight-${i}-to`} value={l.to} placeholder="City or airport" onPick={(c) => set(i, { to: c })} />
            </label>
            <label className="field">Depart
              <input
                id={`flight-${i}-date`}
                type="date"
                value={l.date}
                min={i > 0 ? legs[i - 1].date : undefined}
                onChange={(e) => e.target.value && set(i, { date: e.target.value })}
              />
            </label>
            <button
              type="button"
              className="icon-btn trash"
              aria-label={`Remove flight ${i + 1}, ${airportLabel(l.from)} to ${airportLabel(l.to)}`}
              disabled={legs.length <= 2}
              onClick={() => commit(legs.filter((_, k) => k !== i))}
            >
              <TrashIcon />
            </button>
          </li>
        ))}
      </ol>
      <div className="flight-actions">
        <button
          type="button"
          className="btn small"
          disabled={legs.length >= MAX_FLIGHTS}
          onClick={() => {
            const last = legs[legs.length - 1];
            const home = legs[0].from;
            commit([...legs, { from: last.to, to: last.to === home ? p.destination : home, date: addDays(last.date, 3) }]);
          }}
        >
          + Add another flight
        </button>
        <label className="field inline">
          <input
            id="flex-first"
            type="checkbox"
            checked={!exact}
            onChange={(e) => onChange({ windowEnd: e.target.checked ? addDays(p.windowStart, 14) : p.windowStart })}
          />
          Also try later start dates
        </label>
        {!exact && (
          <label className="field inline">up to
            <input id="flex-until" type="date" value={p.windowEnd} min={p.windowStart} onChange={(e) => e.target.value && onChange({ windowEnd: e.target.value })} />
          </label>
        )}
      </div>
      {!exact && <p className="hint">Every flight moves together, keeping the same gaps between them.</p>}
    </div>
  );
}

/** A starting route when someone switches to multi-city: there and back, ready to add cities. */
export function seedRoute(p: SearchParams): RouteLeg[] {
  return p.route ?? [
    { from: p.origin, to: p.destination, offset: 0 },
    { from: p.destination, to: p.origin, offset: p.stayNights },
  ];
}
