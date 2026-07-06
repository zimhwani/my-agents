"""Vercel serverless function: instant visibility teaser + lead capture.

POST /api/audit  { business, location, vertical, email }

Behavior:
- Always captures the lead (emails the operator via SMTP if configured).
- Returns a teaser. A LIVE scan runs only when GEO_LIVE_AUDIT=1 AND an
  ANTHROPIC_API_KEY is present — this guards you from per-submission API cost
  and abuse. Otherwise it returns a friendly "full audit on its way" message
  and the real audit is produced offline via `geo prospect`.

Env: GEO_LIVE_AUDIT, ANTHROPIC_API_KEY, EMAIL_LEADS_TO (+ SMTP_* for email).
"""

from __future__ import annotations

import json
import os
import sys
from http.server import BaseHTTPRequestHandler

# Make the sibling `geo` package importable when running as a Vercel function.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _capture_lead(data: dict) -> None:
    to = os.environ.get("EMAIL_LEADS_TO") or os.environ.get("DIGEST_TO")
    if not to:
        print(f"[lead] {data}")  # visible in Vercel logs even without email
        return
    try:
        from geo.notify import send_email
        body = (f"New audit request:\n\n"
                f"Business: {data.get('business')}\n"
                f"Type: {data.get('vertical')}\n"
                f"City: {data.get('location')}\n"
                f"Email: {data.get('email')}\n")
        send_email(to, f"New lead: {data.get('business')}", body)
    except Exception as exc:  # never fail the request on a notify hiccup
        print(f"[lead] notify failed ({exc}): {data}")


def _teaser(data: dict) -> str:
    business = (data.get("business") or "your business").strip()
    live = os.environ.get("GEO_LIVE_AUDIT") == "1" and os.environ.get("ANTHROPIC_API_KEY")
    if not live:
        return (f"Thanks! We're preparing {business}'s full AI-visibility audit "
                "and will email it to you shortly.")
    try:
        from geo.config import ClientProfile
        from geo.providers import build_providers
        from geo.scan import run_scan
        from geo.analyze import analyze
        profile = ClientProfile(
            business_name=business,
            vertical=data.get("vertical") or "generic",
            location=data.get("location") or "",
        )
        providers = build_providers(profile, ["anthropic"])
        scan = run_scan(profile, providers, max_prompts=4)
        res = analyze(scan)
        pct = round(res["client"]["presence_rate"] * 100)
        if pct == 0:
            return (f"We checked: {business} was not named in any of the AI answers "
                    "we tested for your area. Your full report (and how to fix it) is "
                    "on its way to your inbox.")
        return (f"We checked: {business} showed up in about {pct}% of AI answers for "
                "your area. Your full report — including who's winning and how to catch "
                "up — is on its way.")
    except Exception as exc:
        print(f"[audit] live scan failed: {exc}")
        return (f"Thanks! We're preparing {business}'s full audit and will email it shortly.")


class handler(BaseHTTPRequestHandler):
    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "POST, OPTIONS")
        self.send_header("access-control-allow-headers", "content-type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):  # CORS preflight
        self._send(204, {})

    def do_POST(self):
        length = int(self.headers.get("content-length", 0))
        try:
            data = json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            return self._send(400, {"ok": False, "message": "Invalid request."})
        if not data.get("business") or not data.get("email"):
            return self._send(400, {"ok": False, "message": "Business name and email are required."})
        _capture_lead(data)
        self._send(200, {"ok": True, "message": _teaser(data)})
