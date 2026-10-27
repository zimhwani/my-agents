#!/bin/bash
#
# Connects pro vetting (supabase/functions/vetting) to the government's ABN Lookup, from your Mac.
# The key goes straight to Supabase's function secrets. Nothing is printed or saved.
#
# Before running:
#   1. Register for ABN Lookup web services (free): abr.business.gov.au > Tools > Web services >
#      "Register". They email you a GUID, which looks like 1a2b3c4d-1234-5678-9abc-def012345678.
#   2. A Supabase personal access token: supabase.com/dashboard/account/tokens > Generate new token.
#      Delete it again afterwards; nothing else needs it.
# Vetting emails go to the watchdog's address, so run tools/setup-watchdog.sh first if you haven't.
#
# Usage:  tools/setup-vetting.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua

read -rsp "ABN Lookup GUID (hidden): " GUID; echo
GUID=$(printf '%s' "$GUID" | tr -d '[:space:]' | tr 'A-F' 'a-f')
[[ "$GUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || { echo "That doesn't look like a GUID (8-4-4-4-12 letters and numbers)."; exit 1; }

# Try it on Hair Done's own ABN before saving it.
MSG=$(curl -sS -m 20 "https://abr.business.gov.au/json/AbnDetails.aspx?abn=45281131814&callback=c&guid=$GUID" \
  | sed -e 's/^c(//' -e 's/)$//' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Message') or ('ok:' + d.get('AbnStatus','')))")
[[ "$MSG" == ok:* ]] || { echo "ABN Lookup didn't accept that GUID: $MSG. Nothing was changed."; exit 1; }
echo "    ABN Lookup accepted it (Hair Done's ABN reads ${MSG#ok:})."

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }

echo "==> Supabase function secrets"
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X POST "https://api.supabase.com/v1/projects/$REF/secrets" \
  -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" \
  -d "$(GUID="$GUID" python3 -c "import json,os; print(json.dumps([{'name':'ABR_GUID','value':os.environ['GUID']}]))")")
if [[ "$CODE" == 2* ]]; then echo "    ok: ABR_GUID"; else echo "    failed (HTTP $CODE):"; cat "$OUT"; echo; rm -f "$OUT"; exit 1; fi
rm -f "$OUT"
unset SBP GUID

echo
echo "Done. Every pro who sends their ID from now on gets their ABN looked up."
echo "Try it on any pro without saving or emailing: Supabase > SQL editor >"
echo "  select net.http_post(url := 'https://$REF.supabase.co/functions/v1/vetting', headers := jsonb_build_object('content-type','application/json','x-cron-secret',(select value from private.settings where key='cron_secret')), body := jsonb_build_object('dry', true, 'pro_id', '<pro id>'));"
