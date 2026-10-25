#!/bin/bash
#
# Sign-in for Apple's app reviewer. Apple's reviewer can't receive our email codes, so for one
# address you choose, a fixed six-digit code works instead (functions/review-sign-in). Use an
# address you own (Outlook and Gmail take a +tag, e.g. you+review@outlook.com) so the real code
# emails that go out for it land with you, not bounce.
#
#   tools/setup-review.sh        turn it on: saves REVIEW_EMAIL and a fresh REVIEW_CODE, prints both
#                                for App Store Connect > App Review Information > Sign-in required
#   tools/setup-review.sh off    turn it off once the app is approved
#
# The Supabase token is typed here, hidden, and goes straight to Supabase. Nothing is saved.
set -euo pipefail
REF=yohqeunmgrxyakviofua

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF")
[[ "$CODE" == 200 ]] || { echo "Supabase didn't accept that token (HTTP $CODE). Make a new one at supabase.com/dashboard/account/tokens. Nothing was changed."; exit 1; }
API="https://api.supabase.com/v1/projects/$REF/secrets"

if [[ "${1:-}" == "off" ]]; then
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$API" -H "Authorization: Bearer $SBP" \
    -H "Content-Type: application/json" -d '["REVIEW_EMAIL","REVIEW_CODE"]')
  [[ "$CODE" == 2* ]] && echo "Off. The review sign-in no longer works." || echo "Supabase said no (HTTP $CODE)."
  exit 0
fi

read -rp "Review email (an address you own): " EMAIL
EMAIL=$(printf '%s' "$EMAIL" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
[[ "$EMAIL" == *@*.* ]] || { echo "That isn't an email address."; exit 1; }
PIN=$(python3 -c "import secrets; print(f'{secrets.randbelow(900000) + 100000}')")

BODY=$(EMAIL="$EMAIL" PIN="$PIN" python3 -c "
import json, os
print(json.dumps([{'name': 'REVIEW_EMAIL', 'value': os.environ['EMAIL']}, {'name': 'REVIEW_CODE', 'value': os.environ['PIN']}]))")
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$API" -H "Authorization: Bearer $SBP" \
  -H "Content-Type: application/json" -d "$BODY")
unset SBP BODY
[[ "$CODE" == 2* ]] || { echo "Supabase said no (HTTP $CODE). Nothing was changed."; exit 1; }

cat <<MSG

On. Put this in App Store Connect > your app > the version > App Review Information:
  Sign-in required: yes
  User name: $EMAIL
  Password:  $PIN
  Notes:     Sign in with "Continue with email". Enter the address above, tap Send code, then enter
             $PIN as the six-digit code. (It's a fixed code for review; no email needed.)

Try it yourself first: sign out, Continue with email, $EMAIL, then $PIN.
When the app's approved: tools/setup-review.sh off
MSG
