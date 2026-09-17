import { NextResponse } from "next/server";
import { providerStatus } from "@/lib/providers";

export const runtime = "nodejs";

export async function GET() {
  try {
    return NextResponse.json(providerStatus());
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : String(e) }, { status: 500 });
  }
}
