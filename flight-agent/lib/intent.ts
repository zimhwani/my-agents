/**
 * Rule-based understanding of spoken commands. Runs in the browser as the
 * instant path and on the server as the fallback when no ANTHROPIC_API_KEY is set.
 */
import { addDays, endOfNextJanuary, formatISODate, parseISODate, todayISO } from "./dates";
import type { Cabin, Intent, SortMode } from "./types";

const MONTHS: Record<string, number> = {
  january: 0, jan: 0, february: 1, feb: 1, march: 2, mar: 2, april: 3, apr: 3, may: 4, june: 5, jun: 5,
  july: 6, jul: 6, august: 7, aug: 7, september: 8, sep: 8, sept: 8, october: 9, oct: 9, november: 10, nov: 10, december: 11, dec: 11,
};
const MONTH_RE = "(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec)";

const WORD_NUMBERS: Record<string, number> = {
  zero: 0, no: 0, one: 1, a: 1, an: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
  first: 1, second: 2, third: 3, fourth: 4, fifth: 5, sixth: 6, seventh: 7, eighth: 8, ninth: 9, tenth: 10,
};

export function normalizeUtterance(s: string): string {
  return s
    .toLowerCase()
    .replace(/[’']/g, "")
    .replace(/[^a-z0-9\s:/-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function num(tok: string | undefined): number | undefined {
  if (tok === undefined) return undefined;
  if (/^\d+$/.test(tok)) return Number(tok);
  return WORD_NUMBERS[tok];
}

function lastDayOfMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate();
}

/** Resolve a month name to the next occurrence of that month on/after `today`. */
function monthRange(monthName: string, todayIso: string, part?: string): { start: string; end: string } {
  const month = MONTHS[monthName];
  const today = parseISODate(todayIso);
  let year = today.getFullYear();
  if (month < today.getMonth()) year++;
  const last = lastDayOfMonth(year, month);
  let s = 1;
  let e = last;
  if (part === "early") e = 10;
  else if (part === "mid" || part === "middle of") { s = 10; e = 20; }
  else if (part === "late" || part === "end of") s = 20;
  const mk = (d: number) => formatISODate(new Date(year, month, d));
  return { start: mk(s), end: mk(e) };
}

function dayMonth(day: string, monthName: string, todayIso: string): string {
  const month = MONTHS[monthName];
  const today = parseISODate(todayIso);
  let year = today.getFullYear();
  const d = new Date(year, month, Number(day));
  if (d < today) d.setFullYear(++year);
  return formatISODate(d);
}

const DATE_TOKEN = `(?:(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?${MONTH_RE}|${MONTH_RE}\\s+(\\d{1,2})(?:st|nd|rd|th)?)`;

function parseDateToken(m: RegExpExecArray, offset: number, todayIso: string): string | undefined {
  // Groups: [offset+1]=day (day-first), [offset+2]=month (day-first), [offset+3]=month (month-first), [offset+4]=day (month-first)
  const d1 = m[offset + 1];
  const m1 = m[offset + 2];
  const m2 = m[offset + 3];
  const d2 = m[offset + 4];
  if (d1 && m1) return dayMonth(d1, m1, todayIso);
  if (m2 && d2) return dayMonth(d2, m2, todayIso);
  return undefined;
}

export function parseDateWindow(text: string, todayIso = todayISO()): { windowStart?: string; windowEnd?: string } | null {
  const t = normalizeUtterance(text);

  // "between 10 december and 20 january", "from december 3 to january 15"
  const between = new RegExp(`(?:between|from)\\s+${DATE_TOKEN}\\s+(?:and|to|until|till|through)\\s+${DATE_TOKEN}`).exec(t);
  if (between) {
    const start = parseDateToken(between, 0, todayIso);
    const end = parseDateToken(between, 4, todayIso);
    if (start && end) return { windowStart: start, windowEnd: end };
  }

  // "between now and end of january", "from now until late january", "anytime before christmas"
  const nowUntil = new RegExp(`(?:between now and|from now (?:until|till|to)|until|till|before|by)\\s+(?:the\\s+)?(early|mid|late|end of|middle of)?\\s*${MONTH_RE}`).exec(t);
  if (nowUntil) {
    const r = monthRange(nowUntil[2], todayIso, nowUntil[1] === "end of" ? "late" : nowUntil[1]);
    return { windowStart: todayIso, windowEnd: r.end };
  }

  if (/\bchristmas\b/.test(t)) {
    const y = parseISODate(todayIso).getFullYear() + (todayIso.slice(5) > "12-26" ? 1 : 0);
    return { windowStart: `${y}-12-18`, windowEnd: `${y}-12-26` };
  }
  if (/\bnew years?\b/.test(t)) {
    const y = parseISODate(todayIso).getFullYear();
    return { windowStart: `${y}-12-28`, windowEnd: `${y + 1}-01-04` };
  }
  if (/\b(school|summer) holidays?\b/.test(t)) {
    const y = parseISODate(todayIso).getFullYear();
    return { windowStart: `${y}-12-19`, windowEnd: `${y + 1}-01-27` };
  }

  // "between september and january" / "from october to december"
  const monthToMonth = new RegExp(`(?:between|from)\\s+(early|mid|late)?\\s*${MONTH_RE}\\s+(?:and|to|until|till|through)\\s+(early|mid|late|end of)?\\s*${MONTH_RE}`).exec(t);
  if (monthToMonth) {
    const a = monthRange(monthToMonth[2], todayIso, monthToMonth[1]);
    const b = monthRange(monthToMonth[4], todayIso, monthToMonth[3] === "end of" ? "late" : monthToMonth[3]);
    return { windowStart: a.start, windowEnd: b.end };
  }

  // "on 3 december" / "december 3rd"
  const single = new RegExp(`\\b(?:on|around|about)?\\s*${DATE_TOKEN}\\b`).exec(t);
  if (single && (single[1] || single[3])) {
    const d = parseDateToken(single, 0, todayIso);
    if (d) return { windowStart: d, windowEnd: d };
  }

  // "in early december", "in december", "december"
  const inMonth = new RegExp(`\\b(?:in|during|for)?\\s*(early|mid|late|end of|middle of)?\\s*${MONTH_RE}\\b`).exec(t);
  if (inMonth) {
    const r = monthRange(inMonth[2], todayIso, inMonth[1]);
    return { windowStart: r.start, windowEnd: r.end };
  }

  if (/\bnext week\b/.test(t)) return { windowStart: addDays(todayIso, 7), windowEnd: addDays(todayIso, 13) };
  if (/\bthis week\b/.test(t)) return { windowStart: todayIso, windowEnd: addDays(todayIso, 6) };
  if (/\bnext month\b/.test(t)) {
    const d = parseISODate(todayIso);
    const r = monthRange(Object.keys(MONTHS)[((d.getMonth() + 1) % 12) * 2], todayIso);
    return r ? { windowStart: r.start, windowEnd: r.end } : null;
  }
  if (/\b(any ?time|whenever|reset dates|default dates|all dates|whole window)\b/.test(t)) {
    return { windowStart: todayIso, windowEnd: endOfNextJanuary(todayIso) };
  }
  return null;
}

function parseSort(t: string): SortMode | undefined {
  if (/\b(cheap|cheapest|lowest|least expensive|budget|bargain)/.test(t)) return "cheapest";
  if (/\b(fast|fastest|quick|quickest|shortest)/.test(t)) return "fastest";
  if (/\b(best|balanced|recommend|good value|overall|top pick)/.test(t)) return "best";
  return undefined;
}

function parseCabin(t: string): Cabin | undefined {
  if (/\bbusiness\b/.test(t)) return "BUSINESS";
  if (/\bpremium\b/.test(t)) return "PREMIUM_ECONOMY";
  if (/\beconomy\b/.test(t)) return "ECONOMY";
  return undefined;
}

/** Turn one utterance into an intent. Returns `unknown` rather than guessing wildly. */
export function parseIntent(utterance: string, todayIso = todayISO()): Intent {
  const t = normalizeUtterance(utterance);
  if (!t) return { type: "unknown", utterance };

  if (/^(stop|be quiet|quiet|shut up|cancel|never ?mind|enough|silence)\b/.test(t) && !/tracking|track/.test(t)) return { type: "stop" };
  if (/\b(help|what can you do|what can i say|commands)\b/.test(t)) return { type: "help" };

  const trackOn = /\b(start|keep|begin|enable|turn on)\b.*\btrack/.test(t) || /\btrack\b.*\b(price|fare|flight)s?\b/.test(t) || /\bwatch (the )?(price|fare)s?\b/.test(t) || /\balert me\b/.test(t);
  const trackOff = /\b(stop|end|disable|turn off|cancel)\b.*\btrack/.test(t);
  if (trackOff) return { type: "track", enabled: false };
  if (trackOn) {
    const every = /every\s+(\d+|one|two|three|four|six|twelve)\s*hours?/.exec(t);
    const daily = /\b(daily|every day|once a day)\b/.test(t);
    return { type: "track", enabled: true, intervalHours: daily ? 24 : every ? num(every[1]) : undefined };
  }

  // "tell me about option 2", "details on the third one", "open number 1", "book option 2"
  const sel = /\b(option|number|result|flight|choice|the)\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten|first|second|third|fourth|fifth)\b(?:\s+(?:one|option|flight))?/.exec(t);
  if (sel && /\b(tell|details?|about|open|show|select|pick|choose|book|expand|more on|explain|what.?s)\b/.test(t)) {
    const n = num(sel[2]);
    if (n && n >= 1) return { type: "select_offer", index: n };
  }

  // Passengers: "two adults and two children", "add a child", "just the two of us"
  const adults = /(\d+|one|two|three|four|five|six|a|an)\s+adults?\b/.exec(t);
  const children = /(\d+|one|two|three|four|five|six|a|an|no)\s+(children|child|kids?)\b/.exec(t);
  const infants = /(\d+|one|two|a|an|no)\s+(infants?|bab(?:y|ies))\b/.exec(t);
  if ((adults || children || infants) && !/\b(read|list|cheapest|fastest|best)\b/.test(t)) {
    return { type: "set_passengers", adults: num(adults?.[1]), children: num(children?.[1]), infants: num(infants?.[1]) };
  }
  if (/\bjust (the two of us|two adults|adults)\b/.test(t)) return { type: "set_passengers", children: 0, infants: 0 };

  // Trip type / stay length
  const stay = /(\d+|one|two|three|four|five|six)\s+(weeks?|nights?|days?)\b/.exec(t);
  if (/\b(one way|one-way|single)\b/.test(t)) return { type: "set_trip", tripType: "oneway" };
  if (/\b(return|round trip|round-trip|come back|coming back|stay(?:ing)? for)\b/.test(t) && stay) {
    const n = num(stay[1]) ?? 0;
    const nights = /week/.test(stay[2]) ? n * 7 : n;
    return { type: "set_trip", tripType: "return", stayNights: nights };
  }
  if (/\b(return|round trip|round-trip)\b/.test(t) && !/\b(read|list)\b/.test(t)) return { type: "set_trip", tripType: "return" };
  if (stay && /\b(stay|staying|for)\b/.test(t)) {
    const n = num(stay[1]) ?? 0;
    return { type: "set_trip", stayNights: /week/.test(stay[2]) ? n * 7 : n };
  }

  const cabin = parseCabin(t);
  if (cabin && /\b(fly|class|cabin|upgrade|switch|change|in)\b/.test(t) && !/\b(read|list)\b/.test(t)) return { type: "set_cabin", cabin };

  // Reading results: "read me the top three", "what's the cheapest", "list the best options"
  const wantsRead = /\b(read|list|tell me|what.?s|whats|which|show me|give me|say|summari[sz]e|top)\b/.test(t);
  const sort = parseSort(t);
  const countMatch = /\b(?:top|first|best)\s+(\d+|one|two|three|four|five)\b/.exec(t) ?? /\b(\d+|two|three|four|five)\s+(?:options|results|flights|fares)\b/.exec(t);
  if (wantsRead && (sort || countMatch || /\b(options|results|flights|fares)\b/.test(t)) && !/\b(search|find|look)\b/.test(t)) {
    return { type: "read_results", count: num(countMatch?.[1]), sort };
  }

  // Dates
  const window = parseDateWindow(t, todayIso);
  const isSearch = /\b(search|find|look|check|get|scan|fetch|run|refresh|update|again|any flights|flights)\b/.test(t);
  if (window && !/\b(search|find|look|check|scan)\b/.test(t)) return { type: "set_dates", ...window };
  if (window && isSearch) return { type: "set_dates", ...window }; // UI applies dates then searches
  if (sort && isSearch) return { type: "set_sort", sort };
  if (isSearch) return { type: "search" };
  if (sort) return { type: "set_sort", sort };

  return { type: "unknown", utterance };
}

export const HELP_TEXT =
  "You can say: search for flights; find the cheapest flights in December; search between 10 December and 20 January; " +
  "show me the best options; what's the fastest; read me the top three; tell me about option two; " +
  "two adults and two children; one way; return staying three weeks; fly business; start tracking prices daily; or stop.";
