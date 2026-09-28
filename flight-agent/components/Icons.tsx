import type { ReactNode } from "react";

function Svg({ size = 20, children, label }: { size?: number; children: ReactNode; label?: string }) {
  return (
    <svg className="icon" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" aria-hidden={label ? undefined : true} role={label ? "img" : undefined} aria-label={label}>
      {children}
    </svg>
  );
}

type P = { size?: number };
export const MicIcon = ({ size = 28 }: P) => <Svg size={size}><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M9 21h6" /></Svg>;
export const StopIcon = ({ size = 24 }: P) => <Svg size={size}><rect x="7" y="7" width="10" height="10" rx="1.5" /></Svg>;
export const SpeakerIcon = ({ size = 28 }: P) => <Svg size={size}><path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4z" /><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" /></Svg>;
export const PlaneIcon = ({ size = 22 }: P) => <Svg size={size}><path d="M12 2.8c.8 0 1.4.6 1.4 1.4v5.1l6.8 4v1.9l-6.8-2.1v4.5l1.9 1.4v1.4L12 19.5l-3.3.9v-1.4l1.9-1.4v-4.5l-6.8 2.1v-1.9l6.8-4V4.2c0-.8.6-1.4 1.4-1.4z" /></Svg>;
export const ClockIcon = ({ size = 16 }: P) => <Svg size={size}><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></Svg>;
export const SettingsIcon = ({ size = 20 }: P) => <Svg size={size}><path d="M4 7h9M17 7h3M4 17h3M11 17h9" /><circle cx="15" cy="7" r="2" /><circle cx="9" cy="17" r="2" /></Svg>;
export const CloseIcon = ({ size = 20 }: P) => <Svg size={size}><path d="M6 6l12 12M18 6L6 18" /></Svg>;
export const ExternalIcon = ({ size = 16 }: P) => <Svg size={size}><path d="M14 4h6v6M20 4l-8.5 8.5M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5" /></Svg>;
export const SendIcon = ({ size = 18 }: P) => <Svg size={size}><path d="M4.5 12 20 4.5 15 20l-3-6.5z" /><path d="M12 13.5 20 4.5" /></Svg>;
export const MoonIcon = ({ size = 14 }: P) => <Svg size={size}><path d="M19.5 14.5A7.5 7.5 0 0 1 9.5 4.5a7.5 7.5 0 1 0 10 10z" /></Svg>;
