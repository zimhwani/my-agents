#!/usr/bin/env python3
"""Pull FreekÀ Runway 2016 photos from the Salt Magazine article into assets/img/raw/freeka-0N.jpg.
Run from any machine with normal internet, inside mati-chinyanda/:
    python3 docs/tools/fetch-freeka.py
    python3 docs/tools/images.py
    python3 docs/tools/build.py
Uses only the Python standard library. Downloads the original-size uploads from the article,
skips logos/avatars/tiny files, keeps the 8 largest. Photos belong to Salt Magazine / the
photographer credited in the article; confirm permission before going live."""
import re, os, sys, urllib.request, html
URL = "https://www.saltmagazine.org/freeka-runway-2016-association-msfw-curated/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "img", "raw")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"}
def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
page = get(URL).decode("utf-8", "ignore")
# Keep only the article body: from the entry content to the first related/comments/footer block.
m = re.search(r'class="[^"]*(?:entry-content|post-content|td-post-content|article-content)[^"]*"', page)
if m:
    body = page[m.start():]
    end = re.search(r'(?:class="[^"]*(?:related|comments|yarpp|jp-relatedposts|td-post-next-prev|post-navigation|sidebar|footer)[^"]*"|<footer|</article>)', body[200:])
    page = body[: 200 + end.start()] if end else body
    print("restricted to article body:", len(page), "chars")
else:
    print("WARNING: could not find the article body, scanning whole page (may include unrelated images)")
cands = set()
for m in re.finditer(r'(?:src|data-src|data-lazy-src|href)=["\']([^"\']+?\.(?:jpe?g|png|webp))(?:\?[^"\']*)?["\']', page, re.I):
    u = html.unescape(m.group(1))
    if "wp-content/uploads" not in u: continue
    if re.search(r'logo|avatar|icon|banner|gravatar|ad[-_]', u, re.I): continue
    u = re.sub(r'-\d{2,4}x\d{2,4}(?=\.\w+$)', '', u)   # strip WordPress size suffix -> original
    if u.startswith("//"): u = "https:" + u
    cands.add(u)
for m in re.finditer(r'srcset=["\']([^"\']+)["\']', page):
    for part in m.group(1).split(","):
        u = part.strip().split(" ")[0]
        if "wp-content/uploads" in u:
            cands.add(re.sub(r'-\d{2,4}x\d{2,4}(?=\.\w+$)', '', html.unescape(u)))
print(f"found {len(cands)} candidate images")
got = []
for u in sorted(cands):
    try:
        data = get(u)
        if len(data) < 60_000: print("skip (small)", u); continue
        got.append((len(data), u, data)); print("ok  ", len(data)//1024, "KB", u)
    except Exception as e:
        print("fail", u, e)
got.sort(reverse=True)
os.makedirs(OUT, exist_ok=True)
for i, (_, u, data) in enumerate(got[:8], 1):
    ext = os.path.splitext(u)[1].lower().replace("jpeg", "jpg")
    path = os.path.join(OUT, f"freeka-{i:02d}{ext if ext in ('.jpg','.png','.webp') else '.jpg'}")
    open(path, "wb").write(data); print("saved", path)
if not got: sys.exit("No images downloaded. Send me the photos directly and I'll add them.")
print("Now run: python3 docs/tools/images.py && python3 docs/tools/build.py")
