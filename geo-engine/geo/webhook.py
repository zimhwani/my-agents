"""Minimal Stripe webhook receiver — provisions a client on payment.

Runs on the Python standard library (no web framework). Verifies Stripe's
signature, and on ``checkout.session.completed`` provisions the customer —
here, a stub that you wire to your onboarding (create a client profile, run
the first scan, email the report).

    export STRIPE_API_KEY=sk_test_...
    export STRIPE_WEBHOOK_SECRET=whsec_...
    python -m geo.webhook            # listens on :4242/stripe

Point a Stripe webhook (or `stripe listen --forward-to`) at /stripe.
Secrets are read from the environment only — never hardcode them.
"""

from __future__ import annotations

import http.server
import json
import os


def _provision(session: dict) -> None:
    """Hook: fulfil a paid order. Replace with real onboarding."""
    email = (session.get("customer_details") or {}).get("email", "unknown")
    print(f"[provision] payment complete for {email} — "
          f"kick off onboarding: create client profile → run scan → send report.")
    # Example next step (left as an integration point):
    #   from .config import ClientProfile
    #   from .providers import build_providers
    #   from .scan import run_scan
    #   ...build a profile from the intake form captured at checkout...


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 (stdlib naming)
        if self.path.rstrip("/") != "/stripe":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(length)
        sig = self.headers.get("Stripe-Signature", "")
        secret = os.environ.get("STRIPE_WEBHOOK_SECRET", "")

        try:
            import stripe
            if secret:
                event = stripe.Webhook.construct_event(payload, sig, secret)
            else:  # dev fallback: no signature verification
                print("[warn] STRIPE_WEBHOOK_SECRET unset — skipping signature check")
                event = json.loads(payload)
        except Exception as exc:  # bad signature / malformed
            self.send_response(400)
            self.end_headers()
            self.wfile.write(f"invalid: {exc}".encode())
            return

        etype = event["type"] if isinstance(event, dict) else event.type
        if etype == "checkout.session.completed":
            obj = (event["data"]["object"] if isinstance(event, dict)
                   else event.data.object)
            _provision(obj)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):  # quieter logs
        pass


def main() -> int:
    port = int(os.environ.get("PORT", "4242"))
    print(f"Stripe webhook listening on http://0.0.0.0:{port}/stripe")
    http.server.HTTPServer(("0.0.0.0", port), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
