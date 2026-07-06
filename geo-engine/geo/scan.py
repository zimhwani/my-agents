"""Run the discovery prompts across providers and record the raw answers."""

from __future__ import annotations

import datetime as _dt
from dataclasses import asdict
from typing import List

from .config import ClientProfile
from .prompts import build_prompts


def run_scan(profile: ClientProfile, providers, max_prompts: int = 12) -> dict:
    """Query every provider with every prompt; return a serialisable scan.

    The returned dict is the durable artifact — persist it and feed it to the
    analyzer/report so a scan and its report are reproducible.
    """
    prompt_records = build_prompts(profile, max_prompts=max_prompts)
    results: List[dict] = []

    for pr in prompt_records:
        for provider in providers:
            answer = provider.query(pr["prompt"])
            results.append(
                {
                    "prompt": pr["prompt"],
                    "service": pr["service"],
                    "provider": provider.name,
                    "answer": answer,
                }
            )

    return {
        "generated_at": _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds"),
        "client": asdict(profile),
        "providers": [p.name for p in providers],
        "prompt_count": len(prompt_records),
        "results": results,
    }
