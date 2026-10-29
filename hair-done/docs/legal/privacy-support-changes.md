# Privacy policy: changes for support (published 29 Oct 2026)

Since 29 Oct 2026, email to hello@hairdonenailsdone.app goes through Cloudflare Email Routing to the
support agent, which keeps a copy in the database next to in-app reports. The live policy
(`site/privacy/index.html`) doesn't say that yet. Changes 1 to 4 describe what already happens. Change 5
only applies if the support agent's drafting is switched on (`private.app_flags` `support_ai`).

Keith approved all five on 29 Oct 2026, with two years for change 4; they're live in
`site/privacy/index.html` (last updated 29 October 2026). The two-year deletion runs daily (migration 0024).

## 1. What we collect

Now: "Messages you send in the app, and reports you make."

Proposed: "Messages you send in the app or email to us, and reports you make."

## 2. The services we use: Resend

Now: "Resend | Sending sign-in codes by email | United States"

Proposed: "Resend | Sending email: sign-in codes, receipts, and our replies to you | United States"

## 3. The services we use: Cloudflare (new row)

"Cloudflare | Our website, and receiving the email you send to hello@hairdonenailsdone.app | Worldwide,
from the location nearest you"

## 4. How long we keep it (new line)

"Emails you send us, with our replies, for two years, so we can look back if the same problem comes up
again. Then we delete them."

(Two years is a suggestion. Nothing deletes support emails yet. Pick the period and I'll add the clean-up
to the photo clean-up timer.)

## 5. Only if drafting is switched on: Anthropic (new row)

"Anthropic | Drafting our replies to the emails and reports you send us. A person reads and approves every
reply before it's sent. | United States"

And under "Who sees it", one sentence:

"When you email us or send a report, an AI service (Anthropic) may draft our reply. It sees your message and
the booking it's about. Apart from anything you write yourself, it never sees your ID photos, card details or
street address, and a person reads and approves every reply before it's sent."

What the agent sends to Anthropic, to back that sentence (from `functions/support/assess.ts`, `draftInput`):
the person's message and subject; their first name, whether they're a client or a pro, and when they
joined; and for up to six of their bookings, the reference, services, the other person's first name, the
time, the suburb, the status and the amounts. The agent adds no ID photos, card details, street addresses,
phone numbers or email addresses; only what the person wrote themselves, which can include anything.
