"""Client profile loading and shared settings for the GEO engine."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import List


# Human-readable label for a vertical slug, used when generating buyer prompts.
VERTICAL_LABELS = {
    "med_spa": "med spa",
    "cosmetic_clinic": "cosmetic clinic",
    "dermatology": "dermatology practice",
    "dental": "dental practice",
    "optometry": "optometry practice",
    "veterinary": "veterinary clinic",
    "physical_therapy": "physical therapy clinic",
    "chiropractic": "chiropractor",
    "law_firm": "law firm",
    "hvac": "HVAC company",
    "roofing": "roofing company",
    "landscaping": "landscaping company",
    "generic": "business",
}


@dataclass
class ClientProfile:
    """A business we run AI-answer visibility scans for."""

    business_name: str
    vertical: str
    location: str
    services: List[str] = field(default_factory=list)
    competitors: List[str] = field(default_factory=list)
    website: str = ""

    @property
    def vertical_label(self) -> str:
        return VERTICAL_LABELS.get(self.vertical, VERTICAL_LABELS["generic"])

    @property
    def tracked_brands(self) -> List[str]:
        """Client first, then competitors — the full set we look for in answers."""
        return [self.business_name] + list(self.competitors)


def load_profile(path: str) -> ClientProfile:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    required = ("business_name", "vertical", "location")
    missing = [k for k in required if not data.get(k)]
    if missing:
        raise ValueError(f"{path}: missing required field(s): {', '.join(missing)}")
    return ClientProfile(
        business_name=data["business_name"].strip(),
        vertical=data["vertical"].strip(),
        location=data["location"].strip(),
        services=[s.strip() for s in data.get("services", []) if s.strip()],
        competitors=[c.strip() for c in data.get("competitors", []) if c.strip()],
        website=data.get("website", "").strip(),
    )


# The model used by the real (Anthropic) provider. Override with GEO_MODEL.
# Defaults to the most capable Opus tier; set GEO_MODEL=claude-sonnet-5 to cut cost.
def default_model() -> str:
    return os.environ.get("GEO_MODEL", "claude-opus-4-8")
