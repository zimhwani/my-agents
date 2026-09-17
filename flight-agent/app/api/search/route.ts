import { NextResponse } from "next/server";
import { normalizeParams } from "@/lib/params";
import { getProvider } from "@/lib/providers";
import { runScan } from "@/lib/search";

export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(req: Request) {
  let body: unknown = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const params = normalizeParams(body);
  try {
    const provider = getProvider();
    const concurrency = Number(process.env.SCAN_CONCURRENCY ?? 3) || 3;
    const result = await runScan(params, provider, { concurrency });
    return NextResponse.json(result);
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ error: message, params }, { status: 500 });
  }
}
