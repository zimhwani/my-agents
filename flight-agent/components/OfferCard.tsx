"use client";
import { airportLabel } from "@/lib/airports";
import { formatDuration, formatTime } from "@/lib/dates";
import { dayOffset, money, shortDay } from "@/lib/format";
import type { Itinerary, RankedOffer } from "@/lib/types";
import { ClockIcon, ExternalIcon } from "./Icons";
import { Price } from "./SummaryStrip";

function carriersOf(it: Itinerary): string {
  return [...new Set(it.segments.map((s) => s.carrierName))].join(" + ");
}

function RouteLine({ it }: { it: Itinerary }) {
  const first = it.segments[0];
  const last = it.segments[it.segments.length - 1];
  const plus = dayOffset(it);
  return (
    <div className="route">
      <div className="end">
        <span className="time">{formatTime(first.departure)}</span>
        <span className="apt">{first.from}</span>
      </div>
      <div className="mid">
        <span className="vias">{it.layovers.map((l) => l.airport).join(" · ") || "Nonstop"}</span>
        <span className="line">
          {it.layovers.map((l, i) => <i key={i} className={l.stopover ? "so" : l.sameFlight ? "same" : undefined} />)}
        </span>
        <span className="dur">{formatDuration(it.durationMin)} travelling</span>
      </div>
      <div className="end right">
        <span className="time">{formatTime(last.arrival)}{plus > 0 && <sup>+{plus}</sup>}</span>
        <span className="apt">{last.to}</span>
      </div>
    </div>
  );
}

function Timeline({ it, title }: { it: Itinerary; title: string }) {
  return (
    <div>
      <div className="tl-title">{title}</div>
      <ol className="tl">
        {it.segments.map((s, i) => {
          const lay = it.layovers[i];
          const warn = lay && !lay.sameFlight && !lay.stopover && (lay.minutes < 90 || lay.minutes > 360 || lay.overnight);
          return (
            <li key={s.flightNumber + s.departure}>
              <div className="node"><span className="t">{formatTime(s.departure)}</span>{airportLabel(s.from)} <span className="muted">{s.departure.slice(0, 10) !== it.segments[0].departure.slice(0, 10) ? shortDay(s.departure.slice(0, 10)) : ""}</span></div>
              <div className="flight"><span className="mono">{s.flightNumber}</span> · {s.carrierName}{s.aircraft ? ` · ${s.aircraft}` : ""} · {formatDuration(s.durationMin)}</div>
              <div className="node"><span className="t">{formatTime(s.arrival)}</span>{airportLabel(s.to)}</div>
              {lay && (
                <div className={`lay${lay.stopover ? " so" : warn ? " warn" : ""}`}>
                  {lay.stopover
                    ? `Stopover in ${airportLabel(lay.airport)}: ${Math.round(lay.minutes / 1440)} days to explore`
                    : lay.sameFlight
                      ? `Stops in ${airportLabel(lay.airport)} · stay on board`
                      : `${formatDuration(lay.minutes)} in ${airportLabel(lay.airport)}${lay.overnight ? " · overnight" : ""}`}
                </div>
              )}
            </li>
          );
        })}
      </ol>
    </div>
  );
}

export function OfferCard({ offer: o, position, selected, onSelect, isSample }: { offer: RankedOffer; position: number; selected: boolean; onSelect: () => void; isSample: boolean }) {
  const primary = o.badges.find((b) => b !== "Family-friendly times") ?? o.badges[0];
  const family = o.badges.includes("Family-friendly times");
  const travellers = o.price.perAdult ? ` · ${money(o.price.perAdult, o.price.currency)}/adult` : "";
  return (
    <article className={`offer${selected ? " selected" : ""}`} id={`offer-${position}`}>
      <div className="offer-top">
        <div className="offer-price">
          <span className="rank">{position}</span>
          <Price value={o.price.total} currency={o.price.currency} />
          <span className="per">for the family{travellers}</span>
        </div>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", justifyContent: "flex-end" }}>
          {primary && <span className="badge">{primary}</span>}
          {family && <span className="badge good">Family-friendly</span>}
          {isSample && <span className="badge sample">Sample</span>}
        </div>
      </div>

      {o.legs && o.legs.length > 1 ? (
        o.legs.map((it, i) => (
          <div className="leg-row" key={i}>
            <div className="leg-label"><b>{shortDay(it.segments[0].departure.slice(0, 10))}</b><span>Flight {i + 1} · {carriersOf(it)}</span></div>
            <RouteLine it={it} />
          </div>
        ))
      ) : (
        <div className="leg-row">
          <div className="leg-label"><b>{shortDay(o.departureDate)}</b><span>{o.validatingCarrierName}</span></div>
          <RouteLine it={o.outbound} />
        </div>
      )}
      {o.legs && o.legs.length > 1 ? null : o.laterLegs?.length ? (
        <div className="later">
          Then {o.laterLegs.map((l) => `${airportLabel(l.from)} → ${airportLabel(l.to)} on ${shortDay(l.date)}`).join(", then ")}. Those flights are picked when you book.
        </div>
      ) : o.inbound ? (
        <div className="leg-row">
          <div className="leg-label"><b>Back {shortDay(o.returnDate!)}</b></div>
          <RouteLine it={o.inbound} />
        </div>
      ) : o.returnDate ? (
        <div className="later">Back {shortDay(o.returnDate)}. The price covers the round trip; the return flight is picked when you book.</div>
      ) : null}

      {o.warnings.length > 0 && (
        <div className="headsup">
          {o.warnings.slice(0, 2).map((w) => <span key={w}><ClockIcon /> {w}</span>)}
          {o.warnings.length > 2 && <span className="muted">+{o.warnings.length - 2} more in details</span>}
        </div>
      )}

      {selected && (
        <div className="timeline">
          {o.legs && o.legs.length > 1
            ? o.legs.map((it, i) => <Timeline key={i} it={it} title={`Flight ${i + 1}: ${airportLabel(it.segments[0].from)} to ${airportLabel(it.segments.at(-1)!.to)}, ${shortDay(it.segments[0].departure.slice(0, 10))}`} />)
            : <Timeline it={o.outbound} title={`To ${airportLabel(o.outbound.segments.at(-1)!.to)}`} />}
          {!o.legs && o.inbound && <Timeline it={o.inbound} title={`Home to ${airportLabel(o.inbound.segments.at(-1)!.to)}`} />}
          {o.warnings.length > 2 && <div className="headsup">{o.warnings.slice(2).map((w) => <span key={w}><ClockIcon /> {w}</span>)}</div>}
          <div className="why">Why it ranks here: overall {o.scores.best} · price {o.scores.cheapest} · speed {o.scores.fastest}</div>
        </div>
      )}

      <div className="offer-actions">
        <div className="left">
          <button className="btn small" onClick={onSelect} aria-expanded={selected}>{selected ? "Hide details" : "Details"}</button>
        </div>
        {o.bookingUrl && (
          <a className="btn small" href={o.bookingUrl} target="_blank" rel="noreferrer">Check &amp; book <ExternalIcon /></a>
        )}
      </div>
    </article>
  );
}
