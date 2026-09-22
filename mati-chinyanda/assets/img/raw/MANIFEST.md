# Image Source Manifest — Mati Chinyanda personal-brand site

**Status: 0 files downloaded.** Every public web host is blocked by this session's egress
policy (CONNECT 403 from the proxy; only github.com / package registries are permitted, and the
WebFetch tool is blocked on the same domains). This manifest is therefore a *verified source map*:
run the fetch recipe at the bottom from any machine with normal internet access and the images
land in this folder with the filenames below.

Hosts confirmed blocked from this session (2026-09-22): saltmagazine.org, freekarunway.com (also
fails DNS — site may be down), podcasts.apple.com, open.spotify.com, castro.fm, music.amazon.com,
greataustralianpods.com, youtube.com, i.ytimg.com, instagram.com, tiktok.com, linkedin.com,
wikipedia.org, unsplash.com, google.com.

## Files present in this folder (verified)

| File | Dimensions | Format | Depicts | Source / rights |
|---|---|---|---|---|
| `mati-portrait-user.webp` | 1772×2000 (portrait 0.89:1) | WebP RGB, 259 KB | Mati laughing at a Shure SM7B mic in a plant-filled podcast studio; black faux-fur jacket, silver hoops, box braids; warm skin tones, green foliage, mud-cloth textile and chalk-art wall behind. Studio still from a What Left The Group Chat recording. | Supplied locally by the project owner before this pass (not downloaded here). Treat as Mati's own / podcast promo image — safe for the site; confirm photographer credit. **Hero #1 candidate**: strong eye-line right, natural crop headroom, works for full-height hero on the left with copy on the right. |

---

## Verified facts (from search snippets — use for captions/alt text)

| Fact | Source |
|---|---|
| Based in Melbourne (Clayton, VIC); Zimbabwean-Australian; BCom, Deakin University | ZoomInfo profile; ZIWA 2016 nominee list ("Mati Chinyanda (L'entendre) — Australia") |
| Co-founder of **FreekÀ Runway** — multicultural runway show "EXPRESS : YOUR : SELF", held 1 Sept 2018, Melbourne | freekarunway.com (search snippet) |
| Creator of **L'entendre** fashion blog; nominated *Fashion Blogger of the Year*, Zimbabwe International Women's Awards 2016 | groovemagazineinternational.wordpress.com/2016/08/04/ziwa-2016-nominees/ |
| Co-host of **What Left The Group Chat** (launched 2025) with Tahj and Jill — "three bold Black women: one Zimbabwean, one African American, one Zambian… navigating life in Australia" | Apple Podcasts id1847614435; Great Australian Pods |
| Contributing author at **Salt Magazine** (saltmagazine.org/author/mati/) | search index |
| Day job history: Program Manager, Monash Institute for Health & Clinical Education (2017); Program Coordinator, Monash Online Education | monash.edu newsletter Aug 2017; ZoomInfo |
| **FashionOne**: no verifiable public record found linking Mati to FashionOne. Do not use FashionOne logo without her confirmation. | — |

---

## Candidate images, ranked by hero value

### A. Podcast — What Left The Group Chat (highest-confidence assets)

| Target filename | Source page | How to get the direct URL | Expected | Rights |
|---|---|---|---|---|
| `wltgc-cover-3000.jpg` | https://podcasts.apple.com/il/podcast/what-left-the-group-chat/id1847614435 | `<meta property="og:image">` or the `<source srcset>` in the artwork `<picture>`; rewrite the mzstatic path suffix to `3000x3000bb.jpg` | 3000×3000 square cover art | Show's own promo art — Mati is a co-owner; safe |
| `wltgc-cover-640.jpg` | https://open.spotify.com/episode/3Oh0mkwGtDSxj7sYHtRgF6 (Ep. 1 "Ok, here goes something.") | og:image (`i.scdn.co/image/…`) | 640×640 | Same |
| `wltgc-cover-castro.jpg` | https://castro.fm/podcast/e99e8137-d1fb-47bc-ab5c-9f65484fc120 | og:image; also exposes the RSS feed URL → `<itunes:image href>` gives the master artwork | ≥1400 | Same |
| `wltgc-cover-amazon.jpg` | https://music.amazon.com/es-cl/podcasts/73171205-89b1-4cd8-b152-cf7ba9c4d283/what-left-the-group-chat | og:image | 500–1000 | Same |
| `wltgc-yt-banner.jpg`, `wltgc-yt-avatar.jpg` | https://www.youtube.com/channel/UCfLkiTk4H_VKDdI4XXaAnUg (handle @Whatleftthegroupchat) | page source: `"banner":{"thumbnails":[…]}` take the last (widest, ~2560px) and `"avatar":{"thumbnails"` (append `=s800`) | 2560×1440 banner, 800 avatar | Same |
| `wltgc-ep-XX-thumb.jpg` (one per video episode) | same channel → each video ID | `https://i.ytimg.com/vi/<VIDEO_ID>/maxresdefault.jpg` (fallback `sddefault.jpg`) | 1280×720 studio stills of Mati, Tahj & Jill | Same |
| `wltgc-tiktok-avatar.jpg` | https://www.tiktok.com/@what.left.the.gro | og:image | ~720 | Same |

Studio stills from the YouTube episode thumbnails are the best bet for "Mati at the mic" imagery.

### B. Mati portrait / editorial

| Target filename | Source page | How to get | Expected | Rights |
|---|---|---|---|---|
| `mati-salt-author.jpg` | http://www.saltmagazine.org/author/mati/ | author-box avatar (`img.avatar` / Gravatar `?s=` → set to 1024) plus og:image of each article she wrote | portrait, variable size | Salt Magazine / Mati — request permission for commercial use |
| `mati-salt-article-*.jpg` | article URLs listed on the author page | og:image of each | 1200×630+ | as above |
| `mati-lentendre-*.jpg` | https://lentendre.wordpress.com/ | header image + post featured images (`?w=2000` on wp.com CDN URLs) | 1000–2000 | Mati's own blog — safe |
| `mati-monash-2017.jpg` | https://www.monash.edu/healthed-institute/about/news/issue-2-august-2017 | look for conference photo `<img>` in the ANZAHPE item | uncertain; may be small | Monash — editorial only |
| `mati-linkedin.jpg` | LinkedIn (needs login; ask Mati for the original) | — | — | Mati |

### C. FreekÀ Runway

| Target filename | Source page | How to get | Expected | Rights |
|---|---|---|---|---|
| `freeka-logo.png` / `freeka-hero-*.jpg` | http://freekarunway.com/ (DNS failed from here — may be offline; try `web.archive.org/web/2018*/freekarunway.com`) | all `<img>` + CSS `background-image` + og:image | hero/runway | Mati co-owns — safe |
| `freeka-runway-2018-*.jpg` | Instagram @freekarunway (unverified handle) and the 2018 event photographer's gallery | ask Mati for the photographer's export; Instagram CDN blocks scrapes | 1080+ | Photographer — credit required |

### D. Logos of brands/media (only where verified)

- Salt Magazine (verified contributor) — logo on saltmagazine.org header.
- Zimbabwe International Women's Awards / ZIWA 2016 nominee (verified) — logo at ziwawards site.
- Monash University (verified employer, but *not* a brand-partner claim; use only in a bio timeline if at all).
- Apple Podcasts / Spotify / Amazon Music / YouTube "listen on" badges — official brand-asset kits (allowed use).
- FashionOne — **not verified**; omit unless Mati supplies proof.

---

## Fetch recipe (run from an unrestricted machine, inside this folder)

```bash
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
og() { curl -sSL -A "$UA" "$1" | grep -oE 'property="og:image"[^>]*content="[^"]+"' | head -1 | sed -E 's/.*content="([^"]+)".*/\1/'; }

curl -sSL -A "$UA" -o wltgc-cover-640.jpg  "$(og https://open.spotify.com/episode/3Oh0mkwGtDSxj7sYHtRgF6)"
curl -sSL -A "$UA" -o wltgc-cover-3000.jpg "$(og https://podcasts.apple.com/il/podcast/what-left-the-group-chat/id1847614435 | sed -E 's/[0-9]+x[0-9]+[a-z]*\.(jpg|png)$/3000x3000bb.jpg/')"
curl -sSL -A "$UA" -o wltgc-cover-castro.jpg "$(og https://castro.fm/podcast/e99e8137-d1fb-47bc-ab5c-9f65484fc120)"
curl -sSL -A "$UA" -o wltgc-cover-amazon.jpg "$(og https://music.amazon.com/es-cl/podcasts/73171205-89b1-4cd8-b152-cf7ba9c4d283/what-left-the-group-chat)"

# YouTube: list video IDs, then pull maxres thumbnails
curl -sSL -A "$UA" https://www.youtube.com/@Whatleftthegroupchat/videos | grep -oE '"videoId":"[A-Za-z0-9_-]{11}"' | sort -u | sed -E 's/.*"([A-Za-z0-9_-]{11})"/\1/' > yt_ids.txt
i=1; while read id; do curl -sSL -A "$UA" -o "wltgc-ep-$(printf %02d $i)-$id.jpg" "https://i.ytimg.com/vi/$id/maxresdefault.jpg"; i=$((i+1)); done < yt_ids.txt

# Salt Magazine author page + article og:images
curl -sSL -A "$UA" http://www.saltmagazine.org/author/mati/ | grep -oE 'https?://[^"]+\.(jpg|jpeg|png|webp)' | sort -u > salt_imgs.txt

# Verify: drop anything <600px wide or non-image
python3 - <<'PY'
import glob, os
from PIL import Image
for f in sorted(glob.glob('*.jpg')+glob.glob('*.png')+glob.glob('*.webp')):
    try:
        im=Image.open(f); w,h=im.size
        print(('KEEP' if w>=600 else 'DROP'), f, w, h, im.format)
        if w<600: os.remove(f)
    except Exception as e:
        print('DROP', f, 'not an image:', e); os.remove(f)
PY
```

After fetching, append a row per file (filename · source page · direct URL · WxH · depicts · rights)
to this manifest.

## Recommended hero shortlist (once fetched)
1. `wltgc-cover-3000.jpg` — 3000px square cover; crop-safe for hero + OG image.
2. Best YouTube `maxresdefault` still with Mati centred at the mic — the "host/MC" hero.
3. `wltgc-yt-banner.jpg` — 2560×1440 wide banner; natural full-bleed hero band.
4. `mati-salt-author.jpg` / L'entendre header — editorial portrait for the About section.
5. `freeka-hero-*.jpg` (or Wayback capture) — runway energy for the "Founder" section.
