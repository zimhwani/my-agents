#!/bin/bash
#
# Turns on push notifications for Hair Done, from your Mac.
# The APNs key is read from the .p8 file on disk and goes straight to Supabase's function secrets.
# Nothing is printed or saved.
#
# Before running (developer.apple.com, signed in as the team that owns the app):
#   1. Certificates, Identifiers & Profiles > Keys > +. Name it "Hair Done push", tick
#      "Apple Push Notifications service (APNs)", Continue, Register, Download. Apple lets you
#      download it once: keep the AuthKey_XXXXXXXXXX.p8 file somewhere safe.
#   2. Identifiers > com.keithchinyanda.hairdone > tick "Push Notifications" > Save.
#      (Xcode's automatic signing usually does this when it sees the entitlement.)
#   3. A Supabase personal access token: supabase.com/dashboard/account/tokens > Generate new token.
#
# Usage:  tools/setup-push.sh ~/Downloads/AuthKey_ABC123DEFG.p8
set -euo pipefail
cd "$(dirname "$0")/.."

REF=yohqeunmgrxyakviofua
TOPIC=com.keithchinyanda.hairdone

P8_FILE="${1:-}"
if [[ -z "$P8_FILE" ]]; then read -rp "Path to the AuthKey_....p8 file: " P8_FILE; fi
P8_FILE="${P8_FILE/#\~/$HOME}"
[[ -f "$P8_FILE" ]] || { echo "Can't find $P8_FILE."; exit 1; }
grep -q "BEGIN PRIVATE KEY" "$P8_FILE" || { echo "That file isn't an APNs key (.p8)."; exit 1; }

# The key id is in the file name Apple gives it: AuthKey_<KEYID>.p8
GUESS=$(basename "$P8_FILE" | sed -nE 's/^AuthKey_([A-Z0-9]{10})\.p8$/\1/p')
read -rp "Key ID${GUESS:+ [$GUESS]}: " KEY_ID; KEY_ID="${KEY_ID:-$GUESS}"
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "A key ID is 10 letters and numbers, shown next to the key in Apple's Keys list."; exit 1; }

TEAM_GUESS=$(sed -nE 's/^HAIRDONE_TEAM_ID *= *([A-Z0-9]{10}).*/\1/p' HairDone.xcconfig 2>/dev/null | head -1 || true)
read -rp "Team ID${TEAM_GUESS:+ [$TEAM_GUESS]}: " TEAM_ID; TEAM_ID="${TEAM_ID:-$TEAM_GUESS}"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "A team ID is 10 letters and numbers (developer.apple.com > Membership details)."; exit 1; }

read -rsp "Supabase personal access token (sbp_..., hidden): " SBP; echo
SBP=$(printf '%s' "$SBP" | tr -d '[:space:]')
[[ "$SBP" == sbp_* ]] || { echo "That isn't a Supabase personal access token (they start with sbp_)."; exit 1; }
CODE=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $SBP" "https://api.supabase.com/v1/projects/$REF")
[[ "$CODE" == 200 ]] || { echo "Supabase didn't accept that token for the hair-done project (HTTP $CODE). Nothing was changed."; exit 1; }

echo "==> Supabase function secrets"
BODY=$(KEY_ID="$KEY_ID" TEAM_ID="$TEAM_ID" TOPIC="$TOPIC" P8_FILE="$P8_FILE" python3 -c "import json,os; print(json.dumps([
  {'name':'APNS_KEY_ID','value':os.environ['KEY_ID']},
  {'name':'APNS_TEAM_ID','value':os.environ['TEAM_ID']},
  {'name':'APNS_TOPIC','value':os.environ['TOPIC']},
  {'name':'APNS_KEY_P8','value':open(os.environ['P8_FILE']).read().strip()}]))")
OUT=$(mktemp)
CODE=$(curl -sS -o "$OUT" -w '%{http_code}' -X POST "https://api.supabase.com/v1/projects/$REF/secrets" \
  -H "Authorization: Bearer $SBP" -H "Content-Type: application/json" -d "$BODY")
if [[ "$CODE" == 2* ]]; then echo "    ok"; else echo "    failed (HTTP $CODE):"; cat "$OUT"; echo; rm -f "$OUT"; exit 1; fi
rm -f "$OUT"
unset SBP BODY

echo
echo "Done. Pushes start straight away: no redeploy needed."
echo "Next: xcodegen generate, run the app on your phone from Xcode, and say yes when it asks about notifications."
echo "Builds run from Xcode use Apple's sandbox; TestFlight builds use production. The app tells the server which."
