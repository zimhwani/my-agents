"""World Monitor (https://www.worldmonitor.app) news and calendar data.

Used for two things only, both safe without a backtest:
  1. a macro blackout: no NEW entries in the minutes around high-impact scheduled releases
     (FOMC, CPI, payrolls...), when volatility spikes through stops;
  2. context in alerts: headlines and earnings dates next to watchlist symbols.
News never triggers a trade -- there is no history to backtest it against.

API: GET https://api.worldmonitor.app/api/<domain>/v1/<rpc>, key (if any) in X-WorldMonitor-Key.
The response shapes below are parsed defensively; run `python -m tradebot news --raw` to see
what the live API returns.
"""

from __future__ import annotations

import json
import logging
import re
import time as _time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable

from . import clock

log = logging.getLogger(__name__)

BASE = "https://api.worldmonitor.app"
PATHS = {
    "economic_calendar": "/api/economic/v1/get-economic-calendar",
    "earnings_calendar": "/api/market/v1/list-earnings-calendar",
    "feed_digest": "/api/news/v1/list-feed-digest",
}
HIGH_IMPACT_WORDS = ("fomc", "federal funds", "interest rate decision", "fed rate", "cpi", "consumer price",
                     "nonfarm", "non-farm", "payroll", "nfp", "pce", "gdp", "unemployment rate", "powell")

Transport = Callable[[str, dict], tuple[int, bytes]]


def _http(url: str, headers: dict) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read() or b""


@dataclass
class MacroEvent:
    time: datetime | None
    name: str
    country: str = ""
    impact: str = ""

    @property
    def high_impact(self) -> bool:
        imp = self.impact.strip().lower()
        if imp in ("high", "3", "***", "critical", "major"):
            return True
        if imp in ("low", "1", "*", "medium", "2", "**", "minor"):
            return False
        name = self.name.lower()
        return any(w in name for w in HIGH_IMPACT_WORDS)

    @property
    def us(self) -> bool:
        c = self.country.strip().upper()
        return c in ("", "US", "USA", "USD", "UNITED STATES", "U.S.")


@dataclass
class Headline:
    title: str
    source: str = ""
    url: str = ""
    time: datetime | None = None
    category: str = ""


# -- tolerant parsing ------------------------------------------------------------------------
def _records(payload) -> list[dict]:
    """The list of dict records in a response, whatever key it lives under (or nested one level,
    e.g. {"categories": {"finance": {"items": [...]}}})."""
    if isinstance(payload, list):
        return [x for x in payload if isinstance(x, dict)]
    if not isinstance(payload, dict):
        return []
    best: list[dict] = []
    for v in payload.values():
        if isinstance(v, list) and v and isinstance(v[0], dict):
            if len(v) > len(best):
                best = v
        elif isinstance(v, dict):
            inner = _records(v)
            if len(inner) > len(best):
                best = inner
    return best


def _first(d: dict, *keys, default=""):
    for k in keys:
        if k in d and d[k] not in (None, ""):
            return d[k]
    return default


def _parse_time(value, date_hint=None) -> datetime | None:
    if value in (None, ""):
        return None
    try:
        if isinstance(value, (int, float)) or (isinstance(value, str) and value.isdigit()):
            v = float(value)
            if v > 1e12:  # milliseconds
                v /= 1000.0
            return clock.to_et(datetime.fromtimestamp(v, tz=timezone.utc))
        s = str(value).strip().replace("Z", "+00:00")
        if date_hint and re.fullmatch(r"\d{1,2}:\d{2}(:\d{2})?", s):
            s = f"{date_hint}T{s}"
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:  # calendars without a zone are almost always US Eastern
            dt = dt.replace(tzinfo=clock.ET)
        return clock.to_et(dt)
    except (ValueError, OverflowError, OSError):
        return None


def parse_economic(payload) -> list[MacroEvent]:
    out = []
    for r in _records(payload):
        date_hint = _first(r, "date", "day")
        t = _parse_time(_first(r, "datetime", "timestamp", "time", "scheduledAt", "releaseTime", "eventTime",
                               "date", default=None), date_hint if isinstance(date_hint, str) else None)
        out.append(MacroEvent(time=t, name=str(_first(r, "event", "name", "title", "indicator")),
                              country=str(_first(r, "country", "countryCode", "region", "currency")),
                              impact=str(_first(r, "impact", "importance", "priority", "severity"))))
    return out


def parse_headlines(payload) -> list[Headline]:
    out = []
    for r in _records(payload):
        title = str(_first(r, "title", "headline", "text", "summary"))
        if not title:
            continue
        out.append(Headline(title=title, source=str(_first(r, "source", "sourceName", "feed", "publisher")),
                            url=str(_first(r, "url", "link")),
                            time=_parse_time(_first(r, "publishedAt", "pubDate", "published", "time", "timestamp",
                                                    default=None)),
                            category=str(_first(r, "category", "topic"))))
    return out


def parse_earnings(payload) -> dict[str, str]:
    """symbol -> date/time text of its next (or latest) report."""
    out: dict[str, str] = {}
    for r in _records(payload):
        sym = str(_first(r, "symbol", "ticker", "code")).upper()
        if sym and sym not in out:
            out[sym] = str(_first(r, "date", "reportDate", "datetime", "time", "when"))
    return out


def mentions(symbol: str, headlines: list[Headline]) -> list[Headline]:
    """Headlines naming the ticker as a word or $TICKER (tickers under 3 letters are too ambiguous)."""
    if len(symbol) < 3:
        return [h for h in headlines if f"${symbol}" in h.title]
    pat = re.compile(rf"(?<![A-Za-z0-9])\$?{re.escape(symbol)}(?![A-Za-z0-9])")
    return [h for h in headlines if pat.search(h.title)]


# -- client ----------------------------------------------------------------------------------
class WorldMonitor:
    def __init__(self, api_key: str = "", base: str = BASE, transport: Transport | None = None,
                 cache_seconds: float = 900.0, variant: str = "finance"):
        self.base = base.rstrip("/")
        self.key = api_key
        self.variant = variant
        self._t = transport or _http
        self.cache_seconds = cache_seconds
        self._cache: dict[str, tuple[float, object]] = {}

    def get(self, name: str, params: dict | None = None):
        path = PATHS[name]
        q = "?" + urllib.parse.urlencode(params) if params else ""
        key = path + q
        hit = self._cache.get(key)
        if hit and _time.time() - hit[0] < self.cache_seconds:
            return hit[1]
        headers = {"Accept": "application/json", "User-Agent": "tradebot/1.0"}
        if self.key:
            headers["X-WorldMonitor-Key"] = self.key
        status, raw = self._t(self.base + path + q, headers)
        if status in (401, 403):
            raise RuntimeError(f"World Monitor {path} -> {status}: needs an API key (WORLDMONITOR_API_KEY, "
                               f"from worldmonitor.app/pro); body: {raw[:120]!r}")
        if status >= 400:
            raise RuntimeError(f"World Monitor {path} -> {status}: {raw[:200]!r}")
        data = json.loads(raw.decode() or "null")
        self._cache[key] = (_time.time(), data)
        return data

    def economic_events(self) -> list[MacroEvent]:
        return parse_economic(self.get("economic_calendar"))

    def headlines(self) -> list[Headline]:
        return parse_headlines(self.get("feed_digest", {"variant": self.variant}))

    def earnings(self) -> dict[str, str]:
        return parse_earnings(self.get("earnings_calendar"))

    def notes(self, symbols: list[str]) -> str:
        try:
            earn = self.earnings()
        except Exception:
            earn = {}
        return watchlist_notes(symbols, self.headlines(), earn)


# -- free sources (no key) ------------------------------------------------------------------------
FF_CALENDAR = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"  # Forex Factory's public weekly export
YAHOO_RSS = "https://feeds.finance.yahoo.com/rss/2.0/headline?s={symbol}&region=US&lang=en-US"


def parse_rss(xml_bytes: bytes, source: str = "") -> list[Headline]:
    import xml.etree.ElementTree as ET
    from email.utils import parsedate_to_datetime
    out = []
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return out
    for item in root.iter("item"):
        title = (item.findtext("title") or "").strip()
        if not title:
            continue
        when = None
        pub = item.findtext("pubDate")
        if pub:
            try:
                when = clock.to_et(parsedate_to_datetime(pub))
            except (TypeError, ValueError):
                when = None
        out.append(Headline(title=title, source=(item.findtext("source") or source).strip(),
                            url=(item.findtext("link") or "").strip(), time=when))
    return out


class FreeNews:
    """Key-free fallback: Forex Factory's weekly calendar JSON for the macro blackout and Yahoo
    Finance's per-ticker RSS for watchlist headlines. Same interface as WorldMonitor."""

    def __init__(self, calendar_url: str = FF_CALENDAR, transport: Transport | None = None,
                 cache_seconds: float = 3600.0):
        self.calendar_url = calendar_url
        self._t = transport or _http
        self.cache_seconds = cache_seconds
        self._cache: dict[str, tuple[float, object]] = {}

    def _fetch(self, url: str) -> bytes:
        hit = self._cache.get(url)
        if hit and _time.time() - hit[0] < self.cache_seconds:
            return hit[1]  # type: ignore[return-value]
        status, raw = self._t(url, {"User-Agent": "Mozilla/5.0 (tradebot)", "Accept": "*/*"})
        if status >= 400:
            raise RuntimeError(f"{url.split('?')[0]} -> {status}: {raw[:120]!r}")
        self._cache[url] = (_time.time(), raw)
        return raw

    def economic_events(self) -> list[MacroEvent]:
        return parse_economic(json.loads(self._fetch(self.calendar_url).decode() or "[]"))

    def symbol_headlines(self, symbol: str) -> list[Headline]:
        return parse_rss(self._fetch(YAHOO_RSS.format(symbol=urllib.parse.quote(symbol))), "Yahoo Finance")

    def headlines(self) -> list[Headline]:
        return []  # no general digest without a key; per-symbol feeds are used instead

    def earnings(self) -> dict[str, str]:
        return {}

    def notes(self, symbols: list[str], per_symbol: int = 2, max_age_hours: int = 36) -> str:
        lines, cutoff = [], clock.now_et() - timedelta(hours=max_age_hours)
        for sym in symbols:
            if "/" in sym:  # crypto pairs have no Yahoo equity feed
                continue
            try:
                heads = [h for h in self.symbol_headlines(sym) if h.time is None or h.time >= cutoff]
            except Exception as exc:
                log.debug("%s headlines: %s", sym, exc)
                continue
            if heads:
                lines.append(f"{sym}: " + " | ".join(h.title[:110] for h in heads[:per_symbol]))
        return "\n".join(lines)


def make_news(settings):
    """World Monitor when a key is configured, otherwise the free sources."""
    if getattr(settings, "worldmonitor_api_key", ""):
        return WorldMonitor(settings.worldmonitor_api_key)
    return FreeNews(getattr(settings, "macro_calendar_url", "") or FF_CALENDAR)


def blackout(events: list[MacroEvent], now: datetime, before_min: int, after_min: int) -> MacroEvent | None:
    """The high-impact US event whose blackout window contains ``now``, if any."""
    for e in events:
        if e.time is None or not e.high_impact or not e.us:
            continue
        if e.time - timedelta(minutes=before_min) <= now <= e.time + timedelta(minutes=after_min):
            return e
    return None


def watchlist_notes(symbols: list[str], headlines: list[Headline], earnings: dict[str, str],
                    per_symbol: int = 2) -> str:
    lines = []
    for s in symbols:
        bits = []
        if s.upper() in earnings:
            bits.append(f"earnings {earnings[s.upper()]}")
        for h in mentions(s, headlines)[:per_symbol]:
            bits.append(h.title[:110] + (f" ({h.source})" if h.source else ""))
        if bits:
            lines.append(f"{s}: " + " | ".join(bits))
    return "\n".join(lines)
