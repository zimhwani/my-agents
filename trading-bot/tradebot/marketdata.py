"""Market data providers.

Trading 212's API carries no price history or quotes, so bars come from a
separate provider. ``YFinanceData`` (Yahoo Finance via the ``yfinance``
package) is the free default. Anything with the same four methods works:
swap in Polygon, Alpaca, Twelve Data, etc. by implementing ``DataProvider``.
"""

from __future__ import annotations

import logging
import math
import time as _time
from datetime import datetime
from typing import Protocol

from . import clock
from .models import Bar

log = logging.getLogger("tradebot.marketdata")


class DataProvider(Protocol):
    def daily_bars(self, symbol: str, days: int) -> list[Bar]: ...
    def intraday_bars(self, symbol: str, bar_minutes: int, days: int) -> list[Bar]: ...
    def last_price(self, symbol: str) -> float | None: ...
    def fx_rate(self, base: str, quote: str) -> float: ...


def frame_to_bars(frame, daily: bool = False) -> list[Bar]:
    """Convert an OHLCV DataFrame (yfinance layout: tz-aware DatetimeIndex,
    columns Open/High/Low/Close/Volume) into Bars. Works on anything exposing
    ``.index`` and ``.to_dict("records")``."""
    out: list[Bar] = []
    for ts, row in zip(frame.index, frame.to_dict("records")):
        o, h, l, c = row.get("Open"), row.get("High"), row.get("Low"), row.get("Close")
        if any(v is None or (isinstance(v, float) and math.isnan(v)) for v in (o, h, l, c)):
            continue
        dt = ts.to_pydatetime() if hasattr(ts, "to_pydatetime") else ts
        if daily:
            t = clock.at(dt.date(), clock.MARKET_CLOSE)
        else:
            t = clock.to_et(dt)
        v = row.get("Volume") or 0.0
        out.append(Bar(t, float(o), float(h), float(l), float(c), float(v)))
    out.sort(key=lambda b: b.time)
    return out


class YFinanceData:
    """Free Yahoo Finance data. Intraday bars are near real-time for US
    equities but can lag by a minute or more; treat it as good enough for
    paper trading and a 5-minute strategy, not for scalping."""

    def __init__(self, cache_seconds: float = 20.0):
        import yfinance as yf  # imported lazily so tests/backtests don't need it
        self._yf = yf
        self._cache: dict[tuple, tuple[float, object]] = {}
        self.cache_seconds = cache_seconds

    def _cached(self, key: tuple, ttl: float, fn):
        hit = self._cache.get(key)
        now = _time.time()
        if hit and now - hit[0] < ttl:
            return hit[1]
        val = fn()
        self._cache[key] = (now, val)
        return val

    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        def fetch():
            df = self._yf.Ticker(symbol).history(period="6mo", interval="1d", auto_adjust=False)
            return frame_to_bars(df, daily=True)
        bars = self._cached(("d", symbol), 3600, fetch)
        # drop today's still-forming daily bar; callers treat daily bars as closed sessions
        today = clock.now_et().date()
        return [b for b in bars if b.time.date() < today][-days:]

    def intraday_bars(self, symbol: str, bar_minutes: int = 5, days: int = 5) -> list[Bar]:
        def fetch():
            df = self._yf.Ticker(symbol).history(period=f"{min(days, 59)}d", interval=f"{bar_minutes}m",
                                                 prepost=False, auto_adjust=False)
            return frame_to_bars(df)
        return self._cached(("i", symbol, bar_minutes), self.cache_seconds, fetch)

    def last_price(self, symbol: str) -> float | None:
        def fetch():
            t = self._yf.Ticker(symbol)
            try:
                px = t.fast_info.last_price
                if px and not math.isnan(px):
                    return float(px)
            except Exception as exc:  # fast_info is best-effort
                log.debug("%s fast_info failed: %s", symbol, exc)
            bars = frame_to_bars(t.history(period="1d", interval="1m", prepost=False, auto_adjust=False))
            return bars[-1].close if bars else None
        return self._cached(("p", symbol), self.cache_seconds, fetch)

    def fx_rate(self, base: str, quote: str) -> float:
        base, quote = base.upper(), quote.upper()
        if base == quote:
            return 1.0
        def fetch():
            px = self._yf.Ticker(f"{base}{quote}=X").fast_info.last_price
            if not px or math.isnan(px):
                raise RuntimeError(f"no FX rate for {base}{quote}")
            return float(px)
        return self._cached(("fx", base, quote), 3600, fetch)
