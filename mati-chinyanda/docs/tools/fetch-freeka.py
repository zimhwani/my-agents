#!/usr/bin/env python3
"""Pull FreekÀ Runway photos from a press article into assets/img/raw/freeka-NN.jpg.
Run from any machine with normal internet, inside mati-chinyanda/:
    python3 docs/tools/fetch-freeka.py            # The Age, 29 Aug 2016 (default)
    python3 docs/tools/fetch-freeka.py <url>      # any article (WordPress uploads or Nine/ffx images)
Then: python3 docs/tools/images.py && python3 docs/tools/build.py
Numbering continues after any freeka-NN files already present. Only the standard library is used.
Photos belong to the publisher / photographer credited in the article; confirm permission before launch."""
import re, os, sys, glob, urllib.request, html
URL = sys.argv[1] if len(sys.argv) > 1 else "https://www.theage.com.au/national/victoria/african-inspired-fashion-on-runway-at-freeka-20160829-gr410y.html"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "img", "raw")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
      "Accept": "text/html,image/*,*/*;q=0.8", "Accept-Language": "en-AU,en;q=0.9"}
def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
page = get(URL).decode("utf-8", "ignore")
cands = set()
# Nine / The Age / SMH: images on static.ffx.io with size parameters in the path.
for m in re.finditer(r'https?:\\?/\\?/static\.ffx\.io\\?/images\\?/[^"\'\s<>]+', page):
    u = m.group(0).replace("\\/", "/")
    u = html.unescape(u)
    u = re.sub(r'\$width_\d+', '$width_2000', u)
    u = re.sub(r'\$zoom_[\d.]+', '$zoom_1', u)
    u = re.sub(r'\$multiply_[\d.]+', '$multiply_1', u)
    u = re.sub(r'\$ratio_[\d.]+', '$ratio_1.5', u)
    u = re.sub(r'q_\d+', 'q_90', u)
    cands.add(u)
if not cands:
    # WordPress-style sites: restrict to the article body, take original uploads.
    m = re.search(r'class="[^"]*(?:entry-content|post-content|td-post-content|article-content)[^"]*"', page)
    body = page[m.start():] if m else page
    end = re.search(r'(?:class="[^"]*(?:related|comments|yarpp|jp-relatedposts|td-post-next-prev|post-navigation|sidebar|footer)[^"]*"|<footer|</article>)', body[200:])
    body = body[: 200 + end.start()] if end else body
    for m in re.finditer(r'(?:src|data-src|data-lazy-src|href)=["\']([^"\']+?\.(?:jpe?g|png|webp))(?:\?[^"\']*)?["\']', body, re.I):
        u = html.unescape(m.group(1))
        if "wp-content/uploads" not in u or re.search(r'logo|avatar|icon|banner|gravatar', u, re.I): continue
        if u.startswith("//"): u = "https:" + u
        cands.add(re.sub(r'-\d{2,4}x\d{2,4}(?=\.\w+$)', '', u))
print(f"found {len(cands)} candidate images")
got, seen = [], set()
for u in sorted(cands):
    key = re.sub(r'.*/', '', u)            # same underlying image id, different crops
    if key in seen: continue
    try:
        data = get(u)
        if len(data) < 60_000: print("skip (small)", u[:90]); continue
        seen.add(key); got.append((len(data), u, data)); print("ok  ", len(data)//1024, "KB", u[:110])
    except Exception as e:
        print("fail", u[:90], e)
got.sort(reverse=True)
os.makedirs(OUT, exist_ok=True)
existing = sorted(glob.glob(os.path.join(OUT, "freeka-*.*")))
n = max([int(re.search(r'freeka-(\d+)', f).group(1)) for f in existing] + [0])
for _, u, data in got[:8]:
    n += 1
    path = os.path.join(OUT, f"freeka-{n:02d}.jpg")
    open(path, "wb").write(data); print("saved", path)
if not got: sys.exit("No images downloaded. Save the photos by hand as assets/img/raw/freeka-NN.jpg and run images.py.")
print("Now run: python3 docs/tools/images.py && python3 docs/tools/build.py")
