"use client";
import { useEffect, useRef, useState } from "react";
import type { StoredKeys } from "@/lib/client";
import { CloseIcon } from "./Icons";

export type Theme = "system" | "light" | "dark";

export function SettingsDrawer({ open, onClose, keys, onSaveKeys, isSample, claude, theme, onTheme, handsFree, onHandsFree, speakReplies, onSpeakReplies }: {
  open: boolean;
  onClose: () => void;
  keys: StoredKeys;
  onSaveKeys: (k: StoredKeys) => void;
  isSample: boolean;
  claude: boolean;
  theme: Theme;
  onTheme: (t: Theme) => void;
  handsFree: boolean;
  onHandsFree: (v: boolean) => void;
  speakReplies: boolean;
  onSpeakReplies: (v: boolean) => void;
}) {
  const [draft, setDraft] = useState(keys);
  const [show, setShow] = useState(false);
  const first = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (!open) return;
    setDraft(keys);
    first.current?.focus();
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, keys, onClose]);
  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} />
      <aside className="drawer" role="dialog" aria-modal="true" aria-label="Settings">
        <div className="drawer-head">
          <h2>Settings</h2>
          <button className="icon-btn" onClick={onClose} aria-label="Close settings"><CloseIcon /></button>
        </div>
        <div className="drawer-body">
          <section>
            <h3>Live fares</h3>
            <div className="status-line">
              <span className={`pill ${isSample ? "sample" : "live"}`}>{isSample ? "Not connected" : "Connected"}</span>
              <span className="muted">{isSample ? "Showing sample fares." : "Google Flights. Each date checked uses 1 search."}</span>
            </div>
            <label className="field">SerpApi key (free at serpapi.com)
              <span className="keyfield">
                <input ref={first} id="serpapi-key" type={show ? "text" : "password"} autoComplete="off" value={draft.serpApiKey} placeholder="Paste your key" onChange={(e) => setDraft({ ...draft, serpApiKey: e.target.value })} />
                <button type="button" className="btn small" onClick={() => setShow(!show)}>{show ? "Hide" : "Show"}</button>
              </span>
            </label>
          </section>
          <section>
            <h3>Smarter understanding (optional)</h3>
            <p className="muted small" style={{ margin: 0 }}>Now using: {claude ? "Claude (smart)" : "Basic (built-in)"}. An Anthropic key lets me understand free-form requests.</p>
            <label className="field">Anthropic key
              <input id="anthropic-key" type={show ? "text" : "password"} autoComplete="off" value={draft.anthropicKey} placeholder="sk-ant-…" onChange={(e) => setDraft({ ...draft, anthropicKey: e.target.value })} />
            </label>
            <p className="muted small" style={{ margin: 0 }}>Keys stay in this browser and are sent only with your own searches.</p>
          </section>
          <div className="editor-foot">
            <button className="btn primary" onClick={() => { onSaveKeys(draft); onClose(); }}>Save</button>
            <button className="btn danger-text" onClick={() => { const empty = { serpApiKey: "", anthropicKey: "" }; setDraft(empty); onSaveKeys(empty); }}>Remove keys</button>
          </div>
          <section>
            <h3>Appearance</h3>
            <div className="seg" role="group" aria-label="Theme">
              {(["system", "light", "dark"] as Theme[]).map((t) => (
                <button key={t} aria-pressed={theme === t} onClick={() => onTheme(t)}>{t[0].toUpperCase() + t.slice(1)}</button>
              ))}
            </div>
          </section>
          <section>
            <h3>Voice</h3>
            <div className="toggle-row"><span>Hands-free: keep listening after each reply</span><button className="switch" role="switch" aria-checked={handsFree} aria-label="Hands-free" onClick={() => onHandsFree(!handsFree)} /></div>
            <div className="toggle-row"><span>Read replies aloud</span><button className="switch" role="switch" aria-checked={speakReplies} aria-label="Read replies aloud" onClick={() => onSpeakReplies(!speakReplies)} /></div>
          </section>
        </div>
      </aside>
    </>
  );
}
