import { useEffect, useRef, useState } from "react";
import type { Inbound } from "../../core/bot.ts";
import type { OutMessage } from "../../core/providers.ts";
import { formatMoney } from "../../core/pricing.ts";
import { formatPhone, normalizePhone } from "../../core/service.ts";
import { DEMO_PHONE, GOGO_PHONE, sandbox, type ChatEntry } from "../sandbox/index.ts";
import { Icon, Mark, useSandbox } from "../ui.tsx";

const Verified = () => (
  <svg viewBox="0 0 24 24" aria-label="Verified">
    <path d="M12 1.5l2.6 2 3.2-.3.9 3.1 2.8 1.6-1 3.1 1 3.1-2.8 1.6-.9 3.1-3.2-.3-2.6 2-2.6-2-3.2.3-.9-3.1-2.8-1.6 1-3.1-1-3.1 2.8-1.6.9-3.1 3.2.3z" fill="#fff" />
    <path d="M7.8 12.2l2.8 2.8 5.6-5.6" fill="none" stroke="#008069" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
const Ticks = () => (
  <svg viewBox="0 0 16 11" aria-label="Read">
    <path d="M1 5.8l3 3L10.5 2M6.5 8.3l.5.5L13.5 2" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const PHONES = [
  { phone: DEMO_PHONE, label: "Tendai (has meter)" },
  { phone: GOGO_PHONE, label: "Gogo Ncube (isiNdebele)" },
  { phone: "263779990001", label: "New customer" },
];

/**
 * A WhatsApp look-alike that sends messages through the same bot the Cloud API webhook uses. It also
 * plays the phone's EcoCash USSD prompt and the InnBucks app, so a whole purchase can be done here.
 */
export function WhatsAppSim() {
  const sb = useSandbox();
  const [phone, setPhone] = useState(DEMO_PHONE);
  const [custom, setCustom] = useState("");
  const [draft, setDraft] = useState("");
  const [list, setList] = useState<Extract<OutMessage, { kind: "list" }> | null>(null);
  const [pin, setPin] = useState("");
  const body = useRef<HTMLDivElement>(null);
  const chat: ChatEntry[] = sb.p.chats[phone] ?? [];
  const profileName = sb.p.data.customers[Object.keys(sb.p.data.customers).find((k) => sb.p.data.customers[k].phone === phone) ?? ""]?.name;
  const prompt = sb.p.prompts.find((p) => p.phone === phone && p.method !== "card");

  useEffect(() => {
    body.current?.scrollTo({ top: body.current.scrollHeight, behavior: "smooth" });
  }, [chat.length, phone]);

  const send = (msg: Inbound) => void sandbox.whatsappInbound(phone, { ...msg, profileName: profileName ?? "Guest" });
  const lastOut = chat.map((c, i) => (c.dir === "out" ? i : -1)).filter((i) => i >= 0);
  const live = new Set(lastOut.slice(-3)); // only recent buttons stay tappable, like a real chat

  return (
    <div className="wa">
      <div className="wa-head">
        <div className="av">
          <Mark size={28} />
        </div>
        <div>
          <b>
            Gasguys <Verified />
          </b>
          <small>Business account</small>
        </div>
        <select
          value={PHONES.some((p) => p.phone === phone) ? phone : "custom"}
          onChange={(e) => {
            if (e.target.value === "custom") return setCustom(" ");
            setCustom("");
            setPhone(e.target.value);
          }}
          aria-label="Simulated phone"
        >
          {PHONES.map((p) => (
            <option key={p.phone} value={p.phone}>
              {p.label}
            </option>
          ))}
          <option value="custom">Other number…</option>
        </select>
      </div>
      {custom && (
        <div className="wa-input" style={{ background: "#dff1ee" }}>
          <input placeholder="077 000 0000" value={custom.trim()} onChange={(e) => setCustom(e.target.value || " ")} />
          <button
            onClick={() => {
              const p = normalizePhone(custom);
              if (p) {
                setPhone(p);
                setCustom("");
              }
            }}
          >
            <Icon.Check />
          </button>
        </div>
      )}
      <div className="wa-body" ref={body}>
        <div className="bubble sys">
          Simulated chat for {formatPhone(phone)}. Say “hi” to start. Messages go through the real bot code.
        </div>
        {chat.map((c, i) => (
          <Bubble key={i} entry={c} live={live.has(i)} onButton={(id, title) => send({ type: "button", id, title })} onList={setList} />
        ))}
      </div>
      <form
        className="wa-input"
        onSubmit={(e) => {
          e.preventDefault();
          if (!draft.trim()) return;
          send({ type: "text", text: draft.trim() });
          setDraft("");
        }}
      >
        <input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder="Message" />
        <button type="submit" aria-label="Send">
          <Icon.Send />
        </button>
      </form>

      {list && (
        <div className="sheet-bg" onClick={() => setList(null)}>
          <div className="sheet" onClick={(e) => e.stopPropagation()}>
            <h4>{list.button}</h4>
            {list.rows.map((r) => (
              <button
                key={r.id}
                onClick={() => {
                  setList(null);
                  send({ type: "button", id: r.id, title: r.title });
                }}
              >
                {r.title}
                {r.description && <small>{r.description}</small>}
              </button>
            ))}
          </div>
        </div>
      )}

      {prompt && (
        <div className="ussd">
          <div className="ussd-box">
            {prompt.method === "ecocash" ? (
              <>
                <div>
                  <b>EcoCash</b>
                </div>
                <div style={{ marginTop: 6 }}>
                  Pay {formatMoney(prompt.amount, prompt.currency)} to GASGUYS. Ref {prompt.reference}. Enter PIN to confirm:
                </div>
              </>
            ) : (
              <>
                <div>
                  <b>InnBucks</b>
                </div>
                <div style={{ marginTop: 6 }}>
                  Pay code {prompt.code}: {formatMoney(prompt.amount, prompt.currency)} to Gasguys. Enter PIN to approve:
                </div>
              </>
            )}
            <input type="password" inputMode="numeric" maxLength={4} value={pin} onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))} autoFocus />
            <div className="muted" style={{ fontSize: 11.5 }}>
              Sandbox: any 4 digits approve.
            </div>
            <div className="acts">
              <button
                onClick={() => {
                  setPin("");
                  void sandbox.resolvePrompt(prompt.providerRef, "failed");
                }}
              >
                Cancel
              </button>
              <button
                disabled={pin.length !== 4}
                onClick={() => {
                  setPin("");
                  void sandbox.resolvePrompt(prompt.providerRef, "paid");
                }}
              >
                Send
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Bubble({
  entry,
  live,
  onButton,
  onList,
}: {
  entry: ChatEntry;
  live: boolean;
  onButton: (id: string, title: string) => void;
  onList: (m: Extract<OutMessage, { kind: "list" }>) => void;
}) {
  const time = new Date(entry.at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  if (entry.dir === "in") {
    const m = entry.msg as Inbound;
    return (
      <div className="bubble in">
        {m.type === "text" ? m.text : m.title ?? m.id}
        <time>
          {time} <Ticks />
        </time>
      </div>
    );
  }
  const m = entry.msg as OutMessage;
  return (
    <>
      <div className="bubble out">
        {m.kind === "template" && <div className="tpl">Template · {m.name}</div>}
        {m.text}
        <time>{time}</time>
      </div>
      {m.kind === "buttons" && (
        <div className="wa-btns">
          {m.buttons.map((b) => (
            <button key={b.id} disabled={!live} onClick={() => onButton(b.id, b.title)}>
              {b.title}
            </button>
          ))}
        </div>
      )}
      {m.kind === "list" && (
        <div className="wa-btns">
          <button disabled={!live} onClick={() => onList(m)}>
            <Icon.List /> {m.button}
          </button>
        </div>
      )}
    </>
  );
}
