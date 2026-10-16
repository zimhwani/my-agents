"""Builds the pro Today mockups (proposal: ../pro-today-proposal.md) as HTML, then renders them
with headless Chromium, the same way build.py does.

Run: python3 build_today.py   (writes 08-11 .html and .png, and 00-overview-today.png)

Frames are 390 x 844 (iPhone 15 / 16 class). Each state is laid out once as a normal scrolling
column; the "scrolled" frames are the same column moved up, so the two frames of a state can't drift.
Type stand-ins as build.py: Newsreader for New York, Inter for SF Pro, from fonts/.
build.py isn't imported because importing it rewrites 01-07; the two helpers it shares are copied here.
"""
import os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = "file:///home/user/my-agents/hair-done/HairDone/Resources/Work/"
CHROME = "/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell"
W, H = 390, 844


# ---------------------------------------------------------------- copied from build.py
def photo(name, w, h, pos="50% 50%", zoom=1.0, origin=None, radius=2, box=None, extra=""):
    """An in-flow photo box (build.py's `ph`, without absolute positioning)."""
    origin = origin or pos
    t = f"transform:scale({zoom});transform-origin:{origin};" if zoom != 1 else ""
    if box:
        x0, y0, x1, y1 = box
        t += f"object-view-box:inset({y0*100:.1f}% {(1-x1)*100:.1f}% {(1-y1)*100:.1f}% {x0*100:.1f}%);"
    return (f'<div class="pic" style="width:{w}px;height:{h}px;border-radius:{radius}px;{extra}">'
            f'<img src="{WORK}{name}.jpg" style="object-position:{pos};{t}"></div>')


def status(time, light=False):
    c = "light" if light else ""
    return f'''<div class="status {c}"><div class="time">{time}</div>
<div class="icons">
<svg width="19" height="12" viewBox="0 0 19 12" fill="currentColor"><rect x="0" y="8" width="3.2" height="4" rx="1"/><rect x="5" y="5.5" width="3.2" height="6.5" rx="1"/><rect x="10" y="3" width="3.2" height="9" rx="1"/><rect x="15" y="0" width="3.2" height="12" rx="1"/></svg>
<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 2.3c2.4 0 4.6.9 6.3 2.5l1.2-1.2C14 1.6 11.4.5 8.5.5S3 1.6 1 3.6l1.2 1.2c1.7-1.6 3.9-2.5 6.3-2.5z"/><path d="M8.5 5.8c1.5 0 2.8.5 3.8 1.5l1.2-1.2c-1.3-1.3-3.1-2-5-2s-3.7.7-5 2l1.2 1.2c1-1 2.3-1.5 3.8-1.5z"/><path d="M8.5 9.2c.6 0 1.1.2 1.5.6l-1.5 1.7L7 9.8c.4-.4.9-.6 1.5-.6z"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.8" fill="none" stroke="currentColor" stroke-opacity=".4"/><rect x="2" y="2" width="16" height="9" rx="2.4" fill="currentColor"/><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2z" fill="currentColor" fill-opacity=".45"/></svg>
</div></div><div class="island"></div>'''


# ---------------------------------------------------------------- glyphs (outline, after the SF Symbols the app uses)
def g(path, size=22, vb=24, sw=1.3):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 {vb} {vb}" fill="none" stroke="currentColor" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{path}</svg>')

CHEV = '<svg width="8" height="14" viewBox="0 0 8 14" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="m1.5 1.5 5 5.5-5 5.5"/></svg>'
CHEV_S = '<svg width="7" height="12" viewBox="0 0 8 14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="m1.5 1.5 5 5.5-5 5.5"/></svg>'
STAR = '<svg width="15" height="15" viewBox="0 0 12 12" style="margin:0 5px -1px 0"><path d="M6 .8l1.55 3.3 3.6.45-2.65 2.5.68 3.57L6 8.85l-3.18 1.77.68-3.57L.85 4.55l3.6-.45z" fill="none" stroke="currentColor" stroke-width=".9" stroke-linejoin="round"/></svg>'
G_SHARE = g('<path d="M12 15V3.5M7.5 7.8 12 3.3l4.5 4.5"/><path d="M8.5 10.5H5.5v10h13v-10h-3"/>')
G_PHOTO = g('<rect x="3" y="4.5" width="18" height="15" rx="1.6"/><path d="m3.5 16.5 5-5 4 4 2.5-2.5 5.5 5"/><circle cx="15.5" cy="9" r="1.5"/>')
G_CLOCK = g('<circle cx="12" cy="12" r="8.6"/><path d="M12 7v5.2l3.4 2"/>')
G_BOLT = g('<path d="M13.2 2.8 5.5 13.4h5.6l-1 7.8 7.7-10.6h-5.6z"/>')
G_PLUS = g('<path d="M12 6v12M6 12h12"/>', size=14)

TAB_ICONS = {  # sun.horizon, calendar, bubble.left, chart.bar, person.crop.circle
    "today": '<path d="M3.5 17.5h19"/><path d="M7.6 17.5a5.4 5.4 0 0 1 10.8 0"/><path d="M13 6.2v2.4M6.1 9.2l1.6 1.6M19.9 9.2l-1.6 1.6M3.6 14h1.9M20.5 14h1.9"/><path d="M8 21h10"/>',
    "calendar": '<rect x="4" y="6" width="18" height="15.5" rx="1.6"/><path d="M4 10.8h18M9 3.8v4M17 3.8v4"/>',
    "inbox": '<path d="M5.2 5.8h15.6c.9 0 1.6.7 1.6 1.6v9.4c0 .9-.7 1.6-1.6 1.6H11.2l-4.6 3.4v-3.4H5.2c-.9 0-1.6-.7-1.6-1.6V7.4c0-.9.7-1.6 1.6-1.6z"/>',
    "earnings": '<path d="M4 21.5h18"/><rect x="5.5" y="12.5" width="3.4" height="7" rx=".6"/><rect x="11.3" y="7.5" width="3.4" height="12" rx=".6"/><rect x="17.1" y="4" width="3.4" height="15.5" rx=".6"/>',
    "profile": '<circle cx="13" cy="13" r="9.4"/><circle cx="13" cy="10.6" r="3.3"/><path d="M6.6 19.7c1.4-2.6 3.7-3.9 6.4-3.9s5 1.3 6.4 3.9"/>',
}


def tabbar(unread_today=False):
    out = ['<div class="protabs">']
    for key, label in [("today", "Today"), ("calendar", "Calendar"), ("inbox", "Inbox"), ("earnings", "Earnings"), ("profile", "Profile")]:
        on = " on" if key == "today" else ""
        dot = '<i class="unread"></i>' if (key == "today" and unread_today) else ""
        out.append(f'<div class="ptab{on}"><div class="ic"><svg viewBox="0 0 26 26">{TAB_ICONS[key]}</svg>{dot}</div><span>{label}</span><b></b></div>')
    out.append("</div>")
    return "".join(out)


CSS = """
:root{ --success:#3E7A5A; --warn:#B9741F; --inkFaint:#948880; --onInk:#F4ECE4;
  --onInkSoft:rgba(244,236,228,.62); --inkLine:rgba(244,236,228,.14); --line:#E8DFD5; }
html,body{width:430px;height:884px}
.bezel{width:412px;height:866px}
.screen{width:390px;height:844px}
.status{width:390px}
.island{left:132px}
.homeind{left:128px;background:#F4ECE4}
.pic{position:relative;overflow:hidden;background:#cbbfb2;flex:none}
.pic img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:block}
.num{font-feature-settings:"tnum"}
.soft{color:var(--inkSoft)}
.col{position:absolute;left:0;width:390px;padding:0 20px}
.statusveil{position:absolute;left:0;top:0;width:390px;height:54px;z-index:45;background:rgba(248,243,236,.86);
  backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
.eyebrow{font-size:12px;font-weight:500;letter-spacing:.08em;text-transform:uppercase;line-height:16px}
.display{font-size:40px;line-height:46px;letter-spacing:-.4px}
.section{font-size:26px;line-height:32px}
.sub{font-size:15px;line-height:21px}
.cap{font-size:13px;line-height:18px}
.dot{display:inline-block;width:6px;height:6px;border-radius:3px;margin-right:8px;vertical-align:1.5px}
.dot.warn{background:var(--warn)} .dot.ok{background:var(--success)}
.between{display:flex;justify-content:space-between;align-items:baseline}
.link{font-size:15px;font-weight:500;color:var(--ink);display:flex;align-items:center;gap:6px}
.hair{height:.5px;background:var(--lineStrong)}
.btn{height:44px;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:17px;font-weight:600}
.btn.ink{background:var(--ink);color:var(--onInk)}
.btn.out{box-shadow:0 0 0 1px var(--ink) inset;color:var(--ink)}
.btn.paper{background:var(--onInk);color:var(--ink);height:52px}

/* header */
.head{display:flex;justify-content:space-between;align-items:flex-start;padding-top:64px}
.head .face{margin-top:24px}

/* request */
.req{margin-top:26px;padding-bottom:18px;border-bottom:.5px solid var(--lineStrong)}
.track{height:1px;background:var(--line);margin:10px 0 16px;position:relative}
.track b{position:absolute;left:0;top:0;height:1px;background:var(--ink)}
.reqname{font-size:22px;line-height:27px}
.quote{font-size:17px;line-height:23px}

/* ink hero */
.hero{margin-top:20px;background:var(--ink);color:var(--onInk);border-radius:6px;padding:20px 20px 8px}
.jt{font-size:56px;line-height:58px;font-weight:300;letter-spacing:-1.4px}
.jt small{font-size:22px;font-weight:300;letter-spacing:0;margin-left:4px}
.hero .who{font-size:24px;line-height:29px;margin-top:6px}
.hero .facts{font-size:15px;line-height:21px;color:var(--onInkSoft)}
.hero .acts{display:flex;gap:28px;height:46px;align-items:center;font-size:15px;font-weight:500}

/* job rows */
.job{display:flex;align-items:center;padding:14px 0;border-bottom:.5px solid var(--lineStrong)}
.job .t{width:76px;font-size:15px;line-height:24px;align-self:flex-start;padding-top:1px}
.job .mid{flex:1}
.job .nm{font-size:19px;line-height:24px}
.job .pr{font-size:15px;margin-right:12px;align-self:flex-start;padding-top:2px}
.job .chev{color:var(--inkFaint)}

/* week strip */
.strip{display:flex;gap:0;margin-top:14px}
.day{flex:1;height:84px;border-radius:6px;display:flex;flex-direction:column;align-items:center;padding-top:10px}
.day .wd{font-size:11px;font-weight:500;letter-spacing:.08em;text-transform:uppercase;color:var(--inkSoft)}
.day .dn{font-size:20px;line-height:26px;font-weight:400;margin-top:2px}
.day .mk{height:8px;display:flex;gap:3px;margin-top:5px;align-items:center}
.day .mk i{width:5px;height:5px;border-radius:3px;background:var(--ink)}
.day .mk i.rq{background:none;box-shadow:0 0 0 1px var(--ink) inset}
.day .hr{font-size:11px;line-height:14px;color:var(--inkSoft);margin-top:4px}
.day.off .dn{color:var(--inkSoft)}
.day.today{background:var(--ink);color:var(--onInk)}
.day.today .wd,.day.today .hr{color:var(--onInkSoft)}
.day.today .mk i{background:var(--onInk)}
.stripwrap{border-top:.5px solid var(--lineStrong);border-bottom:.5px solid var(--lineStrong);padding:10px 0;margin-top:14px}
.stripwrap .strip{margin-top:0}

/* money */
.money{display:flex;align-items:center;padding:16px 0;border-top:.5px solid var(--lineStrong);border-bottom:.5px solid var(--lineStrong)}
.money .v{font-size:17px;line-height:23px}
.lq{color:var(--lacquer);font-size:22px;line-height:0;font-weight:700}

/* nudges */
.nudge{display:flex;align-items:flex-start;padding:15px 0;border-bottom:.5px solid var(--lineStrong)}
.nudge .gl{width:36px;color:var(--ink);padding-top:1px;flex:none}
.nudge .tx{flex:1}
.nudge .tt{font-size:17px;line-height:22px}
.nudge .ss{font-size:13px;line-height:18px;color:var(--inkSoft);margin-top:3px}
.nudge .tr{margin-left:12px;padding-top:1px;font-size:15px;font-weight:500;flex:none}
.thumbs{display:flex;gap:4px;margin-top:10px}
.empty{width:30px;height:38px;border-radius:2px;box-shadow:0 0 0 1px var(--line) inset;display:flex;align-items:center;justify-content:center;color:var(--inkFaint)}
.sw{width:40px;height:24px;border-radius:6px;background:var(--line);position:relative;margin-top:-1px}
.sw b{position:absolute;left:3px;top:3px;width:18px;height:18px;border-radius:4px;background:var(--paper);box-shadow:0 1px 2px rgba(36,26,22,.18)}

/* record */
.facts2{display:flex;margin-top:14px}
.facts2 > div{flex:1}
.facts2 .vr{width:.5px;background:var(--lineStrong);flex:none;margin:0 16px}
.big{font-size:22px;line-height:28px;margin-top:4px}
.rquote{font-size:19px;line-height:27px;margin-top:22px}

/* pro tab bar: solid ink, paper icons 55% / 100%, lacquer dots */
.protabs{position:absolute;left:0;bottom:0;width:390px;height:83px;z-index:40;background:#241A16;display:flex;padding:6px 12px 0}
.ptab{flex:1;height:49px;display:flex;flex-direction:column;align-items:center;color:rgba(244,236,228,.55)}
.ptab .ic{position:relative;height:26px}
.ptab svg{width:26px;height:26px;stroke:currentColor;fill:none;stroke-width:1.2;stroke-linecap:round;stroke-linejoin:round}
.ptab span{font-size:10px;font-weight:500;margin-top:3px;line-height:12px}
.ptab b{width:4px;height:4px;border-radius:2px;margin-top:3px}
.ptab.on{color:#F4ECE4} .ptab.on span{font-weight:600} .ptab.on b{background:#C8323A}
.ptab .unread{position:absolute;right:-3px;top:-1px;width:7px;height:7px;border-radius:4px;background:#C8323A;box-shadow:0 0 0 1.5px #241A16}
"""


def page(title, body):
    return (f'<!doctype html><html lang="en-AU"><head><meta charset="utf-8"><title>{title}</title>'
            f'<link rel="stylesheet" href="common.css"><style>{CSS}</style></head>'
            f'<body><div class="bezel"></div>{body}</body></html>')


def frame(title, time, column, scroll=0, unread_today=False):
    veil = '<div class="statusveil"></div>' if scroll else ""
    return page(title, f'''<div class="screen">
{status(time)}{veil}
<div class="col" style="top:{-scroll}px">{column}</div>
{tabbar(unread_today)}
<div class="homeind"></div>
</div>''')


def header(greeting, dayline):
    face = photo("work-nails-4", 32, 40, pos="50% 35%", extra="")
    return f'''<div class="head"><div>
  <div class="eyebrow soft">Pro · Mati</div>
  <div class="serif display" style="margin-top:6px">{greeting}, <i>Mati</i>.</div>
  <div class="sub soft" style="margin-top:6px">{dayline}</div>
</div><div class="face">{face}</div></div>'''


def day(wd, dn, jobs=0, reqs=0, hrs="", today=False, off=False):
    cls = "day" + (" today" if today else "") + (" off" if off else "")
    marks = "<i></i>" * jobs + '<i class="rq"></i>' * reqs
    return (f'<div class="{cls}"><div class="wd">{wd}</div><div class="dn num">{dn}</div>'
            f'<div class="mk">{marks}</div><div class="hr">{"Off" if off else hrs}</div></div>')


def job(t, name, line, price, done=False):
    badge = ('<div class="eyebrow" style="font-size:11px;margin-top:6px"><i class="dot ok"></i>Done · paying you</div>' if done else "")
    return (f'<div class="job"><div class="t num">{t}</div><div class="mid"><div class="serif nm">{name}</div>'
            f'<div class="cap soft" style="margin-top:2px">{line}</div>{badge}</div>'
            f'<div class="pr num">{price}</div><div class="chev">{CHEV_S}</div></div>')


def strip_head(right_line):
    return (f'<div class="between"><div class="eyebrow soft">Next 7 days</div>'
            f'<div class="link">Calendar <span style="color:var(--inkFaint)">{CHEV_S}</span></div></div>{right_line}')


def money(main, lands):
    return (f'<div class="money"><div style="flex:1"><div class="v">{main}</div>'
            f'<div class="cap soft" style="margin-top:2px">{lands}<span class="lq">.</span></div></div>'
            f'<div style="color:var(--inkFaint)">{CHEV_S}</div></div>')


# ================================================================ busy: Friday 16 Oct, 10:48 am
BUSY = header("Morning", 'Friday 16 October · 4 jobs · <span class="num">$334.40</span> to you') + f'''
<div class="req">
  <div class="between">
    <div class="eyebrow soft">New request</div>
    <div class="cap" style="font-weight:500"><i class="dot warn"></i><span class="num">1 h 12 min</span> to answer</div>
  </div>
  <div class="track"><b style="width:60%"></b></div>
  <div style="display:flex;gap:16px">
    <div style="flex:1">
      <div class="serif reqname">Tash wants a French tip set</div>
      <div class="sub soft" style="margin-top:4px">Tomorrow, 10:00 am · Thornbury</div>
      <div class="serif quote" style="margin-top:8px">“Short and squoval, a fine white tip.”</div>
      <div style="font-size:17px;margin-top:6px"><span class="num">$110</span> to you <span class="soft" style="font-size:15px">· 1 h 30</span></div>
    </div>
    {photo("work-nails-3", 56, 70, box=(0.1, 0.3, 0.6, 0.62))}
  </div>
  <div style="display:flex;gap:8px;margin-top:16px"><div class="btn ink" style="flex:1">Accept</div><div class="btn out" style="flex:1">Decline</div></div>
  <div class="cap soft" style="margin-top:8px">Lapses at 12:00 pm. A lapsed request counts against you.</div>
</div>

<div class="hero">
  <div class="between">
    <div class="eyebrow" style="color:var(--onInkSoft)"><i class="dot ok" style="background:#6FBF8F"></i>Next up · Confirmed</div>
    <div style="color:var(--onInkSoft)">{CHEV_S}</div>
  </div>
  <div style="display:flex;justify-content:space-between;align-items:flex-end;margin-top:8px">
    <div class="jt num">12:30<small>pm</small></div>
    <div style="margin-bottom:4px"><div style="display:flex;gap:4px">{photo("work-nails-1", 38, 48, pos="50% 22%", zoom=1.3, origin="45% 25%")}{photo("work-nails-4", 38, 48, pos="50% 38%")}</div><div style="font-size:11px;line-height:14px;margin-top:5px;color:var(--onInkSoft)">Her inspo</div></div>
  </div>
  <div class="serif who">Ruby · BIAB overlay</div>
  <div class="facts" style="margin-top:4px">8 Glenlyon Rd, Brunswick East</div>
  <div class="facts num">1 h 15 · $96.80 to you</div>
  <div class="btn paper" style="margin-top:18px">On my way</div>
  <div class="acts"><span>Directions</span><span>Message Ruby</span></div>
</div>

<div class="serif section" style="margin-top:32px">Later today</div>
<div style="margin-top:6px">
{job("3:00 pm", "Grace", "Gel pedicure · 1 h · Fitzroy North", "$83.60")}
{job("6:15 pm", "Lily", "BIAB infill · 1 h · Carlton North", "$79.20")}
</div>
<div class="eyebrow soft" style="margin-top:22px">Earlier</div>
<div style="margin-top:2px">
{job("8:30 am", "Sophie", "Gel manicure · 1 h · Northcote", "$74.80", done=True)}
</div>

<div style="margin-top:32px">
{strip_head('<div class="sub soft" style="margin-top:6px">10 jobs booked, 19 hours still open.</div>')}
<div class="stripwrap"><div class="strip">
{day("Fri", 16, jobs=4, hrs="1 h", today=True)}
{day("Sat", 17, jobs=2, reqs=1, hrs="2 h")}
{day("Sun", 18, off=True)}
{day("Mon", 19, off=True)}
{day("Tue", 20, jobs=1, hrs="6 h")}
{day("Wed", 21, jobs=2, hrs="4 h")}
{day("Thu", 22, jobs=1, hrs="6 h")}
</div></div>
</div>

<div style="margin-top:28px">
{money('<span class="num">$642.40</span> <span class="soft">this week</span> · <span class="num">$237.60</span> <span class="soft">on its way</span>', "Lands Mon 19 Oct")}
</div>
<div style="height:140px"></div>
'''

# ================================================================ quiet: Friday 16 Oct, 2:20 pm, nothing booked
QUIET = header("Afternoon", "Friday 16 October · Nothing booked today.") + f'''
<div style="margin-top:30px">
{strip_head('')}
<div class="serif" style="font-size:28px;line-height:34px;margin-top:10px">You've 31 hours open.</div>
<div class="sub soft" style="margin-top:4px">You're live, so clients can book any of them.</div>
<div class="stripwrap"><div class="strip">
{day("Fri", 16, hrs="4 h", today=True)}
{day("Sat", 17, hrs="5 h")}
{day("Sun", 18, off=True)}
{day("Mon", 19, off=True)}
{day("Tue", 20, hrs="7 h")}
{day("Wed", 21, hrs="7 h")}
{day("Thu", 22, hrs="8 h")}
</div></div>
</div>

<div class="serif section" style="margin-top:32px">Get booked</div>
<div style="margin-top:4px">
  <div class="nudge"><div class="gl">{G_SHARE}</div><div class="tx">
    <div class="tt">Share your profile</div>
    <div class="ss">Send it to your regulars, so they book you here and not in your DMs.</div></div>
    <div class="tr">Share</div></div>
  <div class="nudge"><div class="gl">{G_PHOTO}</div><div class="tx">
    <div class="tt">Add more work photos</div>
    <div class="ss"><span class="num">5 of 8.</span> Close, in daylight, your own work.</div>
    <div class="thumbs">
      {photo("work-nails-4", 30, 38, pos="50% 38%")}{photo("work-nails-1", 30, 38, pos="50% 22%", zoom=1.3, origin="45% 25%")}{photo("work-nails-3", 30, 38, box=(0.1, 0.3, 0.6, 0.62))}{photo("work-nails-2", 30, 38, pos="50% 40%")}{photo("work-brows-2", 30, 38, pos="50% 30%")}
      <div class="empty">{G_PLUS}</div><div class="empty">{G_PLUS}</div><div class="empty">{G_PLUS}</div>
    </div></div>
    <div class="tr" style="color:var(--inkFaint);padding-top:3px">{CHEV_S}</div></div>
  <div class="nudge"><div class="gl">{G_CLOCK}</div><div class="tx">
    <div class="tt">Open Saturday mornings</div>
    <div class="ss">You start at 12 on Saturdays. Opening at 9 adds 3 hours a week.</div></div>
    <div class="tr">Add</div></div>
  <div class="nudge"><div class="gl">{G_BOLT}</div><div class="tx">
    <div class="tt">Instant book</div>
    <div class="ss">Your ID's checked, so you can. Clients book your open hours straight in.</div></div>
    <div class="tr"><div class="sw"><b></b></div></div></div>
</div>

<div class="serif section" style="margin-top:32px">Your record</div>
<div class="facts2">
  <div><div class="eyebrow soft">Rating</div><div class="big num">{STAR}4.9</div><div class="cap soft" style="margin-top:2px">23 reviews</div></div>
  <div class="vr"></div>
  <div><div class="eyebrow soft">Reliability</div><div class="big"><span class="num">100%</span> kept</div><div class="cap soft" style="margin-top:2px">Only you see this.</div></div>
</div>
<div class="serif rquote">“She came to mine at 7 before the wedding. My nails were the best thing in the photos.”</div>
<div class="between" style="margin-top:8px">
  <div class="cap soft">Ruby · BIAB overlay · October</div>
  <div class="link" style="font-size:13px">All 23 <span style="color:var(--inkFaint)">{CHEV_S}</span></div>
</div>

<div style="margin-top:28px">
{money('<span class="num">$80.40</span> on its way', "Lands Mon 19 Oct")}
</div>
<div style="height:140px"></div>
'''

SCREENS = {
    "08-pro-today-busy": frame("Today, busy", "10:48", BUSY, unread_today=True),
    "09-pro-today-quiet": frame("Today, quiet", "14:20", QUIET),
    "10-pro-today-scrolled": frame("Today, busy, scrolled", "10:48", BUSY, scroll=700, unread_today=True),
    "11-pro-today-quiet-scrolled": frame("Today, quiet, scrolled", "14:20", QUIET, scroll=480),
}


def render(name):
    html = os.path.join(HERE, name + ".html")
    out = os.path.join(HERE, name + ".png")
    subprocess.run([CHROME, "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=2", "--window-size=430,884", "--virtual-time-budget=5000",
                    "--allow-file-access-from-files", f"--screenshot={out}", "file://" + html],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return out


if __name__ == "__main__":
    for k, v in SCREENS.items():
        with open(os.path.join(HERE, k + ".html"), "w") as f:
            f.write(v)
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
        sheet.save(os.path.join(HERE, "00-overview-today.png"))
    print("\n".join(outs))
