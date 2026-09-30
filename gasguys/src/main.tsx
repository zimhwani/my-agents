import { StrictMode, useState } from "react";
import { createRoot } from "react-dom/client";
import { formatMoney } from "../core/pricing.ts";
import { CustomerApp } from "./customer/CustomerApp.tsx";
import { MeterSim } from "./meter/MeterSim.tsx";
import { Ops } from "./ops/Ops.tsx";
import { sandbox } from "./sandbox/index.ts";
import "./styles.css";
import { Logo, useHashRoute, useSandbox } from "./ui.tsx";
import { WhatsAppSim } from "./whatsapp/WhatsAppSim.tsx";

const TABS = [
  ["/", "Studio"],
  ["/app", "Customer app"],
  ["/whatsapp", "WhatsApp"],
  ["/meter", "Meter"],
  ["/ops", "Ops"],
] as const;

function Shell() {
  const [route] = useHashRoute();
  const sb = useSandbox();

  // The customer app on its own, full screen: what you open on a real phone.
  if (route === "/app") return (
    <div className="fullscreen-app">
      <CustomerApp />
    </div>
  );
  if (route.startsWith("/checkout/")) return <CardCheckout providerRef={route.slice(10)} />;

  return (
    <>
      <header className="studio-top">
        <span className="brand">
          <Logo /> Gasguys <span className="badge">Sandbox</span>
        </span>
        <nav className="tabs">
          {TABS.map(([path, label]) => (
            <a key={path} href={`#${path}`} className={route === path ? "on" : ""}>
              {label}
            </a>
          ))}
        </nav>
        <div className="studio-ctl">
          <label>
            Cooking speed
            <select value={sb.p.settings.speed} onChange={(e) => ((sb.p.settings.speed = Number(e.target.value)), sb.changed())}>
              <option value={1}>1 min/s</option>
              <option value={5}>5 min/s</option>
              <option value={30}>30 min/s</option>
              <option value={120}>2 h/s</option>
            </select>
          </label>
          <label>
            <input type="checkbox" checked={sb.p.settings.autoApprove} onChange={(e) => ((sb.p.settings.autoApprove = e.target.checked), sb.changed())} />
            Auto-approve payments
          </label>
          <ResetButton onReset={() => sb.reset()} />
        </div>
      </header>

      {route === "/" && (
        <main className="stage">
          <div className="stage-col">
            <span className="stage-cap">Customer web app</span>
            <div className="phone">
              <div className="phone-screen">
                <CustomerApp />
              </div>
            </div>
          </div>
          <div className="stage-col">
            <span className="stage-cap">WhatsApp</span>
            <div className="phone">
              <div className="phone-screen">
                <WhatsAppSim />
              </div>
            </div>
          </div>
          <div className="stage-col">
            <span className="stage-cap">The valve</span>
            <MeterSim />
          </div>
        </main>
      )}
      {route === "/whatsapp" && (
        <main className="stage">
          <div className="phone">
            <div className="phone-screen">
              <WhatsAppSim />
            </div>
          </div>
        </main>
      )}
      {route === "/meter" && (
        <main className="stage">
          <MeterSim />
        </main>
      )}
      {route === "/ops" && (
        <main className="stage">
          <div className="stage-wide">
            <Ops />
          </div>
        </main>
      )}
    </>
  );
}

/** Two taps instead of confirm(), which embedded viewers suppress. */
function ResetButton({ onReset }: { onReset: () => void }) {
  const [armed, setArmed] = useState(false);
  return armed ? (
    <>
      <button onClick={onReset}>Reset everything</button>
      <button onClick={() => setArmed(false)}>Keep</button>
    </>
  ) : (
    <button onClick={() => setArmed(true)}>Reset</button>
  );
}

/** Stands in for the payment gateway's hosted card page that diaspora payers are sent to. */
function CardCheckout({ providerRef }: { providerRef: string }) {
  const sb = useSandbox();
  const [done, setDone] = useState<null | "paid" | "failed">(null);
  const prompt = sb.p.prompts.find((p) => p.providerRef === providerRef);
  return (
    <div className="fullscreen-app" style={{ padding: 24, gap: 16 }}>
      <div className="sandbox-hint">
        <b>Sandbox card checkout.</b> In production this is the gateway's hosted, 3-D Secure card page. No card details are collected here.
      </div>
      {!prompt && !done && <div className="card">This payment is no longer waiting. You can close this tab.</div>}
      {done && (
        <div className="card center">
          <h2>{done === "paid" ? "Paid ✓" : "Payment cancelled"}</h2>
          <p className="muted">You can close this tab and go back to Gasguys.</p>
          <button className="btn dark block" onClick={() => history.back()}>
            Back to Gasguys
          </button>
        </div>
      )}
      {prompt && !done && (
        <div className="card stack">
          <span className="muted">Pay Gasguys</span>
          <h1 className="num">{formatMoney(prompt.amount, prompt.currency)}</h1>
          <span className="muted">Reference {prompt.reference}</span>
          <button
            className="btn primary block"
            onClick={async () => {
              await sandbox.resolvePrompt(providerRef, "paid");
              setDone("paid");
            }}
          >
            Simulate successful card payment
          </button>
          <button
            className="btn ghost block"
            onClick={async () => {
              await sandbox.resolvePrompt(providerRef, "failed");
              setDone("failed");
            }}
          >
            Simulate declined card
          </button>
        </div>
      )}
    </div>
  );
}

sandbox.start();
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Shell />
  </StrictMode>,
);
