// Vercel serverless function: receives the enquiry form and emails it via Resend.
// Env vars (Vercel → Settings → Environment Variables):
//   RESEND_API_KEY  from resend.com (verify the matimc.com domain there first)
//   ENQUIRY_TO      where enquiries go, e.g. hello@matimc.com
//   ENQUIRY_FROM    optional. Default "Mati website <onboarding@resend.dev>", which works before the
//                   matimc.com domain is verified in Resend but can only deliver to the Resend account's
//                   own email. Once matimc.com is verified, set it to "Mati website <enquiries@matimc.com>".
export const config = { api: { bodyParser: false } };

async function readForm(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks);
  const ct = req.headers['content-type'] || '';
  if (ct.includes('application/json')) return JSON.parse(raw.toString('utf8') || '{}');
  if (ct.includes('application/x-www-form-urlencoded')) return Object.fromEntries(new URLSearchParams(raw.toString('utf8')));
  const m = /boundary=(?:"([^"]+)"|([^;]+))/.exec(ct);
  if (!m) return {};
  const boundary = '--' + (m[1] || m[2]);
  const out = {};
  for (const part of raw.toString('utf8').split(boundary)) {
    const i = part.indexOf('\r\n\r\n'); if (i < 0) continue;
    const head = part.slice(0, i), body = part.slice(i + 4).replace(/\r\n$/, '');
    const name = /name="([^"]+)"/.exec(head)?.[1]; if (!name || /filename=/.test(head)) continue;
    out[name] = body;
  }
  return out;
}
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const LABELS = { name: 'Name', email: 'Email', organisation: 'Organisation', phone: 'Phone', event_type: 'Enquiry type', event_name: 'Event', event_date: 'Date', location: 'Where', format: 'Format', audience_size: 'Audience size', budget: 'Budget (AUD)', message: 'Message', source: 'Heard about Mati via' };

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ ok: false, error: 'POST only' });
  const key = process.env.RESEND_API_KEY, to = process.env.ENQUIRY_TO;
  if (!key || !to) return res.status(503).json({ ok: false, error: 'Email sending not configured' });
  let f;
  try { f = await readForm(req); } catch { return res.status(400).json({ ok: false, error: 'Bad form data' }); }
  if (f._gotcha) return res.status(200).json({ ok: true });                      // honeypot: pretend success
  if (!f.name || !f.email || !f.message) return res.status(422).json({ ok: false, error: 'Name, email and message are required' });
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.email)) return res.status(422).json({ ok: false, error: 'Invalid email' });
  if (f.date_tbc && !f.event_date) f.event_date = 'Not sure yet';
  if (f.event_date && /^\d{4}-\d{2}-\d{2}$/.test(f.event_date)) { const [y, m, d] = f.event_date.split('-'); f.event_date = `${d}/${m}/${y}`; }
  const rows = Object.entries(LABELS).filter(([k]) => f[k]).map(([k, l]) => `<tr><td style="padding:6px 12px 6px 0;color:#666;vertical-align:top;white-space:nowrap">${l}</td><td style="padding:6px 0;white-space:pre-wrap">${esc(f[k])}</td></tr>`).join('');
  const text = Object.entries(LABELS).filter(([k]) => f[k]).map(([k, l]) => `${l}: ${f[k]}`).join('\n');
  const subject = `Booking enquiry: ${f.event_type || 'event'} from ${f.name}${f.organisation ? ' (' + f.organisation + ')' : ''}`;
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: process.env.ENQUIRY_FROM || 'Mati website <onboarding@resend.dev>',
      to: [to], reply_to: f.email, subject,
      html: `<div style="font:15px/1.5 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#111"><p>New enquiry from the website.</p><table>${rows}</table></div>`,
      text,
    }),
  });
  if (!r.ok) {
    const detail = await r.text();
    console.error('Resend error', r.status, detail);
    let reason = 'Could not send';
    try { reason = JSON.parse(detail).message || reason; } catch {}
    return res.status(502).json({ ok: false, error: reason });
  }
  return res.status(200).json({ ok: true });
}
