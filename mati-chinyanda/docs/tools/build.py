"""Assemble the static pages from docs/tools/pages/*.html fragments.
Usage: python3 docs/tools/build.py   (run from mati-chinyanda/)
Each fragment starts with a JSON front-matter block on the first line: {"path": "/speaking", "title": ..., "description": ..., "nav": "speaking", "og": "..."}"""
import json, os, re, glob
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = "https://matichinyanda.vercel.app"
EMAIL = "hello@matichinyanda.com"

NAV = [("speaking", "/speaking", "Speaking"), ("podcast", "/podcast", "Podcast"),
       ("freeka", "/freeka-runway", "FreekÀ Runway"), ("about", "/about", "About")]

ICONS = {
 "arrow": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
 "arrow-ne": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 17L17 7M8 7h9v9"/></svg>',
 "youtube": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M23.5 6.2a3 3 0 0 0-2.1-2.1C19.5 3.6 12 3.6 12 3.6s-7.5 0-9.4.5A3 3 0 0 0 .5 6.2 31 31 0 0 0 0 12a31 31 0 0 0 .5 5.8 3 3 0 0 0 2.1 2.1c1.9.5 9.4.5 9.4.5s7.5 0 9.4-.5a3 3 0 0 0 2.1-2.1A31 31 0 0 0 24 12a31 31 0 0 0-.5-5.8zM9.6 15.6V8.4l6.3 3.6-6.3 3.6z"/></svg>',
 "tiktok": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12.5 0h4.1c.3 2.6 1.9 4.6 4.4 5.1v4.1c-1.6 0-3.1-.5-4.4-1.4v7.6A6.6 6.6 0 1 1 10 8.9v4.2a2.5 2.5 0 1 0 2.5 2.5V0z"/></svg>',
 "apple": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 0 0-3.6 19.3l.6-3.7a6.3 6.3 0 1 1 6 0l.6 3.7A10 10 0 0 0 12 2zm0 6.5a3.5 3.5 0 0 0-1.3 6.8c.2-1.2.4-2.4.6-3.2a.8.8 0 0 1 1.4 0c.2.8.4 2 .6 3.2A3.5 3.5 0 0 0 12 8.5zm0 5.5c-.7 0-1 .5-1 1l.6 5.5c0 .3.2.5.4.5s.4-.2.4-.5L13 15c0-.5-.3-1-1-1z"/></svg>',
 "amazon": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M13.9 15.6c-1.3 1-3.3 1.5-5 1.5-2.4 0-4.5-.9-6.2-2.3-.1-.1 0-.3.2-.2 1.8 1 4 1.7 6.3 1.7 1.5 0 3.2-.3 4.8-1 .2-.1.4.2.2.3zm.6-.6c-.2-.2-1.1-.1-1.5 0-.1 0-.2-.1 0-.2.8-.5 2-.4 2.1-.2.2.2 0 1.4-.7 2-.1.1-.2 0-.2-.1.2-.4.5-1.3.3-1.5zM12.6 5.3V4.4c0-.1.1-.2.2-.2h4c.1 0 .2.1.2.2v.8c0 .1-.1.3-.3.5l-2.1 3c.8 0 1.6.1 2.3.5.2.1.2.2.2.4v1c0 .1-.1.3-.3.2-1.2-.6-2.9-.7-4.2 0-.2.1-.3-.1-.3-.2v-1c0-.2 0-.4.1-.6l2.4-3.4h-2.1c-.1 0-.2-.1-.2-.2zM6 11h-1.2c-.1 0-.2-.1-.2-.2V4.4c0-.1.1-.2.2-.2H6c.1 0 .2.1.2.2v.8c.3-.8.9-1.2 1.7-1.2.8 0 1.3.4 1.7 1.2.3-.8 1-1.2 1.8-1.2.5 0 1.1.2 1.5.7.4.6.3 1.4.3 2.1v4c0 .1-.1.2-.2.2h-1.2c-.1 0-.2-.1-.2-.2V7.4c0-.3 0-1-.1-1.3-.1-.4-.4-.6-.8-.6-.3 0-.7.2-.8.6-.1.4-.1.9-.1 1.3v3.4c0 .1-.1.2-.2.2H8.4c-.1 0-.2-.1-.2-.2V7.4c0-.7.1-1.8-.8-1.8s-.9 1-.9 1.8v3.4c0 .1-.1.2-.2.2H6z"/></svg>',
}

def head(p):
    url = SITE + (p["path"] if p["path"] != "/" else "/")
    og = SITE + p.get("og", "/assets/img/og.jpg")
    ld = p.get("ld", "")
    return f'''<!doctype html>
<html lang="en-AU" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{p["title"]}</title>
<meta name="description" content="{p["description"]}">
<link rel="canonical" href="{url}">
<meta name="theme-color" content="#0B0A0A">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Mati Chinyanda">
<meta property="og:title" content="{p["title"]}">
<meta property="og:description" content="{p["description"]}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{og}">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="preload" href="/assets/fonts/fraunces-latin-full-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/assets/fonts/figtree-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/assets/css/fonts.css?v=1">
<link rel="stylesheet" href="/assets/css/style.css?v=1">
<script>document.documentElement.classList.replace('no-js','js')</script>
{ld}
</head>
<body>
<a class="skip-link" href="#main">Skip to content</a>
'''

def header(p):
    items = ""
    for key, href, label in NAV:
        cur = ' aria-current="page"' if p.get("nav") == key else ""
        items += f'<li><a href="{href}"{cur}>{label}</a></li>'
    light = " site-header--light" if p.get("header") == "light" else ""
    return f'''<header class="site-header{light}">
  <div class="container">
    <a class="brand" href="/" aria-label="Mati Chinyanda — home">Mati <span class="brand__mark">Chinyanda</span></a>
    <button class="nav-toggle" aria-expanded="false" aria-controls="site-nav"><span class="nav-toggle__label">Menu</span><span class="nav-toggle__bars" aria-hidden="true"></span></button>
    <nav class="site-nav" id="site-nav" aria-label="Primary">
      <ul>{items}</ul>
      <a class="btn" href="/book">Book Mati</a>
      <p class="site-nav__meta">Melbourne / Naarm · Available Australia-wide &amp; internationally</p>
    </nav>
  </div>
</header>
<main id="main">
'''

def footer(p):
    return f'''</main>
<section class="cta-band grain" aria-labelledby="cta-title">
  <div class="container" data-reveal>
    <p class="eyebrow" style="color:var(--gold-400)">Let's talk</p>
    <h2 id="cta-title">Got a room that needs <em>energy</em>?</h2>
    <div class="btn-row">
      <a class="btn btn--gold btn--lg" href="/book">Book Mati {ICONS["arrow"]}</a>
      <a class="btn btn--outline btn--lg" href="mailto:{EMAIL}" style="color:var(--ivory-50)">Email directly</a>
    </div>
  </div>
</section>
<footer class="site-footer">
  <div class="container">
    <div class="cols">
      <div>
        <a class="brand" href="/">Mati <span class="brand__mark">Chinyanda</span></a>
        <p style="margin-top:1rem;max-width:36ch">Speaker, MC &amp; event host. Co-founder and co-host of <em>What Left The Group Chat</em>. Founder of FreekÀ Runway.</p>
        <div class="social" style="margin-top:1.25rem">
          <a href="https://www.youtube.com/@Whatleftthegroupchat" aria-label="What Left The Group Chat on YouTube" rel="noopener" target="_blank">{ICONS["youtube"]}</a>
          <a href="https://www.tiktok.com/@what.left.the.gro" aria-label="What Left The Group Chat on TikTok" rel="noopener" target="_blank">{ICONS["tiktok"]}</a>
          <a href="https://podcasts.apple.com/au/podcast/what-left-the-group-chat/id1847614435" aria-label="What Left The Group Chat on Apple Podcasts" rel="noopener" target="_blank">{ICONS["apple"]}</a>
        </div>
      </div>
      <div><h4>Pages</h4><ul><li><a href="/speaking">Speaking &amp; MC</a></li><li><a href="/podcast">Podcast</a></li><li><a href="/freeka-runway">FreekÀ Runway</a></li><li><a href="/about">About</a></li><li><a href="/book">Book Mati</a></li></ul></div>
      <div><h4>Ventures</h4><ul><li><a href="/podcast">What Left The Group Chat</a></li><li><a href="/freeka-runway">FreekÀ Runway</a></li><li><a href="/about#story">FashionOne</a></li><li><a href="/about#story">L'entendre</a></li></ul></div>
      <div><h4>Connect</h4><ul><li><a href="mailto:{EMAIL}">{EMAIL}</a></li><li>Melbourne / Naarm, Australia</li><li>Available Australia-wide &amp; internationally</li></ul></div>
    </div>
    <div class="legal">
      <span>© <span data-year>2026</span> Mati Chinyanda. All rights reserved.</span>
      <span>Made on the lands of the Wurundjeri people of the Kulin Nation. Sovereignty was never ceded.</span>
    </div>
  </div>
</footer>
<script src="/assets/js/main.js?v=1" defer></script>
</body>
</html>
'''

def relativise(html):
    """Rewrite root-absolute links to relative ones with .html extensions (artifact/file preview)."""
    html = re.sub(r'(href|src|srcset)="/assets/', r'\1="assets/', html)
    html = html.replace('href="/favicon.svg"', 'href="favicon.svg"')
    html = re.sub(r'href="/(speaking|podcast|freeka-runway|about|book)(\?[^"]*)?(#[^"]*)?"', lambda m: f'href="{m.group(1)}.html{m.group(2) or ""}{m.group(3) or ""}"', html)
    html = re.sub(r'href="/(#[^"]*)?"', lambda m: f'href="index.html{m.group(1) or ""}"', html)
    return html

def build(out_dir=None, relative=False):
    out_dir = out_dir or ROOT
    os.makedirs(out_dir, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(ROOT, "docs/tools/pages/*.html"))):
        raw = open(f, encoding="utf-8").read()
        first, body = raw.split("\n", 1)
        p = json.loads(first.strip().removeprefix("<!--").removesuffix("-->"))
        body = body.replace("{{email}}", EMAIL)
        for k, v in ICONS.items(): body = body.replace("{{icon:%s}}" % k, v)
        out = head(p) + header(p) + body + footer(p)
        name = "index.html" if p["path"] == "/" else p["path"].strip("/") + ".html"
        if p.get("file"): name = p["file"]
        if relative: out = relativise(out)
        open(os.path.join(out_dir, name), "w", encoding="utf-8").write(out)
        print("wrote", os.path.join(out_dir, name))
    if relative: return
    # sitemap
    urls = [SITE + "/"] + [SITE + h for _, h, _ in NAV] + [SITE + "/book"]
    open(os.path.join(ROOT, "sitemap.xml"), "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + "".join(f"  <url><loc>{u}</loc></url>\n" for u in urls) + "</urlset>\n")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--preview": build(sys.argv[2], relative=True)
    else: build()
