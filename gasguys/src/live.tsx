// Live mode: the customer app on its own, full screen, on Supabase. Every route is the product; the
// Studio, simulators and sandbox hints don't exist here.

import { StrictMode } from "react";
import type { Root } from "react-dom/client";
import { BackendProvider } from "./backend/context.tsx";
import { createLiveBackend } from "./backend/index.ts";
import { CustomerApp } from "./customer/CustomerApp.tsx";

export async function mount(root: Root) {
  const backend = await createLiveBackend();
  root.render(
    <StrictMode>
      <BackendProvider backend={backend}>
        <div className="fullscreen-app">
          <CustomerApp />
        </div>
      </BackendProvider>
    </StrictMode>,
  );
}
