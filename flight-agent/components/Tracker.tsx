"use client";
import { money } from "@/lib/format";

export interface Snapshot {
  at: string;
  provider: string;
  isSample: boolean;
  window: [string, string];
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
  const recent = [...history].reverse().slice(0, 12);
  return (
    <section className="panel">
      <h2>Price tracking</h2>
      <div className="track-row">
        <button className={`btn${enabled ? "" : " primary"}`} onClick={() => onToggle(!enabled)}>
          {enabled ? "Stop tracking" : "Start tracking"}
        </button>
        <label className="toggle">re-check every
          <select value={intervalHours} onChange={(e) => onInterval(Number(e.target.value))}>
            {[1, 3, 6, 12, 24].map((h) => <option key={h} value={h}>{h}h</option>)}
          </select>
        </label>
        <span className="summary-line">
          {enabled && nextRunAt ? `next check ${new Date(nextRunAt).toLocaleTimeString("en-AU", { hour: "2-digit", minute: "2-digit" })} (while this tab is open)` : "Runs while this tab is open. For always-on tracking use the scan script or the GitHub Action."}
        </span>
        {history.length > 0 && <button className="btn small ghost" onClick={onClear}>clear history</button>}
      </div>
      {recent.length > 0 && (
        <table className="history">
          <thead>
            <tr><th>Checked</th><th>Cheapest</th><th>Change</th><th>Best overall</th><th>Source</th></tr>
          </thead>
          <tbody>
            {recent.map((s, i) => {
              const prev = recent[i + 1];
              const delta = s.cheapest && prev?.cheapest ? s.cheapest.total - prev.cheapest.total : null;
              return (
                <tr key={s.at}>
                  <td>{new Date(s.at).toLocaleString("en-AU", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</td>
                  <td>{s.cheapest ? `${money(s.cheapest.total, s.cheapest.currency)} · ${s.cheapest.carrier} · ${s.cheapest.date}` : "—"}</td>
                  <td className={`delta ${delta === null ? "" : delta < 0 ? "down" : delta > 0 ? "up" : ""}`}>
                    {delta === null ? "" : delta === 0 ? "no change" : `${delta < 0 ? "▼" : "▲"} ${money(Math.abs(delta), s.cheapest!.currency)}`}
                  </td>
                  <td>{s.best ? `${money(s.best.total, s.best.currency)} · ${s.best.carrier} · ${s.best.date}` : "—"}</td>
                  <td>{s.isSample ? "sample" : s.provider}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </section>
  );
}
