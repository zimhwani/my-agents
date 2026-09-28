import { NextResponse } from "next/server";
import { handleInterpret, keysFromHeaders } from "@/lib/api";

export const runtime = "nodejs";
export const maxDuration = 30;

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const r = await handleInterpret(body, keysFromHeaders(req.headers), process.env);
  return NextResponse.json(r.body, { status: r.status });
}
