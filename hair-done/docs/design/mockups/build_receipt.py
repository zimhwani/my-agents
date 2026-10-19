"""Receipt mockups (proposal: ../receipt-proposal.md): the in-app receipt sheet and the emailed receipt.

Run: python3 build_receipt.py   (writes 12-13 .html and .png, and 00-overview-receipt.png)

Same frame, type stand-ins and Chromium render as build_today.py (Newsreader for New York, Inter for SF).
"""
import os, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell"

# The receipt, as the app would fill it in.
R = dict(
    ref="HD-AMF2", paid="21 Oct 2026, 2:58 pm", card="Visa •••• 4242",
    service="Gel manicure", length="1 hr", when="Wed 21 Oct, 2:00 pm",
    where="6 MacKenzie St, Cheltenham VIC 3192", client="Keith C.",
    pro="Hannah W.", pro_abn="12 345 678 901",
    lines=[("Gel manicure", "1 hr", "$60.00"), ("Travel fee", "", "$10.00"), ("Tip", "100% to Hannah", "$10.00")],
    fee="$3.00", total="$83.00",
)

STATUS = '''<div class="status"><div class="time">2:59</div><div class="icons">
<svg width="19" height="12" viewBox="0 0 19 12" fill="currentColor"><rect x="0" y="8" width="3.2" height="4" rx="1"/><rect x="5" y="5.5" width="3.2" height="6.5" rx="1"/><rect x="10" y="3" width="3.2" height="9" rx="1"/><rect x="15" y="0" width="3.2" height="12" rx="1"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.8" fill="none" stroke="currentColor" stroke-opacity=".4"/><rect x="2" y="2" width="16" height="9" rx="2.4" fill="currentColor"/></svg>
</div></div><div class="island"></div>'''

CSS = """
.dim{position:absolute;inset:0;background:rgba(36,26,22,.38);z-index:5}
.behind{position:absolute;left:0;top:0;width:393px;height:852px;padding:110px 24px 0;transform:scale(.94);transform-origin:50% 0;
  border-radius:12px;background:var(--paper)}
.sheet{position:absolute;left:0;right:0;top:58px;bottom:0;background:var(--paper);border-radius:12px 12px 0 0;z-index:10;overflow:hidden}
.grab{width:36px;height:5px;border-radius:3px;background:#D6CCC0;margin:7px auto 0}
.x{position:absolute;right:18px;top:16px;width:30px;height:30px;color:var(--inkSoft)}
.body{padding:18px 24px 0}
.muted{color:var(--inkSoft)}
.k{font-size:12px;font-weight:500;letter-spacing:.08em;text-transform:uppercase;color:var(--inkSoft)}
.row{display:flex;justify-content:space-between;align-items:baseline;padding:11px 0;border-bottom:.5px solid var(--lineStrong)}
.row .l{font-size:16px}.row .s{font-size:13px;color:var(--inkSoft);margin-top:2px}
.row .v{font-size:16px;font-feature-settings:"tnum"}
.from{margin-top:22px;display:flex;justify-content:space-between;align-items:baseline}
.from .who{font-size:15px;font-weight:600}.from .abn{font-size:12px;color:var(--inkSoft);font-feature-settings:"tnum"}
.total{display:flex;justify-content:space-between;align-items:baseline;margin-top:18px}
.total .l{font-size:17px;font-weight:600}.total .v{font-size:28px;font-weight:300;font-feature-settings:"tnum";letter-spacing:-.3px}
.dot{color:var(--lacquer)}
.btns{position:absolute;left:24px;right:24px;bottom:34px;display:flex;gap:10px}
.btn{flex:1;height:50px;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:600}
.btn.ink{background:var(--ink);color:var(--paperOnInk)}
.btn.out{border:1px solid var(--ink);flex:0 0 112px}
.foot{font-size:12px;line-height:1.5;color:var(--inkSoft);margin-top:18px}
/* email */
.mail{position:absolute;left:0;right:0;top:54px;bottom:0;background:#fff;overflow:hidden}
.mailhead{padding:10px 18px 12px;border-bottom:.5px solid #e4e0db;font-size:13px;color:#6b6b6b}
.mailhead b{color:#111;font-weight:600;font-size:15px}
.card{margin:16px;background:var(--paper);border-radius:6px;padding:26px 22px 22px}
.mark{font-family:'NY',serif;font-style:italic;font-size:26px}
"""


def sheet_body():
    lines = "".join(f'<div class="row"><div><div class="l">{n}</div>' + (f'<div class="s">{s}</div>' if s else "") +
                    f'</div><div class="v">{v}</div></div>' for n, s, v in R["lines"])
    return f'''
<div class="k">Receipt · {R["ref"]}</div>
<div class="serif" style="font-size:30px;line-height:1.15;margin-top:8px;text-wrap:balance">{R["service"]} with {R["pro"]}</div>
<div class="muted" style="font-size:15px;margin-top:6px;line-height:1.45">{R["when"]}<br>{R["where"]}</div>

<div class="from"><div class="who">From {R["pro"]}</div><div class="abn">ABN {R["pro_abn"]}</div></div>
{lines}

<div class="from"><div class="who">From Hair Done</div><div class="abn">ABN 45 281 131 814</div></div>
<div class="row"><div><div class="l">Booking fee</div></div><div class="v">{R["fee"]}</div></div>

<div class="total"><div class="l">Total paid</div><div class="v">{R["total"]}<span class="dot">.</span></div></div>
<div class="muted" style="font-size:14px;margin-top:4px">{R["card"]} · {R["paid"]}</div>

<div class="foot">No GST included. Hannah provides the service; Hair Done arranges the booking and payment.<br>
Hair Done · Melbourne VIC · hello@hairdonenailsdone.app · hairdonenailsdone.app/terms</div>'''


def page(title, inner):
    return (f'<!doctype html><html lang="en-AU"><head><meta charset="utf-8"><title>{title}</title>'
            f'<link rel="stylesheet" href="common.css"><style>{CSS}</style></head>'
            f'<body><div class="bezel"></div><div class="screen">{STATUS}{inner}<div class="homeind"></div></div></body></html>')


SHEET = page("Receipt sheet", f'''
<div class="behind"><div class="k">Paid</div><div class="serif" style="font-size:30px;margin-top:8px">Hannah W., Wed 21 Oct</div></div>
<div class="dim"></div>
<div class="sheet"><div class="grab"></div>
<svg class="x" viewBox="0 0 30 30" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M10 10l10 10M20 10L10 20"/></svg>
<div class="body">{sheet_body()}</div>
<div class="btns"><div class="btn ink">Email it to me</div><div class="btn out">Share</div></div>
</div>''')

EMAIL = page("Receipt email", f'''
<div class="mail">
<div class="mailhead"><b>Hair Done</b> &lt;hello@hairdonenailsdone.app&gt;<br>Your Hair Done receipt, {R["ref"]}</div>
<div class="card"><div class="mark">hd<span class="dot">.</span></div>
<div style="font-size:15px;margin:14px 0 18px">Thanks, {R["client"].split()[0]}. Here's your receipt.</div>
{sheet_body()}</div>
</div>''')

SCREENS = {"12-receipt-sheet": SHEET, "13-receipt-email": EMAIL}


def render(name):
    html, out = os.path.join(HERE, name + ".html"), os.path.join(HERE, name + ".png")
    subprocess.run([CHROME, "--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
                    "--window-size=433,892", "--virtual-time-budget=5000", "--allow-file-access-from-files",
                    f"--screenshot={out}", "file://" + html], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return out


if __name__ == "__main__":
    for k, v in SCREENS.items():
        open(os.path.join(HERE, k + ".html"), "w").write(v)
    ims = [Image.open(render(k)).convert("RGB") for k in SCREENS]
    w, h = ims[0].size
    gap = 40
    sheet = Image.new("RGB", (len(ims) * w + (len(ims) + 1) * gap, h + 2 * gap), (230, 222, 211))
    for i, im in enumerate(ims):
        sheet.paste(im, (gap + i * (w + gap), gap))
    sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(os.path.join(HERE, "00-overview-receipt.png"))
    print("ok")
