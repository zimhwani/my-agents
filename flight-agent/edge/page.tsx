/** Browser entry for the hosted build: the page talks to the API served by the edge function. */
import { createRoot } from "react-dom/client";
import Page from "../app/page";
import "../app/globals.css";

declare const API_BASE: string;

// Served from the edge function itself: the API sits next to the page. Served from a static
// host (GitHub Pages, a CDN): use the baked-in API URL.
const servedByFunction = /\/functions\/v1\/[^/]+\/?$/.test(location.pathname);
window.__FLIGHT_AGENT_API__ = servedByFunction ? `${location.pathname.replace(/\/+$/, "")}/api` : API_BASE;

createRoot(document.getElementById("root")!).render(<Page />);
