"use client";
import { useCallback, useEffect, useRef, useState } from "react";

type RecognitionCtor = new () => SpeechRecognitionLike;
interface SpeechRecognitionLike {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  maxAlternatives: number;
  onresult: ((ev: { resultIndex: number; results: ArrayLike<ArrayLike<{ transcript: string }> & { isFinal: boolean }> }) => void) | null;
  onend: (() => void) | null;
  onerror: ((ev: { error: string }) => void) | null;
  onstart: (() => void) | null;
  start(): void;
  stop(): void;
  abort(): void;
}

function getRecognition(): RecognitionCtor | null {
  if (typeof window === "undefined") return null;
  const w = window as unknown as { SpeechRecognition?: RecognitionCtor; webkitSpeechRecognition?: RecognitionCtor };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null;
}

export interface UseSpeech {
  supported: boolean;
  ttsSupported: boolean;
  listening: boolean;
  speaking: boolean;
  interim: string;
  error: string | null;
  start: () => void;
  stop: () => void;
  speak: (text: string) => Promise<void>;
  cancelSpeech: () => void;
}

/**
 * Thin wrapper over the browser's SpeechRecognition + speechSynthesis.
 * `onFinal` fires once per finished utterance. Listening pauses while we speak so the
 * assistant does not transcribe itself.
 */
export function useSpeech(onFinal: (utterance: string) => void, opts: { lang?: string; continuous?: boolean } = {}): UseSpeech {
  const [supported, setSupported] = useState(false);
  const [ttsSupported, setTtsSupported] = useState(false);
  const [listening, setListening] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const [interim, setInterim] = useState("");
  const [error, setError] = useState<string | null>(null);
  const recRef = useRef<SpeechRecognitionLike | null>(null);
  const wantListening = useRef(false);
  const onFinalRef = useRef(onFinal);
  onFinalRef.current = onFinal;
  const continuous = opts.continuous ?? false;
  const lang = opts.lang ?? "en-AU";

  useEffect(() => {
    setSupported(getRecognition() !== null);
    setTtsSupported(typeof window !== "undefined" && "speechSynthesis" in window);
  }, []);

  const stop = useCallback(() => {
    wantListening.current = false;
    recRef.current?.stop();
    setListening(false);
    setInterim("");
  }, []);

  const start = useCallback(() => {
    const Ctor = getRecognition();
    if (!Ctor) {
      setError("Voice input is not supported in this browser. Try Chrome, Edge or Safari.");
      return;
    }
    if (recRef.current) recRef.current.abort();
    const rec = new Ctor();
    rec.lang = lang;
    rec.continuous = continuous;
    rec.interimResults = true;
    rec.maxAlternatives = 1;
    rec.onstart = () => {
      setListening(true);
      setError(null);
    };
    rec.onresult = (ev) => {
      let finalText = "";
      let interimText = "";
      for (let i = ev.resultIndex; i < ev.results.length; i++) {
        const r = ev.results[i];
        const t = r[0].transcript;
        if (r.isFinal) finalText += t;
        else interimText += t;
      }
      setInterim(interimText);
      if (finalText.trim()) {
        setInterim("");
        onFinalRef.current(finalText.trim());
      }
    };
    rec.onerror = (ev) => {
      if (ev.error === "no-speech" || ev.error === "aborted") return;
      setError(ev.error === "not-allowed" ? "Microphone access was blocked. Allow the microphone and try again." : `Voice error: ${ev.error}`);
      wantListening.current = false;
    };
    rec.onend = () => {
      setListening(false);
      // Chrome ends continuous sessions after a while; restart if the user still wants to listen.
      if (wantListening.current && continuous && !window.speechSynthesis?.speaking) {
        try { rec.start(); } catch { /* already started */ }
      }
    };
    recRef.current = rec;
    wantListening.current = true;
    try {
      rec.start();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, [continuous, lang]);

  const cancelSpeech = useCallback(() => {
    if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
    setSpeaking(false);
  }, []);

  const speak = useCallback(
    (text: string) =>
      new Promise<void>((resolve) => {
        if (!text || typeof window === "undefined" || !("speechSynthesis" in window)) return resolve();
        const synth = window.speechSynthesis;
        synth.cancel();
        const u = new SpeechSynthesisUtterance(text);
        u.lang = lang;
        const voices = synth.getVoices();
        const preferred = voices.find((v) => v.lang === lang) ?? voices.find((v) => v.lang.startsWith("en-AU")) ?? voices.find((v) => v.lang.startsWith("en"));
        if (preferred) u.voice = preferred;
        u.rate = 1.02;
        const resumeListening = wantListening.current;
        // Pause the mic so we don't hear ourselves.
        recRef.current?.stop();
        u.onstart = () => setSpeaking(true);
        u.onend = u.onerror = () => {
          setSpeaking(false);
          if (resumeListening && continuous) {
            try { recRef.current?.start(); } catch { /* ignore */ }
          }
          resolve();
        };
        synth.speak(u);
      }),
    [continuous, lang],
  );

  useEffect(() => () => { recRef.current?.abort(); }, []);

  return { supported, ttsSupported, listening, speaking, interim, error, start, stop, speak, cancelSpeech };
}
