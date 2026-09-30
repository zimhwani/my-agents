import { formatKg, formatMoney } from "../../core/pricing.ts";
import { formatMeterId, formatPhone } from "../../core/service.ts";
import type { AlertKind, RefillOrder } from "../../core/types.ts";
import { timeAgo, useSandbox } from "../ui.tsx";

const ALERT_LABEL: Record<AlertKind, string> = {
  leak: "Gas leak",
  low_gas: "Cylinder low",
  low_credit: "Credit low",
  tamper: "Tamper",
  offline: "Offline",
  low_battery: "Battery low",
};

const NEXT: Partial<Record<RefillOrder["status"], [RefillOrder["status"], string]>> = {
  requested: ["scheduled", "Schedule"],
  scheduled: ["out_for_delivery", "Dispatch"],
  out_for_delivery: ["delivered", "Mark delivered"],
};

/** The back office: fleet health, safety alerts, the refill queue and the payments ledger. */
export function Ops() {
  const sb = useSandbox();
  const d = sb.p.data;
  const meters = Object.values(d.meters);
  const payments = Object.values(d.payments).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  const paid = payments.filter((p) => p.status === "paid");
  const today = new Date().toISOString().slice(0, 10);
  const paidToday = paid.filter((p) => p.createdAt.startsWith(today));
  const alerts = Object.values(d.alerts).filter((a) => !a.resolved);
  const refills = Object.values(d.refills).filter((r) => r.status !== "delivered" && r.status !== "cancelled");
  const owner = (id: string | null) => (id ? d.customers[id]?.name ?? "" : "");

  const kpis = [
    ["Meters installed", meters.filter((m) => m.customerId).length],
    ["Online now", `${meters.filter((m) => m.online).length}/${meters.length}`],
    ["Sold today", formatKg(paidToday.reduce((s, p) => s + p.grams, 0))],
    ["Revenue today (USD)", formatMoney(paidToday.reduce((s, p) => s + p.amountUsd, 0), "USD")],
    ["Open alerts", alerts.length],
    ["Refills in queue", refills.length],
  ] as const;

  return (
    <div className="ops">
      <div className="row between" style={{ flexWrap: "wrap" }}>
        <h1 style={{ fontSize: 24 }}>Operations console</h1>
        <span className="muted">Live from the sandbox · updates every second</span>
      </div>
      <div className="kpis">
        {kpis.map(([k, v]) => (
          <div className="kpi" key={k}>
            <b>{v}</b>
            <span>{k}</span>
          </div>
        ))}
      </div>

      <div className="grid2">
        <section className="stack">
          <h2>Safety and alerts</h2>
          <div className="tbl-wrap">
            <table>
              <thead>
                <tr>
                  <th>Alert</th>
                  <th>Meter</th>
                  <th>Since</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {alerts.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted">
                      All clear
                    </td>
                  </tr>
                )}
                {alerts.map((a) => (
                  <tr key={a.id}>
                    <td>
                      <span className={`pill ${a.kind === "leak" || a.kind === "tamper" ? "bad" : "warn"}`}>{ALERT_LABEL[a.kind]}</span>
                    </td>
                    <td className="num">
                      {formatMeterId(a.meterId)}
                      <div className="muted">{d.meters[a.meterId]?.suburb}</div>
                    </td>
                    <td>{timeAgo(a.at)}</td>
                    <td>
                      {a.kind === "leak" && (
                        <button className="btn sm dark" onClick={() => sb.svc.clearLeak(a.meterId).then(() => sb.deviceAction(a.meterId, () => {}))}>
                          Clear leak
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="stack">
          <h2>Refill queue</h2>
          <div className="tbl-wrap">
            <table>
              <thead>
                <tr>
                  <th>Meter</th>
                  <th>Slot</th>
                  <th>Status</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {refills.length === 0 && (
                  <tr>
                    <td colSpan={4} className="muted">
                      No open orders
                    </td>
                  </tr>
                )}
                {refills.map((r) => {
                  const next = NEXT[r.status];
                  return (
                    <tr key={r.id}>
                      <td className="num">
                        {formatMeterId(r.meterId)}
                        <div className="muted">
                          {owner(d.meters[r.meterId]?.customerId ?? null)} {r.auto && "· auto"}
                        </div>
                      </td>
                      <td style={{ whiteSpace: "normal", maxWidth: 180 }}>{r.slot}</td>
                      <td>{r.status.replace(/_/g, " ")}</td>
                      <td>
                        {next && (
                          <button
                            className="btn sm dark"
                            onClick={async () => {
                              await sb.svc.moveRefill(r, next[0]);
                              if (next[0] === "delivered") await sb.deviceAction(r.meterId, (dv) => dv.refill(d.meters[r.meterId].cylinderKg));
                            }}
                          >
                            {next[1]}
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>
      </div>

      <section className="stack">
        <h2>Fleet</h2>
        <div className="tbl-wrap">
          <table>
            <thead>
              <tr>
                <th>Meter</th>
                <th>Customer</th>
                <th>Credit</th>
                <th>Cylinder</th>
                <th>Valve</th>
                <th>Network</th>
                <th>Battery</th>
                <th>Token ctr</th>
              </tr>
            </thead>
            <tbody>
              {meters.map((m) => {
                const pct = Math.round((m.gasGrams / (m.cylinderKg * 1000)) * 100);
                return (
                  <tr key={m.id}>
                    <td className="num">
                      {formatMeterId(m.id)}
                      <div className="muted">{m.suburb}</div>
                    </td>
                    <td>{owner(m.customerId) || <span className="muted">unassigned</span>}</td>
                    <td className="num">{formatKg(m.creditGrams)}</td>
                    <td>
                      <div className="bar" style={{ width: 90 }}>
                        <i style={{ width: `${pct}%`, background: pct < 15 ? "var(--alert)" : pct < 30 ? "var(--maize)" : undefined }} />
                      </div>
                      <span className="muted">
                        {pct}% of {m.cylinderKg} kg
                      </span>
                    </td>
                    <td>{m.leak ? <span className="pill bad">locked</span> : <span className={`pill ${m.valve === "open" ? "on" : "off"}`}>{m.valve}</span>}</td>
                    <td>{m.online ? timeAgo(m.lastSeen) : <span className="pill warn">offline</span>}</td>
                    <td>{m.batteryPct}%</td>
                    <td className="num">{m.tokenCounter}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section className="stack">
        <h2>Payments ledger</h2>
        <div className="tbl-wrap">
          <table>
            <thead>
              <tr>
                <th>Ref</th>
                <th>When</th>
                <th>Payer</th>
                <th>Meter</th>
                <th>Method</th>
                <th>Amount</th>
                <th>Gas</th>
                <th>Status</th>
                <th>Delivery</th>
              </tr>
            </thead>
            <tbody>
              {payments.length === 0 && (
                <tr>
                  <td colSpan={9} className="muted">
                    No payments yet. Buy gas in the app or on WhatsApp.
                  </td>
                </tr>
              )}
              {payments.slice(0, 50).map((p) => (
                <tr key={p.id}>
                  <td className="num">{p.reference}</td>
                  <td>{timeAgo(p.createdAt)}</td>
                  <td>
                    {p.payerName || formatPhone(p.payerPhone)} {p.gift && "🎁"}
                    <div className="muted">{p.channel}</div>
                  </td>
                  <td className="num">{formatMeterId(p.meterId)}</td>
                  <td>{p.method}</td>
                  <td className="num">{formatMoney(p.amount, p.currency)}</td>
                  <td className="num">{formatKg(p.grams)}</td>
                  <td>
                    <span className={`pill ${p.status === "paid" ? "on" : p.status === "pending" ? "warn" : "off"}`}>{p.status}</span>
                  </td>
                  <td>{p.delivery ?? "–"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
