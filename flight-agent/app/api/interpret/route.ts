import Anthropic from "@anthropic-ai/sdk";
import { NextResponse } from "next/server";
import { claudeAvailable, fallbackInterpretation, interpretWithClaude, type InterpretContext } from "@/lib/claude";
import { todayISO } from "@/lib/dates";
import { normalizeParams } from "@/lib/params";

export const runtime = "nodejs";
export const maxDuration = 30;

export async function POST(req: Request) {
  const body = (await req.json().catch(() => ({}))) as { utterance?: unknown; params?: unknown; lastResult?: InterpretContext["lastResult"] };
  const utterance = typeof body.utterance === "string" ? body.utterance.slice(0, 500) : "";
  if (!utterance.trim()) return NextResponse.json({ error: "utterance is required" }, { status: 400 });

  const ctx: InterpretContext = { params: normalizeParams(body.params), today: todayISO(), lastResult: body.lastResult };

  if (!claudeAvailable()) return NextResponse.json(fallbackInterpretation(utterance, ctx));

  try {
    return NextResponse.json(await interpretWithClaude(utterance, ctx));
  } catch (e) {
    // Degrade to the rule-based parser rather than failing the voice command.
    const reason =
      e instanceof Anthropic.AuthenticationError ? "invalid ANTHROPIC_API_KEY"
      : e instanceof Anthropic.RateLimitError ? "rate limited"
      : e instanceof Anthropic.APIError ? `API error ${e.status}`
      : e instanceof Error ? e.message : String(e);
    console.warn(`[interpret] Claude unavailable (${reason}); using rules`);
    return NextResponse.json({ ...fallbackInterpretation(utterance, ctx), degraded: reason });
  }
}
