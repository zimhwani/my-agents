import { useEffect, useReducer, useState } from "react";
import { sandbox } from "./sandbox/index.ts";

/** Re-renders whenever anything in the sandbox changes. */
export function useSandbox() {
  const [, bump] = useReducer((x: number) => x + 1, 0);
  useEffect(() => sandbox.subscribe(bump), []);
  return sandbox;
}

export function useHashRoute(): [string, (to: string) => void] {
  const [hash, setHash] = useState(() => location.hash.slice(1) || "/");
  useEffect(() => {
    const on = () => setHash(location.hash.slice(1) || "/");
    addEventListener("hashchange", on);
    return () => removeEventListener("hashchange", on);
  }, []);
  return [hash, (to) => (location.hash = to)];
}

export const timeAgo = (iso: string) => {
  const s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000);
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return new Date(iso).toLocaleDateString();
};

const P = { fill: "none", stroke: "currentColor", strokeWidth: 2, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };

export const Icon = {
  Flame: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <path d="M12 3c1 3.5 5 5.5 5 10a5 5 0 0 1-10 0c0-2.6 1.4-4 2.6-5.4.3 1.8 1.1 2.6 2.1 2.9-.7-2.8 0-5.3.3-7.5z" />
    </svg>
  ),
  Home: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <path d="M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z" />
    </svg>
  ),
  Gift: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <rect x="3" y="8" width="18" height="4" rx="1" />
      <path d="M5 12v8h14v-8M12 8v12M12 8c-1.5-3-5-3.5-5-1.2C7 8 9 8 12 8zm0 0c1.5-3 5-3.5 5-1.2C17 8 15 8 12 8z" />
    </svg>
  ),
  Clock: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  ),
  Cylinder: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <path d="M9 3h6M10 3v2M14 3v2" />
      <rect x="6" y="5" width="12" height="16" rx="5" />
      <path d="M6 11h12" />
    </svg>
  ),
  Phone: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <rect x="7" y="2.5" width="10" height="19" rx="2.5" />
      <path d="M11 18.5h2" />
    </svg>
  ),
  Shield: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <path d="M12 3l7 3v5c0 5-3.5 8.5-7 10-3.5-1.5-7-5-7-10V6z" />
    </svg>
  ),
  Warn: () => (
    <svg viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 2.5 1.8 20.2A1.2 1.2 0 0 0 2.8 22h18.4a1.2 1.2 0 0 0 1-1.8zm-1 7h2v6h-2zm0 8h2v2h-2z" />
    </svg>
  ),
  Check: () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={3} strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12.5l4.5 4.5L19 7.5" />
    </svg>
  ),
  Send: () => (
    <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
      <path d="M3 20.5 21 12 3 3.5 3 10l12 2-12 2z" />
    </svg>
  ),
  Help: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <circle cx="12" cy="12" r="9" />
      <path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17h.01" />
    </svg>
  ),
  Wifi: () => (
    <svg viewBox="0 0 24 24" {...P}>
      <path d="M2 8.5a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0M12 19h.01" />
    </svg>
  ),
};

export function Logo({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden>
      <rect width="64" height="64" rx="16" fill="#14213D" />
      <path d="M32 10c3 9 14 15 14 28a14 14 0 0 1-28 0c0-7 4-11 7-15 1 5 3 7 6 8-2-8 0-15 1-21z" fill="#FF6B1A" />
      <path d="M32 34c1.5 3 5 5 5 9a5 5 0 0 1-10 0c0-2.5 2-4 3-5 .3 1.5 1 2 2 2.5-.5-2.5-.5-4.5 0-6.5z" fill="#FFC53D" />
    </svg>
  );
}
