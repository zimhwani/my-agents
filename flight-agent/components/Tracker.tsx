"use client";
import { money } from "@/lib/format";

export interface Snapshot {
  at: string;
  provider: string;
  isSample: boolean;
  window: [string, string];
  /** Identifies the exact trip searched, so only like-for-like searches are compared. */
  key?: string;
  cheapest: { total: number; currency: string; date: string; carrier: string } | null;
  best: { total: number; currency: string; date: string; carrier: string } | null;
}

export function Tracker({ enabled, intervalHours, nextRunAt, history, onToggle, onInterval, onClear }: {
  enabled: boolean;
  intervalHours: number;
  nextRunAt: number | null;
  history: Snapshot[];
  onToggle: (on: boolean) => void;
  onInterval: (h: number) => void;
  onClear: () => void;
}) {
  const recent = [...history].reverse().slice(0, 8);
  return (
    <section className="rail-card" aria-label="Price tracking">
      <div className="head">
        <h2>Price tracking</h2>
        <button className="switch" role="switch" aria-checked={enabled} aria-label="Track prices" onClick={() => onToggle(!enabled)} />
      </div>
      <label className="field">Re-check every
        <select id="track-interval" value={intervalHours} onChange={(e) => onInterval(Number(e.target.value))}>
          {[1, 3, 6, 12, 24].map((h) => <option key={h} value={h}>{h === 24 ? "day" : `${h} hours`}</option>)}
        </select>
      </label>
      <p className="muted small" style={{ margin: 0 }}>
        {enabled && nextRunAt
          ? `Next check ${new Date(nextRunAt).toLocaleTimeString("en-AU", { hour: "2-digit", minute: "2-digit" })}. Keep this tab open.`
          : "I’ll re-check while this tab is open and tell you when the cheapest fare drops."}
      </p>
      {recent.length > 0 && (
        <>
          <ul className="hist">
            {recent.map((s, i) => {
              const prev = recent.slice(i + 1).find((x) => (x.key ?? x.window.join()) === (s.key ?? s.window.join()));
              const delta = s.cheapest && prev?.cheapest ? s.cheapest.total - prev.cheapest.total : null;
              return (
                <li key={s.at}>
                  <div className="row1">
                    <span className="muted">{new Date(s.at).toLocaleString("en-AU", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}{s.isSample ? " · sample" : ""}</span>
                    <span className={`num delta ${delta === null ? "" : delta < 0 ? "down" : delta > 0 ? "up" : ""}`}>
                      {delta === null || delta === 0 ? "" : `${delta < 0 ? "▼" : "▲"} ${money(Math.abs(delta), s.cheapest!.currency)}`}
                    </span>
                  </div>
                  <span className="num">{s.cheapest ? `${money(s.cheapest.total, s.cheapest.currency)} · ${s.cheapest.carrier}` : "No fares"}</span>
                </li>
              );
            })}
          </ul>
          <button className="btn link small" onClick={onClear} style={{ justifySelf: "start" }}>Clear history</button>
        </>
      )}
    </section>
  );
}

export function ScanNotes({ notes }: { notes: string[] }) {
  if (!notes.length) return null;
  return (
    <section className="rail-card">
      <details className="notes">
        <summary>Scan notes ({notes.length})</summary>
        <ul>{notes.map((n) => <li key={n}>{n}</li>)}</ul>
      </details>
    </section>
  );
}
