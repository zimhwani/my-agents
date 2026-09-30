import { useEffect, useMemo, useState } from "react";
import { LANGS, t, type StringKey } from "../../core/i18n/index.ts";
import { formatKg, formatMoney, fromUsd, gramsFor, PRESETS_USD } from "../../core/pricing.ts";
import type { PaymentInstruction } from "../../core/providers.ts";
import { formatMeterId, formatPhone, maskName, normalizeMeterId, normalizePhone } from "../../core/service.ts";
import { formatToken } from "../../core/token.ts";
import type { Currency, Customer, Lang, Meter, PayMethod, Payment } from "../../core/types.ts";
import { DEMO_PHONE, GOGO_METER, SPARE_METER, sandbox } from "../sandbox/index.ts";
import { Icon, Logo, timeAgo, useSandbox } from "../ui.tsx";

type Tr = (k: StringKey, v?: Record<string, string | number>) => string;
type Screen =
  | { name: "home" }
  | { name: "buy"; gift?: boolean }
  | { name: "pay"; paymentId: string; instruction: PaymentInstruction }
  | { name: "history" }
  | { name: "refill" }
  | { name: "settings" };

const SESSION = "gasguys.session";
const LANG = "gasguys.lang";
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
  const sb = useSandbox();
  const [customerId, setCustomerId] = useState<string | null>(() => read(SESSION));
  const customer = customerId ? sb.p.data.customers[customerId] ?? null : null;
  const [lang, setLangState] = useState<Lang>(() => customer?.lang ?? ((read(LANG) as Lang) || "en"));
  const tr: Tr = (k, v) => t(lang, k, v);
  const setLang = async (l: Lang) => {
    setLangState(l);
    write(LANG, l);
    if (customer) await sb.svc.updateCustomer(customer, { lang: l });
  };
  const signIn = (c: Customer) => {
    write(SESSION, c.id);
    setCustomerId(c.id);
  };
  const signOut = () => {
    write(SESSION, null);
    setCustomerId(null);
  };

  const meters = customer ? Object.values(sb.p.data.meters).filter((m) => m.customerId === customer.id) : [];
  if (!customer || meters.length === 0) return <Onboarding tr={tr} lang={lang} setLang={setLang} customer={customer} onDone={signIn} />;
  return <Main tr={tr} lang={lang} setLang={setLang} customer={customer} meters={meters} signOut={signOut} />;
}

// ── Onboarding ───────────────────────────────────────────────────────────────────────────────────

function Onboarding(props: { tr: Tr; lang: Lang; setLang: (l: Lang) => void; customer: Customer | null; onDone: (c: Customer) => void }) {
  const { tr, lang } = props;
  const [step, setStep] = useState<"lang" | "phone" | "otp" | "meter">(props.customer ? "meter" : "lang");
  const [phone, setPhone] = useState(formatPhone(DEMO_PHONE).slice(1));
  const [otp, setOtp] = useState("");
  const [meterId, setMeterId] = useState("");
  const [nickname, setNickname] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [customer, setCustomer] = useState<Customer | null>(props.customer);
  const idx = ["lang", "phone", "otp", "meter"].indexOf(step);

  const submitPhone = () => {
    const p = normalizePhone(phone);
    if (!p) return setErr(tr("err_invalid_phone"));
    setErr(null);
    setStep("otp");
  };
  const submitOtp = async () => {
    if (otp !== "123456") return setErr(tr("otp_wrong"));
    setErr(null);
    const c = await sandbox.svc.ensureCustomer(normalizePhone(phone)!, lang, nickname);
    setCustomer(c);
    if ((await sandbox.store.metersFor(c.id)).length) return props.onDone(c);
    setStep("meter");
  };
  const submitMeter = async () => {
    const res = await sandbox.svc.linkMeter(customer!.id, meterId);
    if (!res.ok) return setErr(tr(res.error === "meter_taken" ? "meter_taken" : "meter_not_found"));
    props.onDone(customer!);
  };

  return (
    <div className="app">
      <div className="app-head">
        <span className="brand">
          <Logo /> Gasguys
        </span>
        {step !== "lang" && <LangPill lang={lang} setLang={props.setLang} />}
      </div>
      <div className="app-body">
        <div className="steps">
          {[0, 1, 2, 3].map((i) => (
            <i key={i} className={i <= idx ? "on" : ""} />
          ))}
        </div>

        {step === "lang" && (
          <>
            <div className="hero" style={{ padding: 24 }}>
              <h1 style={{ fontSize: 28, position: "relative", zIndex: 1 }}>{tr("welcome_title")}</h1>
              <p className="sub" style={{ position: "relative", zIndex: 1 }}>{tr("welcome_body")}</p>
            </div>
            <h2 style={{ fontSize: 18 }}>
              {t("en", "choose_language")} · {t("sn", "choose_language")} · {t("nd", "choose_language")}
            </h2>
            {LANGS.map((l) => (
              <button key={l.code} className={`btn block ${lang === l.code ? "primary" : "ghost"}`} onClick={() => props.setLang(l.code)}>
                {l.label}
              </button>
            ))}
            <div className="notice ok">
              <Icon.Shield />
              {tr("trust_no_upfront")}
            </div>
            <button className="btn dark block" onClick={() => setStep("phone")}>
              {tr("btn_continue")}
            </button>
          </>
        )}

        {step === "phone" && (
          <>
            <h1 style={{ fontSize: 24 }}>{tr("sign_in")}</h1>
            <div className="field">
              <label>{tr("phone_label")}</label>
              <div className="prefix">
                <span>+263</span>
                <input inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder={tr("phone_hint")} />
              </div>
            </div>
            <div className="field">
              <label>{tr("your_name")}</label>
              <input className="input" value={nickname} onChange={(e) => setNickname(e.target.value)} placeholder="Tendai" />
            </div>
            {err && <div className="notice warn">{err}</div>}
            <button className="btn primary block" onClick={submitPhone}>
              {tr("btn_continue")}
            </button>
            <div className="sandbox-hint">
              <b>Sandbox:</b> {formatPhone(DEMO_PHONE).slice(1)} is Tendai, who already has a meter. Any other Zimbabwe mobile number starts a new account.
            </div>
          </>
        )}

        {step === "otp" && (
          <>
            <h1 style={{ fontSize: 24 }}>{tr("otp_label")}</h1>
            <p className="muted">{tr("otp_sent", { phone })}</p>
            <input className="input num" inputMode="numeric" maxLength={6} value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))} style={{ letterSpacing: ".4em", fontSize: 24, textAlign: "center" }} />
            {err && <div className="notice warn">{err}</div>}
            <button className="btn primary block" onClick={submitOtp} disabled={otp.length !== 6}>
              {tr("btn_confirm")}
            </button>
            <button className="link" onClick={() => setStep("phone")}>
              {tr("btn_back")}
            </button>
            <div className="sandbox-hint">
              <b>Sandbox:</b> the code is always <b>123456</b>. Production sends it by SMS through Supabase Auth.
            </div>
          </>
        )}

        {step === "meter" && (
          <>
            <h1 style={{ fontSize: 24 }}>{tr("meter_link_title")}</h1>
            <MeterSticker />
            <div className="field">
              <label>{tr("meter_enter_id")}</label>
              <input className="input num" inputMode="numeric" value={meterId} onChange={(e) => setMeterId(e.target.value)} placeholder="370 0000 0000" />
              <span className="muted">{tr("meter_id_hint")}</span>
            </div>
            {err && <div className="notice warn">{err}</div>}
            <button className="btn primary block" onClick={submitMeter} disabled={normalizeMeterId(meterId).length !== 11}>
              {tr("btn_continue")}
            </button>
            <div className="sandbox-hint">
              <b>Sandbox:</b> try the uninstalled meter <b>{formatMeterId(SPARE_METER)}</b>. In production a technician links the meter at install, and this step confirms it with an SMS code.
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function MeterSticker() {
  return (
    <svg viewBox="0 0 320 110" style={{ width: "100%", height: "auto" }} aria-hidden>
      <rect x="1" y="1" width="318" height="108" rx="16" fill="#fff" stroke="#e7e3dc" />
      <rect x="18" y="18" width="74" height="74" rx="8" fill="#14213D" />
      <path d="M30 30h20v20H30zM60 30h20v20H60zM30 60h20v20H30zM62 62h6v6h-6zM72 72h8v8h-8zM62 74h6v6h-6z" fill="#fff" />
      <text x="110" y="42" fontFamily="Plus Jakarta Sans" fontWeight="700" fontSize="14" fill="#14213D">GASGUYS SMART VALVE</text>
      <text x="110" y="72" fontFamily="ui-monospace, monospace" fontWeight="700" fontSize="22" fill="#FF6B1A">370 1234 5678</text>
      <text x="110" y="92" fontFamily="Inter" fontSize="11" fill="#6B7280">Meter no. · 11 digits</text>
    </svg>
  );
}

function LangPill({ lang, setLang }: { lang: Lang; setLang: (l: Lang) => void }) {
  return (
    <select className="lang-pill" value={lang} onChange={(e) => setLang(e.target.value as Lang)} aria-label="Language">
      {LANGS.map((l) => (
        <option key={l.code} value={l.code}>
          {l.label}
        </option>
      ))}
    </select>
  );
}

// ── Signed-in app ────────────────────────────────────────────────────────────────────────────────

function Main(props: { tr: Tr; lang: Lang; setLang: (l: Lang) => void; customer: Customer; meters: Meter[]; signOut: () => void }) {
  const { tr, customer, meters } = props;
  const [screen, setScreen] = useState<Screen>({ name: "home" });
  const [meterId, setMeterId] = useState(meters[0].id);
  const [dismissedLeak, setDismissedLeak] = useState<string | null>(null);
  const meter = meters.find((m) => m.id === meterId) ?? meters[0];
  const leakMeter = meters.find((m) => m.leak && dismissedLeak !== m.id);
  const go = (s: Screen) => setScreen(s);

  return (
    <div className="app">
      <div className="app-head">
        <span className="brand">
          <Logo /> Gasguys
        </span>
        <div className="row">
          <LangPill lang={props.lang} setLang={props.setLang} />
          <button className="lang-pill" onClick={() => go({ name: "settings" })} aria-label={tr("nav_settings")}>
            ⚙︎
          </button>
        </div>
      </div>
      <div className="app-body">
        {screen.name === "home" && <Home tr={tr} customer={customer} meters={meters} meter={meter} setMeterId={setMeterId} go={go} />}
        {screen.name === "buy" && <Buy tr={tr} customer={customer} meter={meter} gift={!!screen.gift} go={go} />}
        {screen.name === "pay" && <Pay tr={tr} paymentId={screen.paymentId} instruction={screen.instruction} go={go} />}
        {screen.name === "history" && <History tr={tr} customer={customer} meters={meters} />}
        {screen.name === "refill" && <Refill tr={tr} customer={customer} meter={meter} go={go} />}
        {screen.name === "settings" && <Settings tr={tr} lang={props.lang} setLang={props.setLang} customer={customer} signOut={props.signOut} />}
      </div>
      <nav className="nav">
        {(
          [
            ["home", "nav_home", <Icon.Home />],
            ["buy", "nav_buy", <Icon.Flame />],
            ["gift", "nav_gift", <Icon.Gift />],
            ["history", "nav_history", <Icon.Clock />],
          ] as const
        ).map(([name, key, icon]) => {
          const on = name === "gift" ? screen.name === "buy" && !!screen.gift : name === "buy" ? screen.name === "buy" && !screen.gift : screen.name === name;
          return (
            <button key={name} className={on ? "on" : ""} onClick={() => go(name === "gift" ? { name: "buy", gift: true } : ({ name } as Screen))}>
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

function Home(props: { tr: Tr; customer: Customer; meters: Meter[]; meter: Meter; setMeterId: (id: string) => void; go: (s: Screen) => void }) {
  const { tr, meter: m, go } = props;
  const days = sandbox.svc.daysLeft(m);
  const cylPct = Math.max(0, Math.min(100, (m.gasGrams / (m.cylinderKg * 1000)) * 100));
  const creditKg = m.creditGrams / 1000;
  const refill = Object.values(sandbox.p.data.refills).find((r) => r.meterId === m.id && r.status !== "delivered" && r.status !== "cancelled");
  const recent = Object.values(sandbox.p.data.payments)
    .filter((p) => p.meterId === m.id && p.status === "paid")
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 3);
  const lastToken = recent.find((p) => p.delivery === "token");
  const offlineHours = Math.floor((Date.now() - Date.parse(m.lastSeen)) / 3.6e6);

  return (
    <>
      <div className="row between">
        <div>
          <div className="muted">{tr("greeting", { name: props.customer.name.split(" ")[0] || "" })}</div>
          {props.meters.length > 1 ? (
            <select className="lang-pill" value={m.id} onChange={(e) => props.setMeterId(e.target.value)}>
              {props.meters.map((x) => (
                <option key={x.id} value={x.id}>
                  {formatMeterId(x.id)} · {x.suburb}
                </option>
              ))}
            </select>
          ) : (
            <b className="num">
              {tr("meter_label")} {formatMeterId(m.id)}
            </b>
          )}
        </div>
        <span className={`pill ${m.online ? "" : "warn"}`} title={m.online ? "" : tr("meter_offline")}>
          <Icon.Wifi /> {m.online ? timeAgo(m.lastSeen) : "Offline"}
        </span>
      </div>

      {!m.online && (
        <div className="notice warn">
          <Icon.Wifi />
          <div>
            {offlineHours >= 1 && `${tr("err_meter_offline", { hours: offlineHours })}. `}
            {lastToken?.token ? tr("token_enter", { kg: (lastToken.grams / 1000).toFixed(2) }) : tr("meter_offline")}
            {lastToken?.token && <div className="token" style={{ marginTop: 8 }}>{formatToken(lastToken.token)}</div>}
          </div>
        </div>
      )}

      <div className="hero">
        <div className="row between" style={{ position: "relative", zIndex: 1 }}>
          <div>
            <div className="sub">{tr("credit_balance")}</div>
            <div className="days num">{creditKg.toFixed(creditKg < 10 ? 2 : 1)} kg</div>
            <div className="sub" style={{ marginTop: 6, fontSize: 16, color: "#fff" }}>
              {days === 1 ? tr("days_left_one") : tr("days_left", { days })}
            </div>
          </div>
          <Gauge pct={Math.min(100, (days / 14) * 100)} />
        </div>
        <div className="row" style={{ marginTop: 14, gap: 8, position: "relative", zIndex: 1, flexWrap: "wrap" }}>
          {m.leak ? (
            <span className="pill bad">
              <span className="dot" /> {tr("leak_title")}
            </span>
          ) : m.valve === "open" ? (
            <span className="pill on">
              <span className="dot" /> {tr("valve_open")}
            </span>
          ) : (
            <span className="pill off">
              <span className="dot" /> {tr("valve_closed")}
            </span>
          )}
          <span className="pill" style={{ background: "rgba(255,255,255,.1)", color: "#fff", borderColor: "transparent" }}>
            ≈ {formatMoney(fromUsd((m.creditGrams / 1000) * sandbox.svc.tariff.usdPerKg, "USD"), "USD")}
          </span>
        </div>
      </div>

      {m.valve === "closed" && !m.leak && m.creditGrams <= 0 && <div className="notice warn">{tr("valve_closed_no_credit")}</div>}

      <button className="btn primary block" onClick={() => go({ name: "buy" })}>
        <Icon.Flame /> {tr("nav_buy")}
      </button>

      <div className="card stack">
        <div className="row between">
          <h3>
            {tr("cylinder")} · {m.cylinderKg} kg
          </h3>
          <span className="muted num">{formatKg(m.gasGrams)}</span>
        </div>
        <div className={`bar ${cylPct < 5 ? "empty" : cylPct < 20 ? "low" : ""}`}>
          <i style={{ width: `${cylPct}%` }} />
        </div>
        {refill ? (
          <div className="notice info">
            <Icon.Cylinder />
            <div>
              <b>{tr("refill_title")}</b> · {tr(`refill_status_${refill.status}` as StringKey)} · {refill.slot}
            </div>
          </div>
        ) : cylPct < 20 ? (
          <>
            <p className="muted" style={{ margin: 0 }}>
              {tr("low_cylinder_body", { kg: (m.gasGrams / 1000).toFixed(1) })}
            </p>
            <button className="btn ghost block" onClick={() => go({ name: "refill" })}>
              <Icon.Cylinder /> {tr("refill_title")}
            </button>
          </>
        ) : (
          <button className="link" style={{ alignSelf: "flex-start" }} onClick={() => go({ name: "refill" })}>
            {tr("refill_title")} →
          </button>
        )}
      </div>

      <div className="card">
        <div className="row between">
          <h3>{tr("history_title")}</h3>
          <button className="link" onClick={() => go({ name: "history" })}>
            {tr("see_all")}
          </button>
        </div>
        {recent.length === 0 && <p className="muted">{tr("history_empty")}</p>}
        {recent.map((p) => (
          <PaymentRow key={p.id} tr={tr} p={p} customer={props.customer} />
        ))}
      </div>

      <div className="card row" style={{ gap: 12 }}>
        <div className="ico" style={{ background: "#fff3ec", color: "var(--flame)" }}>
          <Icon.Gift />
        </div>
        <div style={{ flex: 1 }}>
          <b>{tr("gift_title")}</b>
          <div className="muted">{tr("gift_body")}</div>
        </div>
        <button className="btn sm ghost" onClick={() => go({ name: "buy", gift: true })}>
          {tr("nav_gift")}
        </button>
      </div>
    </>
  );
}

function Gauge({ pct }: { pct: number }) {
  const r = 38;
  const c = Math.PI * r;
  const color = pct < 15 ? "#E0322B" : pct < 35 ? "#FFC53D" : "#1FA35C";
  return (
    <svg width="104" height="62" viewBox="0 0 104 62" className="gauge" aria-hidden>
      <path d="M14 56a38 38 0 0 1 76 0" fill="none" stroke="rgba(255,255,255,.15)" strokeWidth="12" strokeLinecap="round" />
      <path d="M14 56a38 38 0 0 1 76 0" fill="none" stroke={color} strokeWidth="12" strokeLinecap="round" strokeDasharray={`${(c * pct) / 100} ${c}`} style={{ transition: "stroke-dasharray .6s" }} />
      <g transform="translate(40 26)" fill="#FF6B1A">
        <path d="M12 3c1 3.5 5 5.5 5 10a5 5 0 0 1-10 0c0-2.6 1.4-4 2.6-5.4.3 1.8 1.1 2.6 2.1 2.9-.7-2.8 0-5.3.3-7.5z" />
      </g>
    </svg>
  );
}

function PaymentRow({ tr, p, customer }: { tr: Tr; p: Payment; customer: Customer }) {
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
    <div className="list-item">
      <div className="ico" style={{ background: failed ? "#eef0f3" : giftIn || giftOut ? "#fff3ec" : "var(--msasa-bg)", color: failed ? "#6b7280" : giftIn || giftOut ? "var(--flame)" : "#13703f" }}>
        {giftIn || giftOut ? <Icon.Gift /> : <Icon.Flame />}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 600, fontSize: 14.5 }}>{label}</div>
        <div className="muted" style={{ fontSize: 12.5 }}>
          {new Date(p.createdAt).toLocaleString()} · {p.method === "ecocash" ? "EcoCash" : p.method === "innbucks" ? "InnBucks" : "Card"} · {p.reference}
          {failed && ` · ${p.status}`}
        </div>
      </div>
    </div>
  );
}

// ── Buy and gift ─────────────────────────────────────────────────────────────────────────────────

const METHOD_STYLE: Record<PayMethod, { bg: string; short: string; name: string }> = {
  ecocash: { bg: "#0d4b9a", short: "Eco", name: "EcoCash" },
  innbucks: { bg: "#e0322b", short: "Inn", name: "InnBucks" },
  card: { bg: "#14213d", short: "VISA", name: "Visa / Mastercard" },
};

function Buy(props: { tr: Tr; customer: Customer; meter: Meter; gift: boolean; go: (s: Screen) => void }) {
  const { tr, customer, gift } = props;
  const tariff = sandbox.svc.tariff;
  const [currency, setCurrency] = useState<Currency>("USD");
  const [preset, setPreset] = useState<number | null>(gift ? 5 : 2);
  const [other, setOther] = useState("");
  const [method, setMethod] = useState<PayMethod>(gift ? "card" : "ecocash");
  const [payPhone, setPayPhone] = useState(formatPhone(customer.phone));
  const [recipientInput, setRecipientInput] = useState(gift ? formatMeterId(GOGO_METER) : "");
  const [message, setMessage] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [recipient, setRecipient] = useState<{ meterId: string; name: string; suburb: string } | null>(null);
  const [confirmed, setConfirmed] = useState(false);

  useEffect(() => {
    setConfirmed(false);
    setRecipient(null);
    if (!gift) return;
    const id = normalizeMeterId(recipientInput);
    if (id.length === 11) void sandbox.svc.giftLookup(id).then(setRecipient);
  }, [recipientInput, gift]);

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
    const res = await sandbox.svc.startPurchase({
      meterId: targetMeter!,
      amount,
      currency,
      method,
      payerPhone: phone,
      payerName: customer.name,
      payerCustomerId: customer.id,
      giftMessage: gift ? message || null : null,
      channel: "web",
    });
    setBusy(false);
    if (!res.ok) return setErr(res.error === "amount_too_small" ? tr("err_amount_min", { amount: formatMoney(fromUsd(tariff.minUsd, currency, tariff), currency) }) : tr("err_generic"));
    props.go({ name: "pay", paymentId: res.payment.id, instruction: res.instruction });
  };

  return (
    <>
      <h1 style={{ fontSize: 24 }}>{gift ? tr("gift_title") : tr("buy_title")}</h1>
      {gift ? (
        <div className="card stack">
          <p className="muted" style={{ margin: 0 }}>
            {tr("gift_body")}
          </p>
          <div className="field">
            <label>{tr("recipient_meter")}</label>
            <input className="input num" inputMode="numeric" value={recipientInput} onChange={(e) => setRecipientInput(e.target.value)} placeholder="370 0000 0000" />
          </div>
          {recipient && (
            <div className={`notice ${confirmed ? "ok" : "info"}`} style={{ alignItems: "center" }}>
              <div style={{ flex: 1 }}>{tr("recipient_name_check", { name: `${recipient.name} · ${recipient.suburb}` })}</div>
              {!confirmed && (
                <button className="btn sm dark" onClick={() => setConfirmed(true)}>
                  {tr("yes")}
                </button>
              )}
            </div>
          )}
          {normalizeMeterId(recipientInput).length === 11 && !recipient && <div className="notice warn">{tr("meter_not_found")}</div>}
          <input className="input" value={message} onChange={(e) => setMessage(e.target.value)} placeholder={tr("gift_message")} style={{ fontSize: 15 }} />
        </div>
      ) : (
        <div className="muted">
          {tr("meter_label")} <b className="num">{formatMeterId(props.meter.id)}</b> · {props.meter.suburb}
        </div>
      )}

      <div className="card stack">
        <div className="row between">
          <b>{tr("amount")}</b>
          <div className="seg">
            {(["USD", "ZWG"] as Currency[]).map((c) => (
              <button
                key={c}
                className={currency === c ? "on" : ""}
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
        <div className="chips">
          {presets.map((a) => (
            <button key={a} className={`chip ${preset === a ? "on" : ""}`} onClick={() => setPreset(a)}>
              {formatMoney(a, currency).replace(".00", "")}
              <small>≈ {formatKg(gramsFor(a, currency, tariff))}</small>
            </button>
          ))}
          <button className={`chip ${preset === null ? "on" : ""}`} onClick={() => setPreset(null)}>
            {tr("amount_other")}
            <small>{currency === "USD" ? "$" : "ZiG"}</small>
          </button>
        </div>
        {preset === null && <input className="input num" inputMode="decimal" autoFocus value={other} onChange={(e) => setOther(e.target.value)} placeholder="0.00" />}
        {grams > 0 && (
          <div className="muted">
            {tr("amount_gets_you", { amount: formatMoney(amount, currency), kg: (grams / 1000).toFixed(2) })} ·{" "}
            {tr("days_left", { days: Math.floor(grams / props.meter.avgDailyGrams) })}
          </div>
        )}
      </div>

      <div className="card stack">
        <b>{tr("pay_with")}</b>
        {(["ecocash", "innbucks", "card"] as PayMethod[]).map((mth) => (
          <button key={mth} className={`method ${method === mth ? "on" : ""}`} onClick={() => setMethod(mth)}>
            <span className="logo" style={{ background: METHOD_STYLE[mth].bg }}>
              {METHOD_STYLE[mth].short}
            </span>
            <span style={{ flex: 1 }}>
              <b>{METHOD_STYLE[mth].name}</b>
              <span className="muted">{mth === "ecocash" ? tr("confirm_on_phone") : mth === "innbucks" ? "Code · QR" : tr("gift_from_card")}</span>
            </span>
          </button>
        ))}
        {method === "ecocash" && (
          <div className="field">
            <label>{tr("pay_number")}</label>
            <input className="input num" inputMode="tel" value={payPhone} onChange={(e) => setPayPhone(e.target.value)} />
          </div>
        )}
      </div>

      {err && <div className="notice warn">{err}</div>}
      <div className="stack" style={{ position: "sticky", bottom: 0, background: "var(--mist)", paddingTop: 8 }}>
        <div className="row between muted">
          <span>✓ {tr("fee_none")}</span>
          <span>{tr("trust_secure")}</span>
        </div>
        <button className="btn primary block" disabled={!canPay} onClick={pay}>
          {amount > 0 ? `${tr("btn_confirm")} · ${formatMoney(amount, currency)}` : tr("btn_confirm")}
        </button>
      </div>
    </>
  );
}

function Pay({ tr, paymentId, instruction, go }: { tr: Tr; paymentId: string; instruction: PaymentInstruction; go: (s: Screen) => void }) {
  const sb = useSandbox();
  const p = sb.p.data.payments[paymentId];
  const prompt = sb.p.prompts.find((x) => x.reference === p?.reference);
  const [secs, setSecs] = useState(90);
  useEffect(() => {
    const t = setInterval(() => setSecs((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, []);
  const shareText = useMemo(() => (p ? `Gasguys receipt ${p.reference}: ${formatMoney(p.amount, p.currency)} = ${(p.grams / 1000).toFixed(2)} kg for meter ${formatMeterId(p.meterId)}` : ""), [p]);
  if (!p) return null;

  if (p.status === "paid")
    return (
      <div className="stack center">
        <div className="big-tick">
          <Icon.Check />
        </div>
        <h1 style={{ fontSize: 24 }}>{tr("payment_success")}</h1>
        <p style={{ fontSize: 17, margin: 0 }}>
          {p.delivery === "online" ? tr("credit_sent", { kg: (p.grams / 1000).toFixed(2) }) : tr("token_enter", { kg: (p.grams / 1000).toFixed(2) })}
        </p>
        {p.gift && <div className="notice ok">🎁 {tr("gift_sent", { name: ownerName(p.meterId) })}</div>}
        <div className="card stack" style={{ textAlign: "left" }}>
          <div className="row between">
            <span className="muted">{tr("receipt_ref", { ref: "" }).replace(/[:.]?\s*$/, "")}</span>
            <b className="num">{p.reference}</b>
          </div>
          <div className="row between">
            <span className="muted">{tr("amount")}</span>
            <b className="num">{formatMoney(p.amount, p.currency)}</b>
          </div>
          <div className="row between">
            <span className="muted">{tr("meter_label")}</span>
            <b className="num">{formatMeterId(p.meterId)}</b>
          </div>
          {p.token && p.delivery === "token" && (
            <>
              <span className="muted">{tr("token_title")}</span>
              <div className="token">{formatToken(p.token)}</div>
            </>
          )}
        </div>
        <a className="btn ghost block" href={`https://wa.me/?text=${encodeURIComponent(shareText)}`} target="_blank" rel="noreferrer" style={{ textDecoration: "none" }}>
          Share on WhatsApp
        </a>
        <button className="btn dark block" onClick={() => go({ name: "home" })}>
          {tr("btn_done")}
        </button>
      </div>
    );

  if (p.status !== "pending")
    return (
      <div className="stack center">
        <div className="big-tick" style={{ background: "var(--granite)" }}>
          <span style={{ color: "#fff", fontSize: 40, fontWeight: 800 }}>!</span>
        </div>
        <h1 style={{ fontSize: 22 }}>{p.status === "expired" ? tr("payment_timeout") : tr("payment_failed")}</h1>
        <button className="btn primary block" onClick={() => go({ name: "buy", gift: p.gift })}>
          {tr("btn_retry")}
        </button>
        <button className="btn ghost block" onClick={() => go({ name: "home" })}>
          {tr("btn_back")}
        </button>
      </div>
    );

  return (
    <div className="stack center">
      <h1 style={{ fontSize: 22 }}>{tr("waiting_payment")}</h1>
      <p className="muted" style={{ margin: 0 }}>
        {tr("review_summary", { amount: formatMoney(p.amount, p.currency), meter: formatMeterId(p.meterId) })}
      </p>
      {instruction.kind === "ussd_push" && (
        <div className="card stack">
          <div style={{ fontSize: 56 }}>📲</div>
          <b style={{ fontSize: 18 }}>{tr("confirm_on_phone")}</b>
          <span className="muted">
            EcoCash · {formatPhone(instruction.phone)} · <span className="num">{secs}s</span>
          </span>
        </div>
      )}
      {instruction.kind === "code" && (
        <div className="card stack">
          <span className="muted">InnBucks</span>
          <div className="token" style={{ fontSize: 34 }}>
            {instruction.code.replace(/(\d{3})(\d{3})/, "$1 $2")}
          </div>
          <span>{tr("innbucks_code", { code: instruction.code })}</span>
          <a className="btn ghost block" href={instruction.deepLink} style={{ textDecoration: "none" }}>
            Open InnBucks
          </a>
        </div>
      )}
      {instruction.kind === "redirect" && (
        <div className="card stack">
          <div style={{ fontSize: 48 }}>💳</div>
          <a className="btn primary block" href={instruction.url} style={{ textDecoration: "none" }}>
            {tr("pay_card")}
          </a>
        </div>
      )}
      <div className="muted">{tr("receipt_ref", { ref: p.reference })}</div>
      {prompt && (
        <div className="sandbox-hint stack">
          <span>
            <b>Sandbox:</b> play the customer. {prompt.method === "ecocash" ? "Enter a PIN on the WhatsApp phone's EcoCash prompt, or:" : "Approve here:"}
          </span>
          <div className="row" style={{ justifyContent: "center" }}>
            <button className="btn sm dark" onClick={() => sandbox.resolvePrompt(prompt.providerRef, "paid")}>
              Approve
            </button>
            <button className="btn sm ghost" onClick={() => sandbox.resolvePrompt(prompt.providerRef, "failed")}>
              Decline
            </button>
          </div>
        </div>
      )}
      <button className="link" onClick={() => go({ name: "home" })}>
        {tr("btn_back")}
      </button>
    </div>
  );
}

const ownerName = (meterId: string) => {
  const owner = sandbox.p.data.customers[sandbox.p.data.meters[meterId]?.customerId ?? ""];
  return owner ? maskName(owner.name) : formatMeterId(meterId);
};

/** Zimbabwe fire brigade. Confirm the right number (and a Gasguys 24h safety line) before launch. */
const EMERGENCY_TEL = "993";

// ── History, refill, settings, leak ──────────────────────────────────────────────────────────────

function History({ tr, customer, meters }: { tr: Tr; customer: Customer; meters: Meter[] }) {
  const sb = useSandbox();
  const mine = new Set(meters.map((m) => m.id));
  const list = Object.values(sb.p.data.payments)
    .filter((p) => (p.customerId === customer.id || mine.has(p.meterId)) && p.status !== "pending")
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return (
    <>
      <h1 style={{ fontSize: 24 }}>{tr("history_title")}</h1>
      <div className="card">
        {list.length === 0 && <p className="muted">{tr("history_empty")}</p>}
        {list.map((p) => (
          <PaymentRow key={p.id} tr={tr} p={p} customer={customer} />
        ))}
      </div>
    </>
  );
}

const SLOTS: StringKey[] = ["refill_slot_today_pm", "refill_slot_tomorrow_am", "refill_slot_tomorrow_pm"];

function Refill({ tr, customer, meter, go }: { tr: Tr; customer: Customer; meter: Meter; go: (s: Screen) => void }) {
  const sb = useSandbox();
  const [size, setSize] = useState(meter.cylinderKg);
  const [slot, setSlot] = useState<StringKey>(SLOTS[1]);
  const [landmark, setLandmark] = useState("");
  const open = Object.values(sb.p.data.refills).find((r) => r.meterId === meter.id && r.status !== "delivered" && r.status !== "cancelled");
  const steps = ["requested", "scheduled", "out_for_delivery", "delivered"] as const;

  if (open)
    return (
      <>
        <h1 style={{ fontSize: 24 }}>{tr("refill_title")}</h1>
        <div className="notice ok">{tr("refill_requested", { phone: formatPhone(customer.phone) })}</div>
        <div className="card stack">
          {steps.map((s, i) => {
            const on = steps.indexOf(open.status as (typeof steps)[number]) >= i;
            return (
              <div key={s} className="row">
                <span className="ico" style={{ background: on ? "var(--msasa)" : "#eef0f3", color: "#fff", width: 28, height: 28, borderRadius: 99 }}>
                  {on ? "✓" : ""}
                </span>
                <span style={{ fontWeight: on ? 700 : 500 }}>{tr(`refill_status_${s}` as StringKey)}</span>
              </div>
            );
          })}
          <span className="muted">{open.slot}</span>
        </div>
        <div className="sandbox-hint">
          <b>Sandbox:</b> move the order along from the Ops console.
        </div>
        <button className="btn ghost block" onClick={() => go({ name: "home" })}>
          {tr("btn_back")}
        </button>
      </>
    );

  return (
    <>
      <h1 style={{ fontSize: 24 }}>{tr("refill_title")}</h1>
      <p className="muted" style={{ margin: 0 }}>
        {tr("refill_body")}
      </p>
      <div className="card stack">
        <b>{tr("refill_size")}</b>
        <div className="chips">
          {[9, 14, 19, 48].map((k) => (
            <button key={k} className={`chip ${size === k ? "on" : ""}`} onClick={() => setSize(k)}>
              {k} kg
            </button>
          ))}
        </div>
        <b>{tr("refill_when")}</b>
        <div className="chips">
          {SLOTS.map((s) => (
            <button key={s} className={`chip ${slot === s ? "on" : ""}`} onClick={() => setSlot(s)}>
              {tr(s)}
            </button>
          ))}
        </div>
        <div className="field">
          <label>{tr("refill_address")}</label>
          <input className="input" value={landmark} onChange={(e) => setLandmark(e.target.value)} placeholder="Opposite Mbare Musika, gate 3" style={{ fontSize: 15 }} />
        </div>
      </div>
      <button className="btn primary block" onClick={() => sandbox.svc.requestRefill(meter.id, `${tr(slot)} · ${size} kg${landmark ? " · " + landmark : ""}`)}>
        {tr("btn_confirm")}
      </button>
    </>
  );
}

function Settings({ tr, lang, setLang, customer, signOut }: { tr: Tr; lang: Lang; setLang: (l: Lang) => void; customer: Customer; signOut: () => void }) {
  return (
    <>
      <h1 style={{ fontSize: 24 }}>{tr("nav_settings")}</h1>
      <div className="card stack">
        <b>{customer.name || formatPhone(customer.phone)}</b>
        <span className="muted num">{formatPhone(customer.phone)}</span>
      </div>
      <div className="card stack">
        <b>{tr("language")}</b>
        {LANGS.map((l) => (
          <button key={l.code} className={`btn block ${lang === l.code ? "primary" : "ghost"}`} onClick={() => setLang(l.code)}>
            {l.label}
          </button>
        ))}
      </div>
      <div className="card stack">
        <b>{tr("support_title")}</b>
        <a className="btn ghost block" href="#/whatsapp" style={{ textDecoration: "none" }}>
          {tr("support_whatsapp")}
        </a>
        <a className="btn ghost block" href="tel:+263000000000" style={{ textDecoration: "none" }}>
          {tr("support_call")}
        </a>
        <div className="notice info">
          <Icon.Shield />
          <div>
            <b>{tr("safety_title")}</b>
            <div>{tr("leak_steps")}</div>
          </div>
        </div>
      </div>
      <div className="notice warn">{tr("sandbox_note")}</div>
      <button className="btn ghost block" onClick={signOut}>
        {tr("settings_logout")}
      </button>
    </>
  );
}

function LeakAlert({ tr, meter, onSafe }: { tr: Tr; meter: Meter; onSafe: () => void }) {
  useEffect(() => {
    navigator.vibrate?.([400, 200, 400]);
  }, []);
  return (
    <div className="leak" role="alertdialog" aria-labelledby="leak-title">
      <div style={{ width: 64, height: 64 }}>
        <Icon.Warn />
      </div>
      <h1 id="leak-title">{tr("leak_title")}</h1>
      <p style={{ fontSize: 18, margin: 0 }}>{tr("leak_shutoff")}</p>
      <ol>
        {tr("leak_steps")
          .split(/(?<=\.)\s+/)
          .map((s) => (
            <li key={s}>{s}</li>
          ))}
      </ol>
      <p style={{ margin: 0, opacity: 0.9 }}>{tr("leak_tech_coming")}</p>
      <p className="num" style={{ margin: 0, opacity: 0.8 }}>
        {tr("meter_label")} {formatMeterId(meter.id)} · {meter.suburb}
      </p>
      <div style={{ flex: 1 }} />
      <a className="btn block" href={`tel:${EMERGENCY_TEL}`} style={{ background: "#fff", color: "var(--alert)", textDecoration: "none" }}>
        {tr("leak_call")}
      </a>
      <button className="btn ghost block" onClick={onSafe}>
        {tr("leak_im_safe")}
      </button>
    </div>
  );
}
