/** Spoken replies for the rule-based path (no API key needed). Shared by the server and the static demo. */
import { airportLabel } from "./airports";
import { spokenDate } from "./dates";
import { HELP_TEXT, parseIntent } from "./intent";
import type { Intent, InterpretResponse, SearchParams } from "./types";

export interface RulesContext {
  params: SearchParams;
  today: string;
}

/** Rule-based path: same intents, canned but sensible speech. */
export function fallbackInterpretation(utterance: string, ctx: RulesContext): InterpretResponse {
  const intent = parseIntent(utterance, ctx.today);
  return { intent, speech: speechFor(intent), source: "rules" };
}

export function speechFor(intent: Intent): string {
  switch (intent.type) {
    case "search": return "Searching for flights now.";
    case "set_dates": {
      const back = intent.returnDate ? `, returning ${spokenDate(intent.returnDate)}` : "";
      if (intent.windowStart && intent.windowEnd) {
        return intent.windowStart === intent.windowEnd
          ? `Checking flights on ${spokenDate(intent.windowStart)}${back}.`
          : `Checking flights leaving between ${spokenDate(intent.windowStart)} and ${spokenDate(intent.windowEnd)}${back}.`;
      }
      return intent.returnDate ? `Returning ${spokenDate(intent.returnDate)}.` : "Updating the dates.";
    }
    case "set_stopover":
      return intent.airport
        ? `Adding ${intent.nights ?? 3} nights in ${airportLabel(intent.airport)} on the way${intent.leg === "return" ? " home" : ""}.`
        : "Removing the stopover.";
    case "set_step": return `Checking a date every ${intent.stepDays === 1 ? "day" : `${intent.stepDays} days`}.`;
    case "set_passengers": return "Updating the travellers.";
    case "set_trip": return intent.tripType === "oneway" ? "Switching to one-way flights." : intent.stayNights ? `Return trip, ${intent.stayNights} nights away.` : "Switching to return flights.";
    case "set_cabin": return `Switching to ${intent.cabin.toLowerCase().replace("_", " ")} class.`;
    case "set_sort": return `Sorting by ${intent.sort}.`;
    case "read_results": return "Here are the results.";
    case "select_offer": return `Here is option ${intent.index}.`;
    case "track": return intent.enabled ? `Tracking prices${intent.intervalHours ? ` every ${intent.intervalHours} hours` : ""}.` : "Stopped tracking prices.";
    case "help": return HELP_TEXT;
    case "stop": return "";
    default: return "Sorry, I did not catch that. Say help to hear what I can do.";
  }
}
