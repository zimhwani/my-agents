// WhatsApp Cloud API webhook. GET is Meta's subscription check; POST carries customer messages.
// Every message runs through the same bot the web sandbox's WhatsApp simulator uses (core/bot.ts).
import { handleInbound } from "../_shared/core/bot.ts";
import { service } from "../_shared/gasguys.ts";
import { parseInbound, verifySignature } from "../_shared/whatsapp.ts";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  if (req.method === "GET") {
    const ok = url.searchParams.get("hub.mode") === "subscribe" && url.searchParams.get("hub.verify_token") === Deno.env.get("WHATSAPP_VERIFY_TOKEN");
    return ok ? new Response(url.searchParams.get("hub.challenge")) : new Response("forbidden", { status: 403 });
  }

  const raw = await req.text();
  if (!(await verifySignature(raw, req.headers.get("x-hub-signature-256")))) return new Response("bad signature", { status: 401 });

  const svc = await service();
  for (const { phone, msg } of parseInbound(JSON.parse(raw))) await svc.send(phone, await handleInbound(svc, phone, msg));
  // Always 200 quickly, or Meta retries and the customer gets duplicate replies.
  return new Response("ok");
});
