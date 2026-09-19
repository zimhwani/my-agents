"""Event-driven data for gap strategies.

Backtesting a gap-and-go strategy on a fixed list of large caps tests the wrong
market: 3%+ gappers are mostly small and mid caps, and different names every
day. This module finds the *events* (symbol-days that gapped) across the whole
market from cheap daily bars, then plans the minimal set of 5-minute bar
ranges needed to replay them (each event day plus the sessions before it that
the relative-volume filter looks back over).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from .indicators import sma
from .models import Bar


@dataclass
class GapEvent:
    symbol: str
    day: date
    gap_pct: float
    prev_close: float
    open: float
    dollar_volume: float  # 20-day average, in the feed's own volume units


def find_gap_events(daily: dict[str, list[Bar]], min_gap_pct: float = 3.0, min_price: float = 3.0,
                    min_dollar_volume: float = 500_000.0, sma_days: int = 200,
                    require_sma: bool = True, start: date | None = None) -> list[GapEvent]:
    """Symbol-days where the open gapped >= min_gap_pct above the prior close,
    the prior close sat above its SMA, price >= min_price and the 20-day average
    dollar volume >= min_dollar_volume. ``daily`` must be ascending per symbol."""
    out: list[GapEvent] = []
    for sym, bars in daily.items():
        closes: list[float] = []
        dv: list[float] = []
        for i, b in enumerate(bars):
            if i > 0:
                prev = bars[i - 1]
                if (start is None or b.time.date() >= start) and prev.close > 0:
                    gap = (b.open - prev.close) / prev.close * 100.0
                    ok = gap >= min_gap_pct and b.open >= min_price
                    if ok and require_sma:
                        avg = sma(closes, sma_days)
                        ok = avg is not None and prev.close > avg
                    if ok:
                        recent = dv[-20:]
                        adv = sum(recent) / len(recent) if recent else 0.0
                        if adv >= min_dollar_volume:
                            out.append(GapEvent(sym, b.time.date(), gap, prev.close, b.open, adv))
            closes.append(b.close)
            dv.append(b.close * b.volume)
    out.sort(key=lambda e: (e.day, -e.gap_pct))
    return out


def plan_ranges(events: list[GapEvent], context_sessions: int = 16) -> dict[str, list[tuple[date, date]]]:
    """Per symbol, merged (start, end) calendar-date ranges covering each event day
    and ~context_sessions trading days before it."""
    back = timedelta(days=int(context_sessions * 1.5) + 4)
    per: dict[str, list[tuple[date, date]]] = {}
    for e in events:
        per.setdefault(e.symbol, []).append((e.day - back, e.day))
    for sym, ranges in per.items():
        ranges.sort()
        merged: list[tuple[date, date]] = []
        for s, e in ranges:
            if merged and s <= merged[-1][1] + timedelta(days=1):
                merged[-1] = (merged[-1][0], max(merged[-1][1], e))
            else:
                merged.append((s, e))
        per[sym] = merged
    return per


def summarize(events: list[GapEvent]) -> str:
    if not events:
        return "no gap events found"
    by_month: dict[str, int] = {}
    for e in events:
        k = e.day.strftime("%Y-%m")
        by_month[k] = by_month.get(k, 0) + 1
    days = {e.day for e in events}
    syms = {e.symbol for e in events}
    lines = [f"{len(events)} gap events · {len(syms)} symbols · {len(days)} days · "
             f"{len(events) / max(1, len(days)):.1f} per event day"]
    lines.append("per month: " + ", ".join(f"{k} {v}" for k, v in sorted(by_month.items())))
    return "\n".join(lines)
