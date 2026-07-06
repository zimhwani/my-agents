"""Turn a raw scan into visibility metrics and prioritised recommendations."""

from __future__ import annotations

import re
from typing import List, Optional


def _first_index(text: str, brand: str) -> int:
    """Character index of the first whole-word mention of ``brand``, or -1.

    Tolerates punctuation inside brand names (e.g. 'Milk + Honey') by using
    non-alphanumeric boundaries rather than \\b.
    """
    pattern = re.compile(
        r"(?<![A-Za-z0-9])" + re.escape(brand) + r"(?![A-Za-z0-9])", re.IGNORECASE
    )
    m = pattern.search(text or "")
    return m.start() if m else -1


def _ranked_brands(answer: str, brands: List[str]) -> List[str]:
    """Brands mentioned in ``answer``, ordered by first appearance."""
    hits = [(idx, b) for b in brands if (idx := _first_index(answer, b)) >= 0]
    hits.sort(key=lambda t: t[0])
    return [b for _, b in hits]


def analyze(scan: dict) -> dict:
    client = scan["client"]
    client_name = client["business_name"]
    competitors = list(client.get("competitors", []))
    brands = [client_name] + competitors
    results = scan["results"]
    total = len(results) or 1

    # Per-brand tallies.
    stats = {
        b: {"mentions": 0, "first_mentions": 0, "rank_sum": 0} for b in brands
    }
    per_prompt = []

    for rec in results:
        ranked = _ranked_brands(rec["answer"], brands)
        for pos, b in enumerate(ranked):
            stats[b]["mentions"] += 1
            stats[b]["rank_sum"] += pos + 1  # 1-indexed rank
            if pos == 0:
                stats[b]["first_mentions"] += 1
        per_prompt.append(
            {
                "prompt": rec["prompt"],
                "provider": rec["provider"],
                "service": rec["service"],
                "ranked": ranked,
                "client_present": client_name in ranked,
            }
        )

    total_mentions = sum(s["mentions"] for s in stats.values()) or 1
    brand_rows = []
    for b in brands:
        s = stats[b]
        m = s["mentions"]
        brand_rows.append(
            {
                "brand": b,
                "is_client": b == client_name,
                "mentions": m,
                "presence_rate": m / total,
                "first_mentions": s["first_mentions"],
                "first_rate": s["first_mentions"] / total,
                "avg_rank": (s["rank_sum"] / m) if m else None,
                "share_of_voice": m / total_mentions,
            }
        )
    # Rank competitors by presence for the report; client tracked separately.
    brand_rows.sort(key=lambda r: (r["mentions"], r["first_mentions"]), reverse=True)

    client_row = next(r for r in brand_rows if r["is_client"])
    # Visibility score (0-100): mostly presence, partly whether the client is
    # the *first* name the AI reaches for.
    visibility = round(
        100 * (0.6 * client_row["presence_rate"] + 0.4 * client_row["first_rate"])
    )

    # Services where the client never surfaces — concrete content gaps.
    missing_services = _missing_services(per_prompt, client_name)

    return {
        "client_name": client_name,
        "total_queries": total,
        "visibility_score": visibility,
        "client": client_row,
        "brands": brand_rows,
        "per_prompt": per_prompt,
        "missing_services": missing_services,
        "recommendations": _recommend(client_row, brand_rows, missing_services, client),
    }


def _missing_services(per_prompt, client_name) -> List[str]:
    seen, present = set(), set()
    for row in per_prompt:
        svc = row["service"]
        if not svc:
            continue
        seen.add(svc)
        if row["client_present"]:
            present.add(svc)
    return sorted(seen - present)


def _recommend(client_row, brand_rows, missing_services, client) -> List[dict]:
    recs: List[dict] = []
    presence = client_row["presence_rate"]
    name = client_row["brand"]

    # 1. Foundational visibility.
    if presence < 0.3:
        recs.append(
            {
                "priority": "P0",
                "title": "Establish baseline AI-answer visibility",
                "why": f"{name} appears in only {presence:.0%} of buyer queries — "
                "below the threshold where AI engines treat you as a default option.",
                "action": "Publish citation-worthy content (service pages, an "
                "expert FAQ, and 'best of' comparison pages) and add LocalBusiness "
                "+ FAQPage schema so engines can extract and cite you.",
            }
        )
    elif client_row["first_rate"] < 0.2:
        recs.append(
            {
                "priority": "P1",
                "title": "Move from 'also mentioned' to top recommendation",
                "why": f"{name} shows up but is rarely the first name cited "
                f"(first in only {client_row['first_rate']:.0%} of answers).",
                "action": "Build authority signals: review-cadence content, "
                "third-party citations, and specific outcome/pricing pages the "
                "models can quote.",
            }
        )

    # 2. Dominant competitor.
    competitors = [r for r in brand_rows if not r["is_client"]]
    if competitors:
        top = max(competitors, key=lambda r: r["presence_rate"])
        if top["presence_rate"] >= presence + 0.3:
            recs.append(
                {
                    "priority": "P1",
                    "title": f"Close the gap with {top['brand']}",
                    "why": f"{top['brand']} appears in {top['presence_rate']:.0%} of "
                    f"answers vs {presence:.0%} for {name}.",
                    "action": f"Publish an honest '{name} vs {top['brand']}' "
                    "comparison and alternatives page targeting the queries they win.",
                }
            )

    # 3. Service-level gaps.
    if missing_services:
        shown = ", ".join(missing_services[:4])
        recs.append(
            {
                "priority": "P2",
                "title": "Cover services where you're invisible",
                "why": f"{name} never surfaces for: {shown}.",
                "action": "Ship a dedicated, location-targeted page per service "
                "with schema and genuine detail (not spun filler).",
            }
        )

    # 4. Always-on structured data hygiene.
    recs.append(
        {
            "priority": "P2",
            "title": "Lock in structured data + consistent NAP",
            "why": "AI engines lean on schema and consistent Name/Address/Phone "
            "to trust and cite a business.",
            "action": "Validate LocalBusiness schema"
            + (f" on {client.get('website')}" if client.get("website") else "")
            + ", keep NAP identical across directories, and maintain a steady "
            "review cadence.",
        }
    )
    order = {"P0": 0, "P1": 1, "P2": 2}
    recs.sort(key=lambda r: order.get(r["priority"], 9))
    return recs
