import strings from "./strings.json" with { type: "json" };
import type { Lang } from "../types.ts";

export type StringKey = keyof typeof strings.en;

export const LANGS: { code: Lang; label: string }[] = [
  { code: "en", label: "English" },
  { code: "sn", label: "chiShona" },
  { code: "nd", label: "isiNdebele" },
];

/** Looks a string up in the user's language, falling back to English, and fills {placeholders}. */
export function t(lang: Lang, key: StringKey, vars: Record<string, string | number> = {}): string {
  const table = strings[lang] as Record<string, string>;
  const raw = table[key] ?? strings.en[key] ?? key;
  return raw.replace(/\{(\w+)\}/g, (_, v) => (v in vars ? String(vars[v]) : `{${v}}`));
}

/** For call sites that switch language often (the bot). */
export const translator = (lang: Lang) => (key: StringKey, vars?: Record<string, string | number>) => t(lang, key, vars);
