import { createContext, useContext, useEffect, useReducer, type ReactNode } from "react";
import type { Backend } from "./types.ts";

const BackendContext = createContext<Backend | null>(null);

export function BackendProvider({ backend, children }: { backend: Backend; children: ReactNode }) {
  return <BackendContext.Provider value={backend}>{children}</BackendContext.Provider>;
}

/** The app's backend; re-renders the calling component whenever the backend's data changes. */
export function useBackend(): Backend {
  const backend = useContext(BackendContext);
  if (!backend) throw new Error("useBackend() needs a <BackendProvider> above it");
  const [, bump] = useReducer((x: number) => x + 1, 0);
  useEffect(() => backend.subscribe(bump), [backend]);
  return backend;
}
