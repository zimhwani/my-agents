"""Weekly autopilot: scan the whole portfolio and email an operator digest.

Designed for a scheduled runner (GitHub Actions cron, or any host cron):
scan every client, refresh the reports, and send a short digest highlighting
at-risk accounts. Email is optional and safe — without SMTP config it prints.
"""

from __future__ import annotations

import datetime
from typing import List

from .batch import run_batch
from .notify import send_email
from .report import score_band


def _digest_text(summaries: List[dict]) -> tuple[str, str]:
    n = len(summaries)
    avg = round(sum(s["score"] for s in summaries) / n) if n else 0
    at_risk = [s for s in summaries if s["score"] < 30]
    today = datetime.date.today().isoformat()

    lines = [f"GEO weekly digest — {today}", ""]
    lines.append(f"{n} accounts · average score {avg}/100 · {len(at_risk)} at risk")
    lines.append("")
    lines.append("Accounts (worst first):")
    for s in sorted(summaries, key=lambda x: x["score"]):
        _, band = score_band(s["score"])
        lines.append(
            f"  {s['score']:>3}/100  [{band:<9}]  {s['name']} "
            f"({s['vertical']}, {s['location']}) — seen in {s['presence_rate']:.0%}"
        )
    if at_risk:
        lines.append("")
        lines.append("Priority this week:")
        for s in at_risk:
            lines.append(f"  • {s['name']} — top competitor {s.get('top_competitor') or 'n/a'}")
    text = "\n".join(lines)

    rows = "".join(
        f'<tr><td style="padding:6px 12px 6px 0;font-weight:600">{s["name"]}</td>'
        f'<td style="padding:6px 12px;color:#556">{s["vertical"]}, {s["location"]}</td>'
        f'<td style="padding:6px 0;text-align:right;font-weight:700;'
        f'color:{"#c0392b" if s["score"] < 30 else "#c47d16" if s["score"] < 60 else "#1a8f52"}">'
        f'{s["score"]}/100</td></tr>'
        for s in sorted(summaries, key=lambda x: x["score"])
    )
    html = (
        f'<div style="font-family:system-ui,sans-serif;max-width:560px">'
        f'<h2 style="margin:0 0 4px">GEO weekly digest</h2>'
        f'<p style="color:#667;margin:0 0 16px">{today} · {n} accounts · avg {avg}/100 · '
        f'{len(at_risk)} at risk</p>'
        f'<table style="width:100%;border-collapse:collapse;font-size:14px">{rows}</table></div>'
    )
    return text, html


def run_digest(clients_dir: str, out_dir: str, provider_names: List[str],
               email_to: str | None = None, max_prompts: int = 12,
               model: str | None = None, dry_run: bool = False) -> None:
    summaries = run_batch(clients_dir, out_dir, provider_names,
                          max_prompts=max_prompts, model=model)
    text, html = _digest_text(summaries)
    print("\n" + text)
    if email_to:
        subject = f"GEO weekly digest — {datetime.date.today().isoformat()}"
        send_email(email_to, subject, text, html_body=html, dry_run=dry_run)
