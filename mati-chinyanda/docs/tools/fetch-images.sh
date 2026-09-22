#!/usr/bin/env bash
# Downloads the podcast artwork and episode stills that the site is wired to use.
# Run from any machine with normal internet, from the mati-chinyanda folder:
#   bash docs/tools/fetch-images.sh && python3 docs/tools/images.py && python3 docs/tools/build.py
# Sources (verified 22 Sep 2026): Apple Podcasts show page og:image and the What Left The Group Chat
# YouTube channel (@Whatleftthegroupchat). All are the podcast's own promotional images.
set -e
cd "$(dirname "$0")/../../assets/img/raw"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
get() { curl -fsSL -A "$UA" "$1" -o "$2" && echo "ok  $2" || echo "FAILED $2"; }
get "https://is1-ssl.mzstatic.com/image/thumb/Podcasts211/v4/a9/e2/8d/a9e28db1-00dc-2916-6c4b-863d4090d31b/mza_14256773780674523336.jpg/3000x3000bb.jpg" wltgc-cover.jpg
get "https://yt3.googleusercontent.com/ZZoifUXZ8rlAcgjPv44Dsf7rHg-bREd78nLcKUzpPZFzq_jp2VyraNEdvp2PeJfEBIwIDpGy=w2276-fcrop64=1" wltgc-banner.jpg
i=0
for id in 2b1ZNydIAJA AoyDBp1Gn4I BjPTcH5jcFk CY6PCXioAEU Dt1eGc5vvr0 E278rON9vWU GAiEooPV9E8 Z0PUCiderDA i4gN_F1nT6k rMU9nsoBrUo rOzcjdd1JZ0 stIWH0xrpu8; do
  i=$((i+1)); n=$(printf "wltgc-still-%02d.jpg" $i)
  get "https://i.ytimg.com/vi/$id/maxresdefault.jpg" "$n" || get "https://i.ytimg.com/vi/$id/hqdefault.jpg" "$n"
done
# FreekÀ Runway show photos: freekarunway.com is offline. Drop your own show photography here as
# freeka-01.jpg ... freeka-08.jpg (any size over 1200px wide) and the gallery picks them up.
echo "Done. Now run: python3 docs/tools/images.py && python3 docs/tools/build.py"
