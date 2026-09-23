#!/bin/bash
# Turn a folder of downloaded photos into correctly named, resized placeholder
# work photos for one category.
#
#   tools/add-photos.sh nails ~/Downloads/nail-photos
#   tools/add-photos.sh hair ~/Downloads/hair-photos
#
# Categories: hair nails makeup lashes brows thelot
# Each file becomes HairDone/Resources/Work/work-<category>-<n>.jpg, longest
# side 1200 px, so a dozen photos add a couple of MB, not fifty.
set -euo pipefail
cd "$(dirname "$0")/.."
cat_="${1:-}"; src="${2:-}"
case "$cat_" in hair|nails|makeup|lashes|brows|thelot) ;; *) echo "usage: tools/add-photos.sh <hair|nails|makeup|lashes|brows|thelot> <folder>"; exit 1;; esac
[[ -d "$src" ]] || { echo "no such folder: $src"; exit 1; }
out=HairDone/Resources/Work
mkdir -p "$out"
shopt -s nullglob nocaseglob
existing=("$out"/work-"$cat_"-*.jpg)
n=${#existing[@]}
found=0
for f in "$src"/*.{jpg,jpeg,png,heic,webp}; do
  [[ -f "$f" ]] || continue
  found=1
  n=$((n + 1))
  dest="$out/work-$cat_-$n.jpg"
  sips -s format jpeg -s formatOptions 82 -Z 1200 "$f" --out "$dest" >/dev/null
  echo "$(basename "$f") -> $(basename "$dest")"
done
[[ "$found" == 1 ]] || { echo "no photos found in $src"; exit 1; }
echo "$cat_: $n photo(s). Now: xcodegen generate, then build."
