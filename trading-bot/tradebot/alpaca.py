"""Alpaca Market Data as a ``DataProvider`` (REST v2, standard library only).

Why: Yahoo caps 5-minute history at 60 days; Alpaca's free plan serves years
of minute bars from the IEX feed plus real-time IEX quotes, with 200 requests
per minute. Sign up at https://alpaca.markets, create (paper) API keys, and set

    DATA_PROVIDER=alpaca
    ALPACA_API_KEY=...
    ALPACA_API_SECRET=...
    ALPACA_FEED=iex          # sip needs the paid plan

Alpaca has no FX rates or market caps, so those come from Yahoo (``yfinance``)
when it is installed; otherwise FX falls back to 1.0 with a warning and market
caps are treated as unknown (the gap scanner then accepts the symbol).
"""

from __future__ import annotations

import json
import logging
import threading
import time as _time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Callable, Optional, Tuple

from . import clock
from .marketdata import Gapper
from .models import Bar

log = logging.getLogger("tradebot.alpaca")

DATA_BASE = "https://data.alpaca.markets"
TRADING_BASE = "https://paper-api.alpaca.markets"  # assets list only; the bot never sends Alpaca an order
Transport = Callable[[str, dict], Tuple[int, bytes]]


class AlpacaError(RuntimeError):
    pass


def _urllib_transport(url: str, headers: dict) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise AlpacaError(f"cannot reach data.alpaca.markets: {exc}") from exc


def _parse_ts(value: str) -> datetime:
    return clock.to_et(datetime.fromisoformat(value.replace("Z", "+00:00")))


def _bar(raw: dict) -> Bar:
    return Bar(_parse_ts(raw["t"]), float(raw["o"]), float(raw["h"]), float(raw["l"]), float(raw["c"]),
               float(raw.get("v") or 0))


class AlpacaData:
    def __init__(self, api_key: str, api_secret: str, feed: str = "iex", universe: list[str] | None = None,
                 transport: Transport | None = None, sleep: Callable[[float], None] = _time.sleep,
                 cache_seconds: float = 20.0, aux=None):
        if not api_key or not api_secret:
            raise AlpacaError("ALPACA_API_KEY and ALPACA_API_SECRET are required for DATA_PROVIDER=alpaca")
        self.headers = {"APCA-API-KEY-ID": api_key, "APCA-API-SECRET-KEY": api_secret,
                        "Accept": "application/json"}
        self.feed = feed
        self.universe = universe or []
        self._t = transport or _urllib_transport
        self._sleep = sleep
        self._last_call = 0.0
        self._lock = threading.Lock()
        self.cache_seconds = cache_seconds
        self._cache: dict[tuple, tuple[float, object]] = {}
        self._aux = aux  # optional YFinanceData for fx / market cap / screener
        if self._aux is None:
            try:
                from .marketdata import YFinanceData
                self._aux = YFinanceData()
            except Exception as exc:  # yfinance not installed
                log.warning("yfinance unavailable (%s): no FX rates / market caps", exc)

    # -- http --------------------------------------------------------------------
    def _get(self, path: str, params: dict, retries: int = 4, base: str = DATA_BASE):
        url = base + path + "?" + urllib.parse.urlencode({k: v for k, v in params.items() if v is not None})
        for attempt in range(retries + 1):
            with self._lock:  # ~200 req/min across all threads
                gap = 0.31 - (_time.monotonic() - self._last_call)
                if gap > 0:
                    self._sleep(gap)
                self._last_call = _time.monotonic()
            status, raw = self._t(url, self.headers)
            if status == 429 and attempt < retries:
                self._sleep(3.0 * (attempt + 1))
                continue
            text = raw.decode(errors="replace") if raw else ""
            if status in (401, 403):
                raise AlpacaError(f"Alpaca rejected the request ({status}): {text[:200]}. Check "
                                  "ALPACA_API_KEY/SECRET; on the free plan use ALPACA_FEED=iex.")
            if status >= 400:
                raise AlpacaError(f"Alpaca GET {path} -> {status}: {text[:200]}")
            return json.loads(text) if text.strip() else {}
        raise AlpacaError(f"Alpaca {path}: still rate limited after {retries} retries")

    def _cached(self, key: tuple, ttl: float, fn):
        hit = self._cache.get(key)
        now = _time.time()
        if hit and now - hit[0] < ttl:
            return hit[1]
        val = fn()
        self._cache[key] = (now, val)
        return val

    # -- bars ---------------------------------------------------------------------
    def bars(self, symbol: str, timeframe: str, start: datetime, end: datetime | None = None) -> list[Bar]:
        out: list[Bar] = []
        token = None
        while True:
            res = self._get(f"/v2/stocks/{symbol}/bars", {
                "timeframe": timeframe, "start": start.astimezone(timezone.utc).isoformat(),
                "end": end.astimezone(timezone.utc).isoformat() if end else None,
                "limit": 10000, "adjustment": "raw", "feed": self.feed, "sort": "asc",
                "page_token": token})
            out.extend(_bar(b) for b in res.get("bars") or [])
            token = res.get("next_page_token")
            if not token:
                break
        return out

    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        def fetch():
            start = clock.now_et() - timedelta(days=int(days * 1.6) + 10)
            bars = self.bars(symbol, "1Day", start)
            return [Bar(clock.at(b.time.date(), clock.MARKET_CLOSE), b.open, b.high, b.low, b.close, b.volume)
                    for b in bars]
        bars = self._cached(("d", symbol, days), 3600, fetch)
        today = clock.now_et().date()
        return [b for b in bars if b.time.date() < today][-days:]

    def intraday_bars(self, symbol: str, bar_minutes: int = 5, days: int = 5,
                      include_premarket: bool = False) -> list[Bar]:
        def fetch():
            start = clock.now_et() - timedelta(days=days + 2)
            return self.bars(symbol, f"{bar_minutes}Min", start)
        bars = self._cached(("i", symbol, bar_minutes, days), self.cache_seconds, fetch)
        if not include_premarket:
            bars = [b for b in bars if clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE]
        return bars

    def bars_between(self, symbol: str, timeframe: str, start: datetime, end: datetime) -> list[Bar]:
        return self.bars(symbol, timeframe, start, end)

    def assets(self, exchanges: tuple[str, ...] = ("NASDAQ", "NYSE", "ARCA", "AMEX")) -> list[str]:
        """Active, tradable US common stocks on the main exchanges (plain symbols only)."""
        rows = self._get("/v2/assets", {"status": "active", "asset_class": "us_equity"}, base=TRADING_BASE)
        out = []
        for a in rows or []:
            sym = a.get("symbol", "")
            if not a.get("tradable") or a.get("exchange") not in exchanges:
                continue
            if not sym.isalpha() or len(sym) > 5:
                continue  # skip units, warrants, preferreds, test symbols
            out.append(sym)
        return sorted(set(out))

    def multi_daily_bars(self, symbols: list[str], start: datetime, chunk: int = 200) -> dict[str, list[Bar]]:
        """Daily bars for many symbols via the multi-symbol endpoint (paginated)."""
        out: dict[str, list[Bar]] = {}
        for i in range(0, len(symbols), chunk):
            group = symbols[i:i + chunk]
            token = None
            while True:
                res = self._get("/v2/stocks/bars", {
                    "symbols": ",".join(group), "timeframe": "1Day",
                    "start": start.astimezone(timezone.utc).isoformat(), "limit": 10000,
                    "adjustment": "raw", "feed": self.feed, "sort": "asc", "page_token": token})
                for sym, rows in (res.get("bars") or {}).items():
                    out.setdefault(sym, []).extend(
                        Bar(clock.at(_parse_ts(b["t"]).date(), clock.MARKET_CLOSE), float(b["o"]), float(b["h"]),
                            float(b["l"]), float(b["c"]), float(b.get("v") or 0)) for b in rows)
                token = res.get("next_page_token")
                if not token:
                    break
        for rows in out.values():
            rows.sort(key=lambda b: b.time)
        return out

    # -- quotes -------------------------------------------------------------------
    def last_price(self, symbol: str) -> float | None:
        def fetch():
            res = self._get(f"/v2/stocks/{symbol}/trades/latest", {"feed": self.feed})
            p = (res.get("trade") or {}).get("p")
            return float(p) if p else None
        return self._cached(("p", symbol), self.cache_seconds, fetch)

    def snapshots(self, symbols: list[str]) -> dict[str, dict]:
        out: dict[str, dict] = {}
        for i in range(0, len(symbols), 100):
            chunk = symbols[i:i + 100]
            res = self._get("/v2/stocks/snapshots", {"symbols": ",".join(chunk), "feed": self.feed})
            out.update({k: v for k, v in res.items() if isinstance(v, dict)})
        return out

    def gappers(self, min_gap_pct: float, min_price: float, min_market_cap: float,
                limit: int = 100) -> list[Gapper]:
        """Gap scan: Yahoo's whole-market screener (when available) merged with
        Alpaca snapshots over the static universe (Alpaca has no screener).
        Market cap is checked via Yahoo when available."""
        out: list[Gapper] = []
        seen: set[str] = set()
        if self._aux is not None and hasattr(self._aux, "gappers"):
            try:
                for g in self._aux.gappers(min_gap_pct, min_price, min_market_cap, limit):
                    if g.symbol not in seen:
                        seen.add(g.symbol)
                        out.append(g)
            except Exception as exc:
                log.warning("Yahoo screener unavailable (%s); using the static universe only", exc)
        if not self.universe:
            return out[:limit]
        for sym, snap in self.snapshots(self.universe).items():
            if sym in seen:
                continue
            prev = (snap.get("prevDailyBar") or {}).get("c")
            today = snap.get("dailyBar") or {}
            price = (snap.get("latestTrade") or {}).get("p") or today.get("c")
            if not prev or not price:
                continue
            gap = (float(price) - float(prev)) / float(prev) * 100.0
            if gap < min_gap_pct or float(price) < min_price:
                continue
            cap = self.market_cap(sym)
            if cap is not None and cap < min_market_cap:
                continue
            seen.add(sym)
            out.append(Gapper(sym, float(price), gap, cap, float(prev)))
        out.sort(key=lambda g: -g.gap_pct)
        return out[:limit]

    # -- delegated to Yahoo when available ------------------------------------------
    def market_cap(self, symbol: str) -> float | None:
        if self._aux is None:
            return None
        try:
            return self._aux.market_cap(symbol)
        except Exception:
            return None

    def fx_rate(self, base: str, quote: str) -> float:
        if base.upper() == quote.upper():
            return 1.0
        if self._aux is not None:
            return self._aux.fx_rate(base, quote)
        log.warning("No FX source for %s%s; assuming 1.0 (install yfinance to fix)", base, quote)
        return 1.0
