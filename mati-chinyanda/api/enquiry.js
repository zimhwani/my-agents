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
const TYPE_LABELS = { speaking: 'Talk or keynote', mc: 'MC / event host', panel: 'Panel or fireside host', podcast: 'Podcast guest or partnership', other: 'Something else' };
const LABELS = { name: 'Name', email: 'Email', organisation: 'Organisation', phone: 'Phone', event_type: 'Enquiry type', event_name: 'Event', event_date: 'Date', location: 'Where', format: 'Format', audience_size: 'Audience size', budget: 'Budget (AUD)', message: 'Message', source: 'Heard about Mati via' };


// ---- Branded email shell (table layout, inline styles: works in Gmail, Outlook, Apple Mail) ----
const SITE = 'https://www.matimc.com';
const F_SERIF = "Georgia,'Times New Roman',serif";
const F_SANS = "-apple-system,'Segoe UI',Helvetica,Arial,sans-serif";
function shell({ eyebrow, title, bodyHtml, cta, footerNote }) {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${esc(title)}</title></head>
<body style="margin:0;padding:0;background:#F5EFE6;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#F5EFE6;">
<tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;">
  <tr><td style="background:#0B0A0A;padding:28px 36px;border-radius:4px 4px 0 0;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr>
      <td style="font-family:${F_SERIF};font-size:26px;color:#F5EFE6;letter-spacing:-.01em;">Mati<span style="color:#D4AE5A;">.</span></td>
      <td align="right" style="font-family:${F_SANS};font-size:10px;letter-spacing:.2em;text-transform:uppercase;color:#D4AE5A;">Speaker &amp; MC</td>
    </tr></table>
  </td></tr>
  <tr><td style="background:#0B0A0A;padding:0 36px 40px;">
    <p style="margin:0 0 14px;font-family:${F_SANS};font-size:11px;letter-spacing:.18em;text-transform:uppercase;color:#D4AE5A;">${esc(eyebrow)}</p>
    <h1 style="margin:0;font-family:${F_SERIF};font-weight:400;font-size:34px;line-height:1.1;letter-spacing:-.02em;color:#F5EFE6;">${title}</h1>
  </td></tr>
  <tr><td style="background:#FBF8F3;padding:36px;border-left:1px solid #DDD5CC;border-right:1px solid #DDD5CC;font-family:${F_SANS};font-size:16px;line-height:1.65;color:#141212;">
    ${bodyHtml}
    ${cta ? `<table role="presentation" cellspacing="0" cellpadding="0" style="margin:28px 0 4px;"><tr><td style="background:#C39A3E;border-radius:999px;"><a href="${cta.href}" style="display:inline-block;padding:14px 26px;font-family:${F_SANS};font-size:13px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#0B0A0A;text-decoration:none;">${esc(cta.label)}</a></td></tr></table>` : ''}
  </td></tr>
  <tr><td style="background:#0B0A0A;padding:22px 36px;border-radius:0 0 4px 4px;font-family:${F_SANS};font-size:12px;line-height:1.6;color:#9B938E;">
    <span style="color:#BDB5AE;">Mati</span> · Speaker, MC &amp; event host · Melbourne / Naarm<br>
    <a href="${SITE}" style="color:#D4AE5A;text-decoration:none;">matimc.com</a> &nbsp;·&nbsp; <a href="mailto:${esc(process.env.ENQUIRY_TO || 'hello@matimc.com')}" style="color:#D4AE5A;text-decoration:none;">${esc(process.env.ENQUIRY_TO || 'hello@matimc.com')}</a>
    ${footerNote ? `<br><span style="color:#5A5451;">${esc(footerNote)}</span>` : ''}
  </td></tr>
</table>
</td></tr></table></body></html>`;
}
function detailsTable(f) {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-top:1px solid #DDD5CC;margin-top:8px;">` +
    Object.entries(LABELS).filter(([k]) => f[k]).map(([k, l]) =>
      `<tr><td style="padding:11px 16px 11px 0;border-bottom:1px solid #DDD5CC;font-family:${F_SANS};font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:#7A5D1C;vertical-align:top;white-space:nowrap;width:120px;">${esc(l)}</td><td style="padding:11px 0;border-bottom:1px solid #DDD5CC;font-family:${F_SANS};font-size:15px;line-height:1.5;color:#141212;white-space:pre-wrap;">${esc(f[k])}</td></tr>`
    ).join('') + `</table>`;
}

// Spam heuristics. Returns true for submissions that look automated. The form sets _t to the
// time it was opened; anything submitted in under 4 seconds is a bot. Then link-heavy SEO pitches.
function isSpam(f) {
  const opened = Number(f._t || 0);
  if (opened && Date.now() - opened < 4000) return true;
  const text = `${f.message || ''} ${f.name || ''} ${f.organisation || ''} ${f.event_name || ''}`.toLowerCase();
  const links = (text.match(/https?:\/\/|www\.|\b[a-z0-9-]+\.(?:pro|xyz|top|click|site|online|shop|info|biz|ru|cn)\b/g) || []).length;
  if (links >= 2) return true;
  const pitches = /search index|google'?s? index|indexsubmit|seo service|backlink|rank(?:ing)? (?:on|in) google|web design service|boost your (?:traffic|ranking)|crypto|bitcoin|casino|loan offer|guest post/;
  if (pitches.test(text)) return true;
  if (/^[a-z]{2,}[0-9]{3,}$/i.test(String(f.name || '').trim())) return true;   // "john48213"
  return false;
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ ok: false, error: 'POST only' });
  const key = process.env.RESEND_API_KEY, to = process.env.ENQUIRY_TO;
  if (!key || !to) return res.status(503).json({ ok: false, error: 'Email sending not configured' });
  let f;
  try { f = await readForm(req); } catch { return res.status(400).json({ ok: false, error: 'Bad form data' }); }
  if (f._gotcha) return res.status(200).json({ ok: true });                      // honeypot: pretend success
  if (isSpam(f)) { console.warn('Dropped as spam:', { name: f.name, email: f.email, msg: String(f.message).slice(0, 80) }); return res.status(200).json({ ok: true }); }
  if (!f.name || !f.email || !f.message) { console.error('Missing fields; keys received:', Object.keys(f)); return res.status(422).json({ ok: false, error: 'Name, email and message are required (form data not received)' }); }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.email)) return res.status(422).json({ ok: false, error: 'Invalid email' });
  if (f.date_tbc && !f.event_date) f.event_date = 'Not sure yet';
  if (f.event_type && TYPE_LABELS[f.event_type]) f.event_type = TYPE_LABELS[f.event_type];
  if (f.event_date && /^\d{4}-\d{2}-\d{2}$/.test(f.event_date)) { const [y, m, d] = f.event_date.split('-'); f.event_date = `${d}/${m}/${y}`; }
  const text = Object.entries(LABELS).filter(([k]) => f[k]).map(([k, l]) => `${l}: ${f[k]}`).join('\n');
  const first = String(f.name).trim().split(/\s+/)[0];
  const subject = `Enquiry: ${f.event_type || 'event'} · ${f.name}${f.organisation ? ' (' + f.organisation + ')' : ''}`;
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: process.env.ENQUIRY_FROM || 'Mati website <onboarding@resend.dev>',
      to: [to], reply_to: f.email, subject,
      html: shell({
        eyebrow: 'New enquiry · matimc.com',
        title: `${esc(f.name)}${f.organisation ? ', ' + esc(f.organisation) : ''}`,
        bodyHtml: `<p style="margin:0 0 18px;">${esc(f.event_type || 'Enquiry')}${f.event_name ? ' · ' + esc(f.event_name) : ''}${f.event_date ? ' · ' + esc(f.event_date) : ''}</p>${detailsTable(f)}`,
        cta: { href: `mailto:${f.email}?subject=${encodeURIComponent('Re: your enquiry' + (f.event_name ? ' about ' + f.event_name : ''))}`, label: 'Reply to ' + first },
        footerNote: 'Sent by the enquiry form on matimc.com. Reply goes straight to the enquirer.',
      }),
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
  const what = f.event_name ? ` about ${f.event_name}` : '';
  const confirmText = `Hi ${first},\n\nThanks for getting in touch${what}. I've got your enquiry and I'll come back to you within two business days, usually with a couple of questions so I can put the right proposal together.\n\nIf anything changes in the meantime, just reply to this email.\n\nMati\nmatimc.com\n\n---\nWhat you sent:\n${text}`;
  const confirmHtml = shell({
    eyebrow: 'Thanks, ' + esc(first),
    title: `Got your enquiry<span style="color:#D4AE5A;">.</span>`,
    bodyHtml: `<p style="margin:0 0 16px;">Hi ${esc(first)},</p><p style="margin:0 0 16px;">Thanks for getting in touch${esc(what)}. I've got your enquiry and I'll come back to you within two business days, usually with a couple of questions so I can put the right proposal together.</p><p style="margin:0 0 16px;">If anything changes in the meantime, just reply to this email.</p><p style="margin:0 0 28px;font-family:${F_SERIF};font-size:22px;color:#141212;">Mati</p><p style="margin:0 0 6px;font-family:${F_SANS};font-size:11px;letter-spacing:.18em;text-transform:uppercase;color:#7A5D1C;">What you sent</p>${detailsTable(f)}`,
    cta: { href: SITE + '/speaking', label: 'See how I work' },
    footerNote: "You're receiving this because you sent an enquiry through matimc.com.",
  });
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
