import { NextResponse } from "next/server";
import { handleStatus, keysFromHeaders } from "@/lib/api";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const r = handleStatus(keysFromHeaders(req.headers), process.env);
  return NextResponse.json(r.body, { status: r.status });
}
