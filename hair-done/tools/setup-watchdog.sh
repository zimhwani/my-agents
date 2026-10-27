#!/bin/bash
#
# Points the Hair Done watchdog (supabase/functions/watchdog) at your inbox, from your Mac.
# Everything goes straight to Supabase's function secrets. Nothing is printed or saved.
#
# It asks for, in order (Enter skips any of the optional ones):
#   1. The email address the watchdog writes to.
#   2. A Resend key and sender, only if tools/setup-email.sh hasn't saved them already.
#   3. A read-only Stripe key (optional, recommended). Stripe > Developers > API keys > Create restricted
#      key, name it "Hair Done watchdog", set to Read: Balance, Disputes, Events, Webhook Endpoints;
#      everything else None. Without it the watchdog uses the payment key, and still only reads.
#   4. The App Store Connect key that tools/asc-status.py already uses, read from HairDone.xcconfig and
#      ~/.appstoreconnect/private_keys/. You're asked before it's sent.
#   5. An Anthropic API key (optional), for the two lines at the top of the morning email.
#   6. A Supabase personal access token: supabase.com/dashboard/account/tokens > Generate new token.
#
# Usage:  tools/setup-watchdog.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua
SECRETS=()   # name=value pairs, sent together at the end
add() { SECRETS+=("$1=$2"); }

read -rp "Email the watchdog writes to: " TO
TO=$(printf '%s' "$TO" | tr -d '[:space:]')
[[ "$TO" == *@*.* ]] || { echo "That doesn't look like an email address."; exit 1; }
add WATCHDOG_TO "$TO"

read -rsp "Resend API key (re_..., hidden; Enter if setup-email.sh already saved one): " RESEND; echo
RESEND=$(printf '%s' "$RESEND" | tr -d '[:space:]')
if [[ -n "$RESEND" ]]; then
  [[ "$RESEND" == re_* ]] || { echo "Resend keys start with re_."; exit 1; }
  add RESEND_API_KEY "$RESEND"
fi
read -rp "Send from (an address on your Resend domain; Enter to use the receipts address): " FROM
FROM=$(printf '%s' "$FROM" | tr -d '[:space:]')
[[ -z "$FROM" ]] || add WATCHDOG_FROM "$FROM"

read -rsp "Read-only Stripe key (rk_..., hidden; Enter to skip): " RK; echo
RK=$(printf '%s' "$RK" | tr -d '[:space:]')
if [[ -n "$RK" ]]; then
  [[ "$RK" == rk_* ]] || { echo "A restricted key starts with rk_. Don't use the sk_ secret key here."; exit 1; }
  add STRIPE_WATCHDOG_KEY "$RK"
fi

ASC_KEY_ID=$(sed -nE 's/^HAIRDONE_ASC_KEY_ID *= *([A-Z0-9]+).*/\1/p' HairDone.xcconfig 2>/dev/null | head -1 || true)
ASC_ISSUER=$(sed -nE 's/^HAIRDONE_ASC_ISSUER_ID *= *([0-9a-f-]+).*/\1/p' HairDone.xcconfig 2>/dev/null | head -1 || true)
ASC_P8="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
if [[ -n "$ASC_KEY_ID" && -n "$ASC_ISSUER" && -f "$ASC_P8" ]]; then
  read -rp "Let the watchdog read App Store Connect with key $ASC_KEY_ID? [Y/n] " YN
  if [[ ! "$YN" =~ ^[Nn] ]]; then
    add ASC_KEY_ID "$ASC_KEY_ID"; add ASC_ISSUER_ID "$ASC_ISSUER"; add ASC_KEY_P8 "$(cat "$ASC_P8")"
  fi
else
  echo "No App Store Connect key found (HAIRDONE_ASC_KEY_ID in HairDone.xcconfig and its .p8). Skipping."
fi

read -rsp "Anthropic API key (sk-ant-..., hidden; Enter to skip): " ANT; echo
ANT=$(printf '%s' "$ANT" | tr -d '[:space:]')
[[ -z "$ANT" ]] || add ANTHROPIC_API_KEY "$ANT"

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF")
[[ "$CODE" == 200 ]] || { echo "Supabase didn't accept that token for the hair-done project (HTTP $CODE). Nothing was changed."; exit 1; }

echo "==> Supabase function secrets"
BODY=$(python3 -c "import json,sys; print(json.dumps([{'name':k,'value':v} for k,v in (a.split('=',1) for a in sys.argv[1:])]))" "${SECRETS[@]}")
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X POST "https://api.supabase.com/v1/projects/$REF/secrets" \
  -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" -d "$BODY")
if [[ "$CODE" == 2* ]]; then echo "    ok: $(printf '%s\n' "${SECRETS[@]}" | cut -d= -f1 | paste -sd' ' -)"; else echo "    failed (HTTP $CODE):"; cat "$OUT"; echo; rm -f "$OUT"; exit 1; fi
rm -f "$OUT"
unset SBP BODY SECRETS RESEND RK ANT

echo
echo "Done. The first morning email comes at 7:30 am Melbourne time."
echo "To get one now: Supabase > SQL editor >  select private.call_watchdog('digest');"
echo "If it doesn't arrive: select ran_at, mode, level, email from private.watchdog_runs order by ran_at desc limit 5;"
