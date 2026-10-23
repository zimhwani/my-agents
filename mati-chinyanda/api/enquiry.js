// Vercel serverless function: receives the enquiry form and emails it via Resend.
// Env vars (Vercel → Settings → Environment Variables):
//   RESEND_API_KEY  from resend.com (verify the matimc.com domain there first)
//   ENQUIRY_TO      where enquiries go, e.g. hello@matimc.com
//   ENQUIRY_FROM    optional. Default "Mati website <onboarding@resend.dev>", which works before the
//                   matimc.com domain is verified in Resend but can only deliver to the Resend account's
//                   own email. Once matimc.com is verified, set it to "Mati website <enquiries@matimc.com>".
async function readForm(req) {
  // Vercel may have parsed the body already (req.body); otherwise read the raw stream.
  const ct = req.headers['content-type'] || '';
  if (req.body !== undefined && req.body !== null) {
    if (typeof req.body === 'object' && !Buffer.isBuffer(req.body)) return req.body;
    const str = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : String(req.body);
    if (ct.includes('application/json')) return JSON.parse(str || '{}');
    if (ct.includes('application/x-www-form-urlencoded')) return Object.fromEntries(new URLSearchParams(str));
    return parseMultipart(str, ct);
  }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks);
  if (ct.includes('application/json')) return JSON.parse(raw.toString('utf8') || '{}');
  if (ct.includes('application/x-www-form-urlencoded')) return Object.fromEntries(new URLSearchParams(raw.toString('utf8')));
  return parseMultipart(raw.toString('utf8'), ct);
}
function parseMultipart(text, ct) {
  const m = /boundary=(?:"([^"]+)"|([^;]+))/.exec(ct);
  if (!m) return {};
  const boundary = '--' + (m[1] || m[2]);
  const out = {};
  for (const part of text.split(boundary)) {
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
  if (!f.name || !f.email || !f.message) { console.error('Missing fields; keys received:', Object.keys(f)); return res.status(422).json({ ok: false, error: 'Name, email and message are required (form data not received)' }); }
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

  // Confirmation to the person enquiring. Best effort: a failure here never fails the enquiry.
  const first = String(f.name).trim().split(/\s+/)[0];
  const what = f.event_name ? ` about ${f.event_name}` : '';
  const confirmText = `Hi ${first},\n\nThanks for getting in touch${what}. I've got your enquiry and I'll come back to you within two business days, usually with a couple of questions so I can put the right proposal together.\n\nIf anything changes in the meantime, just reply to this email.\n\nMati\nmatimc.com\n\n---\nWhat you sent:\n${text}`;
  const confirmHtml = `<div style="font:15px/1.6 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#111;max-width:560px"><p>Hi ${esc(first)},</p><p>Thanks for getting in touch${esc(what)}. I've got your enquiry and I'll come back to you within two business days, usually with a couple of questions so I can put the right proposal together.</p><p>If anything changes in the meantime, just reply to this email.</p><p>Mati<br><a href="https://www.matimc.com" style="color:#7A5D1C">matimc.com</a></p><hr style="border:0;border-top:1px solid #ddd;margin:24px 0"><p style="color:#666;font-size:13px;margin:0 0 8px">What you sent:</p><table style="font-size:13px">${rows}</table></div>`;
  try {
    const c = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: process.env.ENQUIRY_FROM || 'Mati website <onboarding@resend.dev>',
        to: [f.email], reply_to: to,
        subject: `Got your enquiry${what ? ' about ' + f.event_name : ''}`,
        html: confirmHtml, text: confirmText,
      }),
    });
    if (!c.ok) console.error('Confirmation not sent', c.status, await c.text());
  } catch (e) { console.error('Confirmation error', e); }
  return res.status(200).json({ ok: true });
}
