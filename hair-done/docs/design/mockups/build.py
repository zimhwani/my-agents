"""Builds the five Hair Done luxe mockups as HTML, then renders them with headless Chromium.

Run: python3 build.py   (writes 01-home.html ... 05-booked.html, the PNGs and 00-overview.png)
Type stand-ins: Newsreader (for New York) and Inter (for SF Pro), loaded from fonts/.
"""
import os, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = "file:///home/user/my-agents/hair-done/HairDone/Resources/Work/"
CHROME = "/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell"


def ph(name, x, y, w, h, pos="50% 50%", zoom=1.0, origin=None, radius=0, extra="", z=1, box=None):
    """A photo box. pos = object-position; zoom scales the image about `origin` so the work fills the frame.
    box = (x0, y0, x1, y1) as fractions of the source: crop to that region first (object-view-box), then cover."""
    origin = origin or pos
    t = f"transform:scale({zoom});transform-origin:{origin};" if zoom != 1 else ""
    if box:
        x0, y0, x1, y1 = box
        t += f"object-view-box:inset({y0*100:.1f}% {(1-x1)*100:.1f}% {(1-y1)*100:.1f}% {x0*100:.1f}%);"
    return (f'<div class="photo" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;border-radius:{radius}px;z-index:{z};{extra}">'
            f'<img src="{WORK}{name}.jpg" style="object-position:{pos};{t}"></div>')


def status(time="14:20", light=False):
    c = "light" if light else ""
    return f'''<div class="status {c}"><div class="time">{time}</div>
<div class="icons">
<svg width="19" height="12" viewBox="0 0 19 12" fill="currentColor"><rect x="0" y="8" width="3.2" height="4" rx="1"/><rect x="5" y="5.5" width="3.2" height="6.5" rx="1"/><rect x="10" y="3" width="3.2" height="9" rx="1"/><rect x="15" y="0" width="3.2" height="12" rx="1"/></svg>
<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 2.3c2.4 0 4.6.9 6.3 2.5l1.2-1.2C14 1.6 11.4.5 8.5.5S3 1.6 1 3.6l1.2 1.2c1.7-1.6 3.9-2.5 6.3-2.5z"/><path d="M8.5 5.8c1.5 0 2.8.5 3.8 1.5l1.2-1.2c-1.3-1.3-3.1-2-5-2s-3.7.7-5 2l1.2 1.2c1-1 2.3-1.5 3.8-1.5z"/><path d="M8.5 9.2c.6 0 1.1.2 1.5.6l-1.5 1.7L7 9.8c.4-.4.9-.6 1.5-.6z"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.8" fill="none" stroke="currentColor" stroke-opacity=".4"/><rect x="2" y="2" width="16" height="9" rx="2.4" fill="currentColor"/><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2z" fill="currentColor" fill-opacity=".45"/></svg>
</div></div><div class="island"></div>'''


ICONS = {
    "home": '<path d="M4.5 11.8 13 4.6l8.5 7.2V21.5h-17z"/><path d="M10.6 21.5v-4.6a2.4 2.4 0 0 1 4.8 0v4.6"/>',
    "bookings": '<rect x="4" y="6" width="18" height="15.5" rx="1.6"/><path d="M4 10.8h18M9 3.8v4M17 3.8v4"/>',
    "inbox": '<path d="M5.2 5.8h15.6c.9 0 1.6.7 1.6 1.6v9.4c0 .9-.7 1.6-1.6 1.6H11.2l-4.6 3.4v-3.4H5.2c-.9 0-1.6-.7-1.6-1.6V7.4c0-.9.7-1.6 1.6-1.6z"/>',
    "you": '<circle cx="13" cy="9.3" r="3.9"/><path d="M5.4 21.6c.9-3.9 3.9-6.1 7.6-6.1s6.7 2.2 7.6 6.1"/>',
}


def tabbar(active="home", unread=True, extra_style=""):
    out = [f'<div class="tabbar" style="{extra_style}">']
    for key, label in [("home", "Home"), ("bookings", "Bookings"), ("inbox", "Inbox"), ("you", "You")]:
        on = " on" if key == active else ""
        dot = '<i class="unread"></i>' if (key == "inbox" and unread) else ""
        out.append(f'<div class="tab{on}"><svg viewBox="0 0 26 26">{ICONS[key]}</svg>{dot}<span>{label}</span></div>')
    out.append("</div>")
    return "".join(out)


def page(title, body, extra_css=""):
    return f'''<!doctype html><html lang="en-AU"><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="common.css"><style>{extra_css}</style></head>
<body><div class="bezel"></div>{body}</body></html>'''


SEARCH = '<svg width="22" height="22" viewBox="0 0 22 22" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><circle cx="9.5" cy="9.5" r="6.3"/><path d="m14.2 14.2 5 5"/></svg>'
BACK = '<svg width="12" height="20" viewBox="0 0 12 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M10 2 2 10l8 8"/></svg>'
SHARE = '<svg width="20" height="22" viewBox="0 0 20 22" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M10 14V2M5.5 6.2 10 1.7l4.5 4.5"/><path d="M6.5 9H3.5v11h13V9h-3"/></svg>'
SAVE = '<svg width="22" height="20" viewBox="0 0 22 20" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M11 18.3S2 12.9 2 7a4.6 4.6 0 0 1 9-1.4A4.6 4.6 0 0 1 20 7c0 5.9-9 11.3-9 11.3z"/></svg>'
MAP = '<svg width="22" height="22" viewBox="0 0 22 22" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"><path d="M2.5 5.2 8 3l6 2.2 5.5-2.2v13.8L14 19l-6-2.2-5.5 2.2z"/><path d="M8 3v13.8M14 5.2V19"/></svg>'
APPLE = '<svg viewBox="0 0 814 1000" fill="currentColor"><path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57-155.5-127C46.7 790.7 0 663 0 541.8c0-194.4 126.4-297.5 250.8-297.5 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/></svg>'

SCREENS = {}

# ---------------------------------------------------------------- 1. Home, as it opens
SCREENS["01-home"] = page("Home", f'''<div class="screen">
{status("14:20", light=True)}
{ph("work-nails-4", 0, 0, 393, 491, pos="50% 32%")}
<div style="position:absolute;left:0;top:0;width:393px;height:150px;z-index:2;background:linear-gradient(rgba(36,26,22,.42),rgba(36,26,22,0))"></div>
<div style="position:absolute;left:0;top:250px;width:393px;height:241px;z-index:2;background:linear-gradient(rgba(36,26,22,0),rgba(36,26,22,.30) 40%,rgba(36,26,22,.62))"></div>
<div class="serif" style="position:absolute;z-index:5;top:62px;left:0;width:393px;text-align:center;color:#FBF7F2;font-size:22px;font-weight:500;top:60px"><i>hd</i><span style="color:var(--lacquer);font-style:normal">.</span> <i>nd</i><span style="color:var(--lacquer);font-style:normal">.</span></div>
<div style="position:absolute;z-index:5;top:63px;right:20px;color:#FBF7F2">{SEARCH}</div>
<div style="position:absolute;z-index:5;left:20px;bottom:{852-491+22}px;width:353px;color:#FBF7F2">
  <div class="eyebrow" style="opacity:.86;margin-bottom:10px">Afternoon, Tash · Fitzroy North</div>
  <div class="serif" style="font-size:42px;line-height:44px;font-weight:400;letter-spacing:-.4px">Kiara is free<br>from 5.</div>
  <div style="font-size:13px;margin-top:10px;opacity:.9">Nail tech · Brunswick · 2.9 km · <span class="num">BIAB $95</span></div>
</div>

<div style="position:absolute;left:20px;top:523px;width:353px;display:flex;justify-content:space-between;align-items:baseline">
  <div class="serif" style="font-size:28px;line-height:32px;font-weight:400">Who's free today</div>
  <div style="font-size:15px;color:var(--inkSoft)">See all</div>
</div>
{ph("work-hair-1", 20, 571, 300, 375, pos="50% 40%", zoom=1.12, origin="55% 45%", radius=2)}
{ph("work-lashes-2", 332, 571, 300, 375, pos="0% 40%", radius=2)}
{tabbar("home")}
<div class="homeind"></div>
</div>''')

# ---------------------------------------------------------------- 2. Home, scrolled
cat = lambda name, label, x, **k: ph(name, x, 290, 128, 170, radius=2, **k) + \
    f'<div class="serif" style="position:absolute;left:{x}px;top:468px;font-size:17px;line-height:22px">{label}</div>'
SCREENS["02-home-scrolled"] = page("Home scrolled", f'''<div class="screen">
{status("14:21")}
{ph("work-hair-1", 20, -173, 300, 375, pos="50% 40%", zoom=1.12, origin="55% 45%", radius=2)}
{ph("work-lashes-2", 332, -173, 300, 375, pos="0% 40%", radius=2)}
<div style="position:absolute;left:0;top:0;width:393px;height:98px;z-index:30;background:rgba(248,243,236,.84);backdrop-filter:blur(20px);border-bottom:.5px solid rgba(36,26,22,.12)"></div>
<div class="serif" style="position:absolute;z-index:31;top:62px;left:0;width:393px;text-align:center;font-size:22px;font-weight:500;top:60px"><i>hd</i><span style="color:var(--lacquer);font-style:normal">.</span> <i>nd</i><span style="color:var(--lacquer);font-style:normal">.</span></div>
<div style="position:absolute;z-index:31;top:63px;right:20px">{SEARCH}</div>

<div class="serif" style="position:absolute;left:20px;top:212px;font-size:24px;line-height:28px">Aaliyah</div>
<div style="position:absolute;left:20px;top:243px;font-size:13px;color:var(--inkSoft)">8.4 km away, free from 3</div>
<div class="serif" style="position:absolute;left:332px;top:212px;font-size:24px;line-height:28px">Sofia</div>
<div style="position:absolute;left:332px;top:243px;font-size:13px;color:var(--inkSoft);white-space:nowrap">5.1 km away, free from 4</div>

{cat("work-hair-3", "Hair", 20, pos="50% 30%", zoom=1.15, origin="50% 35%")}
{cat("work-nails-1", "Nails", 158, pos="50% 20%", zoom=1.25, origin="45% 25%")}
{cat("work-thelot-2", "Makeup", 296, pos="50% 30%", zoom=1.5, origin="45% 28%")}


<div style="position:absolute;left:20px;top:532px;width:353px;display:flex;justify-content:space-between;align-items:center">
  <div class="serif" style="font-size:28px;line-height:32px">Near you</div>
  <div style="color:var(--ink)">{MAP}</div>
</div>
{ph("work-lashes-1", 0, 582, 393, 491, box=(0.3, 0.18, 1.0, 0.95))}
{tabbar("home")}
<div class="homeind"></div>
</div>''')


# ---------------------------------------------------------------- 3. Kiara's profile (scrolled 140pt, hero in parallax)
def svc(name, dur, price, top):
    return (f'<div style="position:absolute;left:20px;top:{top}px;width:353px;height:44px;border-top:1px solid var(--lineStrong);display:flex;align-items:center">'
            f'<div style="flex:1;font-size:17px">{name}</div><div class="num" style="font-size:15px;color:var(--inkSoft);margin-right:22px">{dur}</div>'
            f'<div class="num" style="font-size:17px;width:44px;text-align:right">{price}</div></div>')
STAR = '<svg width="12" height="12" viewBox="0 0 12 12" style="margin:0 3px -1px 0"><path d="M6 .8l1.55 3.3 3.6.45-2.65 2.5.68 3.57L6 8.85l-3.18 1.77.68-3.57L.85 4.55l3.6-.45z" fill="none" stroke="currentColor" stroke-width="1" stroke-linejoin="round"/></svg>'
SCREENS["03-profile"] = page("Kiara M.", f"""<div class="screen">
{status("14:21", light=True)}
{ph("work-nails-4", 0, 0, 393, 351, pos="50% 38%", zoom=1.0)}
<div style="position:absolute;left:0;top:0;width:393px;height:140px;z-index:2;background:linear-gradient(rgba(36,26,22,.5),rgba(36,26,22,0))"></div>
<div style="position:absolute;left:0;top:170px;width:393px;height:181px;z-index:2;background:linear-gradient(rgba(36,26,22,0),rgba(36,26,22,.35) 45%,rgba(36,26,22,.66))"></div>
<div style="position:absolute;z-index:5;top:56px;left:16px;color:#FBF7F2;width:38px;height:38px;border-radius:19px;background:rgba(36,26,22,.42);backdrop-filter:blur(12px);display:flex;align-items:center;justify-content:center;padding-right:2px">{BACK}</div>
<div style="position:absolute;z-index:5;top:56px;right:16px;color:#FBF7F2;display:flex;gap:10px"><div style="width:38px;height:38px;border-radius:19px;background:rgba(36,26,22,.42);backdrop-filter:blur(12px);display:flex;align-items:center;justify-content:center;">{SAVE}</div><div style="width:38px;height:38px;border-radius:19px;background:rgba(36,26,22,.42);backdrop-filter:blur(12px);display:flex;align-items:center;justify-content:center;padding-bottom:2px">{SHARE}</div></div>
<div style="position:absolute;z-index:5;left:20px;top:238px;color:#FBF7F2">
  <div class="serif" style="font-size:50px;line-height:52px;letter-spacing:-.6px">Kiara M.</div>
  <div class="serif" style="font-size:20px;line-height:26px;margin-top:4px;opacity:.95">Does a <i>very</i> good French tip.</div>
</div>
<div style="position:absolute;left:20px;top:371px;width:353px;font-size:15px;line-height:21px;color:var(--inkSoft)">
  Nail tech in Brunswick · 2.9 km from you<br><span style="color:var(--ink)">{STAR}4.9</span> · 212 reviews · ID checked
</div>
<div class="serif" style="position:absolute;left:20px;top:427px;width:353px;font-size:19px;line-height:26px">
  Eight years in salons in Brunswick and Carlton before I went mobile. I bring the lamp, the table, the lot. <span style="font-family:SF;font-size:15px;color:var(--inkSoft)">More</span>
</div>
<div class="eyebrow" style="position:absolute;left:20px;top:529px;color:var(--inkSoft)">Services</div>
<div style="position:absolute;right:20px;top:528px;font-size:13px;color:var(--inkSoft)">Travel fee $15, flat</div>
{svc("BIAB overlay", "1 h 15", "$95", 553)}
{svc("Gel manicure", "1 h", "$70", 597)}
{svc("Full set acrylics", "1 h 45", "$130", 641)}
<div style="position:absolute;left:0;top:705px;width:393px;height:64px;background:var(--ink);color:var(--paperOnInk);z-index:41;display:flex;align-items:center;padding:0 20px">
  <div style="flex:1">
    <div><span class="serif" style="font-size:21px">Kiara</span><span class="num" style="font-size:15px;opacity:.7;margin-left:8px">from $70</span></div>
    <div style="font-size:13px;opacity:.6;margin-top:1px">Free today from 5:00 pm</div>
  </div>
  <div style="width:116px;height:44px;border-radius:4px;background:var(--paperOnInk);color:var(--ink);font-weight:600;font-size:17px;display:flex;align-items:center;justify-content:center">Book</div>
</div>
{tabbar("home")}
<div class="homeind"></div>
</div>""")

# ---------------------------------------------------------------- 4. Check it over (ink ticket)
def line(label, price, top, note=None):
    n = f'<div style="font-size:13px;line-height:17px;opacity:.55;margin-top:3px">{note}</div>' if note else ""
    return (f'<div style="position:absolute;left:36px;top:{top}px;width:321px">'
            f'<div style="display:flex;justify-content:space-between;font-size:17px;line-height:22px"><span>{label}</span><span class="num">{price}</span></div>{n}</div>')
def perf(top, bg, left=16, width=361, color="rgba(244,236,228,.22)"):
    return (f'<div style="position:absolute;left:{left+18}px;top:{top}px;width:{width-36}px;border-top:1.5px dashed {color}"></div>'
            f'<div style="position:absolute;left:{left-9}px;top:{top-9}px;width:18px;height:18px;border-radius:9px;background:{bg}"></div>'
            f'<div style="position:absolute;left:{left+width-9}px;top:{top-9}px;width:18px;height:18px;border-radius:9px;background:{bg}"></div>')
SCREENS["04-review"] = page("Check it over", f"""<div class="screen ink">
{status("14:23", light=True)}
<div style="position:absolute;top:63px;left:22px;color:var(--paperOnInk)">{BACK}</div>
<div class="serif" style="position:absolute;top:60px;left:0;width:393px;text-align:center;font-size:19px">Check it over</div>
<div style="position:absolute;left:16px;top:106px;width:361px;height:534px;border-radius:6px;background:#30251F;box-shadow:0 0 0 .5px rgba(244,236,228,.10) inset"></div>
{ph("work-nails-4", 16, 106, 361, 160, pos="50% 0%", box=(0.22, 0.2, 0.9, 0.62), extra="border-radius:6px 6px 0 0", z=2)}
<div class="serif" style="position:absolute;left:36px;top:284px;font-size:36px;line-height:40px;letter-spacing:-.3px">Kiara at yours.</div>
<div style="position:absolute;left:36px;top:332px;width:321px;font-size:15px;line-height:22px">
  <div style="display:flex;justify-content:space-between"><span style="opacity:.8">Today, 6:15 pm · 1 h 15</span><span style="opacity:.45">Change</span></div>
  <div style="display:flex;justify-content:space-between"><span style="opacity:.8">Home · 14 Rae St, Fitzroy North</span><span style="opacity:.45">Change</span></div>
</div>
{perf(396, "var(--ink)")}
{line("BIAB overlay", "$95", 414)}
{line("Travel fee", "$15", 450, "Set by Kiara. Flat, wherever you are in her area.")}
{line("Hair Done fee", "$3", 508)}
<div style="position:absolute;left:36px;top:546px;width:321px;border-top:1px solid rgba(244,236,228,.14)"></div>
<div style="position:absolute;left:36px;top:556px;width:321px;display:flex;justify-content:space-between;align-items:baseline">
  <div style="font-size:17px">Total</div>
  <div class="num" style="font-size:38px;font-weight:400;letter-spacing:-.6px;line-height:44px">$113</div>
</div>
<div style="position:absolute;left:36px;top:602px;font-size:13px;opacity:.62">Held now, charged when she's done.</div>
<div style="position:absolute;left:20px;top:658px;width:353px;font-size:13px;line-height:18px;opacity:.55">Cancel with more than 24 hours' notice and it's free. Less than that and she keeps half. She's already turned down other work for you. Not there when she arrives and it's the full amount.</div>
<div class="num" style="position:absolute;left:20px;top:752px;width:170px;height:56px;border-radius:4px;background:var(--lacquer);color:#FBF3EE;font-size:17px;font-weight:600;display:flex;align-items:center;justify-content:center">Pay $113</div>
<div style="position:absolute;left:203px;top:752px;width:170px;height:56px;border-radius:4px;background:#000;box-shadow:0 0 0 1px rgba(244,236,228,.34) inset;color:#fff;display:flex;align-items:center;justify-content:center;gap:2px">
  <span style="width:19px;height:23px;display:inline-block;margin-top:-4px">{APPLE}</span><span style="font-size:22px;font-weight:500;letter-spacing:-.3px">Pay</span></div>
<div class="homeind light"></div>
</div>""")

# ---------------------------------------------------------------- 5. You're booked.
CHECK = '<svg width="58" height="44" viewBox="0 0 58 44" fill="none" stroke="#C8323A" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 23.5 19 39 55 3"/></svg>'
WALLET = '<svg width="24" height="18" viewBox="0 0 24 18"><rect x="0" y="0" width="24" height="18" rx="3" fill="#fff"/><rect x="1.5" y="2" width="21" height="4" rx="1" fill="#3E9BDB"/><rect x="1.5" y="5" width="21" height="4" rx="1" fill="#F6B53A"/><rect x="1.5" y="8" width="21" height="4" rx="1" fill="#5DBB63"/><rect x="1.5" y="11" width="21" height="4" rx="1" fill="#E94B3C"/><path d="M1.5 12h7c.6 1.6 1.9 2.6 3.5 2.6s2.9-1 3.5-2.6h7V16.5h-21z" fill="#d9d9d9"/></svg>'
OUTBTN = "height:48px;border-radius:4px;box-shadow:0 0 0 1px rgba(244,236,228,.28) inset;display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:500;"
SCREENS["05-booked"] = page("You're booked", f"""<div class="screen ink">
{status("14:24", light=True)}
<div style="position:absolute;top:61px;right:20px;font-size:17px;font-weight:600">Done</div>
<div style="position:absolute;left:18px;top:102px">{CHECK}</div>
<div class="serif" style="position:absolute;left:20px;top:158px;font-size:50px;line-height:54px;letter-spacing:-.6px">You're booked.</div>
<div style="position:absolute;left:20px;top:222px;font-size:17px;opacity:.75">Sit tight, she's on her way at 6:15.</div>
<div style="position:absolute;left:20px;top:272px;width:353px;height:466px;border-radius:6px;background:var(--paperOnInk);color:var(--ink)"></div>
{ph("work-nails-3", 20, 272, 353, 190, pos="50% 50%", box=(0.04, 0.28, 0.96, 0.62), extra="border-radius:6px 6px 0 0", z=2)}
<div class="eyebrow" style="position:absolute;left:40px;top:484px;color:var(--inkSoft)">For Tash</div>
<div class="serif" style="position:absolute;left:40px;top:502px;font-size:32px;line-height:36px;color:var(--ink)">Kiara M.</div>
<div class="serif" style="position:absolute;left:40px;top:546px;font-size:19px;line-height:26px;color:var(--ink)">
  Tuesday 23 September, 6:15 pm<br>at yours in Fitzroy North<br>BIAB overlay · <span class="num">$113 held</span><span style="color:var(--lacquer);font-size:30px;line-height:0">.</span>
</div>
{perf(650, "var(--ink)", left=20, width=353, color="rgba(36,26,22,.22)")}
<div style="position:absolute;left:40px;top:670px;width:313px;height:48px;border-radius:8px;background:#000;color:#fff;display:flex;align-items:center;justify-content:center;gap:10px;font-size:16px;font-weight:500">{WALLET}Add to Apple Wallet</div>
<div style="position:absolute;left:20px;top:758px;width:170px;{OUTBTN}">Message Kiara</div>
<div style="position:absolute;left:203px;top:758px;width:170px;{OUTBTN}">Share with a friend</div>
<div class="homeind light"></div>
</div>""")

for k, v in SCREENS.items():
    with open(os.path.join(HERE, k + ".html"), "w") as f:
        f.write(v)


def render(name):
    html = os.path.join(HERE, name + ".html")
    out = os.path.join(HERE, name + ".png")
    subprocess.run([CHROME, "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=2", "--window-size=433,892", "--virtual-time-budget=5000",
                    "--allow-file-access-from-files", f"--screenshot={out}", "file://" + html],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return out


if __name__ == "__main__":
    import sys
    names = sys.argv[1:] or list(SCREENS)
    outs = [render(n) for n in names]
    if not sys.argv[1:]:
        ims = [Image.open(os.path.join(HERE, n + ".png")).convert("RGB") for n in SCREENS]
        w, h = ims[0].size
        gap = 40
        sheet = Image.new("RGB", (len(ims) * w + (len(ims) + 1) * gap, h + 2 * gap), (230, 222, 211))
        for i, im in enumerate(ims):
            sheet.paste(im, (gap + i * (w + gap), gap))
        sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
        sheet.save(os.path.join(HERE, "00-overview.png"))
    print("\n".join(outs))
