import { useEffect, useRef, useState } from "react";
import { formatKg } from "../../core/pricing.ts";
import { formatMeterId } from "../../core/service.ts";
import { DEMO_METER } from "../sandbox/index.ts";
import { useSandbox } from "../sandbox/useSandbox.ts";
import { Icon, Mark } from "../ui.tsx";

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
    <div className="device-col">
      <div className="device">
        <div className="device-head">
          <b>
            <Mark size={20} /> Smart valve
          </b>
          <span>ESP32 · fw 0.1.0</span>
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

        <div className="cyl">
          <svg width="64" height="112" viewBox="0 0 64 112" aria-hidden>
            <rect x="22" y="2" width="20" height="12" rx="2" fill={s.valve === "open" ? "#1f9d57" : "#d0271f"} />
            <rect x="26" y="5" width="12" height="4" rx="2" fill="#dedad0" />
            <clipPath id="cl">
              <rect x="6" y="14" width="52" height="90" rx="18" />
            </clipPath>
            <rect x="6" y="14" width="52" height="90" rx="18" fill="#f7f5f0" />
            <rect x="6" y={14 + 90 * (1 - cylPct / 100)} width="52" height={90 * (cylPct / 100)} fill="#ff6b1a" clipPath="url(#cl)" />
            <rect x="6" y="14" width="52" height="90" rx="18" fill="none" stroke="#16140f" strokeWidth="2" />
            <rect x="14" y="104" width="36" height="6" rx="1.5" fill="#16140f" />
            {s.burnerOn && s.valve === "open" && <path d="M32 44c1.6 5 8 8 8 15a8 8 0 0 1-16 0c0-4 2.2-6.2 4.2-8.3.5 2.7 1.7 4 3.3 4.5-1-4.4 0-8.2.5-11.2z" fill="#16140f" />}
          </svg>
          <div className="lcd">
            <small>{formatMeterId(meterId)}</small>
            <div className="big">{flash ?? (entry ? entry.replace(/(\d{4})(?=\d)/g, "$1 ") : formatKg(s.creditGrams))}</div>
            <small>
              {entry ? "TOKEN" : "CREDIT"} · CYL {formatKg(s.gasGrams)} · {s.valve.toUpperCase()}
            </small>
          </div>
        </div>

        <div className="leds">
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
            <button key={k} className={k === "OK" ? "ok" : k === "⌫" ? "del" : ""} onClick={() => key(k)} aria-label={k === "⌫" ? "Delete" : k}>
              {k === "⌫" ? "DEL" : k}
            </button>
          ))}
        </div>
      </div>

      <div className="dev-acts">
        <button className={s.burnerOn ? "on hot" : ""} onClick={() => act((d) => d.setBurner(!d.s.burnerOn))}>
          <Icon.Flame /> {s.burnerOn ? "Stove on" : "Light the stove"}
        </button>
        <button className={s.online ? "" : "on"} onClick={() => act((d) => d.setOnline(!d.s.online))}>
          {s.online ? <Icon.Signal /> : <Icon.NoSignal />} {s.online ? "Lose network" : "Offline"}
        </button>
        <button className={s.leak ? "on bad" : ""} onClick={() => act((d) => d.setLeak(!d.s.leak))}>
          <Icon.Warn /> {s.leak ? "Leaking" : "Simulate leak"}
        </button>
        <button onClick={() => act((d) => d.refill(meter.cylinderKg))}>
          <Icon.Cylinder /> Swap in full cylinder
        </button>
      </div>

      <div className="serial-cap">
        <span>serial · 115200</span>
        <span>{logs.length} lines</span>
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
      <details>
        <summary style={{ cursor: "pointer" }}>MQTT telemetry payload (gg/{meterId}/telemetry)</summary>
        <pre style={{ whiteSpace: "pre-wrap", fontFamily: "var(--mono)", fontSize: 11 }}>{JSON.stringify(dev.telemetry(new Date().toISOString()), null, 1)}</pre>
      </details>
    </div>
  );
}
