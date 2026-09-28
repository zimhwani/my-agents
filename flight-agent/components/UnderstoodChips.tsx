"use client";
import { airportLabel } from "@/lib/airports";
import { dateRange, shortDay } from "@/lib/format";
import { passengerSummary } from "@/lib/params";
import type { SearchParams } from "@/lib/types";

export type EditField = "where" | "when" | "who" | "options" | "stopover";

/** One chip per slot the agent is using, so a misheard date is visible and one tap from fixing. */
export function UnderstoodChips({ params: p, datesCount, returnInferred, onEdit }: {
  params: SearchParams;
  datesCount: number;
  returnInferred: boolean;
  onEdit: (field: EditField) => void;
}) {
  const chips: { k: string; v: string; field: EditField; inferred?: boolean }[] = [
    { k: "Route", v: `${p.origin} → ${p.destination}`, field: "where" },
    { k: "Leave", v: p.windowStart === p.windowEnd ? shortDay(p.windowStart) : dateRange(p.windowStart, p.windowEnd), field: "when" },
  ];
  if (p.tripType === "oneway") chips.push({ k: "Trip", v: "One way", field: "when" });
  else if (p.returnDate) chips.push({ k: "Back", v: shortDay(p.returnDate), field: "when", inferred: returnInferred });
  else chips.push({ k: "Stay", v: `${p.stayNights} nights`, field: "when" });
  if (p.stopover) chips.push({ k: p.stopover.leg === "return" ? "Stopover home" : "Stopover", v: `${airportLabel(p.stopover.airport)} · ${p.stopover.nights} nights`, field: "stopover" });
  chips.push({ k: "Travellers", v: passengerSummary(p), field: "who" });
  chips.push({ k: "Cabin", v: p.cabin === "PREMIUM_ECONOMY" ? "Premium economy" : p.cabin === "BUSINESS" ? "Business" : "Economy", field: "options" });
  chips.push({ k: "Checking", v: `${datesCount} date${datesCount === 1 ? "" : "s"}`, field: "when" });
  return (
    <div className="understood" aria-label="What I understood">
      {chips.map((c) => (
        <button
          key={c.k}
          className={`uchip${c.inferred ? " inferred" : ""}`}
          onClick={() => onEdit(c.field)}
          title={c.inferred ? "I picked this. Tap to change." : `Change ${c.k.toLowerCase()}`}
        >
          <span className="k">{c.k}</span>
          <span className="v">{c.v}</span>
        </button>
      ))}
      <button className="uchip edit" onClick={() => onEdit("when")}>Edit trip</button>
    </div>
  );
}
