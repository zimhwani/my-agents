#!/bin/bash
#
# Gives Hair Done's agents their Anthropic API key, from your Mac. It's used for drafted support replies
# (supabase/functions/support) and the two lines at the top of the watchdog's morning email.
# The key goes straight to Supabase's function secrets. Nothing is printed or saved.
#
# Before running:
#   1. An Anthropic API key: console.anthropic.com > API keys > Create key. Name it "Hair Done agents".
#      Set a monthly spend limit there (Settings > Limits); support drafts cost cents each.
#   2. A Supabase personal access token: supabase.com/dashboard/account/tokens > Generate new token.
#      Delete it again afterwards; nothing else needs it.
#
# Usage:  tools/setup-ai.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua

read -rsp "Anthropic API key (sk-ant-..., hidden): " KEY; echo
KEY=$(printf '%s' "$KEY" | tr -d '[:space:]')
[[ "$KEY" == sk-ant-* ]] || { echo "Anthropic keys start with sk-ant-."; exit 1; }
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" https://api.anthropic.com/v1/models)
[[ "$CODE" == 200 ]] || { echo "Anthropic didn't accept that key (HTTP $CODE). Nothing was changed."; exit 1; }
echo "    Anthropic accepted it."

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }

echo "==> Supabase function secrets"
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X POST "https://api.supabase.com/v1/projects/$REF/secrets" \
  -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" \
  -d "$(KEY="$KEY" python3 -c "import json,os; print(json.dumps([{'name':'ANTHROPIC_API_KEY','value':os.environ['KEY']}]))")")
if [[ "$CODE" == 2* ]]; then echo "    ok: ANTHROPIC_API_KEY"; else echo "    failed (HTTP $CODE):"; cat "$OUT"; echo; rm -f "$OUT"; exit 1; fi
rm -f "$OUT"
unset SBP KEY

echo
echo "Done. The next support email or report comes with a drafted reply."
echo "Drafting itself is switched by private.app_flags 'support_ai' (on since 29 Oct 2026)."
