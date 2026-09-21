"""Telegram alerts via the Bot API (standard library only).

Setup: message @BotFather -> /newbot -> copy the token into TELEGRAM_BOT_TOKEN.
Send your bot any message, then open
https://api.telegram.org/bot<TOKEN>/getUpdates and copy ``chat.id`` into
TELEGRAM_CHAT_ID. Unconfigured, messages are printed instead of sent.
"""

from __future__ import annotations

import html
import json
import logging
import urllib.error
import urllib.parse
import urllib.request

log = logging.getLogger("tradebot.telegram")


class Notifier:
    def __init__(self, token: str = "", chat_id: str = "", timeout: float = 10.0, quiet: bool = False,
                 prefix: str = ""):
        self.token = token
        self.chat_id = chat_id
        self.timeout = timeout
        self.quiet = quiet
        self.prefix = prefix
        self.sent: list[str] = []  # kept for tests / status

    @property
    def configured(self) -> bool:
        return bool(self.token and self.chat_id)

    def send(self, text: str, silent: bool = False) -> bool:
        if self.prefix:
            text = f"[{self.prefix}] {text}"
        self.sent.append(text)
        if not self.configured:
            if not self.quiet:
                print(f"[telegram:unconfigured] {text}")
            return False
        url = f"https://api.telegram.org/bot{self.token}/sendMessage"
        payload = urllib.parse.urlencode({
            "chat_id": self.chat_id, "text": text, "parse_mode": "HTML",
            "disable_notification": "true" if silent else "false",
        }).encode()
        try:
            with urllib.request.urlopen(url, payload, timeout=self.timeout) as resp:
                body = json.loads(resp.read().decode())
                return bool(body.get("ok"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            log.warning("Telegram send failed: %s", exc)
            return False


def esc(s: object) -> str:
    return html.escape(str(s), quote=False)
