"""Generate realistic buyer 'discovery' prompts for a client profile.

These are the questions a prospective customer would type into ChatGPT,
Perplexity, or Google's AI answers — the moments where the client either
shows up as a recommendation or is invisible.
"""

from __future__ import annotations

from typing import List

from .config import ClientProfile

# Templates that don't reference a specific service.
GENERAL_TEMPLATES = [
    "What's the best {label} in {loc}?",
    "Who are the top-rated {label}s in {loc}?",
    "Can you recommend a few {label}s near {loc}?",
    "I just moved to {loc}. Which {label} should I go to?",
    "Which {label} in {loc} has the best reviews?",
]

# Templates that reference one of the client's services.
SERVICE_TEMPLATES = [
    "What's the best {label} in {loc} for {service}?",
    "I'm looking for {service} in {loc}. Which providers should I consider?",
    "Where should I go for {service} in {loc}?",
    "Which {label} in {loc} is known for {service}?",
]


def build_prompts(profile: ClientProfile, max_prompts: int = 12) -> List[dict]:
    """Return a de-duplicated list of {'prompt', 'service'} records.

    General prompts come first (they carry the most weight for overall
    visibility), then service-specific prompts round-robin across services
    so no single service dominates the sample.
    """
    label = profile.vertical_label
    loc = profile.location
    records: List[dict] = []
    seen = set()

    def add(text: str, service: str = ""):
        key = text.lower()
        if key not in seen:
            seen.add(key)
            records.append({"prompt": text, "service": service})

    for tmpl in GENERAL_TEMPLATES:
        add(tmpl.format(label=label, loc=loc))

    # Round-robin over services so every service gets coverage before any
    # service gets a second prompt.
    for tmpl in SERVICE_TEMPLATES:
        for service in profile.services:
            add(tmpl.format(label=label, loc=loc, service=service), service)

    return records[:max_prompts]
