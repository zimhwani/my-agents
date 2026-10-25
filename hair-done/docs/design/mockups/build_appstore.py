"""App Store screenshot mockups (6.9-inch, 1320 x 2868): a serif line on paper, the app below in a frame.

Run: python3 build_appstore.py   (writes appstore-1..6 .html and .png, and 00-overview-appstore.png)

Screens are the real app's, shot by CI (HairDoneUITests/AppStoreShots.swift, workflow hairdone-appstore)
into ../../app-store/raw/appstore-N-*.png. When all six are there, the framed pictures are also copied to
../../app-store/screenshots/, ready for App Store Connect. Until then it falls back to the screen tour's
pictures and the design mockups. Same type stand-ins
as the other mockups (Newsreader for New York, Inter for SF).
"""
import os, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TOUR = os.path.join(HERE, "..", "..", "qa", "screens")
CHROME = "/opt/pw-browsers/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell"
OUT = os.path.join(HERE, "appstore")
RAW = os.path.join(HERE, "..", "..", "app-store", "raw")
FINAL = os.path.join(HERE, "..", "..", "app-store", "screenshots")

# (file, from, headline with one italic phrase, line under it, ink ground)
SHOTS = [
    ("light-client-home-1-top.jpg", "tour", "A vetted pro,<br><i>at your door.</i>",
     "Hair, nails, makeup, lashes and brows, done at home.", False),
    ("03-profile.png", "mockup", "See the price<br>before you <i>book.</i>",
     "Their prices, their travel fee and their own work, up front.", False),
    ("05-booked.png", "mockup", "Booked in<br><i>a minute.</i>",
     "Nothing's charged until they're done.", True),
    ("light-client-bookings-1-top.jpg", "tour", "See them<br><i>on their way.</i>",
     "On their way, at the door, started. You see each step.", False),
    ("12-receipt-sheet.png", "mockup", "Pay when<br>it's <i>done.</i>",
     "Tip if you like. It all goes to them.", False),
    ("light-pro-today-1-top.jpg", "tour", "Pros: your diary,<br><i>your prices.</i>",
     "Take requests, get paid to your bank. Same app.", False),
]

CSS = """
html,body{margin:0;width:660px;height:1434px;overflow:hidden}
body{background:var(--paper);color:var(--ink);font-family:'SF',sans-serif}
body.ink{background:var(--ink);color:var(--paperOnInk)}
.cap{position:absolute;left:56px;right:56px;top:112px}
.mark{font-family:'NY',serif;font-style:italic;font-size:30px;letter-spacing:-.2px}
.mark span{color:var(--lacquer)}
h1{font-family:'NY',serif;font-weight:400;font-size:68px;line-height:1.04;letter-spacing:-.8px;margin:34px 0 0}
h1 i{font-style:italic}
p{font-size:23px;line-height:1.4;margin:22px 0 0;color:var(--inkSoft);max-width:500px;text-wrap:balance}
body.ink p{color:rgba(248,243,236,.72)}
.phone{position:absolute;left:50%;top:520px;width:500px;transform:translateX(-50%);padding:11px;background:#141010;
  border-radius:72px;box-shadow:0 30px 80px rgba(36,26,22,.22)}
body.ink .phone{background:#000;box-shadow:0 0 0 1.5px rgba(248,243,236,.18)}
.phone img{display:block;width:100%;border-radius:62px}
"""


def real(n):
    """The real app's screen for picture n, if CI has shot it."""
    hits = sorted(f for f in os.listdir(RAW) if f.startswith(f"appstore-{n}-") and f.endswith(".png")) if os.path.isdir(RAW) else []
    return os.path.join(RAW, hits[0]) if hits else None


def screen(name, source):
    """The bare screen: real and tour shots already are; mockups lose their drawn bezel (20 pt each side)."""
    if source == "real":
        return os.path.relpath(name, OUT)
    if source == "tour":
        return os.path.relpath(os.path.join(TOUR, name), OUT)
    im = Image.open(os.path.join(HERE, name)).convert("RGB")
    bare = im.crop((40, 40, 40 + 786, 40 + 1704))
    path = os.path.join(OUT, "screen-" + name.replace(".png", ".jpg"))
    bare.save(path, quality=92)
    return os.path.basename(path)


def page(img, head, sub, ink):
    return (f'<!doctype html><html lang="en-AU"><head><meta charset="utf-8"><title>App Store</title>'
            f'<link rel="stylesheet" href="../common.css"><style>{CSS}</style></head>'
            f'<body class="{"ink" if ink else ""}"><div class="cap"><div class="mark">hd<span>.</span> nd<span>.</span></div>'
            f'<h1>{head}</h1><p>{sub}</p></div><div class="phone"><img src="{img}"></div></body></html>')


def render(html, png):
    subprocess.run([CHROME, "--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
                    "--window-size=660,1434", "--virtual-time-budget=5000", "--allow-file-access-from-files",
                    f"--screenshot={png}", "file://" + html], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    pngs = []
    reals = [real(n) for n in range(1, len(SHOTS) + 1)]
    for n, (name, source, head, sub, ink) in enumerate(SHOTS, 1):
        if reals[n - 1]:
            name, source = reals[n - 1], "real"
        html = os.path.join(OUT, f"appstore-{n}.html")
        open(html, "w").write(page(screen(name, source), head, sub, ink))
        png = os.path.join(OUT, f"appstore-{n}.png")
        render(html, png)
        assert Image.open(png).size == (1320, 2868), Image.open(png).size
        pngs.append(png)
    ims = [Image.open(p).convert("RGB") for p in pngs]
    w, h = ims[0].size
    gap = 60
    sheet = Image.new("RGB", (len(ims) * w + (len(ims) + 1) * gap, h + 2 * gap), (214, 204, 192))
    for i, im in enumerate(ims):
        sheet.paste(im, (gap + i * (w + gap), gap))
    sheet.resize((sheet.width // 4, sheet.height // 4), Image.LANCZOS).save(os.path.join(HERE, "00-overview-appstore.png"))
    if all(reals):
        # App Store Connect takes RGB PNGs without transparency. Its iPhone slot ("iPhone with Dynamic
        # Island, medium display") takes 1206 x 2622 (6.3-inch); the 6.9-inch originals are kept too.
        os.makedirs(os.path.join(FINAL, "6.9-inch"), exist_ok=True)
        for n, p in enumerate(pngs, 1):
            im = Image.open(p).convert("RGB")
            im.save(os.path.join(FINAL, "6.9-inch", f"{n}.png"))
            im.resize((1206, 2622), Image.LANCZOS).save(os.path.join(FINAL, f"{n}.png"))
        print("final set in", os.path.normpath(FINAL))
    print("ok", sum(1 for r in reals if r), "of", len(SHOTS), "from the real app")
