"""LLM providers the scanner queries.

Two providers ship today:

* ``mock``      — deterministic, offline. Simulates an underserved client
                  (competitors dominate, the client shows up sometimes and
                  rarely first). Lets you run the whole pipeline — and demo it
                  to a prospect — with no API key and no dependencies.
* ``anthropic`` — real answers from Claude via the official Anthropic SDK.

The scanner treats every provider the same: ``.query(prompt) -> str``.
Add OpenAI / Perplexity / Gemini providers here later; nothing else changes.
"""

from __future__ import annotations

import hashlib
import random
from typing import List

from .config import ClientProfile, default_model


def _rng(seed: str) -> random.Random:
    return random.Random(int(hashlib.md5(seed.encode("utf-8")).hexdigest(), 16))


class MockProvider:
    """Deterministic stand-in for a real AI answer engine."""

    def __init__(self, profile: ClientProfile, name: str = "mock"):
        self.name = name
        self.client = profile.business_name
        self.competitors = list(profile.competitors)
        self.label = profile.vertical_label

    def query(self, prompt: str) -> str:
        r = _rng(f"{self.name}|{prompt}")
        pool = list(self.competitors)
        r.shuffle(pool)
        k = max(2, min(4, len(pool)))
        picks = pool[:k]

        # The client surfaces ~35% of the time, and when it does it's usually
        # buried mid-list rather than the top pick — the underserved pattern.
        if self.competitors and r.random() < 0.35:
            pos = r.randint(1, len(picks))  # 1..len → almost never first
            picks.insert(pos, self.client)
            picks = picks[:k]

        if not picks:
            return f"There are several {self.label}s worth considering."

        lead = picks[0]
        rest = picks[1:]
        parts = [
            f"Based on reputation and reviews, {lead} is a strong choice."
        ]
        if rest:
            joined = ", ".join(rest[:-1]) + (f" and {rest[-1]}" if len(rest) > 1 else rest[-1])
            parts.append(f"Other well-regarded options include {joined}.")
        return " ".join(parts)


class AnthropicProvider:
    """Real answers from Claude. Imports the SDK lazily so the mock path
    stays dependency-free."""

    def __init__(self, model: str | None = None, name: str = "anthropic"):
        self.name = name
        self.model = model or default_model()
        self._client = None

    def _ensure_client(self):
        if self._client is None:
            try:
                import anthropic
            except ImportError as exc:  # pragma: no cover - env dependent
                raise RuntimeError(
                    "The 'anthropic' package is required for the real provider. "
                    "Install it with:  pip install anthropic"
                ) from exc
            # Resolves ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, or an
            # `ant auth login` profile automatically.
            self._client = anthropic.Anthropic()
        return self._client

    def query(self, prompt: str) -> str:
        client = self._ensure_client()
        # Frame it as a real consumer discovery question so the model answers
        # the way a user would actually experience it.
        resp = client.messages.create(
            model=self.model,
            max_tokens=1024,
            system=(
                "You are a helpful assistant answering a consumer's question "
                "about local businesses. Recommend specific, named providers "
                "as you normally would."
            ),
            messages=[{"role": "user", "content": prompt}],
        )
        return "".join(b.text for b in resp.content if b.type == "text")


def build_providers(profile: ClientProfile, names: List[str], model: str | None = None):
    providers = []
    for raw in names:
        n = raw.strip().lower()
        if n == "mock" or n.startswith("mock"):
            providers.append(MockProvider(profile, name=n))
        elif n == "anthropic":
            providers.append(AnthropicProvider(model=model))
        else:
            raise ValueError(f"Unknown provider '{raw}' (expected 'mock' or 'anthropic')")
    return providers
