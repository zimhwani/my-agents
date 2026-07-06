"""Render an analysis into a client-ready HTML report and a Markdown summary.

The HTML is self-contained (inline CSS, no external assets), print-friendly,
and doubles as the cold-outreach lead magnet: "here's where you're invisible
when buyers ask AI about your category."
"""

from __future__ import annotations

import html
from typing import List

ACCENT = "#c2683b"       # client bar / highlight (warm terracotta)
NEUTRAL = "#9aa4b2"      # competitor bars
INK = "#1c2430"
MUTED = "#5b6675"


def _score_band(score: int) -> tuple[str, str]:
    if score >= 60:
        return "Strong", "#2f8f5b"
    if score >= 30:
        return "Emerging", ACCENT
    return "At risk", "#c0392b"


def _bar(pct: float, is_client: bool) -> str:
    width = max(1.5, pct * 100)
    color = ACCENT if is_client else NEUTRAL
    return (
        f'<div style="background:#eef1f5;border-radius:4px;height:14px;'
        f'width:100%;overflow:hidden">'
        f'<div style="width:{width:.1f}%;height:100%;background:{color}"></div></div>'
    )


def render_html(analysis: dict, client: dict) -> str:
    name = html.escape(analysis["client_name"])
    loc = html.escape(client.get("location", ""))
    label = html.escape(client.get("vertical", ""))
    score = analysis["visibility_score"]
    band, band_color = _score_band(score)
    total = analysis["total_queries"]

    # Share-of-voice bars (client + competitors, already sorted by presence).
    rows = []
    for r in analysis["brands"]:
        brand = html.escape(r["brand"])
        sov = r["share_of_voice"]
        pres = r["presence_rate"]
        weight = "700" if r["is_client"] else "500"
        tag = ' <span style="color:%s;font-size:12px">(you)</span>' % ACCENT if r["is_client"] else ""
        rows.append(
            f"""<tr>
  <td style="padding:8px 12px 8px 0;font-weight:{weight};color:{INK};white-space:nowrap">{brand}{tag}</td>
  <td style="padding:8px 12px;width:55%">{_bar(sov, r['is_client'])}</td>
  <td style="padding:8px 0;text-align:right;color:{MUTED};font-variant-numeric:tabular-nums">{sov:.0%} SoV · seen in {pres:.0%}</td>
</tr>"""
        )
    sov_table = "\n".join(rows)

    # Recommendations.
    rec_cards = []
    for rec in analysis["recommendations"]:
        rec_cards.append(
            f"""<div style="border:1px solid #e6e9ef;border-left:4px solid {ACCENT};
      border-radius:8px;padding:16px 18px;margin:0 0 12px">
  <div style="font-size:12px;font-weight:700;letter-spacing:.04em;color:{ACCENT}">{html.escape(rec['priority'])}</div>
  <div style="font-size:17px;font-weight:700;color:{INK};margin:2px 0 6px">{html.escape(rec['title'])}</div>
  <div style="color:{MUTED};margin-bottom:8px">{html.escape(rec['why'])}</div>
  <div style="color:{INK}"><strong>Do this:</strong> {html.escape(rec['action'])}</div>
</div>"""
        )
    recs_html = "\n".join(rec_cards)

    # Prompt-by-prompt evidence table.
    ev_rows = []
    for p in analysis["per_prompt"]:
        mark = "✓" if p["client_present"] else "—"
        mark_color = "#2f8f5b" if p["client_present"] else "#c0392b"
        ranked = ", ".join(html.escape(b) for b in p["ranked"]) or "<em>no named providers</em>"
        ev_rows.append(
            f"""<tr>
  <td style="padding:8px 12px 8px 0;color:{INK}">{html.escape(p['prompt'])}</td>
  <td style="padding:8px 12px;color:{MUTED}">{ranked}</td>
  <td style="padding:8px 0;text-align:center;color:{mark_color};font-weight:700">{mark}</td>
</tr>"""
        )
    evidence = "\n".join(ev_rows)

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AI Visibility Report — {name}</title>
</head>
<body style="margin:0;background:#f6f7f9;color:{INK};
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
  line-height:1.5;-webkit-font-smoothing:antialiased">
<div style="max-width:820px;margin:0 auto;padding:40px 24px">

  <div style="color:{MUTED};font-size:13px;letter-spacing:.08em;text-transform:uppercase">AI Answer Visibility Report</div>
  <h1 style="font-size:30px;margin:6px 0 2px;color:{INK}">{name}</h1>
  <div style="color:{MUTED};margin-bottom:28px">{label} · {loc} · based on {total} buyer questions across AI answer engines</div>

  <div style="display:flex;gap:20px;flex-wrap:wrap;background:#fff;border:1px solid #e6e9ef;
    border-radius:12px;padding:24px;margin-bottom:28px">
    <div style="flex:0 0 auto;text-align:center;min-width:150px">
      <div style="font-size:56px;font-weight:800;color:{band_color};line-height:1">{score}</div>
      <div style="color:{MUTED};font-size:13px">Visibility score / 100</div>
      <div style="display:inline-block;margin-top:6px;padding:2px 10px;border-radius:999px;
        background:{band_color}22;color:{band_color};font-weight:700;font-size:13px">{band}</div>
    </div>
    <div style="flex:1;min-width:220px;border-left:1px solid #eef1f5;padding-left:20px">
      <p style="margin:0;color:{INK}">
        When buyers ask AI engines about {label.lower() or 'this category'} in {loc or 'your area'},
        <strong>{name}</strong> is named in <strong>{analysis['client']['presence_rate']:.0%}</strong>
        of answers and is the <strong>first</strong> recommendation in
        <strong>{analysis['client']['first_rate']:.0%}</strong>.
      </p>
      <p style="margin:10px 0 0;color:{MUTED};font-size:14px">
        This is the new front page. The fixes below move you toward being the answer.
      </p>
    </div>
  </div>

  <h2 style="font-size:20px;color:{INK};margin:0 0 4px">Share of voice vs. competitors</h2>
  <p style="color:{MUTED};margin:0 0 14px;font-size:14px">How often each provider is named across the same buyer questions.</p>
  <table style="width:100%;border-collapse:collapse;margin-bottom:32px;font-size:15px">{sov_table}</table>

  <h2 style="font-size:20px;color:{INK};margin:0 0 14px">Recommended fixes</h2>
  {recs_html}

  <h2 style="font-size:20px;color:{INK};margin:32px 0 14px">The evidence</h2>
  <p style="color:{MUTED};margin:0 0 12px;font-size:14px">Every question we asked, who the AI named, and whether you made the list.</p>
  <table style="width:100%;border-collapse:collapse;font-size:14px">
    <tr style="text-align:left;color:{MUTED};font-size:12px;text-transform:uppercase;letter-spacing:.04em">
      <th style="padding:0 12px 8px 0;font-weight:600">Buyer question</th>
      <th style="padding:0 12px 8px;font-weight:600">AI named</th>
      <th style="padding:0 0 8px;font-weight:600;text-align:center">You?</th>
    </tr>
    {evidence}
  </table>

  <div style="margin-top:40px;padding-top:16px;border-top:1px solid #e6e9ef;color:{MUTED};font-size:12px">
    Generated by the GEO engine · {html.escape(analysis.get('generated_at',''))}.
    AI answers are non-deterministic; treat this as a directional visibility signal, not a revenue guarantee.
  </div>

</div></body></html>"""


def render_portfolio_html(summaries: List[dict]) -> str:
    """Operator dashboard: every client, their score, and a link to the report."""
    rows = []
    for s in sorted(summaries, key=lambda x: x["score"]):
        band, color = _score_band(s["score"])
        rows.append(
            f"""<tr style="border-top:1px solid #eef1f5">
  <td style="padding:12px 12px 12px 0"><a href="{html.escape(s['report'])}"
      style="color:{INK};font-weight:600;text-decoration:none">{html.escape(s['name'])}</a>
    <div style="color:{MUTED};font-size:13px">{html.escape(s['vertical'])} · {html.escape(s['location'])}</div></td>
  <td style="padding:12px;text-align:center"><span style="display:inline-block;min-width:38px;
      padding:3px 8px;border-radius:6px;background:{color}22;color:{color};font-weight:700">{s['score']}</span></td>
  <td style="padding:12px;color:{MUTED};text-align:center">{s['presence_rate']:.0%}</td>
  <td style="padding:12px;color:{MUTED}">{html.escape(s['top_competitor'] or '—')}</td>
</tr>"""
        )
    body = "\n".join(rows)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GEO Portfolio</title></head>
<body style="margin:0;background:#f6f7f9;color:{INK};
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
<div style="max-width:820px;margin:0 auto;padding:40px 24px">
  <div style="color:{MUTED};font-size:13px;letter-spacing:.08em;text-transform:uppercase">GEO Engine</div>
  <h1 style="margin:6px 0 24px;color:{INK}">Client portfolio · {len(summaries)} accounts</h1>
  <table style="width:100%;border-collapse:collapse;font-size:15px">
    <tr style="text-align:left;color:{MUTED};font-size:12px;text-transform:uppercase;letter-spacing:.04em">
      <th style="padding:0 12px 8px 0;font-weight:600">Client</th>
      <th style="padding:0 12px 8px;font-weight:600;text-align:center">Score</th>
      <th style="padding:0 12px 8px;font-weight:600;text-align:center">Seen in</th>
      <th style="padding:0 0 8px;font-weight:600">Top competitor</th>
    </tr>
    {body}
  </table>
  <p style="color:{MUTED};font-size:12px;margin-top:24px">Sorted by score — lowest first (most upside / most at risk).</p>
</div></body></html>"""


def render_markdown(analysis: dict, client: dict) -> str:
    name = analysis["client_name"]
    lines: List[str] = []
    band, _ = _score_band(analysis["visibility_score"])
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
