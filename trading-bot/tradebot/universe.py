"""Universe scan: turn a broad list of liquid names into today's short watchlist.

Runs once before the open. Filters on price, average dollar volume and
volatility (ATR as % of price), then ranks by volatility and overnight gap so
the names most likely to produce a clean range breakout come first.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

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
                 min_price: float = 3.0, min_market_cap: float = 1e9):
        self.b = broker
        self.s = settings
        self.min_gap_pct = min_gap_pct
        self.min_price = min_price
        self.min_market_cap = min_market_cap

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
        return found[: self.s.max_watchlist]


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
