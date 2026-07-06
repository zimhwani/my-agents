"""Render an analysis into a client-ready HTML report and a Markdown summary.

Visual system: "The Answer Engine Readout" — a precision-instrument treatment
for a trust document (designed by the Agency's UI Designer / UX Architect
personas + the dataviz skill). Theme-aware (light/dark), print-friendly,
self-contained (inline CSS, no JS, no external assets).

The large CSS blocks are kept as plain string constants (NOT f-strings) so the
`{` / `}` don't need escaping; only the HTML body is interpolated.
"""

from __future__ import annotations

import datetime
import html
import math
from typing import List, Tuple

from .config import VERTICAL_LABELS


def esc(s) -> str:
    return html.escape(str(s))


def _ip(x: float) -> int:
    return round((x or 0) * 100)


def score_band(score: int) -> Tuple[str, str]:
    """Return (band_key, label). Keys: risk / emerging / strong."""
    if score >= 60:
        return "strong", "Strong"
    if score >= 30:
        return "emerging", "Emerging"
    return "risk", "At risk"


def _fmt_date(iso: str) -> str:
    try:
        dt = datetime.datetime.fromisoformat(iso)
        return f"{dt:%b} {dt.day}, {dt.year}"
    except Exception:
        return iso or ""


def _ref(name: str, iso: str) -> str:
    initials = "".join(w[0] for w in name.split()[:3]).upper() or "GEO"
    try:
        dt = datetime.datetime.fromisoformat(iso)
        return f"{initials}-{dt:%m%d}"
    except Exception:
        return initials


# --- inline icons ----------------------------------------------------------
_GLYPH = ('<svg class="glyph" viewBox="0 0 32 32" fill="none" aria-hidden="true">'
          '<rect x="1" y="14" width="4" height="4" rx="1.4" fill="currentColor" opacity="0.5"/>'
          '<rect x="7" y="10" width="4" height="12" rx="1.6" fill="currentColor" opacity="0.7"/>'
          '<rect x="13" y="4" width="4" height="24" rx="1.8" fill="currentColor"/>'
          '<rect x="19" y="9" width="4" height="14" rx="1.6" fill="currentColor" opacity="0.7"/>'
          '<rect x="25" y="13" width="4" height="6" rx="1.4" fill="currentColor" opacity="0.5"/></svg>')
_I_CROSS = ('<svg viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6.3" stroke="currentColor" '
            'stroke-width="1.3"/><path d="M5.6 5.6l4.8 4.8M10.4 5.6l-4.8 4.8" stroke="currentColor" '
            'stroke-width="1.4" stroke-linecap="round"/></svg>')
_I_CHECK = ('<svg viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6.3" stroke="currentColor" '
            'stroke-width="1.3"/><path d="M5.3 8.2l1.9 1.9 3.5-3.9" stroke="currentColor" stroke-width="1.5" '
            'stroke-linecap="round" stroke-linejoin="round"/></svg>')
_BAND_ICON = {
    "risk": ('<svg viewBox="0 0 16 16" fill="none"><path d="M8 1.8 1.5 13.5h13L8 1.8Z" stroke="currentColor" '
             'stroke-width="1.4" stroke-linejoin="round"/><path d="M8 6.4v3.1" stroke="currentColor" '
             'stroke-width="1.5" stroke-linecap="round"/><circle cx="8" cy="11.4" r="0.9" fill="currentColor"/></svg>'),
    "emerging": ('<svg viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6.3" stroke="currentColor" '
                 'stroke-width="1.4"/><path d="M8 5v3.3l2.2 1.3" stroke="currentColor" stroke-width="1.5" '
                 'stroke-linecap="round"/></svg>'),
    "strong": ('<svg viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6.3" stroke="currentColor" '
               'stroke-width="1.4"/><path d="M5.3 8.2l1.9 1.9 3.5-3.9" stroke="currentColor" stroke-width="1.5" '
               'stroke-linecap="round" stroke-linejoin="round"/></svg>'),
}
_I_CHEV = ('<svg viewBox="0 0 20 20" fill="none"><path d="M7 4l6 6-6 6" stroke="currentColor" stroke-width="1.7" '
           'stroke-linecap="round" stroke-linejoin="round"/></svg>')

_HEADLINE_KIND = {
    "risk": "is nearly invisible to AI assistants.",
    "emerging": "is gaining ground with AI assistants.",
    "strong": "is a go-to answer for AI assistants.",
}


def _doc(title: str, css: str, body: str) -> str:
    return (
        '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8"/>\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1"/>\n'
        f"<title>{esc(title)}</title>\n<style>\n{css}\n</style>\n</head>\n<body>\n"
        f"{body}\n</body>\n</html>\n"
    )


# ===========================================================================
# CLIENT REPORT
# ===========================================================================

def render_html(analysis: dict, client: dict) -> str:
    name = analysis["client_name"]
    score = analysis["visibility_score"]
    bk, blabel = score_band(score)
    total = analysis["total_queries"]
    brands = analysis["brands"]
    cli = analysis["client"]
    per_prompt = analysis["per_prompt"]
    gen = analysis.get("generated_at", "")

    label = VERTICAL_LABELS.get(client.get("vertical", ""), "business")
    label_disp = label[:1].upper() + label[1:]
    loc = client.get("location", "")
    providers = sorted({p["provider"] for p in per_prompt})
    n_assist = len(providers) or 1

    # --- gauge geometry (pathLength=100 → offset = 100 - score) ---
    ang = math.radians(180 - 1.8 * score)
    dot_cx = 140 + 120 * math.cos(ang)
    dot_cy = 140 - 120 * math.sin(ang)
    seg = {
        k: (' on-' + k) if k == bk else ''
        for k in ("risk", "emerging", "strong")
    }

    # --- tiles ---
    presence, first, sov, mentions = cli["presence_rate"], cli["first_rate"], cli["share_of_voice"], cli["mentions"]
    top_comp = max((b for b in brands if not b["is_client"]),
                   key=lambda b: b["share_of_voice"], default=None)
    if _ip(sov) == 0:
        callout = ("Across every answer, competitors capture <b>100%</b> of the "
                   "airtime — you have no share of voice yet.")
    else:
        callout = f"Across every answer, competitors capture <b>{100 - _ip(sov)}%</b> of the airtime."
        if top_comp and sov > 0:
            mult = round(top_comp["share_of_voice"] / sov)
            if mult >= 2:
                callout += (f" The market leader alone takes {_ip(top_comp['share_of_voice'])}% "
                            f"— {mult}× your share.")

    # --- share-of-voice bars ---
    max_sov = max((b["share_of_voice"] for b in brands), default=0) or 1
    sov_rows = []
    for i, b in enumerate(brands):
        width = 22 + 66 * (b["share_of_voice"] / max_sov)
        cls = " client" if b["is_client"] else ""
        badge = '<span class="you-badge">You</span>' if b["is_client"] else ""
        sov_rows.append(
            f'<div class="sov-row{cls}"><div class="sov-name"><span class="rank">{i+1}</span>'
            f'<span class="nm">{esc(b["brand"])}</span>{badge}</div>'
            f'<div class="sov-track"><span class="sov-bar" style="width:{width:.0f}%"></span>'
            f'<span class="sov-val">{_ip(b["share_of_voice"])}%</span></div></div>'
        )

    # --- comparison table ---
    cmp_rows = []
    for b in brands:
        rc = ' class="client-row"' if b["is_client"] else ""
        rank = f'{b["avg_rank"]:.1f}' if b["avg_rank"] is not None else "—"
        cmp_rows.append(
            f'<tr{rc}><td><span class="brandcell"><span class="dot"></span>{esc(b["brand"])}</span></td>'
            f'<td>{_ip(b["share_of_voice"])}%</td><td>{_ip(b["presence_rate"])}%</td>'
            f'<td>{_ip(b["first_rate"])}%</td><td>{rank}</td><td>{b["mentions"]}</td></tr>'
        )

    # --- evidence ---
    evi_rows = []
    for p in per_prompt:
        chips = []
        for j, brand in enumerate(p["ranked"]):
            ic = " is-client" if brand == name else ""
            chips.append(f'<span class="chip{ic}"><span class="ci">{j+1}</span>{esc(brand)}</span>')
        chips_html = "".join(chips) or '<span class="chip">—</span>'
        svc = p["service"] or "General"
        if p["client_present"]:
            pres = f'<span class="presence yes">{_I_CHECK}Named</span>'
        else:
            pres = f'<span class="presence no">{_I_CROSS}Absent</span>'
        evi_rows.append(
            f'<tr><td><div class="prompt-q">{esc(p["prompt"])}</div>'
            f'<div class="prompt-meta"><span class="tag">{esc(p["provider"])}</span>'
            f'<span class="tag">{esc(svc)}</span></div></td>'
            f'<td><div class="ranked">{chips_html}</div></td>'
            f'<td style="text-align:right;">{pres}</td></tr>'
        )

    # --- missing services ---
    gaps_section = ""
    if analysis["missing_services"]:
        chips = "".join(
            f'<span class="gap-chip">{_I_CROSS}{esc(s)}</span>'
            for s in analysis["missing_services"]
        )
        gaps_section = (
            '<section aria-label="Services where you never appear"><div class="sec-head">'
            '<h2><span class="n">03</span> Services where you\'re invisible</h2>'
            "<p>For these high-intent treatments, an AI assistant asked "
            "&ldquo;who&rsquo;s best near me?&rdquo; never once named you — even though "
            f"you offer them.</p></div><div class=\"card gaps\">{chips}</div></section>"
        )

    # --- recommendations ---
    rec_cards = []
    for rec in analysis["recommendations"]:
        pcls = "p-" + rec["priority"].lower()
        rec_cards.append(
            f'<article class="rec {pcls}"><div class="pr"><span class="lab">Priority</span>'
            f'<span class="code">{esc(rec["priority"])}</span></div><div class="body">'
            f'<h3>{esc(rec["title"])}</h3><p class="why">{esc(rec["why"])}</p>'
            f'<div class="action"><span class="lbl">Do this</span><span>{esc(rec["action"])}</span>'
            "</div></div></article>"
        )
    recs_html = "".join(rec_cards)

    band_scale = (
        f'<div class="band-scale" aria-hidden="true">'
        f'<span class="seg{seg["risk"]}">At risk<span class="rg">0–29</span></span>'
        f'<span class="seg{seg["emerging"]}">Emerging<span class="rg">30–59</span></span>'
        f'<span class="seg{seg["strong"]}">Strong<span class="rg">60–100</span></span></div>'
    )

    body = f"""<div class="wrap">
  <header class="topbar">
    <div class="brand">{_GLYPH}<span class="wordmark">GEO&nbsp;<b>Engine</b>
      <span class="sub">AI Visibility Intelligence</span></span></div>
    <div class="doc-meta">Report generated <b>{esc(_fmt_date(gen))}</b><br>
      {total} queries · {n_assist} assistant{'s' if n_assist != 1 else ''} · ref&nbsp;<b>{esc(_ref(name, gen))}</b></div>
  </header>

  <div class="report-head">
    <p class="eyebrow" style="margin-bottom:10px;">AI Answer Visibility Report</p>
    <h1>{esc(name)}<br><span class="kind">{_HEADLINE_KIND[bk]}</span></h1>
    <div class="facts">
      <span class="fact"><span class="k">Location</span> {esc(loc)}</span>
      <span class="fact"><span class="k">Vertical</span> {esc(label_disp)}</span>
      <span class="fact"><span class="k">Queries analyzed</span> {total}</span>
    </div>
  </div>

  <section class="hero" aria-label="Visibility score">
    <div class="gauge-card card">
      <p class="eyebrow">Visibility Score</p>
      <div class="gauge-wrap">
        <svg viewBox="0 0 280 168" role="img" aria-label="Visibility score {score} out of 100, {blabel.lower()}">
          <path class="gauge-track" d="M20 140 A120 120 0 0 1 260 140" pathLength="100"/>
          <path class="gauge-val" d="M20 140 A120 120 0 0 1 260 140" pathLength="100"
                style="stroke: var(--{bk}); --val-offset: {100 - score};"/>
          <circle class="gauge-dot" cx="{dot_cx:.1f}" cy="{dot_cy:.1f}" r="7" fill="var(--{bk})"/>
        </svg>
      </div>
      <div class="score-num">{score}<span class="of"> / 100</span></div>
      <span class="band-pill band-{bk}">{_BAND_ICON[bk]}{blabel}</span>
      {band_scale}
    </div>
    <div class="tiles">
      <div class="tile card"><span class="eyebrow">Presence rate</span>
        <span class="val">{_ip(presence)}<small>%</small></span>
        <span class="desc">Named in {mentions} of {total} AI answers about {esc(loc)} {esc(label)}s.</span>
        <div class="mini-bar"><i style="width:{max(_ip(presence),1)}%"></i></div></div>
      <div class="tile card"><span class="eyebrow">Named first</span>
        <span class="val">{_ip(first)}<small>%</small></span>
        <span class="desc">How often you are the assistant's first recommendation.</span>
        <div class="mini-bar"><i style="width:{max(_ip(first),1)}%"></i></div></div>
      <div class="tile callout card"><span class="eyebrow">Share of voice</span>
        <span class="val">{_ip(sov)}<small>% of all mentions</small></span>
        <span class="desc">{callout}</span>
        <div class="mini-bar"><i style="width:{max(_ip(sov),1)}%"></i></div></div>
    </div>
  </section>

  <section aria-label="Competitive field"><div class="sec-head">
    <h2><span class="n">01</span> The competitive field</h2>
    <p>Share of voice is the percentage of all brand mentions across the {total} AI answers.</p></div>
    <div class="legend"><span class="key"><span class="sw acc"></span> {esc(name)} (you)</span>
      <span class="key"><span class="sw riv"></span> Competitors</span></div>
    <div class="card sov">{''.join(sov_rows)}</div>
    <div class="card table-scroll" style="margin-top:16px;"><table class="data"><thead><tr>
      <th scope="col">Brand</th><th scope="col">Share of voice</th><th scope="col">Presence rate</th>
      <th scope="col">Named first</th><th scope="col">Avg. rank</th><th scope="col">Mentions</th>
    </tr></thead><tbody>{''.join(cmp_rows)}</tbody></table></div>
  </section>

  <section aria-label="Evidence from AI answers"><div class="sec-head">
    <h2><span class="n">02</span> What the assistants actually said</h2>
    <p>Every buyer question we tested, the businesses each assistant named, and whether you made the list.</p></div>
    <div class="card table-scroll"><table class="evi"><thead><tr>
      <th scope="col" style="width:40%">Buyer question</th><th scope="col">Who the assistant named</th>
      <th scope="col" style="text-align:right;">You?</th>
    </tr></thead><tbody>{''.join(evi_rows)}</tbody></table></div>
  </section>

  {gaps_section}

  <section aria-label="Recommendations"><div class="sec-head">
    <h2><span class="n">04</span> Your roadmap to visibility</h2>
    <p>Ordered by impact. P0 items are the reason the assistants can't confirm you're the answer — start there.</p></div>
    <div class="recs">{recs_html}</div>
  </section>

  <footer class="foot">
    <div class="sig">Prepared with the <b>GEO Engine</b><br>AI answer visibility intelligence</div>
    <div class="method">Method: {total} buyer-intent prompts run across {n_assist} AI assistant{'s' if n_assist != 1 else ''} on {esc(_fmt_date(gen))}. Brand mentions extracted and ranked per answer. AI answers are non-deterministic; this is a point-in-time signal, not a revenue guarantee.</div>
  </footer>
</div>"""

    return _doc(f"{name} — AI Visibility Report", _REPORT_CSS, body)


# ===========================================================================
# PORTFOLIO DASHBOARD
# ===========================================================================

def render_portfolio_html(summaries: List[dict]) -> str:
    n = len(summaries)
    avg = round(sum(s["score"] for s in summaries) / n) if n else 0
    avg_bk, _ = score_band(avg)
    at_risk = sum(1 for s in summaries if s["score"] < 30)
    avg_pres = round(sum(s["presence_rate"] for s in summaries) / n * 100) if n else 0

    rows = []
    for s in sorted(summaries, key=lambda x: x["score"]):
        bk, blabel = score_band(s["score"])
        offset = 169.6 * (1 - s["score"] / 100)
        pres = _ip(s["presence_rate"])
        comp = s.get("top_competitor") or "—"
        rows.append(
            f'<a class="row b-{bk}" href="{esc(s["report"])}" '
            f'aria-label="{esc(s["name"])}, score {s["score"]}, {blabel.lower()}. Open report.">'
            '<span class="stripe" aria-hidden="true"></span>'
            '<div class="score-block"><div class="score-ring">'
            '<svg viewBox="0 0 66 66" aria-hidden="true"><circle class="rtrack" cx="33" cy="33" r="27"/>'
            f'<circle class="rval" cx="33" cy="33" r="27" stroke-dasharray="169.6" stroke-dashoffset="{offset:.1f}"/>'
            f'</svg><span class="num">{s["score"]}</span></div>'
            f'<span class="band-tag">{_BAND_ICON[bk]}{blabel}</span></div>'
            f'<div class="who"><div class="name">{esc(s["name"])}</div>'
            f'<div class="meta"><span class="vert">{esc(s["vertical"])}</span>'
            f'<span class="sepdot"></span>{esc(s["location"])}</div></div>'
            f'<div class="metric"><div class="eyebrow">Presence</div><div class="pv">{pres}%</div>'
            f'<div class="mbar"><i style="width:{max(pres,1)}%"></i></div></div>'
            f'<div class="comp"><div class="eyebrow">Top competitor</div><div class="cv">{esc(comp)}</div>'
            '<div class="cnote">leading AI-answer share</div></div>'
            f'<span class="chev" aria-hidden="true">{_I_CHEV}</span></a>'
        )

    body = f"""<div class="wrap">
  <header class="topbar">
    <div class="brand">{_GLYPH}<span class="wordmark">GEO&nbsp;<b>Engine</b>
      <span class="sub">Portfolio Console</span></span></div>
  </header>
  <div class="head"><p class="eyebrow" style="margin-bottom:9px;">Operator Dashboard</p>
    <h1>Client portfolio</h1>
    <p>Every account you manage, sorted so the most at-risk sits on top. Open a client to see the full visibility report.</p></div>
  <div class="agg">
    <div class="stat"><span class="eyebrow">Accounts</span><span class="val">{n}</span>
      <span class="sub">Active this cycle</span></div>
    <div class="stat"><span class="eyebrow">Average score</span><span class="val">{avg}<small> / 100</small></span>
      <span class="sub"><span class="band-dot" style="background:var(--{avg_bk})"></span>{score_band(avg)[1]} overall</span></div>
    <div class="stat{' flag' if at_risk else ''}"><span class="eyebrow">Needs attention</span><span class="val">{at_risk}</span>
      <span class="sub">Account{'s' if at_risk != 1 else ''} below 30 (at risk)</span></div>
    <div class="stat"><span class="eyebrow">Avg. presence rate</span><span class="val">{avg_pres}<small>%</small></span>
      <span class="sub">Share of AI answers naming clients</span></div>
  </div>
  <div class="list-head"><h2>Accounts by score</h2>
    <span class="hint"><svg viewBox="0 0 16 16" fill="none"><path d="M8 3v10M8 13l3-3M8 13l-3-3" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg> Lowest first — triage top-down</span></div>
  <div class="col-head" aria-hidden="true"><span></span><span>Score</span><span style="text-align:left;">Client</span><span>Presence</span><span>Top competitor</span><span></span></div>
  <div class="rows">{''.join(rows)}</div>
  <footer class="foot">{n} account{'s' if n != 1 else ''} · GEO Engine portfolio console</footer>
</div>"""

    return _doc("GEO Engine — Portfolio", _PORTFOLIO_CSS, body)


# ===========================================================================
# MARKDOWN (unchanged content, plain-text summary)
# ===========================================================================

def render_markdown(analysis: dict, client: dict) -> str:
    name = analysis["client_name"]
    lines: List[str] = []
    _, band = score_band(analysis["visibility_score"])
    lines.append(f"# AI Visibility Report — {name}")
    lines.append("")
    lines.append(
        f"**Visibility score: {analysis['visibility_score']}/100 ({band})** · "
        f"{client.get('vertical','')} · {client.get('location','')} · "
        f"{analysis['total_queries']} buyer questions"
    )
    lines.append("")
    cr = analysis["client"]
    lines.append(
        f"{name} is named in {cr['presence_rate']:.0%} of AI answers and is the "
        f"first recommendation {cr['first_rate']:.0%} of the time."
    )
    lines.append("")
    lines.append("## Share of voice")
    lines.append("")
    lines.append("| Provider | Share of voice | Seen in |")
    lines.append("|---|---|---|")
    for r in analysis["brands"]:
        tag = " (you)" if r["is_client"] else ""
        lines.append(f"| {r['brand']}{tag} | {r['share_of_voice']:.0%} | {r['presence_rate']:.0%} |")
    lines.append("")
    lines.append("## Recommended fixes")
    lines.append("")
    for rec in analysis["recommendations"]:
        lines.append(f"### {rec['priority']} — {rec['title']}")
        lines.append(f"*{rec['why']}*")
        lines.append("")
        lines.append(f"**Do this:** {rec['action']}")
        lines.append("")
    return "\n".join(lines)


# ===========================================================================
# STYLES
# ===========================================================================

_REPORT_CSS = r"""
  :root {
    --page:#eef0f4; --surface:#ffffff; --surface-2:#f6f7fa;
    --ink:#111722; --ink-2:#465063; --muted:#78849a;
    --line:rgba(17,23,34,0.10); --line-strong:rgba(17,23,34,0.16);
    --accent:#2563cf; --accent-ink:#1c50ad; --accent-wash:rgba(37,99,207,0.09);
    --rival:#8b97a8; --rival-track:rgba(120,132,154,0.16);
    --risk:#d0392f; --risk-wash:rgba(208,57,47,0.10);
    --emerging:#c47d16; --emerging-wash:rgba(196,125,22,0.10);
    --strong:#1a8f52; --strong-wash:rgba(26,143,82,0.10);
    --p0:#d0392f; --p1:#c47d16; --p2:#5b6675;
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    --mono: ui-monospace, "SF Mono", "Cascadia Mono", "Segoe UI Mono", "Roboto Mono", Menlo, Consolas, monospace;
    --shadow-sm:0 1px 2px rgba(17,23,34,0.05),0 1px 3px rgba(17,23,34,0.06);
    --shadow-md:0 4px 14px rgba(17,23,34,0.08),0 1px 3px rgba(17,23,34,0.06);
    --radius:14px;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --page:#0c0f14; --surface:#161b23; --surface-2:#1c222c;
      --ink:#f4f6fa; --ink-2:#b6c0d0; --muted:#8592a6;
      --line:rgba(255,255,255,0.10); --line-strong:rgba(255,255,255,0.16);
      --accent:#4b90ef; --accent-ink:#7fb0f5; --accent-wash:rgba(75,144,239,0.14);
      --rival:#6d7889; --rival-track:rgba(255,255,255,0.08);
      --risk:#e56a5f; --risk-wash:rgba(229,106,95,0.14);
      --emerging:#e0a63c; --emerging-wash:rgba(224,166,60,0.14);
      --strong:#34b56d; --strong-wash:rgba(52,181,109,0.14);
      --p0:#e56a5f; --p1:#e0a63c; --p2:#93a0b2;
      --shadow-sm:0 1px 2px rgba(0,0,0,0.4); --shadow-md:0 6px 20px rgba(0,0,0,0.45);
    }
  }
  :root[data-theme="light"] {
    --page:#eef0f4; --surface:#ffffff; --surface-2:#f6f7fa; --ink:#111722; --ink-2:#465063; --muted:#78849a;
    --line:rgba(17,23,34,0.10); --line-strong:rgba(17,23,34,0.16);
    --accent:#2563cf; --accent-ink:#1c50ad; --accent-wash:rgba(37,99,207,0.09);
    --rival:#8b97a8; --rival-track:rgba(120,132,154,0.16);
    --risk:#d0392f; --risk-wash:rgba(208,57,47,0.10); --emerging:#c47d16; --emerging-wash:rgba(196,125,22,0.10);
    --strong:#1a8f52; --strong-wash:rgba(26,143,82,0.10); --p0:#d0392f; --p1:#c47d16; --p2:#5b6675;
    --shadow-sm:0 1px 2px rgba(17,23,34,0.05),0 1px 3px rgba(17,23,34,0.06);
    --shadow-md:0 4px 14px rgba(17,23,34,0.08),0 1px 3px rgba(17,23,34,0.06);
  }
  :root[data-theme="dark"] {
    --page:#0c0f14; --surface:#161b23; --surface-2:#1c222c; --ink:#f4f6fa; --ink-2:#b6c0d0; --muted:#8592a6;
    --line:rgba(255,255,255,0.10); --line-strong:rgba(255,255,255,0.16);
    --accent:#4b90ef; --accent-ink:#7fb0f5; --accent-wash:rgba(75,144,239,0.14);
    --rival:#6d7889; --rival-track:rgba(255,255,255,0.08);
    --risk:#e56a5f; --risk-wash:rgba(229,106,95,0.14); --emerging:#e0a63c; --emerging-wash:rgba(224,166,60,0.14);
    --strong:#34b56d; --strong-wash:rgba(52,181,109,0.14); --p0:#e56a5f; --p1:#e0a63c; --p2:#93a0b2;
    --shadow-sm:0 1px 2px rgba(0,0,0,0.4); --shadow-md:0 6px 20px rgba(0,0,0,0.45);
  }
  * { box-sizing:border-box; }
  html { -webkit-text-size-adjust:100%; }
  body { margin:0; font-family:var(--sans); background:var(--page); color:var(--ink);
    line-height:1.5; -webkit-font-smoothing:antialiased; text-rendering:optimizeLegibility; }
  h1,h2,h3 { text-wrap:balance; margin:0; }
  a { color:var(--accent-ink); }
  .wrap { max-width:940px; margin:0 auto; padding:0 20px 72px; }
  .eyebrow { font-size:11px; font-weight:700; letter-spacing:0.14em; text-transform:uppercase; color:var(--muted); }
  .topbar { display:flex; align-items:center; justify-content:space-between; gap:16px; padding:20px 0 18px; flex-wrap:wrap; }
  .brand { display:flex; align-items:center; gap:11px; }
  .brand .glyph { width:30px; height:30px; display:block; color:var(--accent); }
  .brand .wordmark { font-weight:800; letter-spacing:0.02em; font-size:15px; }
  .brand .wordmark b { color:var(--accent); font-weight:800; }
  .brand .sub { display:block; font-size:10.5px; letter-spacing:0.16em; text-transform:uppercase; color:var(--muted); font-weight:600; }
  .doc-meta { text-align:right; font-size:12px; color:var(--muted); font-family:var(--mono); line-height:1.7; }
  .doc-meta b { color:var(--ink-2); font-weight:600; }
  .report-head { border-top:2px solid var(--ink); padding-top:22px; margin-bottom:26px; }
  .report-head h1 { font-size:clamp(30px,6vw,46px); font-weight:800; letter-spacing:-0.02em; line-height:1.02; }
  .report-head .kind { color:var(--muted); font-weight:700; }
  .facts { display:flex; flex-wrap:wrap; gap:8px; margin-top:16px; }
  .fact { display:inline-flex; align-items:center; gap:7px; font-size:12.5px; font-weight:600; color:var(--ink-2);
    background:var(--surface); border:1px solid var(--line); padding:6px 11px; border-radius:999px; }
  .fact .k { color:var(--muted); font-weight:600; }
  .card { background:var(--surface); border:1px solid var(--line); border-radius:var(--radius); box-shadow:var(--shadow-sm); }
  section { margin-top:34px; }
  .sec-head { margin-bottom:16px; }
  .sec-head h2 { font-size:20px; font-weight:750; letter-spacing:-0.01em; display:flex; align-items:baseline; gap:10px; }
  .sec-head .n { font-family:var(--mono); font-size:12px; color:var(--accent); font-weight:700; letter-spacing:0.05em; }
  .sec-head p { margin:6px 0 0; color:var(--ink-2); font-size:14px; max-width:62ch; }
  .hero { display:grid; grid-template-columns:300px 1fr; gap:22px; align-items:stretch; }
  .gauge-card { padding:22px 20px 20px; display:flex; flex-direction:column; align-items:center; text-align:center; position:relative; overflow:hidden; }
  .gauge-card .eyebrow { align-self:flex-start; }
  .gauge-wrap { width:100%; max-width:260px; margin:6px auto 0; }
  .gauge-wrap svg { width:100%; height:auto; display:block; }
  .gauge-track { fill:none; stroke:var(--rival-track); stroke-width:15; stroke-linecap:round; }
  .gauge-val { fill:none; stroke-width:15; stroke-linecap:round; stroke-dasharray:100;
    stroke-dashoffset:var(--val-offset,100); animation:gaugeFill 1.3s cubic-bezier(0.22,0.61,0.36,1) both; }
  @keyframes gaugeFill { from { stroke-dashoffset:100; } to { stroke-dashoffset:var(--val-offset,100); } }
  .gauge-dot { stroke:var(--surface); stroke-width:3; animation:dotFade 1.3s ease both; }
  @keyframes dotFade { 0%,55% { opacity:0; } 100% { opacity:1; } }
  @media (prefers-reduced-motion: reduce) { .gauge-val { animation:none; } .gauge-dot { animation:none; opacity:1; } }
  .score-num { margin-top:-58px; font-size:62px; font-weight:800; letter-spacing:-0.03em; line-height:1; }
  .score-num .of { font-size:20px; font-weight:600; color:var(--muted); letter-spacing:0; }
  .band-pill { margin-top:10px; display:inline-flex; align-items:center; gap:7px; font-size:13px; font-weight:700; padding:6px 13px; border-radius:999px; }
  .band-pill svg { width:15px; height:15px; }
  .band-scale { display:flex; gap:4px; width:100%; margin-top:16px; }
  .band-scale .seg { flex:1; text-align:center; font-size:10px; font-weight:700; letter-spacing:0.03em; text-transform:uppercase;
    color:var(--muted); padding:7px 2px 6px; border-radius:8px; background:var(--surface-2); border:1px solid transparent; }
  .band-scale .seg .rg { display:block; font-family:var(--mono); font-size:9.5px; opacity:0.8; font-weight:600; letter-spacing:0; margin-top:1px; }
  .band-scale .seg.on-risk { color:var(--risk); background:var(--risk-wash); border-color:color-mix(in srgb, var(--risk) 34%, transparent); }
  .band-scale .seg.on-emerging { color:var(--emerging); background:var(--emerging-wash); border-color:color-mix(in srgb, var(--emerging) 34%, transparent); }
  .band-scale .seg.on-strong { color:var(--strong); background:var(--strong-wash); border-color:color-mix(in srgb, var(--strong) 34%, transparent); }
  .band-risk { color:var(--risk); background:var(--risk-wash); }
  .band-emerging { color:var(--emerging); background:var(--emerging-wash); }
  .band-strong { color:var(--strong); background:var(--strong-wash); }
  .tiles { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
  .tile { padding:16px 16px 15px; display:flex; flex-direction:column; gap:4px; min-height:0; }
  .tile .eyebrow { font-size:10.5px; }
  .tile .val { font-size:34px; font-weight:800; letter-spacing:-0.02em; line-height:1.05; margin-top:2px; }
  .tile .val small { font-size:17px; font-weight:700; color:var(--muted); }
  .tile .desc { font-size:12px; color:var(--ink-2); line-height:1.4; }
  .tile.callout { grid-column:span 2; background:var(--accent-wash); border-color:color-mix(in srgb, var(--accent) 26%, transparent); }
  .tile.callout .val { color:var(--accent-ink); }
  .mini-bar { height:6px; border-radius:999px; background:var(--rival-track); overflow:hidden; margin-top:8px; }
  .mini-bar > i { display:block; height:100%; border-radius:999px; background:var(--accent); }
  .legend { display:flex; gap:18px; flex-wrap:wrap; margin-bottom:14px; font-size:12px; color:var(--ink-2); font-weight:600; }
  .legend .key { display:inline-flex; align-items:center; gap:7px; }
  .legend .sw { width:13px; height:13px; border-radius:4px; }
  .legend .sw.acc { background:var(--accent); }
  .legend .sw.riv { background:var(--rival); }
  .sov { padding:18px 20px 8px; }
  .sov-row { display:grid; grid-template-columns:150px 1fr; gap:14px; align-items:center; padding:9px 0; }
  .sov-row + .sov-row { border-top:1px solid var(--line); }
  .sov-name { display:flex; align-items:center; gap:8px; font-size:13.5px; font-weight:650; min-width:0; }
  .sov-name .rank { font-family:var(--mono); font-size:11px; color:var(--muted); width:18px; flex:none; }
  .sov-name .nm { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .you-badge { flex:none; font-size:9.5px; font-weight:800; letter-spacing:0.06em; color:#fff; background:var(--accent); padding:2px 6px; border-radius:5px; text-transform:uppercase; }
  .sov-track { position:relative; display:flex; align-items:center; gap:10px; }
  .sov-bar { height:16px; border-radius:4px 5px 5px 4px; background:var(--rival); flex:none; min-width:3px; }
  .sov-row.client .sov-bar { background:var(--accent); }
  .sov-val { font-size:12.5px; font-weight:700; font-variant-numeric:tabular-nums; color:var(--ink-2); }
  .sov-row.client .sov-val { color:var(--accent-ink); }
  .table-scroll { overflow-x:auto; -webkit-overflow-scrolling:touch; }
  table.data { width:100%; border-collapse:collapse; min-width:560px; font-size:13px; }
  table.data thead th { text-align:right; font-size:11px; font-weight:700; letter-spacing:0.03em; text-transform:uppercase;
    color:var(--muted); padding:12px 14px; border-bottom:1px solid var(--line-strong); white-space:nowrap; }
  table.data thead th:first-child { text-align:left; }
  table.data tbody td { padding:11px 14px; border-bottom:1px solid var(--line); text-align:right;
    font-variant-numeric:tabular-nums; color:var(--ink-2); white-space:nowrap; }
  table.data tbody td:first-child { text-align:left; font-weight:650; color:var(--ink); }
  table.data tbody tr:last-child td { border-bottom:none; }
  table.data tbody tr.client-row { background:var(--accent-wash); }
  table.data tbody tr.client-row td:first-child { color:var(--accent-ink); }
  .brandcell { display:inline-flex; align-items:center; gap:8px; }
  .brandcell .dot { width:9px; height:9px; border-radius:3px; flex:none; background:var(--rival); }
  tr.client-row .brandcell .dot { background:var(--accent); }
  table.evi { width:100%; border-collapse:collapse; min-width:720px; font-size:13px; }
  table.evi thead th { text-align:left; font-size:11px; font-weight:700; letter-spacing:0.03em; text-transform:uppercase;
    color:var(--muted); padding:12px 14px; border-bottom:1px solid var(--line-strong); white-space:nowrap; }
  table.evi td { padding:13px 14px; border-bottom:1px solid var(--line); vertical-align:top; }
  table.evi tr:last-child td { border-bottom:none; }
  .prompt-q { font-family:var(--mono); font-size:12.5px; color:var(--ink); line-height:1.4; }
  .prompt-q::before { content:"\201C"; color:var(--muted); }
  .prompt-q::after { content:"\201D"; color:var(--muted); }
  .prompt-meta { margin-top:5px; display:flex; gap:6px; flex-wrap:wrap; }
  .tag { font-family:var(--mono); font-size:10px; font-weight:600; color:var(--muted); background:var(--surface-2);
    border:1px solid var(--line); padding:1px 6px; border-radius:5px; letter-spacing:0.02em; }
  .ranked { display:flex; flex-wrap:wrap; gap:6px; align-items:center; }
  .chip { display:inline-flex; align-items:center; gap:5px; font-size:12px; font-weight:600; color:var(--ink-2);
    background:var(--surface-2); border:1px solid var(--line); padding:3px 9px; border-radius:999px; white-space:nowrap; }
  .chip .ci { font-family:var(--mono); font-size:10px; color:var(--muted); }
  .chip.is-client { color:#fff; background:var(--accent); border-color:var(--accent); }
  .chip.is-client .ci { color:rgba(255,255,255,0.75); }
  .presence { display:inline-flex; align-items:center; gap:6px; font-size:12px; font-weight:700; white-space:nowrap; }
  .presence svg { width:15px; height:15px; flex:none; }
  .presence.yes { color:var(--strong); }
  .presence.no { color:var(--muted); }
  .gaps { padding:20px; display:flex; flex-wrap:wrap; gap:9px; }
  .gap-chip { display:inline-flex; align-items:center; gap:7px; font-size:13px; font-weight:600; color:var(--ink);
    background:var(--risk-wash); border:1px solid color-mix(in srgb, var(--risk) 26%, transparent); padding:7px 13px; border-radius:8px; }
  .gap-chip svg { width:14px; height:14px; color:var(--risk); flex:none; }
  .recs { display:flex; flex-direction:column; gap:14px; }
  .rec { display:grid; grid-template-columns:62px 1fr; border-radius:var(--radius); overflow:hidden;
    border:1px solid var(--line); background:var(--surface); box-shadow:var(--shadow-sm); }
  .rec .pr { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px; padding:16px 6px; color:#fff; font-weight:800; letter-spacing:0.03em; }
  .rec .pr .lab { font-size:8.5px; letter-spacing:0.12em; text-transform:uppercase; opacity:0.85; font-weight:700; }
  .rec .pr .code { font-size:20px; }
  .rec.p-p0 .pr { background:var(--p0); }
  .rec.p-p1 .pr { background:var(--p1); }
  .rec.p-p2 .pr { background:var(--p2); }
  .rec .body { padding:15px 18px; }
  .rec h3 { font-size:15.5px; font-weight:700; letter-spacing:-0.01em; }
  .rec .why { margin:7px 0 0; font-size:13px; color:var(--ink-2); }
  .rec .action { margin-top:11px; display:flex; gap:9px; align-items:flex-start; font-size:13px; color:var(--ink);
    background:var(--surface-2); border:1px solid var(--line); border-radius:9px; padding:9px 12px; }
  .rec .action .lbl { font-size:10px; font-weight:800; letter-spacing:0.08em; text-transform:uppercase; color:var(--accent); flex:none; margin-top:2px; }
  .foot { margin-top:46px; padding-top:22px; border-top:1px solid var(--line); display:flex; justify-content:space-between; gap:20px; flex-wrap:wrap; font-size:12px; color:var(--muted); }
  .foot .sig b { color:var(--ink-2); font-weight:700; }
  .foot .method { max-width:52ch; font-family:var(--mono); font-size:11px; line-height:1.7; }
  @media (max-width:760px) { .hero { grid-template-columns:1fr; } .sov-row { grid-template-columns:120px 1fr; } }
  @media (max-width:460px) { .tiles { grid-template-columns:1fr; } .tile.callout { grid-column:span 1; } .doc-meta { text-align:left; } }
  @media print {
    :root { --page:#fff; --surface:#fff; }
    body { background:#fff; }
    .card,.rec,.tile { box-shadow:none; break-inside:avoid; }
    section,.rec,.hero { break-inside:avoid; }
    .gauge-val,.gauge-dot { animation:none; opacity:1; }
    * { -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  }
"""

_PORTFOLIO_CSS = r"""
  :root {
    --page:#eef0f4; --surface:#ffffff; --surface-2:#f6f7fa; --ink:#111722; --ink-2:#465063; --muted:#78849a;
    --line:rgba(17,23,34,0.10); --line-strong:rgba(17,23,34,0.16);
    --accent:#2563cf; --accent-ink:#1c50ad; --accent-wash:rgba(37,99,207,0.09);
    --risk:#d0392f; --risk-wash:rgba(208,57,47,0.10); --emerging:#c47d16; --emerging-wash:rgba(196,125,22,0.10);
    --strong:#1a8f52; --strong-wash:rgba(26,143,82,0.10); --track:rgba(120,132,154,0.18);
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    --mono: ui-monospace, "SF Mono", "Cascadia Mono", "Segoe UI Mono", "Roboto Mono", Menlo, Consolas, monospace;
    --shadow-sm:0 1px 2px rgba(17,23,34,0.05),0 1px 3px rgba(17,23,34,0.06);
    --shadow-md:0 6px 20px rgba(17,23,34,0.10); --radius:14px;
  }
  @media (prefers-color-scheme: dark) {
    :root { --page:#0c0f14; --surface:#161b23; --surface-2:#1c222c; --ink:#f4f6fa; --ink-2:#b6c0d0; --muted:#8592a6;
      --line:rgba(255,255,255,0.10); --line-strong:rgba(255,255,255,0.16);
      --accent:#4b90ef; --accent-ink:#7fb0f5; --accent-wash:rgba(75,144,239,0.14);
      --risk:#e56a5f; --risk-wash:rgba(229,106,95,0.14); --emerging:#e0a63c; --emerging-wash:rgba(224,166,60,0.14);
      --strong:#34b56d; --strong-wash:rgba(52,181,109,0.14); --track:rgba(255,255,255,0.10);
      --shadow-sm:0 1px 2px rgba(0,0,0,0.4); --shadow-md:0 6px 22px rgba(0,0,0,0.5); }
  }
  :root[data-theme="light"] { --page:#eef0f4; --surface:#ffffff; --surface-2:#f6f7fa; --ink:#111722; --ink-2:#465063; --muted:#78849a;
    --line:rgba(17,23,34,0.10); --line-strong:rgba(17,23,34,0.16); --accent:#2563cf; --accent-ink:#1c50ad; --accent-wash:rgba(37,99,207,0.09);
    --risk:#d0392f; --risk-wash:rgba(208,57,47,0.10); --emerging:#c47d16; --emerging-wash:rgba(196,125,22,0.10);
    --strong:#1a8f52; --strong-wash:rgba(26,143,82,0.10); --track:rgba(120,132,154,0.18);
    --shadow-sm:0 1px 2px rgba(17,23,34,0.05),0 1px 3px rgba(17,23,34,0.06); --shadow-md:0 6px 20px rgba(17,23,34,0.10); }
  :root[data-theme="dark"] { --page:#0c0f14; --surface:#161b23; --surface-2:#1c222c; --ink:#f4f6fa; --ink-2:#b6c0d0; --muted:#8592a6;
    --line:rgba(255,255,255,0.10); --line-strong:rgba(255,255,255,0.16); --accent:#4b90ef; --accent-ink:#7fb0f5; --accent-wash:rgba(75,144,239,0.14);
    --risk:#e56a5f; --risk-wash:rgba(229,106,95,0.14); --emerging:#e0a63c; --emerging-wash:rgba(224,166,60,0.14);
    --strong:#34b56d; --strong-wash:rgba(52,181,109,0.14); --track:rgba(255,255,255,0.10);
    --shadow-sm:0 1px 2px rgba(0,0,0,0.4); --shadow-md:0 6px 22px rgba(0,0,0,0.5); }
  * { box-sizing:border-box; }
  body { margin:0; font-family:var(--sans); background:var(--page); color:var(--ink); line-height:1.5; -webkit-font-smoothing:antialiased; }
  h1,h2,h3 { margin:0; text-wrap:balance; }
  a { color:inherit; text-decoration:none; }
  .wrap { max-width:1040px; margin:0 auto; padding:0 20px 72px; }
  .eyebrow { font-size:11px; font-weight:700; letter-spacing:0.14em; text-transform:uppercase; color:var(--muted); }
  .topbar { display:flex; align-items:center; justify-content:space-between; gap:16px; padding:20px 0 18px; flex-wrap:wrap; }
  .brand { display:flex; align-items:center; gap:11px; }
  .brand .glyph { width:30px; height:30px; display:block; color:var(--accent); }
  .brand .wordmark { font-weight:800; letter-spacing:0.02em; font-size:15px; }
  .brand .wordmark b { color:var(--accent); }
  .brand .sub { display:block; font-size:10.5px; letter-spacing:0.16em; text-transform:uppercase; color:var(--muted); font-weight:600; }
  .head { border-top:2px solid var(--ink); padding-top:22px; margin-bottom:24px; }
  .head h1 { font-size:clamp(26px,5vw,38px); font-weight:800; letter-spacing:-0.02em; }
  .head p { margin:8px 0 0; color:var(--ink-2); font-size:14.5px; max-width:60ch; }
  .agg { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:30px; }
  .stat { background:var(--surface); border:1px solid var(--line); border-radius:var(--radius); box-shadow:var(--shadow-sm);
    padding:16px 17px; display:flex; flex-direction:column; gap:3px; }
  .stat .eyebrow { font-size:10.5px; }
  .stat .val { font-size:34px; font-weight:800; letter-spacing:-0.02em; line-height:1.05; margin-top:3px; }
  .stat .val small { font-size:16px; font-weight:700; color:var(--muted); }
  .stat .sub { font-size:12px; color:var(--ink-2); }
  .stat.flag .val { color:var(--risk); }
  .stat .band-dot { display:inline-block; width:9px; height:9px; border-radius:3px; margin-right:6px; vertical-align:middle; }
  .list-head { display:flex; align-items:baseline; justify-content:space-between; gap:12px; margin-bottom:12px; flex-wrap:wrap; }
  .list-head h2 { font-size:16px; font-weight:750; letter-spacing:-0.01em; }
  .list-head .hint { font-size:12px; color:var(--muted); display:inline-flex; align-items:center; gap:6px; }
  .list-head .hint svg { width:14px; height:14px; }
  .col-head { display:grid; grid-template-columns:6px 96px 1fr 150px 190px 22px; gap:16px; align-items:center;
    padding:0 18px 8px; font-size:10.5px; font-weight:700; letter-spacing:0.05em; text-transform:uppercase; color:var(--muted); }
  .col-head span:nth-child(2) { text-align:center; }
  .rows { display:flex; flex-direction:column; gap:12px; }
  .row { display:grid; grid-template-columns:6px 96px 1fr 150px 190px 22px; gap:16px; align-items:center;
    background:var(--surface); border:1px solid var(--line); border-radius:var(--radius); box-shadow:var(--shadow-sm);
    padding:16px 18px 16px 0; overflow:hidden; transition:box-shadow .18s ease, transform .18s ease, border-color .18s ease; }
  .row:hover { box-shadow:var(--shadow-md); transform:translateY(-2px); border-color:var(--line-strong); }
  .row:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
  .stripe { width:6px; align-self:stretch; margin:-16px 0; }
  .row.b-risk .stripe { background:var(--risk); }
  .row.b-emerging .stripe { background:var(--emerging); }
  .row.b-strong .stripe { background:var(--strong); }
  .score-block { display:flex; flex-direction:column; align-items:center; gap:5px; }
  .score-ring { position:relative; width:66px; height:66px; }
  .score-ring svg { width:66px; height:66px; transform:rotate(-90deg); display:block; }
  .score-ring .rtrack { fill:none; stroke:var(--track); stroke-width:6; }
  .score-ring .rval { fill:none; stroke-width:6; stroke-linecap:round; }
  .score-ring .num { position:absolute; inset:0; display:flex; align-items:center; justify-content:center; font-size:20px; font-weight:800; letter-spacing:-0.02em; }
  .band-tag { font-size:10px; font-weight:800; letter-spacing:0.04em; text-transform:uppercase; padding:2px 8px; border-radius:999px; display:inline-flex; align-items:center; gap:4px; }
  .band-tag svg { width:11px; height:11px; }
  .b-risk .band-tag { color:var(--risk); background:var(--risk-wash); }
  .b-emerging .band-tag { color:var(--emerging); background:var(--emerging-wash); }
  .b-strong .band-tag { color:var(--strong); background:var(--strong-wash); }
  .b-risk .rval { stroke:var(--risk); }
  .b-emerging .rval { stroke:var(--emerging); }
  .b-strong .rval { stroke:var(--strong); }
  .who .name { font-size:17px; font-weight:750; letter-spacing:-0.01em; }
  .who .meta { margin-top:3px; font-size:12.5px; color:var(--muted); display:flex; gap:7px; flex-wrap:wrap; align-items:center; }
  .who .meta .sepdot { width:3px; height:3px; border-radius:50%; background:var(--muted); opacity:.6; }
  .who .meta .vert { font-weight:700; color:var(--ink-2); text-transform:uppercase; letter-spacing:0.05em; font-size:11px;
    background:var(--surface-2); border:1px solid var(--line); padding:2px 7px; border-radius:5px; }
  .metric .eyebrow { font-size:10px; margin-bottom:5px; }
  .metric .pv { font-size:14px; font-weight:750; font-variant-numeric:tabular-nums; }
  .metric .mbar { height:6px; border-radius:999px; background:var(--track); overflow:hidden; margin-top:6px; }
  .metric .mbar > i { display:block; height:100%; border-radius:999px; background:var(--accent); }
  .comp .eyebrow { font-size:10px; margin-bottom:5px; }
  .comp .cv { font-size:13.5px; font-weight:650; color:var(--ink); }
  .comp .cnote { font-size:11.5px; color:var(--muted); margin-top:2px; }
  .chev { color:var(--muted); display:flex; justify-content:flex-end; }
  .chev svg { width:18px; height:18px; }
  .row:hover .chev { color:var(--accent); }
  .foot { margin-top:36px; padding-top:20px; border-top:1px solid var(--line); font-size:12px; color:var(--muted); font-family:var(--mono); }
  @media (max-width:880px) {
    .agg { grid-template-columns:1fr 1fr; }
    .col-head { display:none; }
    .row { grid-template-columns:6px 84px 1fr 22px;
      grid-template-areas:"stripe score who chev" "stripe score metric chev" "stripe score comp chev"; row-gap:12px; }
    .stripe { grid-area:stripe; } .score-block { grid-area:score; align-self:center; } .who { grid-area:who; }
    .metric { grid-area:metric; } .comp { grid-area:comp; } .chev { grid-area:chev; align-self:center; }
  }
  @media (max-width:560px) {
    .agg { grid-template-columns:1fr 1fr; }
    .row { grid-template-columns:6px 1fr auto;
      grid-template-areas:"stripe who chev" "stripe score score" "stripe metric comp"; align-items:start; }
    .stripe { grid-area:stripe; } .who { grid-area:who; align-self:center; } .chev { grid-area:chev; align-self:center; }
    .score-block { grid-area:score; flex-direction:row; align-items:center; gap:12px; justify-self:start; }
    .metric { grid-area:metric; } .comp { grid-area:comp; }
  }
  @media print {
    :root { --page:#fff; --surface:#fff; }
    body { background:#fff; }
    .row,.stat { box-shadow:none; break-inside:avoid; }
    * { -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  }
"""
