"""The fix pipeline — turn an analysis into the deliverables clients pay for.

Generates three artifacts into an approval folder (nothing is published; a
human reviews and ships):

  1. schema.jsonld  — valid schema.org LocalBusiness + FAQPage structured data
                      (fully deterministic, no LLM needed).
  2. faq.md         — an expert FAQ targeting the buyer questions where the
                      client is invisible.
  3. comparison.md  — an honest "{client} vs {top competitor}" page outline.

FAQ answers and the comparison body are drafted by Claude when an API key is
configured, and fall back to editable templates otherwise — so the pipeline
runs offline and upgrades automatically when credentials are present.
"""

from __future__ import annotations

import json
import os
from typing import List, Tuple

from .config import ClientProfile, default_model

# Map our vertical slugs to the most specific schema.org business type.
SCHEMA_TYPES = {
    "med_spa": "MedicalBusiness",
    "cosmetic_clinic": "MedicalBusiness",
    "dermatology": "MedicalBusiness",
    "chiropractic": "MedicalBusiness",
    "dental": "Dentist",
    "optometry": "Optician",
    "veterinary": "VeterinaryCare",
    "physical_therapy": "Physiotherapy",
    "law_firm": "LegalService",
    "hvac": "HVACBusiness",
    "roofing": "RoofingContractor",
    "landscaping": "LocalBusiness",
    "generic": "LocalBusiness",
}


class Copywriter:
    """Drafts prose via Claude when available, else returns a template.

    Every call reports its source ('claude' or 'template') so the operator
    knows what to review most closely.
    """

    def __init__(self, model: str | None = None, use_claude: bool = True):
        self.model = model or default_model()
        self.use_claude = use_claude
        self._client = None
        self._disabled = not use_claude

    def _get_client(self):
        if self._client is None:
            import anthropic  # lazy: keeps the template path dependency-free
            self._client = anthropic.Anthropic()
        return self._client

    def draft(self, system: str, prompt: str, fallback: str) -> Tuple[str, str]:
        if self._disabled:
            return fallback, "template"
        try:
            resp = self._get_client().messages.create(
                model=self.model,
                max_tokens=1500,
                system=system,
                messages=[{"role": "user", "content": prompt}],
            )
            text = "".join(b.text for b in resp.content if b.type == "text").strip()
            return (text or fallback), ("claude" if text else "template")
        except Exception as exc:
            # No key / no SDK / transient error → fall back, note why once.
            if not self._disabled:
                print(f"  (copywriter falling back to templates: {exc})")
                self._disabled = True
            return fallback, "template"


def build_local_business_schema(profile: ClientProfile) -> dict:
    schema_type = SCHEMA_TYPES.get(profile.vertical, "LocalBusiness")
    node = {
        "@context": "https://schema.org",
        "@type": schema_type,
        "name": profile.business_name,
        "areaServed": profile.location,
    }
    if profile.website:
        node["url"] = profile.website
    if profile.services:
        node["makesOffer"] = [
            {"@type": "Offer", "itemOffered": {"@type": "Service", "name": s}}
            for s in profile.services
        ]
    return node


def _faq_questions(profile: ClientProfile, analysis: dict) -> List[str]:
    """Buyer questions to answer — prioritise services where we're invisible."""
    label = profile.vertical_label
    loc = profile.location
    qs: List[str] = []
    for svc in analysis.get("missing_services", [])[:4]:
        qs.append(f"Where can I get {svc} in {loc}?")
    qs.append(f"What should I look for when choosing a {label} in {loc}?")
    qs.append(f"How much does a typical visit to a {label} in {loc} cost?")
    # De-dup, keep order, cap at 6.
    seen, out = set(), []
    for q in qs:
        if q.lower() not in seen:
            seen.add(q.lower())
            out.append(q)
    return out[:6]


def build_faq(profile: ClientProfile, analysis: dict, writer: Copywriter):
    questions = _faq_questions(profile, analysis)
    system = (
        "You are an expert content writer for a local business. Write a clear, "
        "genuinely helpful, first-person-plural answer (2-4 sentences) to a "
        "prospective customer's question. Be specific and trustworthy; do not "
        "invent prices or fake claims — use ranges and qualifiers where needed."
    )
    items = []
    sources = set()
    for q in questions:
        fallback = (
            f"At {profile.business_name}, we help clients in {profile.location} "
            f"with this. [REVIEW: replace with a specific, accurate answer before "
            f"publishing.]"
        )
        prompt = (
            f"Business: {profile.business_name}, a {profile.vertical_label} in "
            f"{profile.location}. Services: {', '.join(profile.services) or 'n/a'}.\n"
            f"Customer question: {q}\n"
            "Write the answer only."
        )
        answer, src = writer.draft(system, prompt, fallback)
        items.append({"q": q, "a": answer})
        sources.add(src)
    return items, sources


def build_faq_schema(faq_items: List[dict]) -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {
                "@type": "Question",
                "name": it["q"],
                "acceptedAnswer": {"@type": "Answer", "text": it["a"]},
            }
            for it in faq_items
        ],
    }


def build_comparison(profile: ClientProfile, analysis: dict, writer: Copywriter):
    competitors = [b for b in analysis["brands"] if not b["is_client"]]
    if not competitors:
        return None, None
    top = max(competitors, key=lambda r: r["presence_rate"])["brand"]
    system = (
        "You are writing an honest, useful comparison page for a local business. "
        "Be fair to the competitor, factual, and helpful to a buyer deciding "
        "between them. Output Markdown with short sections."
    )
    fallback = (
        f"## {profile.business_name} vs {top}\n\n"
        f"Both are {profile.vertical_label}s in {profile.location}. "
        "[REVIEW: fill in an honest, specific comparison covering services, "
        "specialties, and who each is the best fit for. Do not disparage.]\n\n"
        f"### Choose {profile.business_name} if…\n- [REVIEW]\n\n"
        f"### {top} may fit better if…\n- [REVIEW]\n"
    )
    prompt = (
        f"Write an honest comparison page: {profile.business_name} vs {top}, both "
        f"{profile.vertical_label}s in {profile.location}. Services offered by "
        f"{profile.business_name}: {', '.join(profile.services) or 'n/a'}. "
        "Cover services/specialties and who each is the best fit for. Be fair; "
        "do not fabricate specific claims about the competitor."
    )
    body, src = writer.draft(system, prompt, fallback)
    return body, src


DRAFT_BANNER = (
    "> **STATUS: DRAFT — human review required before publishing.**\n"
    "> AI/template-generated. Verify every factual claim (prices, specialties, "
    "competitor statements) and edit to your brand voice before shipping.\n"
)


def generate_fixes(profile: ClientProfile, analysis: dict, out_dir: str,
                   use_claude: bool = True) -> dict:
    os.makedirs(out_dir, exist_ok=True)
    writer = Copywriter(use_claude=use_claude)

    # 1. Structured data (deterministic).
    lb = build_local_business_schema(profile)
    faq_items, faq_sources = build_faq(profile, analysis, writer)
    faq_schema = build_faq_schema(faq_items)
    schema_doc = {"localBusiness": lb, "faqPage": faq_schema}
    with open(os.path.join(out_dir, "schema.jsonld"), "w", encoding="utf-8") as fh:
        json.dump(schema_doc, fh, indent=2, ensure_ascii=False)

    # 2. FAQ page.
    faq_md = [DRAFT_BANNER, f"\n# Frequently Asked Questions — {profile.business_name}\n"]
    for it in faq_items:
        faq_md.append(f"### {it['q']}\n\n{it['a']}\n")
    with open(os.path.join(out_dir, "faq.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(faq_md))

    # 3. Comparison page.
    comparison_body, comp_source = build_comparison(profile, analysis, writer)
    artifacts = ["schema.jsonld", "faq.md"]
    if comparison_body:
        with open(os.path.join(out_dir, "comparison.md"), "w", encoding="utf-8") as fh:
            fh.write(DRAFT_BANNER + "\n" + comparison_body + "\n")
        artifacts.append("comparison.md")

    # Approval index.
    sources = sorted(faq_sources | ({comp_source} if comp_source else set()))
    index = [
        f"# Fix package — {profile.business_name}",
        "",
        DRAFT_BANNER,
        "",
        f"Content source: {', '.join(sources) or 'template'} "
        "(`claude` = AI-drafted, review for accuracy; `template` = fill in the "
        "`[REVIEW]` placeholders).",
        "",
        "## Artifacts & review checklist",
        "",
        "- **schema.jsonld** — paste into a `<script type=\"application/ld+json\">` "
        "tag; validate at validator.schema.org before publishing.",
        "- **faq.md** — publish as an FAQ page; the FAQPage schema mirrors it.",
    ]
    if comparison_body:
        index.append("- **comparison.md** — publish as a comparison/alternatives page.")
    index.append("")
    index.append("Ship these to move the client's visibility score up on the next scan.")
    with open(os.path.join(out_dir, "INDEX.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(index))

    return {"artifacts": artifacts + ["INDEX.md"], "sources": sources}
