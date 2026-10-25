#!/bin/bash
#
# Turns on email sign-in for Hair Done: the app asks for an email, Supabase emails a 6-digit code,
# she types it in. No password, no link to tap.
#
# Two ways to run it:
#   Testing:  no Resend key. Supabase's built-in mailer sends the codes, but only to the email
#             addresses of your Supabase team members, and only a couple an hour. Fine for you.
#   Real:     a Resend account (resend.com, free up to 3,000 emails a month) with your domain
#             verified (Resend > Domains > Add, then the DNS records it shows). Codes then go to
#             anyone, from an address on that domain, e.g. hello@hairdone.com.au.
#             The same key also turns on receipt emails: it's saved as the edge function secrets
#             RESEND_API_KEY and RECEIPT_FROM, which the receipt, pay-booking and settle functions read.
#
# Keys are typed here, hidden, and go straight to Supabase. Nothing is saved.
# Usage:  tools/setup-email.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF")
[[ "$CODE" == 200 ]] || { echo "Supabase didn't accept that token for the hair-done project (HTTP $CODE). Nothing was changed."; exit 1; }

echo
read -rsp "Resend API key (re_..., hidden; press return to skip and test with Supabase's mailer): " RESEND; echo
RESEND=$(printf '%s' "$RESEND" | tr -d '[:space:]')
FROM=""
if [[ -n "$RESEND" ]]; then
  [[ "$RESEND" == re_* ]] || { echo "That doesn't look like a Resend API key (they start with re_)."; exit 1; }
  read -rp "Send from (an address on your verified domain, e.g. hello@hairdone.com.au): " FROM
  [[ "$FROM" == *@*.* ]] || { echo "That isn't an email address."; exit 1; }
  read -rp "Send receipts from (return for ${FROM}): " RECEIPT_FROM
  RECEIPT_FROM=${RECEIPT_FROM:-$FROM}
  [[ "$RECEIPT_FROM" == *@*.* && "${RECEIPT_FROM#*@}" == "${FROM#*@}" ]] || {
    echo "Receipts need an address on the same verified domain as ${FROM}."; exit 1; }
fi

SUBJECT="Your Hair Done code"
read -r -d '' TEMPLATE <<'HTML' || true
<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;max-width:420px;margin:0 auto;padding:32px 24px;color:#241A16;background:#F4ECE4">
  <p style="font-family:Georgia,'New York',serif;font-size:28px;font-style:italic;margin:0 0 28px">hd.</p>
  <p style="font-size:16px;line-height:1.5;margin:0 0 16px">Here's your code for Hair Done.</p>
  <p style="font-family:Georgia,'New York',serif;font-size:40px;letter-spacing:8px;margin:0 0 24px">{{ .Token }}</p>
  <p style="font-size:14px;line-height:1.5;color:#6B5C55;margin:0">It works for an hour. If you didn't ask for it, you can ignore this email.</p>
</div>
HTML

echo "==> Supabase email sign-in"
AUTH=$(RESEND="$RESEND" FROM="$FROM" SUBJECT="$SUBJECT" TEMPLATE="$TEMPLATE" python3 -c "
import json, os
c = {
  'external_email_enabled': True,
  'mailer_autoconfirm': False,
  'mailer_otp_length': 6,
  'mailer_otp_exp': 3600,
  # A new account and a returning one get the same email: the code, no link.
  'mailer_subjects_confirmation': os.environ['SUBJECT'],
  'mailer_templates_confirmation_content': os.environ['TEMPLATE'],
  'mailer_subjects_magic_link': os.environ['SUBJECT'],
  'mailer_templates_magic_link_content': os.environ['TEMPLATE'],
}
if os.environ['RESEND']:
  c.update({
    'smtp_host': 'smtp.resend.com', 'smtp_port': '465', 'smtp_user': 'resend',
    'smtp_pass': os.environ['RESEND'], 'smtp_admin_email': os.environ['FROM'],
    'smtp_sender_name': 'Hair Done', 'smtp_max_frequency': 30,
    'rate_limit_email_sent': 100,
  })
print(json.dumps(c))")
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X PATCH "https://api.supabase.com/v1/projects/$REF/config/auth" \
  -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" -d "$AUTH")
if [[ "$CODE" == 2* ]]; then
  echo "    ok"
else
  echo "    Supabase said no (HTTP $CODE):"; cat "$OUT"; echo; rm -f "$OUT"; exit 1
fi
rm -f "$OUT"

# Read it back: Supabase can answer 200 and still leave a setting as it was.
echo "==> Checking it took"
WANT_SMTP=$([[ -n "$RESEND" ]] && echo yes || echo no)
curl -sS -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF/config/auth" | \
  WANT_SMTP="$WANT_SMTP" FROM="$FROM" SUBJECT="$SUBJECT" python3 -c "
import json, os, sys
d = json.load(sys.stdin)
checks = [
  ('email sign-in on',          d.get('external_email_enabled') is True),
  ('6-digit codes',             d.get('mailer_otp_length') == 6),
  ('code email subject',        d.get('mailer_subjects_magic_link') == os.environ['SUBJECT']),
  ('code in the email',         '{{ .Token }}' in (d.get('mailer_templates_magic_link_content') or '')),
  ('code in the sign-up email', '{{ .Token }}' in (d.get('mailer_templates_confirmation_content') or '')),
]
if os.environ['WANT_SMTP'] == 'yes':
  checks += [
    ('sent through Resend',    d.get('smtp_host') == 'smtp.resend.com'),
    ('from your address',      d.get('smtp_admin_email') == os.environ['FROM']),
  ]
bad = [name for name, ok in checks if not ok]
for name, ok in checks:
  print(('    ok:   ' if ok else '    NOT SET: ') + name)
if bad:
  print()
  print('    Some settings did not stick. Set them by hand in Supabase:')
  print('      Authentication > Emails > SMTP Settings: host smtp.resend.com, port 465, user resend,')
  print('        password = your Resend key, sender ' + (os.environ['FROM'] or 'hello@yourdomain') + ', name Hair Done')
  print('      Authentication > Emails > Templates > Magic Link and Confirm signup: put {{ .Token }} in the body')
  print('      Authentication > Providers > Email: OTP length 6')
sys.exit(1 if bad else 0)
"

if [[ -n "$RESEND" ]]; then
  echo "==> Receipt emails (edge function secrets)"
  BODY=$(RESEND="$RESEND" RECEIPT_FROM="$RECEIPT_FROM" python3 -c "
import json, os
print(json.dumps([{'name': 'RESEND_API_KEY', 'value': os.environ['RESEND']},
                  {'name': 'RECEIPT_FROM', 'value': os.environ['RECEIPT_FROM']}]))")
  OUT=$(mktemp)
  CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X POST "https://api.supabase.com/v1/projects/$REF/secrets" \
    -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" -d "$BODY")
  unset BODY
  if [[ "$CODE" == 2* ]]; then
    NAMES=$(curl -sS -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF/secrets" | \
      python3 -c "import json,sys; print(' '.join(s['name'] for s in json.load(sys.stdin)))")
    for n in RESEND_API_KEY RECEIPT_FROM; do
      [[ " $NAMES " == *" $n "* ]] && echo "    ok:   $n" || echo "    NOT SET: $n"
    done
  else
    echo "    Supabase said no (HTTP $CODE):"; cat "$OUT"; echo
    echo "    Set them by hand: Supabase > Edge Functions > Secrets: RESEND_API_KEY and RECEIPT_FROM."
  fi
  rm -f "$OUT"
fi
unset SBP RESEND AUTH

echo
if [[ -n "$FROM" ]]; then
  echo "Done. Codes come from Hair Done <$FROM> through Resend, and receipts from <$RECEIPT_FROM>."
  echo "Receipts go out when a booking's paid; a paid booking's receipt screen now has Email it to me."
else
  echo "Done, in test mode: codes only reach your Supabase team members' email addresses."
  echo "Run this again with a Resend key when your domain is verified."
fi
echo "In the app: Continue with email, type the address, then the 6-digit code from the email."
