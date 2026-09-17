"use client";
import { useState } from "react";
import type { UseSpeech } from "@/hooks/useSpeech";

const SUGGESTIONS = [
  "Search for flights",
  "Cheapest flights between now and the end of January",
  "Search early December",
  "Read me the top three",
  "What's the fastest?",
  "Tell me about option two",
  "Start tracking prices daily",
  "Help",
];

export function VoicePanel({ speech, heard, reply, busy, continuous, onContinuous, onCommand }: {
  speech: UseSpeech;
  heard: string;
  reply: string;
  busy: boolean;
  continuous: boolean;
  onContinuous: (v: boolean) => void;
  onCommand: (text: string) => void;
}) {
  const [typed, setTyped] = useState("");
  const micState = speech.speaking ? "speaking" : speech.listening ? "listening" : "";
  return (
    <section className="panel">
      <h2>Voice</h2>
      <div className="voice">
        <button
          className={`mic ${micState}`}
          onClick={() => (speech.listening ? speech.stop() : speech.speaking ? speech.cancelSpeech() : speech.start())}
          disabled={!speech.supported}
          aria-label={speech.listening ? "Stop listening" : "Start listening"}
          title={speech.supported ? "Push to talk" : "Voice input needs Chrome, Edge or Safari"}
        >
          {speech.speaking ? "🔊" : speech.listening ? "🎙️" : "🎤"}
        </button>
        <div className="voice-text">
          <div className="heard">
            {speech.interim ? <span className="interim">{speech.interim}…</span> : heard ? <>You said: <b>{heard}</b></> : speech.supported ? "Tap the mic and speak, e.g. “find the cheapest flights in December”." : "Voice input is not supported in this browser; type a command below instead."}
          </div>
          <div className="reply">{busy ? "Working on it…" : reply}</div>
          <div className="voice-row">
            <input
              value={typed}
              placeholder="…or type a command"
              onChange={(e) => setTyped(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && typed.trim()) {
                  onCommand(typed.trim());
                  setTyped("");
                }
              }}
            />
            <button className="btn" onClick={() => { if (typed.trim()) { onCommand(typed.trim()); setTyped(""); } }}>Send</button>
            <label className="toggle">
              <input type="checkbox" checked={continuous} onChange={(e) => onContinuous(e.target.checked)} /> keep listening
            </label>
            {speech.speaking && <button className="btn small ghost" onClick={speech.cancelSpeech}>stop talking</button>}
          </div>
          {speech.error && <div className="notice error" style={{ marginTop: 8 }}>{speech.error}</div>}
          <div className="chips">
            {SUGGESTIONS.map((s) => (
              <button key={s} className="chip" onClick={() => onCommand(s)}>{s}</button>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
