// WhatsApp Cloud API (Meta, direct, no BSP). Outbound messages and inbound webhook parsing.
// Secrets: WHATSAPP_TOKEN (system user token), WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_APP_SECRET,
// WHATSAPP_VERIFY_TOKEN. Free-form and interactive messages only work inside the 24-hour window
// after the customer last wrote; outside it, `template` messages must match templates approved in
// WhatsApp Manager (see docs/whatsapp-templates.md).

import type { Inbound } from "./core/bot.ts";
import type { Messenger, OutMessage } from "./core/providers.ts";

const GRAPH = "https://graph.facebook.com/v23.0";

function toCloud(to: string, m: OutMessage, lang: string): Record<string, unknown> {
  const base = { messaging_product: "whatsapp", recipient_type: "individual", to };
  switch (m.kind) {
    case "text":
      return { ...base, type: "text", text: { body: m.text, preview_url: true } };
    case "buttons":
      return {
        ...base,
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: m.text.slice(0, 1024) },
          action: { buttons: m.buttons.slice(0, 3).map((b) => ({ type: "reply", reply: { id: b.id, title: b.title.slice(0, 20) } })) },
        },
      };
    case "list":
      return {
        ...base,
        type: "interactive",
        interactive: {
          type: "list",
          body: { text: m.text.slice(0, 1024) },
          action: {
            button: m.button.slice(0, 20),
            sections: [{ title: m.button.slice(0, 24), rows: m.rows.slice(0, 10).map((r) => ({ id: r.id, title: r.title.slice(0, 24), description: r.description?.slice(0, 72) })) }],
          },
        },
      };
    case "template":
      return {
        ...base,
        type: "template",
        template: { name: m.name, language: { code: lang }, components: [{ type: "body", parameters: m.params.map((text) => ({ type: "text", text })) }] },
      };
  }
}

export class WhatsAppCloudMessenger implements Messenger {
  constructor(private langOf: (phone: string) => Promise<string>) {}

  async send(phone: string, messages: OutMessage[]) {
    const token = Deno.env.get("WHATSAPP_TOKEN");
    const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
    if (!token || !phoneId) return console.warn("whatsapp not configured; dropping", messages.length, "messages");
    const lang = await this.langOf(phone);
    for (const m of messages) {
      const res = await fetch(`${GRAPH}/${phoneId}/messages`, {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify(toCloud(phone, m, lang)),
      });
      // A template that isn't approved yet fails; fall back to plain text (works inside the 24 h window).
      if (!res.ok && m.kind === "template") await this.send(phone, [{ kind: "text", text: m.text }]);
      else if (!res.ok) console.error("whatsapp send failed", res.status, await res.text());
    }
  }
}

/** X-Hub-Signature-256 = "sha256=" + hex(HMAC-SHA256(app secret, raw body)). */
export async function verifySignature(raw: string, header: string | null): Promise<boolean> {
  const secret = Deno.env.get("WHATSAPP_APP_SECRET");
  if (!secret || !header?.startsWith("sha256=")) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw)));
  const hex = Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
  const given = header.slice(7);
  if (given.length !== hex.length) return false;
  let diff = 0;
  for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

type CloudMessage = {
  from: string;
  type: string;
  text?: { body: string };
  interactive?: { button_reply?: { id: string; title: string }; list_reply?: { id: string; title: string } };
  button?: { payload: string; text: string }; // quick-reply button on a template
};

/** Flattens a Cloud API webhook payload into (phone, Inbound) pairs the bot understands. */
export function parseInbound(payload: unknown): { phone: string; msg: Inbound }[] {
  const out: { phone: string; msg: Inbound }[] = [];
  const entries = (payload as { entry?: { changes?: { value?: { messages?: CloudMessage[]; contacts?: { profile?: { name?: string } }[] } }[] }[] }).entry ?? [];
  for (const e of entries)
    for (const c of e.changes ?? []) {
      const profileName = c.value?.contacts?.[0]?.profile?.name;
      for (const m of c.value?.messages ?? []) {
        const reply = m.interactive?.button_reply ?? m.interactive?.list_reply;
        if (reply) out.push({ phone: m.from, msg: { type: "button", id: reply.id, title: reply.title, profileName } });
        else if (m.button) out.push({ phone: m.from, msg: { type: "button", id: m.button.payload, title: m.button.text, profileName } });
        else if (m.text) out.push({ phone: m.from, msg: { type: "text", text: m.text.body, profileName } });
        else out.push({ phone: m.from, msg: { type: "text", text: "", profileName } }); // images, voice notes: bot shows the menu
      }
    }
  return out;
}

// ── Sign-in codes (Supabase Auth "Send SMS" hook → WhatsApp) ─────────────────────────────────────

/** Name of the approved Authentication-category template; see docs/whatsapp-templates.md. */
export const OTP_TEMPLATE = () => Deno.env.get("WHATSAPP_OTP_TEMPLATE") ?? "gasguys_login_code";

/**
 * Cloud API body for an Authentication template with a copy-code button. Meta's documented shape:
 * the code goes in the body parameter and again as the button's parameter; the button is sent as
 * sub_type "url" at index 0 even though it is a copy-code button.
 * Language: Authentication templates use Meta's preset text, which (as far as we know) is not offered
 * in Shona or Ndebele, so it is sent in English. The code must match the language the template was
 * created with in WhatsApp Manager ("en" here; change to "en_US" if that is what was submitted).
 */
export function authCodeMessage(to: string, code: string, template = "gasguys_login_code", lang = "en"): Record<string, unknown> {
  return {
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to,
    type: "template",
    template: {
      name: template,
      language: { code: lang },
      components: [
        { type: "body", parameters: [{ type: "text", text: code }] },
        { type: "button", sub_type: "url", index: "0", parameters: [{ type: "text", text: code }] },
      ],
    },
  };
}

/** Sends a sign-in code on WhatsApp. No plain-text fallback: outside the 24 h window it wouldn't arrive. */
export async function sendAuthCode(phone: string, code: string): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const token = Deno.env.get("WHATSAPP_TOKEN");
  const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  if (!token || !phoneId) return { ok: false, status: 503, error: "whatsapp_not_configured" };
  const res = await fetch(`${GRAPH}/${phoneId}/messages`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(authCodeMessage(phone, code, OTP_TEMPLATE())),
  });
  if (res.ok) return { ok: true };
  return { ok: false, status: res.status, error: (await res.text()).slice(0, 500) };
}
