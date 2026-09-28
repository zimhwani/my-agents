"use client";
import type { UseSpeech } from "@/hooks/useSpeech";
import { MicIcon, SpeakerIcon, StopIcon } from "./Icons";

export type MicState = "idle" | "listening" | "thinking" | "speaking";

export function micState(speech: UseSpeech, busy: boolean): MicState {
  if (speech.speaking) return "speaking";
  if (speech.listening) return "listening";
  if (busy) return "thinking";
  return "idle";
}

export const MIC_CAPTION: Record<MicState, string> = {
  idle: "Tap to talk",
  listening: "Listening… tap to stop",
  thinking: "Working it out…",
  speaking: "Speaking… tap to stop",
};

export function MicButton({ speech, busy, small }: { speech: UseSpeech; busy: boolean; small?: boolean }) {
  const state = micState(speech, busy);
  const onClick = () => (state === "speaking" ? speech.cancelSpeech() : state === "listening" ? speech.stop() : speech.start());
  return (
    <button
      type="button"
      className={`mic ${state}${small ? " sm" : ""}`}
      onClick={onClick}
      disabled={!speech.supported && state !== "speaking"}
      aria-label={speech.supported ? MIC_CAPTION[state] : "Voice needs Chrome, Edge or Safari"}
      aria-pressed={state === "listening"}
    >
      {state === "speaking" ? <SpeakerIcon size={small ? 24 : 28} /> : state === "listening" ? <StopIcon size={small ? 20 : 24} /> : <MicIcon size={small ? 24 : 28} />}
    </button>
  );
}
