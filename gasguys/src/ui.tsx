import { useEffect, useId, useState, type ReactNode, type SVGProps } from "react";

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

const P = { fill: "none", stroke: "currentColor", strokeWidth: 1.75, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
const svg = (children: ReactNode, extra: SVGProps<SVGSVGElement> = {}) => (
  <svg viewBox="0 0 24 24" aria-hidden focusable="false" {...P} {...extra}>
    {children}
  </svg>
);

/**
 * One icon set drawn for Gasguys on a 24 px grid with a 1.75 px stroke. Filled shapes are kept for
 * the leak warning only, so the one icon that must be seen first is also the only solid one.
 */
export const Icon = {
  Flame: () => svg(<path d="M12 2.8c.9 3.3 4.8 5.3 4.8 10a4.8 4.8 0 0 1-9.6 0c0-2.5 1.3-3.9 2.5-5.2.3 1.7 1 2.5 2 2.8-.6-2.7 0-5.5.3-7.6z" />),
  Home: () => svg(<path d="M3.5 10.5 12 3.8l8.5 6.7M5.5 9v11h13V9M10 20v-6h4v6" />),
  Gift: () =>
    svg(
      <>
        <path d="M3.5 8.5h17v4h-17zM5 12.5V20h14v-7.5M12 8.5V20" />
        <path d="M12 8.5C11 5.6 7.6 4.6 7.6 6.8c0 1.3 1.6 1.7 4.4 1.7zm0 0c1-2.9 4.4-3.9 4.4-1.7 0 1.3-1.6 1.7-4.4 1.7z" />
      </>,
    ),
  Receipt: () => svg(<path d="M5.5 3h13v18l-2.2-1.4-2.1 1.4-2.2-1.4-2.2 1.4L7.7 19.6 5.5 21zM9 8h6M9 11.5h6M9 15h3.5" />),
  Clock: () =>
    svg(
      <>
        <circle cx="12" cy="12" r="8.5" />
        <path d="M12 7.5V12l3 2" />
      </>,
    ),
  Cylinder: () => svg(<path d="M9.5 2.8h5v3h-5zM7 8.5a2.7 2.7 0 0 1 2.7-2.7h4.6A2.7 2.7 0 0 1 17 8.5V19a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2zM7 12h10" />),
  Phone: () => svg(<path d="M7.5 2.8h9a1 1 0 0 1 1 1v16.4a1 1 0 0 1-1 1h-9a1 1 0 0 1-1-1V3.8a1 1 0 0 1 1-1zM10.5 18h3" />),
  Call: () => svg(<path d="M5 3.5h3.5l1.7 4.3-2.2 1.4a11 11 0 0 0 6.8 6.8l1.4-2.2 4.3 1.7V19a1.5 1.5 0 0 1-1.6 1.5A16.5 16.5 0 0 1 3.5 5.1 1.5 1.5 0 0 1 5 3.5z" />),
  Chat: () => svg(<path d="M4 19.5 5.3 16A8 8 0 1 1 8 18.7zM9 11h.01M12 11h.01M15 11h.01" />),
  Shield: () => svg(<path d="M12 3 19 5.8V11c0 4.6-3 8.2-7 10-4-1.8-7-5.4-7-10V5.8zM9 12l2.2 2.2L15.5 10" />),
  Warn: () => (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden focusable="false">
      <path d="M12 1.8 1.2 21h21.6zm-1.3 6.7h2.6l-.4 7h-1.8zm1.3 8.6a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3z" fillRule="evenodd" />
    </svg>
  ),
  Check: () => svg(<path d="M4.5 12.5 9.5 17.5 19.5 7" />, { strokeWidth: 2.25 }),
  Send: () => (
    <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20" aria-hidden focusable="false">
      <path d="M3 20.5 21 12 3 3.5 3 10l12 2-12 2z" />
    </svg>
  ),
  Help: () =>
    svg(
      <>
        <circle cx="12" cy="12" r="8.5" />
        <path d="M9.6 9.6a2.4 2.4 0 1 1 3.4 2.2c-.6.3-1 .8-1 1.5v.6M12 16.8h.01" />
      </>,
    ),
  Signal: () => svg(<path d="M5 19v-3M9.5 19v-6M14 19v-9M18.5 19V6" />),
  NoSignal: () => svg(<path d="M5 19v-3M9.5 19v-6M14 19v-3M18.5 19v-5M4 4l16 16" />),
  Account: () =>
    svg(
      <>
        <circle cx="12" cy="8.5" r="3.8" />
        <path d="M4.5 20.5c.8-3.8 3.8-5.8 7.5-5.8s6.7 2 7.5 5.8" />
      </>,
    ),
  Arrow: () => svg(<path d="M4.5 12h15M13.5 6l6 6-6 6" />),
  Back: () => svg(<path d="M19.5 12h-15M10.5 6l-6 6 6 6" />),
  Chevron: () => svg(<path d="M9.5 5.5 16 12l-6.5 6.5" />),
  Share: () => svg(<path d="M12 3.5v11M7.5 8 12 3.5 16.5 8M5 12.5V20h14v-7.5" />),
  Copy: () => svg(<path d="M8.5 8.5h11v11h-11zM15.5 8.5V4.5h-11v11h4" />),
  Card: () => svg(<path d="M3 6h18v12H3zM3 10h18M6.5 14.5h4" />),
  Truck: () =>
    svg(
      <>
        <path d="M2.5 6h11v10h-11zM13.5 9.5h4l3 3.5V16h-7" />
        <circle cx="6.5" cy="17.5" r="1.7" />
        <circle cx="16.5" cy="17.5" r="1.7" />
      </>,
    ),
  Pin: () =>
    svg(
      <>
        <path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z" />
        <circle cx="12" cy="10" r="2.3" />
      </>,
    ),
  Globe: () =>
    svg(
      <>
        <circle cx="12" cy="12" r="8.5" />
        <path d="M3.5 12h17M12 3.5c2.4 2.3 3.5 5.1 3.5 8.5s-1.1 6.2-3.5 8.5c-2.4-2.3-3.5-5.1-3.5-8.5s1.1-6.2 3.5-8.5z" />
      </>,
    ),
  Wifi: () => svg(<path d="M5 19v-3M9.5 19v-6M14 19v-9M18.5 19V6" />),
  List: () => svg(<path d="M8.5 6.5h12M8.5 12h12M8.5 17.5h12M4 6.5h.01M4 12h.01M4 17.5h.01" />, { strokeWidth: 2 }),
  /* Leak pictograms: bigger, simpler, meant to be read from arm's length in a panic. */
  Window: () => svg(<path d="M4 3.5h16v17H4zM12 3.5v17M4 12h8M14.5 9.5l4-2.5M14.5 14.5l4 2.5" />),
  NoFlame: () =>
    svg(
      <>
        <path d="M12 4.5c.7 2.6 3.8 4.1 3.8 7.8a3.8 3.8 0 0 1-7.6 0c0-2 1-3.1 2-4.1.2 1.3.8 2 1.6 2.2-.5-2.1 0-4.3.2-5.9z" />
        <circle cx="12" cy="12" r="9" />
        <path d="M5.6 5.6l12.8 12.8" />
      </>,
    ),
  Exit: () =>
    svg(
      <>
        <path d="M13.5 3.5h6v17h-6" />
        <circle cx="8" cy="5.5" r="1.6" />
        <path d="M8 8.5 6.5 13l3 2 .5 5M6.5 13 4 20M7.8 9.5l3.2 2.5 2.5-1" />
      </>,
    ),
};

/** The mark: a gas cylinder, collar and all, with its gas line in Flame. */
export function Mark({ size = 28, level = 0.42 }: { size?: number; level?: number }) {
  const top = 9;
  const bottom = 28;
  const y = bottom - (bottom - top) * level;
  const clip = "gg" + useId().replace(/[^a-zA-Z0-9_-]/g, "");
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden focusable="false" className="mark">
      <defs>
        <clipPath id={clip}>
          <rect x="7" y="8" width="18" height="20.5" rx="6" />
        </clipPath>
      </defs>
      <path d="M11 1.5h10v6.5H11z" fill="currentColor" />
      <rect x="13.6" y="3.3" width="4.8" height="2.4" rx="1.2" fill="var(--mark-bg, #F5F2EB)" />
      <rect x="7" y="8" width="18" height="20.5" rx="6" fill="currentColor" />
      <rect x="7" y={y} width="18" height="30" fill="#FF6B1A" clipPath={`url(#${clip})`} />
      <rect x="9.5" y="28" width="13" height="3" rx="1" fill="currentColor" />
    </svg>
  );
}

/** Mark plus wordmark. Kept as text so it stays sharp and costs no bytes. */
export function Logo({ size = 26 }: { size?: number }) {
  return (
    <span className="logo-lockup">
      <Mark size={size} />
      <span className="wordmark">Gasguys</span>
    </span>
  );
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** Dates as Zimbabwe prints them on receipts ("6 Oct 2026"), whatever the UI language. */
export const fmtDate = (d: Date | string, withYear = false) => {
  const x = new Date(d);
  return `${x.getDate()} ${MONTHS[x.getMonth()]}${withYear ? ` ${x.getFullYear()}` : ""}`;
};
export const monthShort = (d: Date) => MONTHS[d.getMonth()];
export const fmtTime = (d: Date | string) => {
  const x = new Date(d);
  return `${String(x.getHours()).padStart(2, "0")}:${String(x.getMinutes()).padStart(2, "0")}`;
};
