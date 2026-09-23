#!/bin/bash
#
# Connects Hair Done to Stripe and the live Supabase project in one go, from your Mac.
# Keys are typed here, hidden, and go straight to Stripe and Supabase. Nothing is saved
# except the public keys in HairDone.xcconfig (which is gitignored).
#
# Before running:
#   - Stripe (test mode): Connect switched on (Dashboard > Connect > Get started, Express, Australia).
#   - Supabase: a personal access token (supabase.com/dashboard/account/tokens > Generate new token).
#
# What it does:
#   1. Creates the two Stripe webhooks (your account + connected accounts) and reads their secrets.
#   2. Stores STRIPE_SECRET_KEY and both webhook secrets as the project's Edge Function secrets.
#   3. Turns on phone sign-in with test numbers (no SMS needed yet) and Sign in with Apple.
#   4. Writes the Supabase and Stripe publishable lines into HairDone.xcconfig.
#
# Usage:  tools/connect-backend.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua
HOOK_URL="https://$REF.supabase.co/functions/v1/stripe-webhook"
BUNDLE=com.keithchinyanda.hairdone
TEST_NUMBERS="61400000001=123456,61400000002=123456,61400000003=123456"

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

echo "Hair Done: connect the backend"
echo
read -rsp "Stripe secret key (sk_test_..., hidden): " SK; echo
[[ "$SK" == sk_test_* || "$SK" == sk_live_* || "$SK" == rk_* ]] || { echo "That doesn't look like a Stripe secret key."; exit 1; }
read -rp  "Stripe publishable key (pk_test_...): " PK
[[ "$PK" == pk_* ]] || { echo "That doesn't look like a Stripe publishable key."; exit 1; }
read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
[[ -n "$SBP" ]] || { echo "Need the Supabase token."; exit 1; }

stripe() { curl -sS -u "$SK:" "$@"; }

echo
echo "==> Stripe account"
ACCT=$(stripe https://api.stripe.com/v1/account)
echo "$ACCT" | json "d.get('error',{}).get('message') or ('ok: ' + (d.get('settings',{}).get('dashboard',{}).get('display_name') or d.get('id')))"
echo "$ACCT" | grep -q '"error"' && exit 1

echo "==> Stripe webhooks"
EXISTING=$(stripe "https://api.stripe.com/v1/webhook_endpoints?limit=100" |
  python3 -c "import json,sys; print(' '.join(e['id'] for e in json.load(sys.stdin).get('data',[]) if e['url']=='$HOOK_URL'))")
if [[ -n "$EXISTING" ]]; then
  echo "    Hair Done webhooks already exist. Stripe only shows a signing secret when a webhook is made,"
  read -rp "    so replace them with new ones? [y/N] " yn
  [[ "$yn" == [yY] ]] || { echo "Stopped. Nothing changed."; exit 1; }
  for id in $EXISTING; do stripe -X DELETE "https://api.stripe.com/v1/webhook_endpoints/$id" >/dev/null; done
fi
PLATFORM=$(stripe https://api.stripe.com/v1/webhook_endpoints -d url="$HOOK_URL" \
  -d "description=Hair Done bookings" \
  -d "enabled_events[]=payment_intent.amount_capturable_updated" \
  -d "enabled_events[]=payment_intent.succeeded" \
  -d "enabled_events[]=payment_intent.canceled" \
  -d "enabled_events[]=setup_intent.succeeded")
WHSEC=$(echo "$PLATFORM" | json "d.get('secret','')")
[[ "$WHSEC" == whsec_* ]] || { echo "$PLATFORM" | json "d.get('error',{}).get('message')"; exit 1; }
CONNECT=$(stripe https://api.stripe.com/v1/webhook_endpoints -d url="$HOOK_URL" -d connect=true \
  -d "description=Hair Done pros' payouts" \
  -d "enabled_events[]=account.updated" \
  -d "enabled_events[]=payout.paid")
WHSEC_CONNECT=$(echo "$CONNECT" | json "d.get('secret','')")
[[ "$WHSEC_CONNECT" == whsec_* ]] || { echo "$CONNECT" | json "d.get('error',{}).get('message')"; exit 1; }
echo "    ok: two webhooks to $HOOK_URL"

supa() { curl -sS -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" "$@"; }

echo "==> Supabase function secrets"
BODY=$(SK="$SK" W1="$WHSEC" W2="$WHSEC_CONNECT" python3 -c "import json,os; print(json.dumps([
  {'name':'STRIPE_SECRET_KEY','value':os.environ['SK']},
  {'name':'STRIPE_WEBHOOK_SECRET','value':os.environ['W1']},
  {'name':'STRIPE_CONNECT_WEBHOOK_SECRET','value':os.environ['W2']}]))")
CODE=$(supa -o /tmp/hd-secrets.out -w '%{http_code}' -X POST "https://api.supabase.com/v1/projects/$REF/secrets" -d "$BODY")
[[ "$CODE" == 2* ]] && echo "    ok" || { echo "    failed (HTTP $CODE):"; cat /tmp/hd-secrets.out; echo; exit 1; }
rm -f /tmp/hd-secrets.out

echo "==> Supabase sign-in"
UNTIL=$(python3 -c "import datetime; print((datetime.datetime.utcnow()+datetime.timedelta(days=365)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
AUTH=$(python3 -c "import json; print(json.dumps({
  'site_url': 'hairdone://auth',
  'uri_allow_list': 'hairdone://auth',
  'external_phone_enabled': True,
  'sms_test_otp': '$TEST_NUMBERS',
  'sms_test_otp_valid_until': '$UNTIL',
  'external_apple_enabled': True,
  'external_apple_client_id': '$BUNDLE'}))")
CODE=$(supa -o /tmp/hd-auth.out -w '%{http_code}' -X PATCH "https://api.supabase.com/v1/projects/$REF/config/auth" -d "$AUTH")
if [[ "$CODE" == 2* ]]; then
  echo "    ok: phone sign-in with test numbers, and Sign in with Apple"
else
  echo "    Supabase said no (HTTP $CODE):"; cat /tmp/hd-auth.out; echo
  echo "    Do it by hand: Authentication > Sign In / Providers > Phone (test numbers: $TEST_NUMBERS) and Apple (client id $BUNDLE)."
fi
rm -f /tmp/hd-auth.out

echo "==> HairDone.xcconfig"
touch HairDone.xcconfig
set_line() { # key value
  if grep -q "^$1 *=" HairDone.xcconfig; then
    python3 - "$1" "$2" <<'PY'
import re, sys
k, v = sys.argv[1], sys.argv[2]
p = "HairDone.xcconfig"; s = open(p).read()
s = re.sub(r"(?m)^%s *=.*$" % re.escape(k), "%s = %s" % (k, v), s)
open(p, "w").write(s)
PY
  else
    echo "$1 = $2" >> HairDone.xcconfig
  fi
}
set_line HAIRDONE_SUPABASE_URL 'https:/$()/'"$REF.supabase.co"
set_line HAIRDONE_SUPABASE_KEY sb_publishable_dDCoMmIEzBXsLRi4itW94g_fNS5KY0s
set_line HAIRDONE_STRIPE_KEY "$PK"
echo "    ok"

unset SK SBP WHSEC WHSEC_CONNECT
echo
echo "Done. Test sign-in numbers (no SMS sent): 0400 000 001, 0400 000 002, 0400 000 003, code 123456."
echo "Next: xcodegen generate, then run the app. Apple Pay is separate: docs/go-live.md section 2."
