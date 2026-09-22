#!/bin/bash
#
# Archive, validate and upload a TestFlight build of Hair Done.
#
# The build number is the repository's commit count, so it only ever goes up
# and App Store Connect never sees the same CFBundleVersion twice. A tester
# saying "build 14 did X" names a commit:
#   git show $(git rev-list --reverse HEAD | sed -n 14p)
#
# Usage:  tools/release.sh            archive, validate, upload
#         tools/release.sh --validate stop after validating (no upload)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE=/tmp/hairdone-archive.xcarchive
EXPORT=/tmp/hairdone-export

# Account identifiers live in the ignored HairDone.xcconfig; the credential
# itself is the .p8 in ~/.appstoreconnect/private_keys, never in the repo.
cfg() { sed -n "s/^$1 *= *//p" HairDone.xcconfig | tr -d ' '; }
TEAM=$(cfg HAIRDONE_TEAM_ID)
KEY_ID="${HAIRDONE_ASC_KEY_ID:-$(cfg HAIRDONE_ASC_KEY_ID)}"
ISSUER="${HAIRDONE_ASC_ISSUER_ID:-$(cfg HAIRDONE_ASC_ISSUER_ID)}"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
if [[ ! -f "$KEY_FILE" ]]; then
  echo "error: no API key at $KEY_FILE." >&2
  echo "If Caddy has shipped from this Mac the key is already there under its" >&2
  echo "own id; put that id in HairDone.xcconfig. Otherwise download it from" >&2
  echo "App Store Connect > Users and Access > Integrations (downloads once)." >&2
  exit 1
fi
for v in TEAM KEY_ID ISSUER; do
  if [[ -z "${!v}" ]]; then
    echo "error: $v missing. Fill it into HairDone.xcconfig (see HairDone.xcconfig.example)." >&2
    exit 1
  fi
done

# A build that isn't a commit can't be traced from a bug report, and its
# number would collide with the next one.
if [[ -n "$(git status --porcelain -- .)" ]]; then
  echo "error: uncommitted changes in hair-done/. Commit, then run this again." >&2
  git status --short -- . >&2
  exit 1
fi

# This app lives in a folder of a bigger repo, so count only commits that
# touched it. Still monotonic, still names a commit.
BUILD=$(git rev-list --count HEAD -- .)
SHA=$(git rev-parse --short HEAD)
echo "==> build $BUILD ($SHA)"

xcodegen generate >/dev/null
rm -rf "$ARCHIVE" "$EXPORT"

echo "==> archiving"
# The API key is passed to signing too, so xcodebuild can ask Apple for a
# profile it has never seen instead of failing with "No Accounts".
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_FILE"
      -authenticationKeyID "$KEY_ID"
      -authenticationKeyIssuerID "$ISSUER")

xcodebuild archive \
  -project HairDone.xcodeproj -scheme HairDone \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  "${AUTH[@]}" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  | tail -2

GOT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
      "$ARCHIVE/Products/Applications/HairDone.app/Info.plist")
if [[ "$GOT" != "$BUILD" ]]; then
  echo "error: archive says build $GOT, expected $BUILD." >&2
  echo "CFBundleVersion in project.yml must be \$(CURRENT_PROJECT_VERSION)." >&2
  exit 1
fi
echo "==> archive is build $GOT"

cat > /tmp/hairdone-export-options.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

echo "==> exporting"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist /tmp/hairdone-export-options.plist \
  "${AUTH[@]}" | grep -E 'error|SUCCEEDED'

echo "==> validating"
xcrun altool --validate-app -f "$EXPORT/HairDone.ipa" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" 2>&1 | grep -E 'VERIFY|ERROR' || true

if [[ "${1:-}" == "--validate" ]]; then
  echo "==> stopping before upload as asked"
  exit 0
fi

echo "==> uploading"
xcrun altool --upload-app -f "$EXPORT/HairDone.ipa" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" 2>&1 | grep -E 'UPLOAD|ERROR|Delivery'

echo "==> build $BUILD ($SHA) is with Apple; processing takes 5-15 min"
echo "    then: tools/testflight-ship.py $BUILD --internal"
