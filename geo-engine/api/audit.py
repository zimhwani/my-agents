"""Vercel serverless function: capture a landing-page lead.

POST /api/audit  { business, location, vertical, email }

Self-contained (Python standard library only) so the Vercel build is a simple
static site + one function — no dependency on the `geo` package and no heavy
installs. The lead is emailed to the operator via SMTP when configured;
otherwise it's logged (visible in Vercel function logs). The full audit is
produced offline via `geo prospect`.

Env: EMAIL_LEADS_TO (or DIGEST_TO) + SMTP_HOST / SMTP_USER / SMTP_PASS /
EMAIL_FROM  (+ optional SMTP_PORT, default 587).
"""

from __future__ import annotations

import json
import os
import smtplib
import ssl
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler


def _capture_lead(data: dict) -> None:
    to = os.environ.get("EMAIL_LEADS_TO") or os.environ.get("DIGEST_TO")
    configured = all(os.environ.get(k) for k in ("SMTP_HOST", "SMTP_USER", "SMTP_PASS", "EMAIL_FROM"))
    if not to or not configured:
        print(f"[lead] {data}")  # visible in Vercel logs even without email set up
        return
    try:
        msg = EmailMessage()
        msg["From"] = os.environ["EMAIL_FROM"]
        msg["To"] = to
        msg["Subject"] = f"New audit lead: {data.get('business')}"
        msg.set_content(
            f"New AI-visibility audit request:\n\n"
            f"Business: {data.get('business')}\n"
            f"Type: {data.get('vertical')}\n"
            f"City: {data.get('location')}\n"
            f"Email: {data.get('email')}\n"
        )
        with smtplib.SMTP(os.environ["SMTP_HOST"], int(os.environ.get("SMTP_PORT", "587"))) as smtp:
            smtp.starttls(context=ssl.create_default_context())
            smtp.login(os.environ["SMTP_USER"], os.environ["SMTP_PASS"])
            smtp.send_message(msg)
    except Exception as exc:  # never fail the request on an email hiccup
        print(f"[lead] email failed ({exc}): {data}")


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
        business = str(data.get("business")).strip() or "your business"
        self._send(200, {
            "ok": True,
            "message": f"Thanks! We're preparing {business}'s full AI-visibility "
                       "audit and will email it to you shortly.",
        })
