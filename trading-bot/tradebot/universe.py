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
