"use client";
import { useState, type ReactNode } from "react";
import type { UseSpeech } from "@/hooks/useSpeech";
import { SendIcon } from "./Icons";
import { MIC_CAPTION, MicButton, micState } from "./MicButton";

/** The hero: mic, what you said, the short reply, what the agent understood. */
export function Conversation({ speech, heard, reply, busy, busyText, error, onRetry, suggestions, onCommand, handsFree, understood }: {
  speech: UseSpeech;
  heard: string;
  reply: string;
  busy: boolean;
  busyText: string;
  error: string | null;
  onRetry: () => void;
  suggestions: string[];
  onCommand: (text: string) => void;
  handsFree: boolean;
  understood: ReactNode;
}) {
  const [typed, setTyped] = useState("");
  const send = () => {
    if (!typed.trim()) return;
    onCommand(typed.trim());
    setTyped("");
  };
  const state = micState(speech, busy);
  return (
    <section className="card convo" aria-label="Talk to the agent">
      <div className="mic-col">
        <MicButton speech={speech} busy={busy} />
        <span className="mic-caption">{speech.supported ? MIC_CAPTION[state] : "Voice needs Chrome, Edge or Safari"}</span>
        {handsFree && <span className="tag">Hands-free</span>}
        {state === "speaking" && <button className="btn link small" onClick={speech.cancelSpeech}>Stop</button>}
      </div>
      <div className="convo-body">
        <div className="heard">
          {speech.interim ? <span className="interim">{speech.interim}…</span> : heard ? <>You said: <b>{heard}</b></> : "Tap the mic or type below."}
        </div>
        <p className={`reply${busy ? " busy" : ""}`} aria-live="polite">{busy ? busyText : reply}</p>
        {understood}
        {error && (
          <div className="inline-error" role="alert">
            <span>{error}</span>
            <button className="chip" onClick={onRetry}>Try again</button>
          </div>
        )}
        {speech.error && <div className="inline-error">{speech.error}</div>}
        <div className="input-row">
          <input
            id="command-desktop"
            value={typed}
            placeholder={'Type a request, e.g. "back on 8 January"'}
            aria-label="Type a request"
            onChange={(e) => setTyped(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") send(); }}
          />
          <button className="btn" onClick={send} aria-label="Send"><SendIcon /> Send</button>
        </div>
        <div className="suggest">
          {suggestions.map((s) => (
            <button key={s} className="chip" onClick={() => onCommand(s)}>{s}</button>
          ))}
        </div>
      </div>
    </section>
  );
}

/** Phone only: fixed bottom bar so the mic is always in thumb reach. */
export function VoiceBar({ speech, busy, onCommand }: { speech: UseSpeech; busy: boolean; onCommand: (text: string) => void }) {
  const [typed, setTyped] = useState("");
  return (
    <div className="voicebar">
      {speech.interim && <div className="interim">{speech.interim}…</div>}
      <div className="bar-row">
        <input
          id="command-phone"
          value={typed}
          placeholder="Type or tap the mic"
          aria-label="Type a request"
          onChange={(e) => setTyped(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && typed.trim()) { onCommand(typed.trim()); setTyped(""); }
          }}
        />
        <MicButton speech={speech} busy={busy} small />
      </div>
    </div>
  );
}
