import { useEffect, useReducer } from "react";
import { sandbox } from "./index.ts";

/** Re-renders whenever anything in the sandbox changes. For the Studio's simulators only. */
export function useSandbox() {
  const [, bump] = useReducer((x: number) => x + 1, 0);
  useEffect(() => sandbox.subscribe(bump), []);
  return sandbox;
}
