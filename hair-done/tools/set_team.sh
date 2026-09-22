#!/bin/bash
# Read the Apple Developer Team ID off the signing certificate Xcode created
# when you signed in, and write it into HairDone.xcconfig.
#
# If golf-caddy already has a Caddy.xcconfig on this Mac, that's quicker:
#   sed 's/^CADDY_/HAIRDONE_/' ../golf-caddy/Caddy.xcconfig > HairDone.xcconfig
set -euo pipefail
cd "$(dirname "$0")/.."

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Develop"; then
  echo "No Apple development certificate found yet."
  echo "In Xcode: Settings > Accounts > + > Apple ID, sign in. Then open"
  echo "HairDone.xcodeproj, pick the HairDone target, set Team on Signing &"
  echo "Capabilities. Re-run this."
  exit 1
fi

# The Team ID is the certificate's OU, not the code in parentheses after the email.
team=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null \
  | sed -n 's/.*OU=\([A-Z0-9]\{10\}\).*/\1/p' | head -1)

if [ -z "$team" ]; then
  echo "Found a certificate but couldn't read an OU from it:"
  security find-certificate -a -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null
  exit 1
fi

if [ -f HairDone.xcconfig ]; then
  sed -i '' "s/^HAIRDONE_TEAM_ID *=.*/HAIRDONE_TEAM_ID = $team/" HairDone.xcconfig
else
  sed "s/^HAIRDONE_TEAM_ID *=.*/HAIRDONE_TEAM_ID = $team/" HairDone.xcconfig.example > HairDone.xcconfig
fi
echo "Team ID $team written to HairDone.xcconfig."
echo "Now add HAIRDONE_ASC_KEY_ID and HAIRDONE_ASC_ISSUER_ID (same values as Caddy's)."
