import { useEffect, useRef, useState } from "react";
import { formatKg } from "../../core/pricing.ts";
import { formatMeterId } from "../../core/service.ts";
import { DEMO_METER } from "../sandbox/index.ts";
import { useSandbox } from "../ui.tsx";

/**
 * The valve as the ESP32 sees it: LCD, LEDs, token keypad, and the switches a tester flips to make
 * things happen (light the stove, cause a leak, lose network, swap the cylinder). The serial log
 * shows what the firmware would print.
 */
export function MeterSim({ meterId: fixed }: { meterId?: string }) {
  const sb = useSandbox();
  const [meterId, setMeterId] = useState(fixed ?? DEMO_METER);
  const [entry, setEntry] = useState("");
  const [flash, setFlash] = useState<string | null>(null);
  const serial = useRef<HTMLDivElement>(null);
  const dev = sb.device(meterId);
  const meter = sb.p.data.meters[meterId];
  const logs = sb.logs(meterId);

  useEffect(() => {
    serial.current?.scrollTo({ top: serial.current.scrollHeight });
  }, [logs.length]);
  if (!dev || !meter) return null;
  const s = dev.s;
  const act = (fn: Parameters<typeof sb.deviceAction>[1]) => void sb.deviceAction(meterId, fn);

  const key = (k: string) => {
    if (k === "⌫") return setEntry((e) => e.slice(0, -1));
    if (k === "OK") {
      const token = entry;
      setEntry("");
      act(async (d) => {
        const r = await d.enterToken(token);
        setFlash(r.ok ? `+${formatKg(r.grams!)} OK` : r.reason === "locked" ? "LOCKED" : "BAD TOKEN");
        setTimeout(() => setFlash(null), 2500);
      });
      return;
    }
    setEntry((e) => (e.length < 12 ? e + k : e));
  };

  const cylPct = Math.max(0, (s.gasGrams / (meter.cylinderKg * 1000)) * 100);

  return (
    <div className="device">
      <div className="row between" style={{ marginBottom: 10 }}>
        <b style={{ fontFamily: "var(--display)" }}>Smart valve · ESP32</b>
        <span style={{ fontSize: 12, opacity: 0.7 }}>fw 0.1.0</span>
      </div>
      {!fixed && (
        <select value={meterId} onChange={(e) => setMeterId(e.target.value)} aria-label="Meter">
          {Object.values(sb.p.data.meters).map((m) => (
            <option key={m.id} value={m.id}>
              {formatMeterId(m.id)} · {m.suburb}
            </option>
          ))}
        </select>
      )}

      <div className="cyl" style={{ marginTop: 12 }}>
        <svg width="70" height="110" viewBox="0 0 70 110" aria-hidden>
          <rect x="27" y="2" width="16" height="10" rx="2" fill={s.valve === "open" ? "#3ddc84" : "#ff4d4d"} />
          <rect x="6" y="12" width="58" height="94" rx="22" fill="#2b3552" stroke="#4a5677" />
          <clipPath id="cl">
            <rect x="6" y="12" width="58" height="94" rx="22" />
          </clipPath>
          <rect x="6" y={12 + 94 * (1 - cylPct / 100)} width="58" height={94 * (cylPct / 100)} fill="#ff6b1a" opacity=".85" clipPath="url(#cl)" />
          {s.burnerOn && s.valve === "open" && (
            <text x="35" y="68" textAnchor="middle" fontSize="22">
              🔥
            </text>
          )}
        </svg>
        <div className="lcd" style={{ flex: 1, margin: 0 }}>
          <div style={{ fontSize: 11 }}>{formatMeterId(meterId)}</div>
          <div className="big">{flash ?? (entry ? entry.replace(/(\d{4})(?=\d)/g, "$1 ") : formatKg(s.creditGrams))}</div>
          <div style={{ fontSize: 11 }}>
            {entry ? "TOKEN" : "CREDIT"} · CYL {formatKg(s.gasGrams)} · VALVE {s.valve.toUpperCase()}
          </div>
        </div>
      </div>

      <div className="leds" style={{ marginTop: 12 }}>
        <span className="led">
          <i className={s.online ? "g" : ""} /> NET
        </span>
        <span className="led">
          <i className={s.valve === "open" ? "g" : ""} /> GAS
        </span>
        <span className="led">
          <i className={s.leak ? "r" : ""} /> LEAK
        </span>
        <span className="led">
          <i className={s.batteryPct < 20 ? "y" : "g"} /> {Math.round(s.batteryPct)}%
        </span>
      </div>

      <div className="keypad">
        {["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"].map((k) => (
          <button key={k} className={k === "OK" ? "ok" : k === "⌫" ? "del" : ""} onClick={() => key(k)}>
            {k}
          </button>
        ))}
      </div>

      <div className="dev-acts">
        <button className={s.burnerOn ? "on" : ""} onClick={() => act((d) => d.setBurner(!d.s.burnerOn))}>
          {s.burnerOn ? "🔥 Stove on" : "Light the stove"}
        </button>
        <button className={s.online ? "" : "on"} onClick={() => act((d) => d.setOnline(!d.s.online))}>
          {s.online ? "Lose network" : "📵 Offline"}
        </button>
        <button className={s.leak ? "on" : ""} onClick={() => act((d) => d.setLeak(!d.s.leak))}>
          {s.leak ? "⚠️ Leaking" : "Simulate leak"}
        </button>
        <button onClick={() => act((d) => d.refill(meter.cylinderKg))}>Swap in full cylinder</button>
      </div>

      <div className="serial" ref={serial} aria-label="Serial log">
        {logs.length === 0 && <div style={{ opacity: 0.6 }}>Waiting for events… light the stove or buy gas.</div>}
        {logs.map((l, i) => (
          <div key={i}>
            <span style={{ opacity: 0.5 }}>{String(Math.floor(l.at)).padStart(5, "0")}m </span>
            <span className="tag">[{l.tag}]</span> {l.text}
          </div>
        ))}
      </div>
      <details style={{ marginTop: 10, fontSize: 12 }}>
        <summary style={{ cursor: "pointer" }}>MQTT telemetry payload (gg/{meterId}/telemetry)</summary>
        <pre style={{ whiteSpace: "pre-wrap", fontFamily: "var(--mono)", fontSize: 11 }}>{JSON.stringify(dev.telemetry(new Date().toISOString()), null, 1)}</pre>
      </details>
    </div>
  );
}
