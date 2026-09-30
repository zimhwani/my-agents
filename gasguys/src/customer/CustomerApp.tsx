import { Fragment, useEffect, useMemo, useState, type ReactNode } from "react";
import { LANGS, t, type StringKey } from "../../core/i18n/index.ts";
import { formatKg, formatMoney, fromUsd, gramsFor, PRESETS_USD } from "../../core/pricing.ts";
import type { PaymentInstruction } from "../../core/providers.ts";
import { formatMeterId, formatPhone, normalizeMeterId, normalizePhone } from "../../core/service.ts";
import { formatToken } from "../../core/token.ts";
import type { Currency, Customer, Lang, Meter, PayMethod, Payment } from "../../core/types.ts";
import { useBackend } from "../backend/context.tsx";
import { fmtDate, fmtTime, Icon, Logo, monthShort } from "../ui.tsx";

type Tr = (k: StringKey, v?: Record<string, string | number>) => string;
type Screen =
  | { name: "home" }
  | { name: "buy"; gift?: boolean; preset?: number }
  | { name: "pay"; paymentId: string; instruction: PaymentInstruction; returned?: boolean }
  | { name: "history" }
  | { name: "refill" }
  | { name: "settings" };

const LANG = "gasguys.lang";
/** Live mode: the card payment we sent the customer to Paynow's page for, so we can pick it up on return. */
const PAY = "gasguys.pay";
const read = (k: string) => {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
};
const write = (k: string, v: string | null) => {
  try {
    if (v === null) localStorage.removeItem(k);
    else localStorage.setItem(k, v);
  } catch {
    /* ignore */
  }
};

export function CustomerApp() {
  const backend = useBackend();
  // A live backend restores the session before the first real render, so a signed-in customer
  // doesn't see the sign-in screen flash past. The sandbox is always ready.
  if (!backend.ready())
    return (
      <div className="app">
        <div className="app-head">
          <Logo />
        </div>
      </div>
    );
  return <Session />;
}

function Session() {
  const backend = useBackend();
  const customer = backend.customer();
  const [lang, setLangState] = useState<Lang>(() => customer?.lang ?? ((read(LANG) as Lang) || "en"));
  const tr: Tr = (k, v) => t(lang, k, v);
  const setLang = async (l: Lang) => {
    setLangState(l);
    write(LANG, l);
    if (customer) await backend.updateCustomer({ lang: l });
  };
  const signOut = () => void backend.signOut();

  const meters = customer ? backend.meters() : [];
  if (!customer || meters.length === 0) return <Onboarding tr={tr} lang={lang} setLang={setLang} customer={customer} />;
  return <Main tr={tr} lang={lang} setLang={setLang} customer={customer} meters={meters} signOut={signOut} />;
}

// ── Small shared pieces ──────────────────────────────────────────────────────────────────────────

function LangSelect({ lang, setLang }: { lang: Lang; setLang: (l: Lang) => void }) {
  return (
    <select className="lang-select" value={lang} onChange={(e) => setLang(e.target.value as Lang)} aria-label="Language">
      {LANGS.map((l) => (
        <option key={l.code} value={l.code}>
          {l.label}
        </option>
      ))}
    </select>
  );
}

/** A gas cylinder drawn to scale: collar, body, foot ring, and optionally its gas level. */
function CylinderGlyph({ h, w = Math.round(h * 0.56), pct, tone = "flame" }: { h: number; w?: number; pct?: number; tone?: "flame" | "low" | "empty" }) {
  const collar = Math.max(4, h * 0.13);
  const foot = Math.max(3, h * 0.07);
  const bodyTop = collar;
  const bodyH = h - collar - foot + 1;
  const rx = Math.min(w * 0.32, bodyH * 0.3);
  const fill = tone === "empty" ? "var(--alert)" : tone === "low" ? "var(--maize)" : "var(--flame)";
  const level = pct === undefined ? null : bodyTop + bodyH * (1 - Math.max(0, Math.min(100, pct)) / 100);
  const id = `cyl${h}${w}${Math.round(pct ?? -1)}`;
  return (
    <svg className="cyl" width={w} height={h} viewBox={`0 0 ${w} ${h}`} aria-hidden focusable="false">
      <defs>
        <clipPath id={id}>
          <rect x="1" y={bodyTop} width={w - 2} height={bodyH - 1} rx={rx} />
        </clipPath>
      </defs>
      <rect x={w * 0.27} y="1" width={w * 0.46} height={collar} rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.5" />
      {level !== null && <rect x="0" y={level} width={w} height={h} fill={fill} clipPath={`url(#${id})`} />}
      <rect x="1" y={bodyTop} width={w - 2} height={bodyH - 1} rx={rx} fill="none" stroke="currentColor" strokeWidth="1.5" />
      <rect x={w * 0.18} y={h - foot} width={w * 0.64} height={foot - 0.75} rx="1" fill="currentColor" />
    </svg>
  );
}

const METHOD: Record<PayMethod, { bg: string; mark: ReactNode; name: string }> = {
  ecocash: { bg: "#1c4f9c", mark: "E", name: "EcoCash" },
  innbucks: { bg: "#c8261d", mark: "I", name: "InnBucks" },
  card: { bg: "#16140f", mark: <Icon.Card />, name: "Visa / Mastercard" },
};

// ── Onboarding ───────────────────────────────────────────────────────────────────────────────────

/** Signing in (and linking a meter) makes the backend's customer and meters appear, which swaps this for Main. */
function Onboarding(props: { tr: Tr; lang: Lang; setLang: (l: Lang) => void; customer: Customer | null }) {
  const { tr, lang } = props;
  const backend = useBackend();
  const demo = backend.sandbox;
  const [step, setStep] = useState<"lang" | "phone" | "otp" | "meter">(props.customer ? "meter" : "lang");
  const [phone, setPhone] = useState(demo ? formatPhone(demo.demoPhone).slice(1) : "");
  const [otp, setOtp] = useState("");
  const [otpFocus, setOtpFocus] = useState(false);
  const [meterId, setMeterId] = useState("");
  const [nickname, setNickname] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const idx = ["lang", "phone", "otp", "meter"].indexOf(step);

  /** Runs one step at a time, so a double tap doesn't send two codes or link twice. */
  const once = async (fn: () => Promise<unknown>) => {
    if (busy) return;
    setBusy(true);
    try {
      await fn();
    } finally {
      setBusy(false);
    }
  };
  const submitPhone = () =>
    once(async () => {
      const p = normalizePhone(phone);
      if (!p) return setErr(tr("err_invalid_phone"));
      const res = await backend.requestOtp(p);
      if (!res.ok) return setErr(tr("err_generic"));
      setErr(null);
      setStep("otp");
    });
  const submitOtp = () =>
    once(async () => {
      const res = await backend.verifyOtp(normalizePhone(phone)!, otp, { lang, name: nickname });
      if (!res.ok) return setErr(tr(res.error === "otp_wrong" ? "otp_wrong" : "err_generic"));
      setErr(null);
      if (backend.meters().length) return; // signed in with a meter: Main takes over
      setStep("meter");
    });
  const submitMeter = () =>
    once(async () => {
      const res = await backend.linkMeter(meterId);
      if (!res.ok) return setErr(res.error === "meter_taken" || res.error === "meter_not_found" ? tr(res.error) : tr("err_generic"));
    });

  return (
    <div className="app">
      <div className="app-head">
        <Logo />
        {step !== "lang" && <LangSelect lang={lang} setLang={props.setLang} />}
      </div>
      <div className="app-body">
        <div className="steps" aria-label={`${idx + 1} / 4`}>
          {[0, 1, 2, 3].map((i) => (
            <i key={i} className={i <= idx ? "on" : ""} />
          ))}
        </div>

        {step === "lang" && (
          <>
            <div className="welcome">
              <h1 className="display">{tr("welcome_title")}</h1>
              <p>{tr("welcome_body")}</p>
            </div>
            <section className="section">
              <div className="trilingual">
                {LANGS.map((l) => (l.code === lang ? <b key={l.code}>{t(l.code, "choose_language")}</b> : <span key={l.code}>{t(l.code, "choose_language")}</span>))}
              </div>
              <div className="choices" role="radiogroup">
                {LANGS.map((l) => (
                  <button key={l.code} role="radio" aria-checked={lang === l.code} className={`choice big ${lang === l.code ? "on" : ""}`} onClick={() => props.setLang(l.code)}>
                    <span className="radio" />
                    <span className="grow">
                      <b>{l.label}</b>
                      <span className="sub">{t(l.code, "nav_buy")}</span>
                    </span>
                  </button>
                ))}
              </div>
            </section>
            <p className="note ok">
              <Icon.Shield />
              {tr("trust_no_upfront")}
            </p>
            <button className="btn primary block" onClick={() => setStep("phone")}>
              {tr("btn_continue")} <Icon.Arrow />
            </button>
          </>
        )}

        {step === "phone" && (
          <>
            <h1 className="title">{tr("sign_in")}</h1>
            <div className="stack" style={{ gap: 20 }}>
              <div className="field">
                <label htmlFor="ph">{tr("phone_label")}</label>
                <div className="prefix">
                  <span>+263</span>
                  <input id="ph" inputMode="tel" autoComplete="tel-national" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder={tr("phone_hint")} />
                </div>
              </div>
              <div className="field">
                <label htmlFor="nm">{tr("your_name")}</label>
                <input id="nm" className="input" value={nickname} onChange={(e) => setNickname(e.target.value)} placeholder="Tendai" autoComplete="given-name" />
              </div>
            </div>
            {err && <div className="notice warn">{err}</div>}
            <button className="btn primary block" onClick={submitPhone}>
              {tr("btn_continue")} <Icon.Arrow />
            </button>
            {demo && (
              <div className="sandbox-hint">
                <b>{formatPhone(demo.demoPhone).slice(1)}</b> is Tendai, who already has a meter. Any other Zimbabwe mobile number starts a new account.
              </div>
            )}
          </>
        )}

        {step === "otp" && (
          <>
            <div className="stack" style={{ gap: 6 }}>
              <h1 className="title">{tr("otp_label")}</h1>
              <p className="muted">{tr("otp_sent", { phone })}</p>
            </div>
            <div className="code-cells">
              {[0, 1, 2, 3, 4, 5].map((i) => (
                <span key={i} className={otpFocus && i === Math.min(otp.length, 5) ? "cur" : ""}>
                  {otp[i] ?? ""}
                </span>
              ))}
              <input
                aria-label={tr("otp_label")}
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                value={otp}
                onFocus={() => setOtpFocus(true)}
                onBlur={() => setOtpFocus(false)}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
              />
            </div>
            {err && <div className="notice warn">{err}</div>}
            <button className="btn primary block" onClick={submitOtp} disabled={otp.length !== 6}>
              {tr("btn_confirm")}
            </button>
            <button className="link" style={{ alignSelf: "flex-start" }} onClick={() => setStep("phone")}>
              <Icon.Back /> {tr("btn_back")}
            </button>
            {demo && (
              <div className="sandbox-hint">
                The code is always <b>{demo.otp}</b>. Production sends it by SMS through Supabase Auth.
              </div>
            )}
          </>
        )}

        {step === "meter" && (
          <>
            <h1 className="title">{tr("meter_link_title")}</h1>
            <MeterSticker hint={tr("meter_id_hint")} />
            <div className="field">
              <label htmlFor="mid">{tr("meter_enter_id")}</label>
              <input id="mid" className="input mono" inputMode="numeric" value={meterId} onChange={(e) => setMeterId(e.target.value)} placeholder="370 0000 0000" />
            </div>
            {err && <div className="notice warn">{err}</div>}
            <button className="btn primary block" onClick={submitMeter} disabled={normalizeMeterId(meterId).length !== 11}>
              {tr("btn_continue")} <Icon.Arrow />
            </button>
            {demo && (
              <div className="sandbox-hint">
                Try the uninstalled meter <b>{formatMeterId(demo.spareMeter)}</b>. In production a technician links the meter at install, and this step confirms it with an SMS code.
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

/** The label on the valve, drawn so people know which number to look for. */
function MeterSticker({ hint }: { hint: string }) {
  // A fixed, plausible-looking QR: three finder squares and a scatter of modules.
  const mods = useMemo(() => {
    const out: [number, number][] = [];
    let s = 7;
    for (let y = 0; y < 21; y++)
      for (let x = 0; x < 21; x++) {
        const finder = (x < 8 && y < 8) || (x > 12 && y < 8) || (x < 8 && y > 12);
        s = (s * 1103515245 + 12345) & 0x7fffffff;
        if (!finder && s % 5 < 2) out.push([x, y]);
      }
    return out;
  }, []);
  const finder = (x: number, y: number) => (
    <g key={`${x}${y}`}>
      <rect x={x} y={y} width="7" height="7" fill="#16140f" />
      <rect x={x + 1} y={y + 1} width="5" height="5" fill="#fbfaf6" />
      <rect x={x + 2} y={y + 2} width="3" height="3" fill="#16140f" />
    </g>
  );
  return (
    <div className="sticker" aria-hidden>
      <svg className="qr" viewBox="-1 -1 23 23" shapeRendering="crispEdges">
        {mods.map(([x, y]) => (
          <rect key={`${x}-${y}`} x={x} y={y} width="1" height="1" fill="#16140f" />
        ))}
        {finder(0, 0)}
        {finder(14, 0)}
        {finder(0, 14)}
      </svg>
      <div>
        <div className="brand-line">Gasguys smart valve</div>
        <div className="no">
          <mark>370 1234 5678</mark>
        </div>
        <div className="faint">{hint}</div>
      </div>
    </div>
  );
}

// ── Signed-in app ────────────────────────────────────────────────────────────────────────────────

function Main(props: { tr: Tr; lang: Lang; setLang: (l: Lang) => void; customer: Customer; meters: Meter[]; signOut: () => void }) {
  const { tr, customer, meters } = props;
  const backend = useBackend();
  const [screen, setScreen] = useState<Screen>(() => (backend.mode === "live" && resumeCardPayment()) || { name: "home" });
  const [meterId, setMeterId] = useState(meters[0].id);
  const [dismissedLeak, setDismissedLeak] = useState<string | null>(null);
  const meter = meters.find((m) => m.id === meterId) ?? meters[0];
  const leakMeter = meters.find((m) => m.leak && dismissedLeak !== m.id);
  const go = (s: Screen) => setScreen(s);

  return (
    <div className="app">
      <div className="app-head">
        <Logo />
        <div className="tools">
          <LangSelect lang={props.lang} setLang={props.setLang} />
          <button className={`icon-btn ${screen.name === "settings" ? "on" : ""}`} onClick={() => go({ name: "settings" })} aria-label={tr("nav_settings")} title={tr("nav_settings")}>
            <Icon.Account />
          </button>
        </div>
      </div>
      <div className="app-body">
        {screen.name === "home" && <Home tr={tr} customer={customer} meters={meters} meter={meter} setMeterId={setMeterId} go={go} />}
        {screen.name === "buy" && <Buy key={`${!!screen.gift}-${screen.preset ?? ""}`} tr={tr} customer={customer} meter={meter} gift={!!screen.gift} preset={screen.preset} go={go} />}
        {screen.name === "pay" && <Pay tr={tr} paymentId={screen.paymentId} instruction={screen.instruction} returned={!!screen.returned} go={go} />}
        {screen.name === "history" && <History tr={tr} customer={customer} go={go} />}
        {screen.name === "refill" && <Refill tr={tr} customer={customer} meter={meter} go={go} />}
        {screen.name === "settings" && <Settings tr={tr} lang={props.lang} setLang={props.setLang} customer={customer} signOut={props.signOut} />}
      </div>
      <nav className="nav">
        {(
          [
            ["home", "nav_home", <Icon.Home />],
            ["buy", "nav_buy", <Icon.Flame />],
            ["gift", "nav_gift", <Icon.Gift />],
            ["history", "nav_history", <Icon.Receipt />],
          ] as const
        ).map(([name, key, icon]) => {
          const on = name === "gift" ? screen.name === "buy" && !!screen.gift : name === "buy" ? (screen.name === "buy" && !screen.gift) || screen.name === "pay" : screen.name === name;
          return (
            <button key={name} className={on ? "on" : ""} aria-current={on ? "page" : undefined} onClick={() => go(name === "gift" ? { name: "buy", gift: true } : ({ name } as Screen))}>
              {icon}
              {tr(key)}
            </button>
          );
        })}
      </nav>
      {leakMeter && <LeakAlert tr={tr} meter={leakMeter} onSafe={() => setDismissedLeak(leakMeter.id)} />}
    </div>
  );
}

// ── Home ─────────────────────────────────────────────────────────────────────────────────────────

function Home(props: { tr: Tr; customer: Customer; meters: Meter[]; meter: Meter; setMeterId: (id: string) => void; go: (s: Screen) => void }) {
  const { tr, meter: m, go } = props;
  const backend = useBackend();
  const tariff = backend.tariff();
  const days = backend.daysLeft(m);
  const cylPct = Math.max(0, Math.min(100, (m.gasGrams / (m.cylinderKg * 1000)) * 100));
  const creditKg = m.creditGrams / 1000;
  const refill = backend.openRefill(m.id);
  const recent = backend
    .payments()
    .filter((p) => p.meterId === m.id && p.status === "paid")
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 3);
  const lastToken = recent.find((p) => p.delivery === "token");
  const offlineHours = Math.floor((Date.now() - Date.parse(m.lastSeen)) / 3.6e6);
  const state = creditKg <= 0 || days === 0 ? "empty" : days <= 3 ? "low" : "";
  const runOut = new Date(Date.now() + days * 864e5);
  const cylTone = cylPct < 5 ? "empty" : cylPct < 20 ? "low" : "flame";

  return (
    <>
      <div className="row between" style={{ alignItems: "flex-end" }}>
        <div className="meter-id">
          {props.meters.length > 1 ? (
            <select value={m.id} onChange={(e) => props.setMeterId(e.target.value)} aria-label={tr("bot_choose_meter")}>
              {props.meters.map((x) => (
                <option key={x.id} value={x.id}>
                  {formatMeterId(x.id)} · {x.suburb}
                </option>
              ))}
            </select>
          ) : (
            <>
              <span className="where">{m.suburb}</span>
              <span className="no">
                <span>{tr("meter_label")}</span> {formatMeterId(m.id)}
              </span>
            </>
          )}
        </div>
        {m.online ? (
          <span className="faint row" style={{ gap: 5 }} title={tr("last_updated", { time: fmtTime(m.lastSeen) })}>
            <span style={{ width: 18, height: 18, display: "inline-flex" }}>
              <Icon.Signal />
            </span>
            <span className="mono" style={{ fontSize: 13 }}>
              {fmtTime(m.lastSeen)}
            </span>
          </span>
        ) : (
          <span className="status warn">Offline</span>
        )}
      </div>

      {!m.online && (
        <div className="notice warn">
          <Icon.NoSignal />
          <div className="grow">
            {offlineHours >= 1 && `${tr("err_meter_offline", { hours: offlineHours })}. `}
            {lastToken?.token ? tr("token_enter", { kg: (lastToken.grams / 1000).toFixed(2) }) : tr("meter_offline")}
            {lastToken?.token && (
              <div className="token-box">
                <div className="token">{formatToken(lastToken.token)}</div>
              </div>
            )}
          </div>
        </div>
      )}

      <section className={`readout ${state}`} aria-label={days === 1 ? tr("days_left_one") : tr("days_left", { days })}>
        <div className="readout-top">
          <span className="eyebrow">{tr("gas_remaining")}</span>
          {m.leak ? (
            <span className="status bad">{tr("leak_title")}</span>
          ) : m.valve === "open" ? (
            <span className="status on">{tr("valve_open")}</span>
          ) : (
            <span className="status off">{tr("valve_closed")}</span>
          )}
        </div>
        <div className="big" aria-hidden>
          <span className="n display num">{days}</span>
          <span className="u">{days === 1 ? tr("day_unit") : tr("days_unit")}</span>
        </div>
        <div className="sub">
          <span>
            {tr("credit_balance")} <b className="num">{creditKg.toFixed(creditKg < 10 ? 2 : 1)} kg</b>
          </span>
          <span>
            ≈ <b className="num">{formatMoney(fromUsd(creditKg * tariff.usdPerKg, "USD"), "USD")}</b>
          </span>
        </div>
        <DayStrip days={days} />
        {days > 0 && (
          <div className="foot">
            <span>{tr("runs_out_about", { date: fmtDate(runOut) })}</span>
          </div>
        )}
      </section>

      {m.valve === "closed" && !m.leak && m.creditGrams <= 0 && <div className="notice warn">{tr("valve_closed_no_credit")}</div>}

      <section className="section">
        <div className="section-head">
          <h2 className="section-title">{tr("nav_buy")}</h2>
          <span className="faint mono" style={{ fontSize: 13 }}>
            ${tariff.usdPerKg.toFixed(2)} / kg
          </span>
        </div>
        <div className="board four">
          {PRESETS_USD.map((a) => (
            <button key={a} className="price" onClick={() => go({ name: "buy", preset: a })} aria-label={`$${a} ≈ ${formatKg(gramsFor(a, "USD", tariff))}`}>
              <span className="amt num">
                <small>$</small>
                {a}
              </span>
              <span className="kg">{formatKg(gramsFor(a, "USD", tariff))}</span>
            </button>
          ))}
        </div>
      </section>

      <section className="section">
        <div className="cyl-row" style={{ flexWrap: "wrap" }}>
          <CylinderGlyph h={44} pct={cylPct} tone={cylTone} />
          <div className="t grow">
            <b>
              {tr("cylinder")} · {m.cylinderKg} kg
            </b>
            <span className="faint num">
              {formatKg(m.gasGrams)} · {Math.round(cylPct)}%
            </span>
          </div>
          {refill ? (
            <span className="tag warn">
              {tr(`refill_status_${refill.status}` as StringKey)}
            </span>
          ) : (
            cylPct >= 20 && (
              <button className="link" onClick={() => go({ name: "refill" })}>
                {tr("refill_title")} <Icon.Arrow />
              </button>
            )
          )}
        </div>
        {refill && (
          <p className="faint row" style={{ gap: 8 }}>
            <span style={{ width: 20, height: 20, display: "inline-flex", flex: "none" }}>
              <Icon.Truck />
            </span>
            {tr("refill_title")} · {refill.slot}
          </p>
        )}
        {!refill && cylPct < 20 && (
          <>
            <p className="muted">{tr("low_cylinder_body", { kg: (m.gasGrams / 1000).toFixed(1) })}</p>
            <button className="btn ghost block" onClick={() => go({ name: "refill" })}>
              <Icon.Cylinder /> {tr("refill_title")}
            </button>
          </>
        )}
      </section>

      <section className="section">
        <div className="section-head">
          <h2 className="section-title">{tr("history_title")}</h2>
          {recent.length > 0 && (
            <button className="link" onClick={() => go({ name: "history" })}>
              {tr("see_all")} <Icon.Arrow />
            </button>
          )}
        </div>
        {recent.length === 0 ? (
          <p className="faint">{tr("history_empty_body")}</p>
        ) : (
          <div className="ledger" style={{ borderTop: "1px solid var(--rule)" }}>
            {recent.map((p) => (
              <LedgerEntry key={p.id} tr={tr} p={p} customer={props.customer} showDate />
            ))}
          </div>
        )}
      </section>

      <button className="line-row" onClick={() => go({ name: "buy", gift: true })}>
        <span className="ico">
          <Icon.Gift />
        </span>
        <span className="grow">
          <b>{tr("gift_title")}</b>
          <span className="faint">{tr("gift_body")}</span>
        </span>
        <span className="chev">
          <Icon.Chevron />
        </span>
      </button>
    </>
  );
}

/** The next fourteen days, numbered by date, filled up to the day the gas runs out. */
function DayStrip({ days }: { days: number }) {
  const today = new Date();
  const cells = Array.from({ length: 14 }, (_, i) => new Date(today.getFullYear(), today.getMonth(), today.getDate() + i));
  return (
    <div className="days" aria-hidden>
      {cells.map((_, i) => (
        <i key={`b${i}`} className={i < days ? "f" : ""} />
      ))}
      {cells.map((d, i) => (
        <span key={`l${i}`} className={d.getDate() === 1 || i === 0 ? "m" : i === days ? "end" : ""}>
          {d.getDate() === 1 ? monthShort(d) : d.getDate()}
        </span>
      ))}
    </div>
  );
}

function LedgerEntry({ tr, p, customer, showDate }: { tr: Tr; p: Payment; customer: Customer; showDate?: boolean }) {
  const backend = useBackend();
  const ownerName = (meterId: string) => backend.meterOwnerName(meterId);
  const kg = (p.grams / 1000).toFixed(2);
  const giftIn = p.gift && p.customerId !== customer.id;
  const giftOut = p.gift && p.customerId === customer.id;
  const label = giftIn
    ? tr("history_gift_in", { name: p.payerName || formatPhone(p.payerPhone), kg })
    : giftOut
      ? tr("history_gift_out", { name: ownerName(p.meterId), amount: formatMoney(p.amount, p.currency) })
      : tr("history_purchase", { kg, amount: formatMoney(p.amount, p.currency) });
  const failed = p.status !== "paid";
  return (
    <div className={`entry ${failed ? "failed" : ""} ${giftIn || giftOut ? "gift" : ""}`}>
      <span className="when">{showDate ? fmtDate(p.createdAt) : fmtTime(p.createdAt)}</span>
      <div>
        <div className="what">{label}</div>
        <div className="meta">
          {METHOD[p.method].name} · <span className="mono">{p.reference}</span>
          {failed && ` · ${p.status}`}
        </div>
      </div>
      <div className="amt">{giftOut ? `${kg} kg` : `+${kg} kg`}</div>
    </div>
  );
}

// ── Buy and gift ─────────────────────────────────────────────────────────────────────────────────

function Buy(props: { tr: Tr; customer: Customer; meter: Meter; gift: boolean; preset?: number; go: (s: Screen) => void }) {
  const { tr, customer, gift } = props;
  const backend = useBackend();
  const tariff = backend.tariff();
  const [currency, setCurrency] = useState<Currency>("USD");
  const [preset, setPreset] = useState<number | null>(props.preset ?? (gift ? 5 : 2));
  const [other, setOther] = useState("");
  const [method, setMethod] = useState<PayMethod>(gift ? "card" : "ecocash");
  const [payPhone, setPayPhone] = useState(formatPhone(customer.phone));
  const [recipientInput, setRecipientInput] = useState(gift && backend.sandbox ? formatMeterId(backend.sandbox.giftMeter) : "");
  const [message, setMessage] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [recipient, setRecipient] = useState<{ meterId: string; name: string; suburb: string } | null>(null);
  const [confirmed, setConfirmed] = useState(false);
  const [lookedUp, setLookedUp] = useState(""); // the meter number the last finished lookup was for

  useEffect(() => {
    setConfirmed(false);
    setRecipient(null);
    if (!gift) return;
    const id = normalizeMeterId(recipientInput);
    let current = true; // a live lookup can finish after the number has changed again
    if (id.length === 11)
      void backend.giftLookup(id).then((r) => {
        if (!current) return;
        setRecipient(r);
        setLookedUp(id);
      });
    return () => {
      current = false;
    };
  }, [backend, recipientInput, gift]);

  const presets = currency === "USD" ? PRESETS_USD : PRESETS_USD.map((a) => Math.round(fromUsd(a, "ZWG", tariff) / 5) * 5);
  const amount = preset ?? Number(other.replace(",", "."));
  const grams = amount > 0 ? gramsFor(amount, currency, tariff) : 0;
  const targetMeter = gift ? recipient?.meterId : props.meter.id;
  const canPay = !!targetMeter && amount > 0 && (!gift || confirmed) && !busy;

  const pay = async () => {
    setErr(null);
    const phone = method === "ecocash" ? normalizePhone(payPhone) : customer.phone;
    if (!phone) return setErr(tr("err_invalid_phone"));
    setBusy(true);
    const res = await backend.startPurchase({
      meterId: targetMeter!,
      amount,
      currency,
      method,
      payerPhone: phone,
      giftMessage: gift ? message || null : null,
    });
    setBusy(false);
    if (!res.ok) return setErr(res.error === "amount_too_small" ? tr("err_amount_min", { amount: formatMoney(fromUsd(tariff.minUsd, currency, tariff), currency) }) : tr("err_generic"));
    props.go({ name: "pay", paymentId: res.payment.id, instruction: res.instruction });
  };

  const sym = currency === "USD" ? "$" : "ZiG ";
  return (
    <>
      <div className="stack" style={{ gap: 6 }}>
        <h1 className="title">{gift ? tr("gift_title") : tr("buy_title")}</h1>
        {gift ? (
          <p className="muted">{tr("gift_body")}</p>
        ) : (
          <p className="muted">
            {tr("meter_label")} <span className="mono">{formatMeterId(props.meter.id)}</span> · {props.meter.suburb}
          </p>
        )}
      </div>

      {gift && (
        <section className="section">
          <div className="field">
            <label htmlFor="rcp">{tr("recipient_meter")}</label>
            <input id="rcp" className="input mono" inputMode="numeric" value={recipientInput} onChange={(e) => setRecipientInput(e.target.value)} placeholder="370 0000 0000" />
          </div>
          {recipient && (
            <div className={`notice ${confirmed ? "ok" : "info"}`} style={{ alignItems: "center" }}>
              {confirmed ? <Icon.Check /> : <Icon.Account />}
              <div className="grow">{tr("recipient_name_check", { name: `${recipient.name} · ${recipient.suburb}` })}</div>
              {!confirmed && (
                <button className="btn sm dark" onClick={() => setConfirmed(true)}>
                  {tr("yes")}
                </button>
              )}
            </div>
          )}
          {normalizeMeterId(recipientInput).length === 11 && lookedUp === normalizeMeterId(recipientInput) && !recipient && <div className="notice warn">{tr("meter_not_found")}</div>}
          <input className="input" value={message} onChange={(e) => setMessage(e.target.value)} placeholder={tr("gift_message")} style={{ fontSize: 16 }} aria-label={tr("gift_message")} />
        </section>
      )}

      <section className="section">
        <div className="section-head">
          <h2 className="section-title">{tr("amount")}</h2>
          <div className="seg" role="group" aria-label="Currency">
            {(["USD", "ZWG"] as Currency[]).map((c) => (
              <button
                key={c}
                className={currency === c ? "on" : ""}
                aria-pressed={currency === c}
                onClick={() => {
                  setCurrency(c);
                  setPreset(c === "USD" ? 2 : Math.round(fromUsd(2, "ZWG", tariff) / 5) * 5);
                }}
              >
                {c === "USD" ? tr("currency_usd") : tr("currency_zig")}
              </button>
            ))}
          </div>
        </div>
        <div className="board">
          {presets.map((a) => (
            <button key={a} className={`price ${preset === a ? "on" : ""}`} aria-pressed={preset === a} onClick={() => setPreset(a)}>
              <span className="amt num">
                <small>{sym.trim()}</small>
                {a}
              </span>
              <span className="kg">≈ {formatKg(gramsFor(a, currency, tariff))}</span>
            </button>
          ))}
          <button className={`price other ${preset === null ? "on" : ""}`} aria-pressed={preset === null} onClick={() => setPreset(null)}>
            <span className="amt">{tr("amount_other")}</span>
            <span className="kg" style={{ marginLeft: "auto" }}>
              {sym.trim()}
            </span>
          </button>
        </div>
        {preset === null && (
          <div className="prefix">
            <span>{sym.trim()}</span>
            <input inputMode="decimal" autoFocus value={other} onChange={(e) => setOther(e.target.value)} placeholder="0.00" aria-label={tr("amount_other")} />
          </div>
        )}
        {grams > 0 && (
          <div className="yields">
            <b>{tr("amount_gets_you", { amount: formatMoney(amount, currency), kg: (grams / 1000).toFixed(2) })}</b>
            <span>{tr("days_left", { days: Math.floor(grams / props.meter.avgDailyGrams) })}</span>
          </div>
        )}
      </section>

      <section className="section">
        <h2 className="section-title">{tr("pay_with")}</h2>
        <div className="choices" role="radiogroup">
          {(["ecocash", "innbucks", "card"] as PayMethod[]).map((mth) => (
            <button key={mth} role="radio" aria-checked={method === mth} className={`choice ${method === mth ? "on" : ""}`} onClick={() => setMethod(mth)}>
              <span className="radio" />
              <span className="grow">
                <b>{METHOD[mth].name}</b>
                <span className="sub">{mth === "ecocash" ? tr("confirm_on_phone") : mth === "innbucks" ? "Code · QR" : tr("gift_from_card")}</span>
              </span>
              <span className="method-mark" style={{ background: METHOD[mth].bg }}>
                {METHOD[mth].mark}
              </span>
            </button>
          ))}
        </div>
        {method === "ecocash" && (
          <div className="field">
            <label htmlFor="eco">{tr("pay_number")}</label>
            <input id="eco" className="input mono" inputMode="tel" value={payPhone} onChange={(e) => setPayPhone(e.target.value)} />
          </div>
        )}
      </section>

      {err && <div className="notice warn">{err}</div>}
      <div className="paybar">
        <p className="note ok" style={{ fontSize: 14 }}>
          <Icon.Shield />
          <span>
            {tr("fee_none")} · {tr("trust_secure")}
          </span>
        </p>
        <button className="btn primary block" disabled={!canPay} onClick={pay}>
          {amount > 0 ? `${tr("btn_confirm")} · ${formatMoney(amount, currency)}` : tr("btn_confirm")}
        </button>
      </div>
    </>
  );
}

// ── Paying ───────────────────────────────────────────────────────────────────────────────────────

function Kv({ k, v }: { k: string; v: ReactNode }) {
  return (
    <div className="kv">
      <span className="k">{k}</span>
      <span className="dots" />
      <span className="v">{v}</span>
    </div>
  );
}

function Pay({ tr, paymentId, instruction, returned, go }: { tr: Tr; paymentId: string; instruction: PaymentInstruction; returned: boolean; go: (s: Screen) => void }) {
  const backend = useBackend();
  const p = backend.payment(paymentId);
  const prompt = p ? backend.sandbox?.promptFor(p.reference) : null;
  const [secs, setSecs] = useState(90);
  useEffect(() => {
    const t = setInterval(() => setSecs((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, []);
  // Live: keep the payment row fresh until it settles (Realtime usually beats the poll).
  useEffect(() => backend.watchPayment(paymentId), [backend, paymentId]);
  // Live card payments: go to Paynow's hosted page, and remember the payment so the app reopens this
  // screen when Paynow sends the customer back.
  useEffect(() => {
    if (backend.mode !== "live" || instruction.kind !== "redirect") return;
    if (!returned) {
      write(PAY, JSON.stringify({ paymentId, instruction }));
      location.assign(instruction.url);
    }
    return () => write(PAY, null);
  }, [backend, paymentId, instruction, returned]);
  const settled = !!p && p.status !== "pending";
  useEffect(() => {
    if (settled && returned) write(PAY, null);
  }, [settled, returned]);
  const shareText = useMemo(() => (p ? `Gasguys receipt ${p.reference}: ${formatMoney(p.amount, p.currency)} = ${(p.grams / 1000).toFixed(2)} kg for meter ${formatMeterId(p.meterId)}` : ""), [p]);
  if (!p) return null;
  const kg = (p.grams / 1000).toFixed(2);

  if (p.status === "paid")
    return (
      <>
        <div className="result-head">
          <span className="result-mark">
            <Icon.Check />
          </span>
          <div className="stack" style={{ gap: 4 }}>
            <h1 className="title">{tr("payment_success")}</h1>
            <p className="muted">{p.delivery === "online" ? tr("credit_sent", { kg }) : tr("token_enter", { kg })}</p>
          </div>
        </div>
        {p.gift && (
          <div className="notice ok">
            <Icon.Gift />
            <div>{tr("gift_sent", { name: backend.meterOwnerName(p.meterId) })}</div>
          </div>
        )}
        <div className="slip-wrap">
          <div className="slip">
            <div className="slip-head">
              <Logo size={22} />
              <span className="k">{tr("receipt_title")}</span>
            </div>
            <Kv k={tr("receipt_ref", { ref: "" }).replace(/[:.]?\s*$/, "")} v={p.reference} />
            <Kv k={tr("date_label")} v={`${fmtDate(p.createdAt, true)} ${fmtTime(p.createdAt)}`} />
            <Kv k={tr("meter_label")} v={formatMeterId(p.meterId)} />
            <Kv k={tr("paid_with")} v={METHOD[p.method].name} />
            <Kv k={tr("amount")} v={formatMoney(p.amount, p.currency)} />
            <div className="slip-total">
              <span className="k">{tr("gas_label")}</span>
              <span className="v display num">{kg} kg</span>
            </div>
            {p.token && p.delivery === "token" && (
              <div className="token-box">
                <span className="k">{tr("token_title")}</span>
                <div className="token">{formatToken(p.token)}</div>
              </div>
            )}
          </div>
        </div>
        <div className="stack">
          <button className="btn primary block" onClick={() => go({ name: "home" })}>
            {tr("btn_done")}
          </button>
          <a className="btn ghost block" href={`https://wa.me/?text=${encodeURIComponent(shareText)}`} target="_blank" rel="noreferrer">
            <Icon.Share /> {tr("share_whatsapp")}
          </a>
        </div>
      </>
    );

  if (p.status !== "pending") {
    // "Payment did not go through. No money was taken." → headline, then the reassurance on its own.
    const [head, ...rest] = (p.status === "expired" ? tr("payment_timeout") : tr("payment_failed")).split(/(?<=\.)\s+/);
    return (
      <>
        <div className="result-head">
          <span className="result-mark bad" style={{ fontSize: 28, fontWeight: 800 }}>
            !
          </span>
          <div className="stack" style={{ gap: 6 }}>
            <h1 className="title">{head}</h1>
            {rest.length > 0 && <p className="section-title">{rest.join(" ")}</p>}
          </div>
        </div>
        <div className="stack">
          <button className="btn primary block" onClick={() => go({ name: "buy", gift: p.gift })}>
            {tr("btn_retry")}
          </button>
          <button className="btn ghost block" onClick={() => go({ name: "home" })}>
            {tr("btn_back")}
          </button>
          <a className="link" href="tel:+263000000000" style={{ alignSelf: "flex-start" }}>
            <Icon.Call /> {tr("bot_talk_agent")}
          </a>
        </div>
      </>
    );
  }

  const mmss = `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, "0")}`;
  return (
    <>
      <div className="stack" style={{ gap: 6 }}>
        <h1 className="title">{tr("waiting_payment")}</h1>
        <p className="muted">{tr("review_summary", { amount: formatMoney(p.amount, p.currency), meter: formatMeterId(p.meterId) })}</p>
      </div>
      {instruction.kind === "ussd_push" && (
        <>
          <div className="handset">
            <span className="handset-cap">
              <Icon.Phone /> {tr("ussd_preview_label")}
            </span>
            <div className="ussd-mock" aria-hidden>
              <div>
                Pay {p.currency === "USD" ? "USD" : "ZiG"} {p.amount.toFixed(2)} to GASGUYS. Ref {p.reference}. Enter PIN to confirm:
              </div>
              <div className="pin">
                <i />
              </div>
              <div className="acts">
                <span>CANCEL</span>
                <span>SEND</span>
              </div>
            </div>
          </div>
          <div className="stack" style={{ gap: 10 }}>
            <p className="section-title">{tr("confirm_on_phone")}</p>
            <div className="countdown">
              <div className="row between faint">
                <span>
                  EcoCash · <span className="mono">{formatPhone(instruction.phone)}</span>
                </span>
                <span className="mono">{mmss}</span>
              </div>
              <div className="track">
                <i style={{ width: `${(secs / 90) * 100}%` }} />
              </div>
            </div>
          </div>
        </>
      )}
      {instruction.kind === "code" && (
        <section className="section">
          <span className="eyebrow">InnBucks</span>
          <div className="code-big mono" aria-label={instruction.code}>
            {instruction.code.split("").map((c, i) => (
              <Fragment key={i}>
                {i === 3 && <span className="gap" />}
                <span>{c}</span>
              </Fragment>
            ))}
          </div>
          <p className="muted">{tr("innbucks_code", { code: instruction.code })}</p>
          <a className="btn ghost block" href={instruction.deepLink}>
            Open InnBucks <Icon.Arrow />
          </a>
        </section>
      )}
      {instruction.kind === "redirect" && (
        <a className="btn primary block" href={instruction.url}>
          <Icon.Card /> {tr("pay_card")}
        </a>
      )}
      <p className="faint">
        {tr("receipt_ref", { ref: "" })}
        <span className="mono">{p.reference}</span>
      </p>
      {prompt && backend.sandbox && (
        <div className="sandbox-hint stack">
          <span>Play the customer. {prompt.method === "ecocash" ? "Enter a PIN on the WhatsApp phone's EcoCash prompt, or:" : "Approve here:"}</span>
          <div className="row">
            <button className="btn sm dark" onClick={() => backend.sandbox?.resolvePrompt(prompt.providerRef, "paid")}>
              Approve
            </button>
            <button className="btn sm ghost" onClick={() => backend.sandbox?.resolvePrompt(prompt.providerRef, "failed")}>
              Decline
            </button>
          </div>
        </div>
      )}
      <button className="link" style={{ alignSelf: "flex-start" }} onClick={() => go({ name: "home" })}>
        <Icon.Back /> {tr("btn_back")}
      </button>
    </>
  );
}

/** Live mode, after Paynow's card page sends the customer back: reopen the payment they were paying. */
function resumeCardPayment(): Screen | null {
  try {
    const v = JSON.parse(read(PAY) ?? "null") as { paymentId?: string; instruction?: PaymentInstruction } | null;
    return v?.paymentId && v.instruction ? { name: "pay", paymentId: v.paymentId, instruction: v.instruction, returned: true } : null;
  } catch {
    return null;
  }
}

/** Zimbabwe fire brigade. Confirm the right number (and a Gasguys 24h safety line) before launch. */
const EMERGENCY_TEL = "993";

// ── History, refill, settings, leak ──────────────────────────────────────────────────────────────

function History({ tr, customer, go }: { tr: Tr; customer: Customer; go: (s: Screen) => void }) {
  const backend = useBackend();
  // The backend's list is already "paid by me, or onto my meters".
  const list = backend
    .payments()
    .filter((p) => p.status !== "pending")
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  const days: [string, Payment[]][] = [];
  for (const p of list) {
    const d = fmtDate(p.createdAt, true);
    if (days.at(-1)?.[0] !== d) days.push([d, []]);
    days.at(-1)![1].push(p);
  }
  return (
    <>
      <h1 className="title">{tr("history_title")}</h1>
      {list.length === 0 ? (
        <div className="empty-state">
          <svg width="56" height="64" viewBox="0 0 56 64" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
            <path d="M8 4h40v56l-6.7-4-6.6 4-6.7-4-6.7 4-6.6-4L8 60z" strokeDasharray="4 3" />
            <path d="M17 18h22M17 27h22M17 36h12" />
          </svg>
          <b className="section-title">{tr("history_empty")}</b>
          <p className="muted">{tr("history_empty_body")}</p>
          <button className="btn primary" onClick={() => go({ name: "buy" })}>
            <Icon.Flame /> {tr("nav_buy")}
          </button>
        </div>
      ) : (
        <div className="ledger">
          {days.map(([d, ps]) => (
            <div key={d}>
              <div className="ledger-day">{d}</div>
              {ps.map((p) => (
                <LedgerEntry key={p.id} tr={tr} p={p} customer={customer} />
              ))}
            </div>
          ))}
        </div>
      )}
    </>
  );
}

const SLOTS: StringKey[] = ["refill_slot_today_pm", "refill_slot_tomorrow_am", "refill_slot_tomorrow_pm"];
/** Real cylinder heights, roughly: 9 kg ≈ 48 cm, 14 kg ≈ 58 cm, 19 kg ≈ 65 cm, 48 kg ≈ 125 cm. */
const SIZE_H: Record<number, [number, number]> = { 9: [40, 26], 14: [50, 28], 19: [58, 30], 48: [98, 34] };

function Refill({ tr, customer, meter, go }: { tr: Tr; customer: Customer; meter: Meter; go: (s: Screen) => void }) {
  const backend = useBackend();
  const [size, setSize] = useState(meter.cylinderKg);
  const [slot, setSlot] = useState<StringKey>(SLOTS[1]);
  const [landmark, setLandmark] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const open = backend.openRefill(meter.id);
  const steps = ["requested", "scheduled", "out_for_delivery", "delivered"] as const;

  if (open) {
    const at = steps.indexOf(open.status as (typeof steps)[number]);
    return (
      <>
        <h1 className="title">{tr("refill_title")}</h1>
        <div className="notice ok">
          <Icon.Check />
          <div>{tr("refill_requested", { phone: formatPhone(customer.phone) })}</div>
        </div>
        <div className="track-steps">
          {steps.map((s, i) => (
            <div key={s} className={`track-step ${at >= i ? "done" : ""} ${at === i ? "cur" : ""}`}>
              <span className="dot">{at >= i && <Icon.Check />}</span>
              <span>{tr(`refill_status_${s}` as StringKey)}</span>
            </div>
          ))}
        </div>
        <p className="muted">{open.slot}</p>
        {backend.sandbox && <div className="sandbox-hint">Move the order along from the Ops console.</div>}
        <button className="btn ghost block" onClick={() => go({ name: "home" })}>
          {tr("btn_back")}
        </button>
      </>
    );
  }

  return (
    <>
      <div className="stack" style={{ gap: 6 }}>
        <h1 className="title">{tr("refill_title")}</h1>
        <p className="muted">{tr("refill_body")}</p>
      </div>
      <section className="section">
        <h2 className="section-title">{tr("refill_size")}</h2>
        <div className="sizes" role="radiogroup">
          {[9, 14, 19, 48].map((k) => (
            <button key={k} role="radio" aria-checked={size === k} className={`size ${size === k ? "on" : ""}`} onClick={() => setSize(k)}>
              <CylinderGlyph h={SIZE_H[k][0]} w={SIZE_H[k][1]} />
              <b className="num">{k} kg</b>
            </button>
          ))}
        </div>
      </section>
      <section className="section">
        <h2 className="section-title">{tr("refill_when")}</h2>
        <div className="choices" role="radiogroup">
          {SLOTS.map((s) => (
            <button key={s} role="radio" aria-checked={slot === s} className={`choice ${slot === s ? "on" : ""}`} onClick={() => setSlot(s)}>
              <span className="radio" />
              <b>{tr(s)}</b>
            </button>
          ))}
        </div>
      </section>
      <div className="field">
        <label htmlFor="lm">{tr("refill_address")}</label>
        <input id="lm" className="input" value={landmark} onChange={(e) => setLandmark(e.target.value)} placeholder="Opposite Mbare Musika, gate 3" style={{ fontSize: 16 }} />
      </div>
      {err && <div className="notice warn">{err}</div>}
      <button
        className="btn primary block"
        onClick={async () => {
          const res = await backend.requestRefill(meter.id, `${tr(slot)} · ${size} kg${landmark ? " · " + landmark : ""}`);
          setErr(res.ok ? null : tr("err_generic"));
        }}
      >
        {tr("btn_confirm")}
      </button>
    </>
  );
}

function Settings({ tr, lang, setLang, customer, signOut }: { tr: Tr; lang: Lang; setLang: (l: Lang) => void; customer: Customer; signOut: () => void }) {
  const backend = useBackend();
  return (
    <>
      <h1 className="title">{tr("nav_settings")}</h1>
      <div className="row" style={{ gap: 14 }}>
        <span className="ico" style={{ width: 52, height: 52, borderRadius: "50%" }}>
          <Icon.Account />
        </span>
        <div>
          <div className="section-title">{customer.name || formatPhone(customer.phone)}</div>
          <div className="mono faint">{formatPhone(customer.phone)}</div>
        </div>
      </div>
      <section className="section">
        <h2 className="section-title">{tr("language")}</h2>
        <div className="choices" role="radiogroup">
          {LANGS.map((l) => (
            <button key={l.code} role="radio" aria-checked={lang === l.code} className={`choice ${lang === l.code ? "on" : ""}`} onClick={() => setLang(l.code)}>
              <span className="radio" />
              <span className="grow">
                <b>{l.label}</b>
                <span className="sub">{t(l.code, "nav_buy")}</span>
              </span>
            </button>
          ))}
        </div>
      </section>
      <section className="section">
        <h2 className="section-title">{tr("support_title")}</h2>
        <div className="choices">
          <a className="choice" href={backend.supportWhatsApp} style={{ textDecoration: "none" }}>
            <span className="ico">
              <Icon.Chat />
            </span>
            <b className="grow">{tr("support_whatsapp")}</b>
            <span className="chev" style={{ width: 20, height: 20, color: "var(--ink-3)" }}>
              <Icon.Chevron />
            </span>
          </a>
          <a className="choice" href="tel:+263000000000" style={{ textDecoration: "none" }}>
            <span className="ico">
              <Icon.Call />
            </span>
            <b className="grow">{tr("support_call")}</b>
            <span className="chev" style={{ width: 20, height: 20, color: "var(--ink-3)" }}>
              <Icon.Chevron />
            </span>
          </a>
        </div>
        <div className="note" style={{ paddingTop: 4 }}>
          <Icon.Shield />
          <div>
            <b style={{ color: "var(--ink)" }}>{tr("safety_title")}</b>
            <div>{tr("leak_steps")}</div>
          </div>
        </div>
      </section>
      {backend.sandbox && <div className="sandbox-hint">{tr("sandbox_note")}</div>}
      <button className="btn ghost block" onClick={signOut}>
        {tr("settings_logout")}
      </button>
    </>
  );
}

const LEAK_PICTS = [<Icon.Window />, <Icon.NoFlame />, <Icon.Exit />];

function LeakAlert({ tr, meter, onSafe }: { tr: Tr; meter: Meter; onSafe: () => void }) {
  useEffect(() => {
    navigator.vibrate?.([400, 200, 400]);
  }, []);
  return (
    <div className="leak" role="alertdialog" aria-labelledby="leak-title">
      <div className="leak-top">
        <span className="warn">
          <Icon.Warn />
        </span>
        <h1 id="leak-title">{tr("leak_title")}</h1>
        <p className="lede">{tr("leak_shutoff")}</p>
      </div>
      <ol className="leak-steps">
        {tr("leak_steps")
          .split(/(?<=\.)\s+/)
          .map((s, i) => (
            <li key={s}>
              <span className="pict">
                {LEAK_PICTS[i]}
                <em>{i + 1}</em>
              </span>
              {s}
            </li>
          ))}
      </ol>
      <div className="leak-foot">
        <p>{tr("leak_tech_coming")}</p>
        <p className="meter">
          {tr("meter_label")} {formatMeterId(meter.id)} · {meter.suburb}
        </p>
        <a className="btn block call" href={`tel:${EMERGENCY_TEL}`}>
          <span className="row" style={{ gap: 10 }}>
            <Icon.Call /> {tr("leak_call")}
          </span>
          <span className="mono">{EMERGENCY_TEL}</span>
        </a>
        <button className="btn ghost block" onClick={onSafe}>
          {tr("leak_im_safe")}
        </button>
      </div>
    </div>
  );
}
