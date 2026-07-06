"""Stripe billing for the GEO service — catalog setup and payment links.

Safety first:
* The Stripe secret is read from the ``STRIPE_API_KEY`` environment variable.
  It is never hardcoded, logged, or committed.
* Live keys (``sk_live_``/``rk_live_``) are REFUSED unless you explicitly set
  ``GEO_STRIPE_ALLOW_LIVE=1`` — creating catalog objects and charges is hard to
  reverse, so develop against a test key (``sk_test_``/``rk_test_``) first.
* ``--dry-run`` prints exactly what would be created without calling Stripe.

Usage:
    export STRIPE_API_KEY=sk_test_...
    python -m geo.billing setup --dry-run
    python -m geo.billing setup
    python -m geo.billing link --plan growth
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Plan:
    key: str
    name: str
    description: str
    amount_cents: int
    interval: Optional[str]  # None = one-time, else "month"/"year"


# --- EDIT THESE to your pricing before going live. -------------------------
# Defaults reflect typical GEO-service price points; they are placeholders.
PLANS: List[Plan] = [
    Plan("audit", "GEO Visibility Audit",
         "One-time AI-answer visibility audit and fix roadmap.",
         29900, None),
    Plan("starter", "GEO Monitoring — Starter",
         "Monthly AI-answer visibility scan + report.",
         50000, "month"),
    Plan("growth", "GEO Monitoring + Fixes — Growth",
         "Monthly scan, report, and done-for-you fix drafts.",
         150000, "month"),
]
# ---------------------------------------------------------------------------


def _plan(key: str) -> Plan:
    for p in PLANS:
        if p.key == key:
            return p
    raise ValueError(f"Unknown plan '{key}'. Choices: {', '.join(p.key for p in PLANS)}")


def _fmt(cents: int, interval: Optional[str]) -> str:
    base = f"${cents / 100:,.2f}"
    return base + (f"/{interval}" if interval else " one-time")


def _stripe():
    """Return a configured stripe module, enforcing the live-key guard."""
    key = os.environ.get("STRIPE_API_KEY", "").strip()
    if not key:
        raise RuntimeError(
            "STRIPE_API_KEY is not set. Export a Stripe secret key first "
            "(use a test key: sk_test_... / rk_test_...)."
        )
    if key.startswith(("sk_live_", "rk_live_")) and os.environ.get("GEO_STRIPE_ALLOW_LIVE") != "1":
        raise RuntimeError(
            "Refusing to use a LIVE Stripe key — this creates real, billable "
            "objects in your production account. Develop with a test key "
            "(sk_test_/rk_test_). To override deliberately, set "
            "GEO_STRIPE_ALLOW_LIVE=1."
        )
    try:
        import stripe
    except ImportError as exc:
        raise RuntimeError("The 'stripe' package is required:  pip install stripe") from exc
    stripe.api_key = key
    return stripe


def _find_product(stripe, name: str):
    for prod in stripe.Product.list(active=True, limit=100).auto_paging_iter():
        if prod.name == name:
            return prod
    return None


def _find_price(stripe, product_id: str, plan: Plan):
    for price in stripe.Price.list(product=product_id, active=True, limit=100).auto_paging_iter():
        recurring = getattr(price, "recurring", None)
        interval = recurring["interval"] if recurring else None
        if price.unit_amount == plan.amount_cents and interval == plan.interval:
            return price
    return None


def ensure_price(stripe, plan: Plan):
    """Find-or-create the Product + Price for a plan (idempotent by name/amount)."""
    product = _find_product(stripe, plan.name)
    if product is None:
        product = stripe.Product.create(name=plan.name, description=plan.description)
    price = _find_price(stripe, product.id, plan)
    if price is None:
        params = {"product": product.id, "unit_amount": plan.amount_cents, "currency": "usd"}
        if plan.interval:
            params["recurring"] = {"interval": plan.interval}
        price = stripe.Price.create(**params)
    return product, price


def cmd_setup(args) -> int:
    if args.dry_run:
        print("DRY RUN — would create/reuse these Stripe products & prices:\n")
        for p in PLANS:
            print(f"  [{p.key}] {p.name} — {_fmt(p.amount_cents, p.interval)}")
            print(f"        {p.description}")
        print("\nNo API calls made. Drop --dry-run (with a test key) to apply.")
        return 0
    stripe = _stripe()
    print(f"Setting up catalog (mode: {'LIVE' if stripe.api_key.startswith(('sk_live_','rk_live_')) else 'test'})")
    for p in PLANS:
        product, price = ensure_price(stripe, p)
        print(f"  [{p.key}] {p.name}: product={product.id} price={price.id} "
              f"({_fmt(p.amount_cents, p.interval)})")
    return 0


def cmd_link(args) -> int:
    plan = _plan(args.plan)
    if args.dry_run:
        print(f"DRY RUN — would create a payment link for [{plan.key}] "
              f"{plan.name} ({_fmt(plan.amount_cents, plan.interval)}).")
        return 0
    stripe = _stripe()
    _, price = ensure_price(stripe, plan)
    link = stripe.PaymentLink.create(line_items=[{"price": price.id, "quantity": 1}])
    print(link.url)
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="geo.billing", description="Stripe billing for the GEO service")
    sub = parser.add_subparsers(dest="command", required=True)

    p_setup = sub.add_parser("setup", help="Create/reuse products & prices")
    p_setup.add_argument("--dry-run", action="store_true")
    p_setup.set_defaults(func=cmd_setup)

    p_link = sub.add_parser("link", help="Create a shareable payment link for a plan")
    p_link.add_argument("--plan", required=True, help="Plan key: " + ", ".join(p.key for p in PLANS))
    p_link.add_argument("--dry-run", action="store_true")
    p_link.set_defaults(func=cmd_link)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
