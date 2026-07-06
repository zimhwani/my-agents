"""Email delivery over SMTP — used by the weekly digest and (optionally) to
send prospect outreach.

All config comes from the environment; nothing is hardcoded:
    SMTP_HOST, SMTP_PORT (default 587), SMTP_USER, SMTP_PASS, EMAIL_FROM

If config is missing or ``dry_run`` is set, the message is printed instead of
sent — so pipelines run safely offline and in CI without secrets.
"""

from __future__ import annotations

import os
import smtplib
import ssl
from email.message import EmailMessage


def _configured() -> bool:
    return all(os.environ.get(k) for k in ("SMTP_HOST", "SMTP_USER", "SMTP_PASS", "EMAIL_FROM"))


def send_email(to: str, subject: str, text_body: str,
               html_body: str | None = None, dry_run: bool = False) -> bool:
    """Return True if actually sent, False if printed (dry-run / unconfigured)."""
    if dry_run or not _configured():
        reason = "dry-run" if dry_run else "SMTP not configured"
        print(f"[email:{reason}] to={to} subject={subject!r}")
        print("  " + text_body.replace("\n", "\n  ")[:600])
        return False

    msg = EmailMessage()
    msg["From"] = os.environ["EMAIL_FROM"]
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(text_body)
    if html_body:
        msg.add_alternative(html_body, subtype="html")

    host = os.environ["SMTP_HOST"]
    port = int(os.environ.get("SMTP_PORT", "587"))
    with smtplib.SMTP(host, port) as smtp:
        smtp.starttls(context=ssl.create_default_context())
        smtp.login(os.environ["SMTP_USER"], os.environ["SMTP_PASS"])
        smtp.send_message(msg)
    print(f"[email:sent] to={to} subject={subject!r}")
    return True
