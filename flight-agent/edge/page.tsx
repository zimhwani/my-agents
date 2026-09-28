/** Browser entry for the hosted build: the page talks to the API served next to it. */
import { createRoot } from "react-dom/client";
import Page from "../app/page";
import "../app/globals.css";

// The page is served at .../functions/v1/flight-agent and the API at .../flight-agent/api/*
window.__FLIGHT_AGENT_API__ = `${location.pathname.replace(/\/+$/, "")}/api`;

createRoot(document.getElementById("root")!).render(<Page />);
