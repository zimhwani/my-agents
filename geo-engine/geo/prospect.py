"""Automated prospecting — turn a list of target businesses into personalized
outreach.

For each prospect: run a visibility scan, measure how invisible they are to AI
assistants, and draft a short, specific cold-outreach email built around that
finding (the free-audit hook). Claude-drafted when a key is set, editable
template otherwise. Nothing is sent — a human reviews and sends.

Input: a CSV with headers
    business_name,vertical,location,services,competitors
where `services` and `competitors` are optional `;`-separated lists.

⚠️  Outreach compliance is the operator's responsibility. Only contact
businesses you have a lawful basis to email, honor opt-outs, and follow
CAN-SPAM / CASL / GDPR. Every draft includes a review banner + unsubscribe
placeholder you must complete before sending.
"""

from __future__ import annotations

import csv
import os
import re
from typing import List

from .analyze import analyze
from .config import ClientProfile
from .fixes import Copywriter
from .providers import build_providers
from .report import render_html
from .scan import run_scan


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "prospect"


def load_prospects(path: str) -> List[ClientProfile]:
    out: List[ClientProfile] = []
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            if not row.get("business_name"):
                continue
            out.append(ClientProfile(
                business_name=row["business_name"].strip(),
                vertical=(row.get("vertical") or "generic").strip(),
                location=(row.get("location") or "").strip(),
                services=[s.strip() for s in (row.get("services") or "").split(";") if s.strip()],
                competitors=[c.strip() for c in (row.get("competitors") or "").split(";") if c.strip()],
                website=(row.get("website") or "").strip(),
            ))
    return out


_COMPLIANCE = (
    "\n\n---\n"
    "[REVIEW before sending] Sent by [Your Name], [Company], [Physical Address].\n"
    "You're receiving this because [lawful basis]. Reply STOP or click "
    "[unsubscribe link] to opt out.\n"
)


def _draft_email(profile: ClientProfile, analysis: dict, writer: Copywriter):
    presence = analysis["client"]["presence_rate"]
    competitors = [b for b in analysis["brands"] if not b["is_client"]]
    top = max(competitors, key=lambda r: r["presence_rate"])["brand"] if competitors else ""
    label = profile.vertical_label
    loc = profile.location

    if presence == 0:
        finding = (f"When I asked AI assistants like ChatGPT for the best {label} "
                   f"in {loc}, {profile.business_name} didn't come up at all.")
    else:
        finding = (f"When I asked AI assistants like ChatGPT for the best {label} "
                   f"in {loc}, {profile.business_name} only came up about "
                   f"{presence:.0%} of the time.")
    if top:
        finding += f" Competitors like {top} showed up far more often."

    subject = f"{profile.business_name} vs. AI search in {loc}"
    fallback = (
        f"Subject: {subject}\n\n"
        f"Hi {profile.business_name} team,\n\n"
        f"{finding}\n\n"
        "More people are asking AI assistants — not Google — for "
        "recommendations, so this quietly costs you customers. I put together a "
        "free, no-obligation visibility audit showing exactly where you stand and "
        "what to fix.\n\n"
        "Want me to send it over?\n\n"
        "[Your Name]"
    )
    system = (
        "You are a local-marketing consultant writing a SHORT (under 120 words), "
        "friendly, non-spammy cold email to a business owner. Personalize around "
        "the specific finding. Concrete, low-pressure, one clear CTA: a free "
        "visibility audit. No hype, no false claims. Start with 'Subject:' then the body."
    )
    prompt = (
        f"Business: {profile.business_name}, a {label} in {loc}.\n"
        f"Finding: {finding}\n"
        "Write the email (subject + body)."
    )
    body, source = writer.draft(system, prompt, fallback)
    return subject, body + _COMPLIANCE, source, presence, top


def run_prospecting(csv_path: str, out_dir: str, provider_names: List[str],
                    max_prompts: int = 8, model: str | None = None,
                    use_claude: bool = True) -> List[dict]:
    prospects = load_prospects(csv_path)
    if not prospects:
        raise ValueError(f"No prospects found in {csv_path}")
    os.makedirs(out_dir, exist_ok=True)
    writer = Copywriter(model=model, use_claude=use_claude)
    rows: List[dict] = []

    for p in prospects:
        providers = build_providers(p, provider_names, model=model)
        scan = run_scan(p, providers, max_prompts=max_prompts)
        result = analyze(scan)
        result["generated_at"] = scan.get("generated_at", "")
        subject, email, source, presence, top = _draft_email(p, result, writer)

        sub = os.path.join(out_dir, _slug(p.business_name))
        os.makedirs(sub, exist_ok=True)
        with open(os.path.join(sub, "email.md"), "w", encoding="utf-8") as fh:
            fh.write(email)
        # Attach a full report only when we know the competitor set.
        if p.competitors:
            with open(os.path.join(sub, "report.html"), "w", encoding="utf-8") as fh:
                fh.write(render_html(result, scan["client"]))

        hot = presence < 0.15
        rows.append({
            "name": p.business_name, "location": p.location,
            "presence": presence, "score": result["visibility_score"],
            "top_competitor": top, "hot": hot, "source": source,
            "dir": _slug(p.business_name),
        })
        flag = "HOT LEAD" if hot else "lead"
        print(f"  [{flag}] {p.business_name}: seen in {presence:.0%} "
              f"(score {result['visibility_score']}) → {sub}/email.md")

    _write_index(out_dir, rows)
    return rows


def _write_index(out_dir: str, rows: List[dict]) -> None:
    lines = ["# Prospecting run", ""]
    lines.append("> Drafts only. Verify each finding and complete the compliance "
                 "footer (sender, address, lawful basis, unsubscribe) before sending. "
                 "Follow CAN-SPAM / CASL / GDPR.")
    lines.append("")
    lines.append(f"{sum(1 for r in rows if r['hot'])} hot lead(s) of {len(rows)} prospects "
                 "(hot = named in <15% of AI answers).")
    lines.append("")
    lines.append("| Prospect | Location | Seen in | Score | Top competitor | Draft |")
    lines.append("|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda x: x["presence"]):
        flag = "🔥 " if r["hot"] else ""
        lines.append(
            f"| {flag}{r['name']} | {r['location']} | {r['presence']:.0%} | "
            f"{r['score']}/100 | {r['top_competitor'] or '—'} | "
            f"`{r['dir']}/email.md` ({r['source']}) |"
        )
    with open(os.path.join(out_dir, "INDEX.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"\nProspecting index: {out_dir}/INDEX.md")
