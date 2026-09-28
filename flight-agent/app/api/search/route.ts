import { NextResponse } from "next/server";
import { handleSearch, keysFromHeaders } from "@/lib/api";

export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const r = await handleSearch(body, keysFromHeaders(req.headers), process.env);
  return NextResponse.json(r.body, { status: r.status });
}
