"use client";
/** Browser-side helpers: where the API lives and which of the traveller's own keys to send. */

declare global {
  interface Window { __FLIGHT_AGENT_API__?: string }
}

export const KEYS_STORAGE = "flight-agent:keys";

export interface StoredKeys { serpApiKey: string; anthropicKey: string }

export function loadKeys(): StoredKeys {
  try {
    const raw = localStorage.getItem(KEYS_STORAGE);
    const k = raw ? (JSON.parse(raw) as Partial<StoredKeys>) : {};
    return { serpApiKey: k.serpApiKey ?? "", anthropicKey: k.anthropicKey ?? "" };
  } catch {
    return { serpApiKey: "", anthropicKey: "" };
  }
}

export function saveKeys(k: StoredKeys): void {
  try { localStorage.setItem(KEYS_STORAGE, JSON.stringify(k)); } catch { /* ignore */ }
}

export function apiUrl(path: "status" | "search" | "interpret"): string {
  const base = typeof window !== "undefined" && window.__FLIGHT_AGENT_API__ ? window.__FLIGHT_AGENT_API__.replace(/\/$/, "") : "/api";
  return `${base}/${path}`;
}

export function apiHeaders(keys: StoredKeys, json = true): Record<string, string> {
  const h: Record<string, string> = {};
  if (json) h["Content-Type"] = "application/json";
  if (keys.serpApiKey.trim()) h["x-serpapi-key"] = keys.serpApiKey.trim();
  if (keys.anthropicKey.trim()) h["x-anthropic-key"] = keys.anthropicKey.trim();
  return h;
}
