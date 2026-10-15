#!/bin/bash
#
# Turns on real text-message sign-in codes for Hair Done, through Twilio Verify.
# Twilio Verify picks the sender and handles Australian delivery rules, so there's no number to buy.
# The test numbers (0400 000 001 to 003, code 123456) keep working and never send a text.
#
# Before running (twilio.com):
#   1. Sign up, then upgrade the account (add a card and some credit). A trial account can only
#      text numbers you've verified with Twilio.
#   2. Verify > Services > Create new. Name it "Hair Done", tick SMS, leave the code length at 6.
#      Copy its Service SID (starts with VA).
#   3. From the Console home page, copy the Account SID (starts with AC) and the Auth Token.
#   4. A Supabase personal access token: supabase.com/dashboard/account/tokens > Generate new token.
#
# Keys are typed here, hidden, and go straight to Supabase. Nothing is saved.
# Usage:  tools/setup-sms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF")
[[ "$CODE" == 200 ]] || { echo "Supabase didn't accept that token for the hair-done project (HTTP $CODE). Nothing was changed."; exit 1; }

read -rp  "Twilio Account SID (AC...): " SID
read -rsp "Twilio Auth Token (hidden): " TOKEN; echo
read -rp  "Twilio Verify Service SID (VA...): " VA
SID=$(printf '%s' "$SID" | tr -d '[:space:]'); TOKEN=$(printf '%s' "$TOKEN" | tr -d '[:space:]'); VA=$(printf '%s' "$VA" | tr -d '[:space:]')
[[ "$SID" == AC* ]] || { echo "The Account SID starts with AC. It's on the Twilio Console home page."; exit 1; }
[[ "$VA" == VA* ]] || { echo "The Verify Service SID starts with VA. It's under Verify > Services."; exit 1; }

echo "==> Checking Twilio"
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -u "$SID:$TOKEN" "https://verify.twilio.com/v2/Services/$VA")
if [[ "$CODE" != 200 ]]; then
  echo "    Twilio said no (HTTP $CODE). Check the Account SID, Auth Token and Service SID. Nothing was changed."
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print('    ' + str(d.get('message', '')))" "$OUT" 2>/dev/null || true
  rm -f "$OUT"; exit 1
fi
python3 - "$OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(f"    ok: Verify service \"{d.get('friendly_name')}\", codes {d.get('code_length')} digits")
if d.get("code_length") != 6:
    print("    The app expects 6-digit codes. Set the code length to 6 on that service, then run this again.")
    sys.exit(1)
PY
rm -f "$OUT"

echo "==> Supabase phone sign-in"
AUTH=$(SID="$SID" TOKEN="$TOKEN" VA="$VA" python3 -c "
import json, os
print(json.dumps({
  'external_phone_enabled': True,
  'sms_provider': 'twilio_verify',
  'sms_twilio_verify_account_sid': os.environ['SID'],
  'sms_twilio_verify_auth_token': os.environ['TOKEN'],
  'sms_twilio_verify_message_service_sid': os.environ['VA'],
}))")
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X PATCH "https://api.supabase.com/v1/projects/$REF/config/auth" \
  -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" -d "$AUTH")
if [[ "$CODE" != 2* ]]; then
  echo "    Supabase said no (HTTP $CODE):"; cat "$OUT"; echo; rm -f "$OUT"
  echo "    Do it by hand: Authentication > Sign In / Providers > Phone > SMS provider: Twilio Verify."
  exit 1
fi
rm -f "$OUT"

# Read it back, so a field Supabase quietly ignored doesn't pass as done.
curl -sS -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF/config/auth" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ok = d.get('external_phone_enabled') and d.get('sms_provider') == 'twilio_verify' and d.get('sms_twilio_verify_message_service_sid')
print('    ok: phone sign-in on, Twilio Verify, test numbers kept' if ok else '    Supabase took the request but the settings did not stick. Set Twilio Verify by hand under Authentication > Sign In / Providers > Phone.')
sys.exit(0 if ok else 1)"
unset SBP TOKEN AUTH

echo
echo "Done. Real numbers now get a text with a 6-digit code. Try it with your own mobile."
echo "Twilio charges per code sent. Set a usage alert in Twilio (Billing > Usage triggers) so there are no surprises."
