// Mail to hello@hairdonenailsdone.app (Cloudflare Email Routing sends it here).
//   1. Hands a plain-text copy to the support agent (Supabase functions/support-inbound).
//   2. Forwards the original to Keith, always, so nothing is lost if step 1 fails.
// Auto-replies and bounces are forwarded but not queued, so they never get a drafted answer.
// Secrets: MAIL_SECRET (matches private.settings 'mail_secret'), FORWARD_TO. Var: INBOUND_URL.
import PostalMime from "postal-mime";

const AUTOMATED = /^(mailer-daemon|postmaster|no-?reply|bounce)/i;

/** Plain text from an HTML-only email: tags out, entities for the common few, blank lines squeezed. */
function htmlText(html) {
  return String(html ?? "")
    .replace(/<(script|style)[\s\S]*?<\/\1>/gi, "")
    .replace(/<br\s*\/?>|<\/(p|div|li|tr|h\d)>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"')
    .replace(/\n{3,}/g, "\n\n").trim();
}

export default {
  async email(message, env) {
    try {
      const mail = await PostalMime.parse(message.raw);
      const from = mail.from?.address || message.from;
      const auto = AUTOMATED.test(from) || /^(auto-replied|auto-generated)/i.test(message.headers.get("auto-submitted") ?? "")
        || /^(bulk|junk|list|auto_reply)$/i.test(message.headers.get("precedence") ?? "");
      if (!auto) {
        const res = await fetch(env.INBOUND_URL, {
          method: "POST",
          headers: { "content-type": "application/json", "x-mail-secret": env.MAIL_SECRET },
          body: JSON.stringify({
            from_email: from, from_name: mail.from?.name || null, subject: mail.subject || "",
            body: (mail.text || htmlText(mail.html)).slice(0, 20000), message_id: mail.messageId || null,
          }),
        });
        if (!res.ok) console.error("support-inbound", res.status, (await res.text()).slice(0, 200));
      }
    } catch (e) {
      console.error("hello@ copy failed", e?.message ?? e);
    }
    await message.forward(env.FORWARD_TO);
  },
};
