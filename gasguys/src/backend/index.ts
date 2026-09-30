// Which backend the customer app runs on, decided once at build/start time: live (Supabase) when both
// VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are set, the in-browser sandbox otherwise.

export type { Backend } from "./types.ts";

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const LIVE = !!(url && anonKey);

/** Only loaded in live mode, so the sandbox build never downloads supabase-js. */
export async function createLiveBackend() {
  const { SupabaseBackend } = await import("./supabase.ts");
  return new SupabaseBackend(url!, anonKey!);
}
