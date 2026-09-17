/**
 * Conversational understanding with Claude. Only used when ANTHROPIC_API_KEY is set;
 * `lib/intent.ts` handles everything offline otherwise.
 */
import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";
import { passengerSummary } from "./params";
import { fallbackInterpretation } from "./speech";
import type { Intent, InterpretResponse, RankedOffer, ScanResult, SearchParams } from "./types";

export { fallbackInterpretation, speechFor } from "./speech";

const IntentSchema = z.object({
  type: z.enum([
    "search", "set_dates", "set_passengers", "set_trip", "set_cabin", "set_sort",
    "read_results", "select_offer", "track", "help", "stop", "unknown",
  ]),
  windowStart: z.string().nullable().describe("YYYY-MM-DD, for set_dates"),
  windowEnd: z.string().nullable().describe("YYYY-MM-DD, for set_dates"),
  adults: z.number().int().nullable(),
  children: z.number().int().nullable(),
  infants: z.number().int().nullable(),
  tripType: z.enum(["return", "oneway"]).nullable(),
  stayNights: z.number().int().nullable(),
  cabin: z.enum(["ECONOMY", "PREMIUM_ECONOMY", "BUSINESS"]).nullable(),
  sort: z.enum(["best", "cheapest", "fastest"]).nullable(),
  count: z.number().int().nullable().describe("How many results to read"),
  index: z.number().int().nullable().describe("1-based option number for select_offer"),
  enabled: z.boolean().nullable().describe("For track: start (true) or stop (false)"),
  intervalHours: z.number().nullable(),
  speech: z.string().describe("A short, friendly spoken reply (max 2 sentences). If type is search or set_*, confirm what you will do."),
});

export interface InterpretContext {
  params: SearchParams;
  today: string;
  lastResult?: Pick<ScanResult, "datesScanned" | "isSample"> & { top: Pick<RankedOffer, "price" | "validatingCarrierName" | "departureDate" | "totalDurationMin" | "stops">[] };
}

function toIntent(p: z.infer<typeof IntentSchema>, utterance: string): Intent {
  const or = <T>(v: T | null): T | undefined => (v === null ? undefined : v);
  switch (p.type) {
    case "search": return { type: "search" };
    case "set_dates": return { type: "set_dates", windowStart: or(p.windowStart), windowEnd: or(p.windowEnd) };
    case "set_passengers": return { type: "set_passengers", adults: or(p.adults), children: or(p.children), infants: or(p.infants) };
    case "set_trip": return { type: "set_trip", tripType: or(p.tripType), stayNights: or(p.stayNights) };
    case "set_cabin": return p.cabin ? { type: "set_cabin", cabin: p.cabin } : { type: "unknown", utterance };
    case "set_sort": return { type: "set_sort", sort: p.sort ?? "best" };
    case "read_results": return { type: "read_results", count: or(p.count), sort: or(p.sort) };
    case "select_offer": return p.index ? { type: "select_offer", index: p.index } : { type: "unknown", utterance };
    case "track": return { type: "track", enabled: p.enabled ?? true, intervalHours: or(p.intervalHours) };
    case "help": return { type: "help" };
    case "stop": return { type: "stop" };
    default: return { type: "unknown", utterance };
  }
}

const SYSTEM = `You are the voice of a flight travel agent app. The user speaks; you map each utterance to exactly one intent and write a short spoken reply.
The app tracks flights from Melbourne (MEL) to Harare (HRE). Intents:
- search: run the fare scan now.
- set_dates: change the departure window (always resolve to concrete YYYY-MM-DD dates; "anytime" means today to the following 31 January).
- set_passengers / set_trip / set_cabin: change travellers, one-way vs return and nights away, or cabin.
- set_sort: reorder results (best = balanced price, travel time, interchange quality and family-friendly timings; cheapest; fastest).
- read_results: read the top N results aloud (default 3), optionally in a given sort.
- select_offer: the user asks about option N.
- track: start or stop price tracking (optional intervalHours).
- help, stop (stop talking), unknown.
If the user asks to search for a specific period, use set_dates (the app searches right after applying dates).
Keep speech under 40 words, plain and warm, no markdown. Mention prices only from the provided context. Latency-sensitive; begin your visible answer immediately.`;

export function claudeAvailable(env: NodeJS.ProcessEnv = process.env): boolean {
  return Boolean(env.ANTHROPIC_API_KEY?.trim());
}

export async function interpretWithClaude(utterance: string, ctx: InterpretContext, client: Anthropic = new Anthropic()): Promise<InterpretResponse> {
  const context = {
    today: ctx.today,
    currentSearch: {
      window: `${ctx.params.windowStart} to ${ctx.params.windowEnd}`,
      trip: ctx.params.tripType === "return" ? `return, ${ctx.params.stayNights} nights away` : "one way",
      passengers: passengerSummary(ctx.params),
      cabin: ctx.params.cabin,
    },
    lastResults: ctx.lastResult
      ? {
          datesScanned: ctx.lastResult.datesScanned,
          sampleData: ctx.lastResult.isSample,
          top: ctx.lastResult.top.map((o, i) => `${i + 1}. ${o.price.currency} ${o.price.total} ${o.validatingCarrierName}, departs ${o.departureDate}, ${Math.round(o.totalDurationMin / 60)}h total, ${o.stops} stops`),
        }
      : "none yet",
  };

  const response = await client.beta.messages.parse({
    model: "claude-opus-5",
    max_tokens: 1024,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    thinking: { type: "adaptive" },
    output_config: { effort: "low", format: zodOutputFormat(IntentSchema) },
    system: [{ type: "text", text: SYSTEM, cache_control: { type: "ephemeral" } }],
    messages: [
      { role: "user", content: `Context:\n${JSON.stringify(context, null, 2)}\n\nUser said: "${utterance}"` },
    ],
  });

  if (response.stop_reason === "refusal" || !response.parsed_output) {
    return fallbackInterpretation(utterance, ctx);
  }
  return { intent: toIntent(response.parsed_output, utterance), speech: response.parsed_output.speech, source: "claude" };
}
