import { createRoot } from "react-dom/client";
import "@fontsource-variable/archivo/wdth.css";
import "@fontsource/jetbrains-mono/latin-500.css";
import { LIVE } from "./backend/index.ts";
import "./styles.css";

// Live (Supabase) when VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are set; the sandbox Studio
// otherwise. Each mode is its own chunk, so neither ships the other's code to the browser.
const root = createRoot(document.getElementById("root")!);
if (LIVE) void import("./live.tsx").then((m) => m.mount(root));
else void import("./studio.tsx").then((m) => m.mount(root));
