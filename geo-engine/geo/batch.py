"""Run the engine across a folder of client profiles — the ops autopilot layer.

Scans every client, writes each one's report into its own subfolder, and
builds a portfolio index so one operator can watch many accounts at a glance.
"""

from __future__ import annotations

import glob
import json
import os
import re
from typing import List

from .analyze import analyze
from .config import load_profile
from .providers import build_providers
from .report import render_html, render_markdown, render_portfolio_html
from .scan import run_scan


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "client"


def run_batch(clients_dir: str, out_dir: str, provider_names: List[str],
              max_prompts: int = 12, model: str | None = None) -> List[dict]:
    paths = sorted(glob.glob(os.path.join(clients_dir, "*.json")))
    if not paths:
        raise ValueError(f"No client profiles (*.json) found in {clients_dir}")

    os.makedirs(out_dir, exist_ok=True)
    summaries: List[dict] = []

    for path in paths:
        profile = load_profile(path)
        providers = build_providers(profile, provider_names, model=model)
        print(f"• {profile.business_name} ({os.path.basename(path)})")
        scan = run_scan(profile, providers, max_prompts=max_prompts)
        result = analyze(scan)
        result["generated_at"] = scan.get("generated_at", "")

        sub = os.path.join(out_dir, _slug(profile.business_name))
        os.makedirs(sub, exist_ok=True)
        with open(os.path.join(sub, "scan.json"), "w", encoding="utf-8") as fh:
            json.dump(scan, fh, indent=2)
        with open(os.path.join(sub, "report.html"), "w", encoding="utf-8") as fh:
            fh.write(render_html(result, scan["client"]))
        with open(os.path.join(sub, "report.md"), "w", encoding="utf-8") as fh:
            fh.write(render_markdown(result, scan["client"]))

        competitors = [b for b in result["brands"] if not b["is_client"]]
        top = max(competitors, key=lambda r: r["presence_rate"])["brand"] if competitors else ""
        summaries.append(
            {
                "name": profile.business_name,
                "vertical": profile.vertical_label,
                "location": profile.location,
                "score": result["visibility_score"],
                "presence_rate": result["client"]["presence_rate"],
                "top_competitor": top,
                "report": os.path.join(_slug(profile.business_name), "report.html"),
            }
        )
        print(f"    score {result['visibility_score']}/100 → {sub}/report.html")

    with open(os.path.join(out_dir, "index.html"), "w", encoding="utf-8") as fh:
        fh.write(render_portfolio_html(summaries))
    print(f"\nPortfolio index: {out_dir}/index.html ({len(summaries)} clients)")
    return summaries
