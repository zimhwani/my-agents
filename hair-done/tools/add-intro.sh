#!/bin/bash
# Put a welcome-screen clip in place.
#
#   tools/add-intro.sh hair   ~/Downloads/braiding.mp4
#   tools/add-intro.sh makeup ~/Downloads/IMG_2041.MOV
#   tools/add-intro.sh nails  ~/Downloads/polish.mp4
#
# With ffmpeg installed (brew install ffmpeg) the clip is trimmed to 6 s, cropped to
# portrait 1080x1920, muted and compressed to ~5 MB. Without it, the file is copied
# as is, which plays fine but is bigger.
set -euo pipefail
cd "$(dirname "$0")/.."
slot="${1:-}"; src="${2:-}"
case "$slot" in hair|makeup|lashes|nails) ;; *) echo "usage: tools/add-intro.sh <hair|makeup|lashes|nails> <video file>"; exit 1;; esac
[[ -f "$src" ]] || { echo "no such file: $src"; exit 1; }
out=HairDone/Resources/Intro
rm -f "$out"/intro-"$slot".mp4 "$out"/intro-"$slot".mov "$out"/intro-"$slot".m4v
if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -loglevel error -y -i "$src" -t 6 \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30" \
    -c:v libx264 -b:v 6M -pix_fmt yuv420p -an -movflags +faststart "$out/intro-$slot.mp4"
  echo "intro-$slot.mp4: $(du -h "$out/intro-$slot.mp4" | cut -f1), trimmed and compressed"
else
  ext="${src##*.}"; ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  case "$ext" in mp4|mov|m4v) ;; *) echo "ffmpeg isn't installed and .$ext isn't a format iOS plays directly. brew install ffmpeg, or export as .mp4/.mov first."; exit 1;; esac
  cp "$src" "$out/intro-$slot.$ext"
  echo "intro-$slot.$ext: $(du -h "$out/intro-$slot.$ext" | cut -f1), copied as is (brew install ffmpeg to compress)"
fi
echo "Now: xcodegen generate, then build."
