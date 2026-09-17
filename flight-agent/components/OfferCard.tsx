"use client";
import { airportLabel } from "@/lib/airports";
import { formatDuration, formatTime, humanDate } from "@/lib/dates";
import { legSummary, money } from "@/lib/format";
import type { Itinerary, RankedOffer } from "@/lib/types";

function Leg({ label, it }: { label: string; it: Itinerary }) {
  return (
    <div className="leg">
      <div className="lbl">{label}</div>
      <div>
        <div>{legSummary(it)}</div>
        <ul className="segments">
          {it.segments.map((s, i) => (
            <li key={s.flightNumber + s.departure}>
              {i > 0 && it.layovers[i - 1] && (
                <div className={it.layovers[i - 1].minutes < 90 || it.layovers[i - 1].minutes > 360 ? "lay" : undefined}>
                  ⏱ {formatDuration(it.layovers[i - 1].minutes)} in {airportLabel(it.layovers[i - 1].airport)}
                  {it.layovers[i - 1].overnight ? " (overnight)" : ""}
                </div>
              )}
              <b>{s.flightNumber}</b> {s.carrierName} · {s.from} {formatTime(s.departure)} → {s.to} {formatTime(s.arrival)}
              {s.arrival.slice(0, 10) !== s.departure.slice(0, 10) ? " (+1)" : ""} · {formatDuration(s.durationMin)}
              {s.aircraft ? ` · ${s.aircraft}` : ""}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export function OfferCard({ offer, position, selected, onSelect }: { offer: RankedOffer; position: number; selected: boolean; onSelect: () => void }) {
  const o = offer;
  return (
    <article className={`offer${selected ? " selected" : ""}`} id={`offer-${position}`}>
      <div className="offer-head">
        <div>
          <span className="rank-num">{position}</span>
          <span className="price">
            {money(o.price.total, o.price.currency)}
            <small>total for the family{o.price.perAdult ? ` · ${money(o.price.perAdult, o.price.currency)}/adult` : ""}</small>
          </span>
        </div>
        <div className="meta">
          {o.validatingCarrierName} · {formatDuration(o.totalDurationMin)} total · {o.stops} stop{o.stops === 1 ? "" : "s"} · {humanDate(o.departureDate)}
          {o.returnDate ? ` → ${humanDate(o.returnDate)}` : ""}
        </div>
      </div>
      <div className="badges">
        {o.badges.map((b) => (
          <span key={b} className="badge">{b}</span>
        ))}
        {o.warnings.map((w) => (
          <span key={w} className="badge warn">{w}</span>
        ))}
        {typeof o.seatsLeft === "number" && o.seatsLeft <= 4 && <span className="badge info">{o.seatsLeft} seats left</span>}
      </div>
      {selected && (
        <div className="legs">
          <Leg label="Out" it={o.outbound} />
          {o.inbound && <Leg label="Back" it={o.inbound} />}
        </div>
      )}
      <div className="offer-actions">
        <button className="btn small" onClick={onSelect}>{selected ? "Hide details" : "Details"}</button>
        {o.bookingUrl && (
          <a className="btn small" href={o.bookingUrl} target="_blank" rel="noreferrer">Check &amp; book ↗</a>
        )}
        <span className="scores">best {o.scores.best} · price {o.scores.cheapest} · speed {o.scores.fastest}</span>
      </div>
    </article>
  );
}
