#!/bin/bash
# Download free placeholder work photos from Pexels and put them in the app.
#
#   PEXELS_API_KEY=xxxx tools/fetch-photos.sh          # four per category
#   PEXELS_API_KEY=xxxx tools/fetch-photos.sh 6        # six per category
#
# Get a key in a minute at https://www.pexels.com/api/ (free). The Pexels licence
# allows use in apps without attribution. Photos are portrait, cropped to the work,
# and resized to 1200 px by tools/add-photos.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${PEXELS_API_KEY:?Set PEXELS_API_KEY (free at https://www.pexels.com/api/)}"
PER="${1:-4}"
TMP=$(mktemp -d)

# category|search terms (first term first; later ones fill in if the first is thin)
QUERIES=(
  "nails|gel manicure close up hands|nail polish application|acrylic nails hand"
  "hair|braiding hair close up|blow dry hair salon|balayage hair back view"
  "makeup|makeup artist brush cheek|lipstick application close up|makeup application eyes closed"
  "lashes|eyelash extensions application|lash lift close up"
  "brows|eyebrow threading|brow lamination|eyebrow shaping close up"
  "thelot|bride getting ready hair makeup|getting ready mirror makeup"
)

fetch() { # category, query, count -> downloads into $TMP/<category>/
  local cat_="$1" q="$2" want="$3"
  local got=0
  [[ -d "$TMP/$cat_" ]] && got=$(find "$TMP/$cat_" -type f | wc -l | tr -d ' ')
  [[ "$got" -ge "$want" ]] && return 0
  local need=$((want - got))
  local json
  json=$(curl -sS -H "Authorization: $PEXELS_API_KEY" \
    "https://api.pexels.com/v1/search?query=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$q")&orientation=portrait&per_page=$((need + 6))")
  python3 - "$json" "$need" <<'PY' | while read -r url; do
import json, sys
data = json.loads(sys.argv[1]); need = int(sys.argv[2])
seen = 0
for p in data.get("photos", []):
    # skip obvious stock-face shots by preferring landscape-free, hand/hair-ish alt text
    alt = (p.get("alt") or "").lower()
    if any(w in alt for w in ("portrait of", "smiling", "posing", "looking at camera")): continue
    print(p["src"]["large2x"]); seen += 1
    if seen >= need: break
PY
    mkdir -p "$TMP/$cat_"
    n=$(find "$TMP/$cat_" -type f | wc -l | tr -d ' ')
    curl -sS -L "$url" -o "$TMP/$cat_/$((n + 1)).jpg" && echo "  $cat_: got $((n + 1))"
  done
}

for entry in "${QUERIES[@]}"; do
  cat_="${entry%%|*}"; rest="${entry#*|}"
  echo "==> $cat_"
  IFS='|' read -ra terms <<< "$rest"
  for t in "${terms[@]}"; do fetch "$cat_" "$t" "$PER"; done
  if [[ -d "$TMP/$cat_" ]] && [[ "$(find "$TMP/$cat_" -type f | wc -l | tr -d ' ')" -gt 0 ]]; then
    rm -f HairDone/Resources/Work/work-"$cat_"-*.jpg
    tools/add-photos.sh "$cat_" "$TMP/$cat_" || echo "  $cat_: naming step failed; the downloads are in $TMP/$cat_"
  else
    echo "  $cat_: nothing found; keeps the drawn art"
  fi
done
echo "==> done. Now: xcodegen generate, then build. (Downloads kept in $TMP in case you want the originals.)"
