"""Publish the dashboard's data files somewhere the hosted dashboard can read.

``BlobPublisher`` targets Vercel Blob storage via its REST API (standard
library only). Create a Blob store in your Vercel project (Storage -> Blob),
copy its read/write token into ``VERCEL_BLOB_TOKEN``, and the bot uploads
``live.json`` every tick and ``trades.json`` whenever a trade closes. The
first upload logs the public base URL to put into ``DASHBOARD_DATA_URL``.
"""

from __future__ import annotations

import json
import logging
import time as _time
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable, Optional, Tuple

log = logging.getLogger("tradebot.publish")

BLOB_API = "https://blob.vercel-storage.com"
Transport = Callable[[str, str, dict, Optional[bytes]], Tuple[int, bytes]]


class PublishError(RuntimeError):
    pass


def _urllib_transport(method: str, url: str, headers: dict, body: bytes | None) -> tuple[int, bytes]:
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise PublishError(f"cannot reach blob.vercel-storage.com: {exc}") from exc


class BlobPublisher:
    def __init__(self, token: str, prefix: str = "tradebot", transport: Transport | None = None,
                 min_interval: float = 10.0):
        if not token:
            raise PublishError("VERCEL_BLOB_TOKEN is not set")
        self.token = token
        self.prefix = prefix.strip("/")
        self._t = transport or _urllib_transport
        self.base_url: str | None = None
        self.min_interval = min_interval
        self._last: dict[str, float] = {}
        self._failures = 0

    def _headers(self, content_type: str) -> dict:
        return {"authorization": f"Bearer {self.token}", "x-api-version": "7",
                "x-content-type": content_type, "x-add-random-suffix": "0",
                "x-allow-overwrite": "1", "x-cache-control-max-age": "60"}

    def put(self, name: str, body: bytes, content_type: str = "application/json") -> str:
        """Upload ``name`` under the prefix; returns its public URL."""
        path = f"{self.prefix}/{name}" if self.prefix else name
        url = f"{BLOB_API}/{urllib.parse.quote(path)}"
        status, raw = self._t("PUT", url, self._headers(content_type), body)
        if status == 409 or (status >= 400 and b"already exists" in raw):
            # older API: delete then re-upload
            self._t("POST", f"{BLOB_API}/delete", {"authorization": f"Bearer {self.token}",
                                                    "x-api-version": "7", "content-type": "application/json"},
                    json.dumps({"urls": [self.base_url.rstrip("/") + "/" + name if self.base_url else path]}).encode())
            status, raw = self._t("PUT", url, self._headers(content_type), body)
        if status >= 400:
            raise PublishError(f"Vercel Blob PUT {path} -> {status}: {raw[:200].decode(errors='replace')}")
        res = json.loads(raw.decode() or "{}")
        public = res.get("url") or ""
        if public and self.base_url is None:
            self.base_url = public[: public.rfind("/" + name)] if ("/" + name) in public else public.rsplit("/", 1)[0]
            log.info("Vercel Blob base URL: %s  (put this in DASHBOARD_DATA_URL)", self.base_url)
        return public

    def publish(self, name: str, payload: dict, force: bool = False) -> bool:
        """Rate-limited JSON upload; never raises (logs and returns False)."""
        now = _time.monotonic()
        last = self._last.get(name)
        if not force and last is not None and now - last < self.min_interval:
            return False
        try:
            self.put(name, json.dumps(payload, separators=(",", ":")).encode())
            self._last[name] = now
            self._failures = 0
            return True
        except PublishError as exc:
            self._failures += 1
            if self._failures <= 3 or self._failures % 20 == 0:
                log.warning("publish %s failed (%d): %s", name, self._failures, exc)
            return False
