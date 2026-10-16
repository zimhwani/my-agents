"""Universe scan: turn a broad list of liquid names into today's short watchlist.

Runs once before the open. Filters on price, average dollar volume and
volatility (ATR as % of price), then ranks by volatility and overnight gap so
the names most likely to produce a clean range breakout come first.
"""

from __future__ import annotations

import logging
from collections import Counter
from dataclasses import dataclass
from typing import Callable

from . import clock
from .broker import Broker
from .config import Settings
from .indicators import atr

log = logging.getLogger("tradebot.universe")


@dataclass
class Candidate:
    symbol: str
    price: float
    avg_volume: float
    avg_dollar_volume: float
    atr_pct: float
    gap_pct: float
    score: float
    rejected: str = ""

    def line(self) -> str:
        return (f"{self.symbol:<6} ${self.price:>8.2f}  ATR {self.atr_pct:4.1f}%  "
                f"gap {self.gap_pct:+5.1f}%  $vol {self.avg_dollar_volume/1e6:6.0f}M")


class UniverseScanner:
    def __init__(self, broker: Broker, settings: Settings):
        self.b = broker
        self.s = settings

    def evaluate(self, symbol: str) -> Candidate | None:
        daily = self.b.daily_bars(symbol, 40)
        if len(daily) < 21:
            log.info("%s: not enough daily history (%d bars)", symbol, len(daily))
            return None
        recent = daily[-21:]
        prev_close = recent[-1].close
        avg_vol = sum(b.volume for b in recent[-20:]) / 20
        a = atr(recent, 14) or 0.0
        price = self.b.last_price(symbol) or prev_close
        gap = (price - prev_close) / prev_close * 100.0 if prev_close else 0.0
        c = Candidate(symbol=symbol, price=price, avg_volume=avg_vol,
                      avg_dollar_volume=avg_vol * prev_close, atr_pct=a / prev_close * 100.0,
                      gap_pct=gap, score=0.0)
        s = self.s
        if not (s.min_price <= price <= s.max_price):
            c.rejected = "price"
        elif c.avg_dollar_volume < s.min_avg_dollar_volume:
            c.rejected = "liquidity"
        elif c.atr_pct < s.min_atr_pct:
            c.rejected = "too quiet"
        c.score = c.atr_pct * (1.0 + min(abs(gap), 5.0) / 5.0)
        return c

    def scan(self, symbols: list[str] | None = None) -> list[Candidate]:
        symbols = symbols or self.s.universe
        out: list[Candidate] = []
        for sym in symbols:
            try:
                c = self.evaluate(sym)
            except Exception as exc:  # one bad symbol must not kill the scan
                log.warning("%s: scan error %s", sym, exc)
                continue
            if c is not None:
                out.append(c)
        accepted = sorted((c for c in out if not c.rejected), key=lambda c: -c.score)
        for c in out:
            log.info("%s %s", "ACCEPT" if not c.rejected else f"reject({c.rejected})", c.line())
        return accepted[: self.s.max_watchlist]


class GapScanner:
    """Post-open scan for Trend Join Long: stocks gapping >= min_gap_pct above
    the prior close, priced >= min_price, market cap >= min_cap. Uses the data
    provider's screener when available, otherwise checks the static universe
    symbol by symbol. Results are filtered to what the broker can trade."""

    def __init__(self, broker: Broker, settings: Settings, min_gap_pct: float = 3.0,
                 min_price: float = 3.0, min_market_cap: float = 1e9,
                 day_check: Callable | None = None, max_checked: int = 100):
        self.b = broker
        self.s = settings
        self.min_gap_pct = min_gap_pct
        self.min_price = min_price
        self.min_market_cap = min_market_cap
        # the strategy's daily filter (TJL: prior close above SMA200, gap): checked at scan time so the
        # watchlist slots go to names that can actually trade today, not the biggest gappers that can't
        self.day_check = day_check
        self.max_checked = max_checked
        self.summary = ""

    def _tradable(self, symbol: str) -> bool:
        check = getattr(self.b, "is_tradable", None)
        return bool(check(symbol)) if check else True

    def _from_screener(self) -> list[Candidate]:
        data = getattr(self.b, "data", None)
        fn = getattr(data, "gappers", None)
        if fn is None:
            return []
        out = []
        for g in fn(self.min_gap_pct, self.min_price, self.min_market_cap, limit=150):
            if not self._tradable(g.symbol):
                continue
            out.append(Candidate(symbol=g.symbol, price=g.price, avg_volume=0.0, avg_dollar_volume=0.0,
                                 atr_pct=0.0, gap_pct=g.gap_pct, score=g.gap_pct))
        return out

    def _from_universe(self, symbols: list[str]) -> list[Candidate]:
        data = getattr(self.b, "data", None)
        cap_fn = getattr(data, "market_cap", None)
        out = []
        for sym in symbols:
            try:
                if not self._tradable(sym):
                    continue
                daily = self.b.daily_bars(sym, 5)
                price = self.b.last_price(sym)
                if not daily or not price:
                    continue
                prev = daily[-1].close
                gap = (price - prev) / prev * 100.0 if prev else 0.0
                if gap < self.min_gap_pct or price < self.min_price:
                    continue
                cap = cap_fn(sym) if cap_fn else None
                if cap is not None and cap < self.min_market_cap:
                    continue
                out.append(Candidate(symbol=sym, price=price, avg_volume=0.0, avg_dollar_volume=0.0,
                                     atr_pct=0.0, gap_pct=gap, score=gap))
            except Exception as exc:
                log.warning("%s: gap scan error %s", sym, exc)
        return out

    def scan(self, symbols: list[str] | None = None) -> list[Candidate]:
        found = self._from_screener()
        source = "screener"
        if not found:
            found = self._from_universe(symbols or self.s.universe)
            source = "static universe"
        found.sort(key=lambda c: -c.gap_pct)
        for c in found:
            log.info("GAP %-6s $%8.2f  gap %+5.1f%%", c.symbol, c.price, c.gap_pct)
        log.info("Gap scan via %s: %d candidates", source, len(found))
        self.summary = f"{len(found)} gappers >= {self.min_gap_pct:g}% via {source}"
        if self.day_check is not None and found:
            return self._prefilter(found)
        return found[: self.s.max_watchlist]

    def _today_open(self, symbol: str, today) -> float | None:
        """Open of today's first regular-session bar: the strategy measures the gap from the open, not
        from the price at scan time (a flat open that runs 3% by 09:36 is not a gap)."""
        try:
            bars = self.b.intraday_bars(symbol, 5, 2, include_premarket=True)
        except Exception as exc:
            log.debug("%s: no intraday bars at scan (%s)", symbol, exc)
            return None
        rth = [b for b in bars or [] if b.time.date() == today and clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE]
        return rth[0].open if rth else None

    def _prefilter(self, found: list[Candidate]) -> list[Candidate]:
        """Keep gappers that pass the daily filter, biggest gap first, until the watchlist is full."""
        today = clock.now_et().date()
        kept: list[Candidate] = []
        why_not: Counter = Counter()
        for c in found[: self.max_checked]:
            if len(kept) >= self.s.max_watchlist:
                break
            try:
                prior = [d for d in self.b.daily_bars(c.symbol, 260) if d.time.date() < today]
                why, detail = self.day_check(self._today_open(c.symbol, today) or c.price, prior)
            except Exception as exc:  # data hiccup: let the live loop decide on the symbol
                log.warning("%s: daily filter check failed at scan (%s); keeping it", c.symbol, exc)
                kept.append(c)
                continue
            if why == "ok":
                kept.append(c)
            else:
                c.rejected = why
                why_not[why] += 1
                log.info("GAP %-6s dropped: %s (%s)", c.symbol, why, detail)
        if why_not:
            self.summary += "; dropped " + ", ".join(f"{n} {k}" for k, n in why_not.most_common())
        self.summary += f"; {len(kept)} pass the daily filters"
        log.info("Gap scan: %s", self.summary)
        return kept


class StaticScanner:
    """A fixed universe (crypto): every symbol is on the watchlist; ranked by 24h change."""

    def __init__(self, broker: Broker, settings: Settings, symbols: list[str]):
        self.b = broker
        self.s = settings
        self.symbols = symbols

    def scan(self, symbols: list[str] | None = None) -> list[Candidate]:
        out = []
        for sym in symbols or self.symbols:
            try:
                price = self.b.last_price(sym)
                daily = self.b.daily_bars(sym, 3)
                prev = daily[-1].close if daily else None
                gap = (price - prev) / prev * 100.0 if price and prev else 0.0
                out.append(Candidate(symbol=sym, price=price or 0.0, avg_volume=0.0, avg_dollar_volume=0.0,
                                     atr_pct=0.0, gap_pct=gap, score=gap))
            except Exception as exc:
                log.warning("%s: scan error %s", sym, exc)
        out.sort(key=lambda c: -c.gap_pct)
        return out
