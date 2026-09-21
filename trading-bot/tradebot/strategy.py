"""Strategy layer.

A strategy is anything with ``evaluate(symbol, intraday_bars, daily_bars, now)``
returning a :class:`Signal` or ``None``. Parameters live in ``strategy.json`` so
they can be tuned (by you, or by Claude) without touching code, and every
change can be re-checked with ``python -m tradebot backtest``.

The shipped strategy is a classic Opening Range Breakout (ORB):

    1. Opening range = high/low of the first N minutes (default 15).
    2. Entry = first 5-minute close above the range high (long) inside the
       entry window, with close > session VWAP, relative volume above a
       floor, and the stock above its 20-day EMA.
    3. Stop = range low, or entry - k*ATR if that is tighter.
    4. Exits are handled by :mod:`tradebot.exits` (partial at +1R, breakeven,
       ATR trail, hard target, time stop, forced close before the bell).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, fields
from datetime import datetime, time, timedelta
from pathlib import Path

from . import clock
from .exits import ExitRules
from .indicators import atr as atr_of, ema, vwap as vwap_of
from .models import LONG, SHORT, Bar, Signal


@dataclass
class StrategyParams:
    name: str = "Opening Range Breakout"
    description: str = ""
    bar_minutes: int = 5
    opening_range_minutes: int = 15
    entry_window_start: str = "09:45"
    entry_window_end: str = "11:30"
    min_or_pct: float = 0.3
    max_or_pct: float = 3.0
    min_rel_volume: float = 1.2
    require_above_vwap: bool = True
    require_daily_trend: bool = True
    trend_ema_days: int = 20
    atr_period: int = 14
    stop_atr_mult: float = 1.5
    max_risk_pct_of_price: float = 2.5
    target_r: float = 2.0
    # exit management (read by ExitManager)
    partial_r: float = 1.0
    partial_fraction: float = 0.5
    breakeven_after_partial: bool = True
    trail_atr_mult: float = 1.5
    final_target_r: float = 3.0
    time_stop_minutes: int = 120
    time_stop_min_r: float = 0.5

    @classmethod
    def load(cls, path: str | Path = "strategy.json") -> "StrategyParams":
        p = Path(path)
        if not p.exists():
            return cls()
        raw = json.loads(p.read_text())
        known = {f.name for f in fields(cls)}
        unknown = set(raw) - known
        if unknown:
            raise ValueError(f"Unknown keys in {p}: {sorted(unknown)}")
        return cls(**raw)

    def to_exit_rules(self) -> ExitRules:
        return ExitRules(partial_r=self.partial_r, partial_fraction=self.partial_fraction,
                         breakeven_r=self.partial_r if self.breakeven_after_partial else 0.0,
                         trail_mode="atr", trail_atr_mult=self.trail_atr_mult,
                         final_target_r=self.final_target_r, time_stop_minutes=self.time_stop_minutes,
                         time_stop_min_r=self.time_stop_min_r)

    @property
    def window_start(self) -> time:
        return clock.parse_hhmm(self.entry_window_start)

    @property
    def window_end(self) -> time:
        return clock.parse_hhmm(self.entry_window_end)


def rth_bars(bars: list[Bar]) -> list[Bar]:
    """Regular-session bars only (drops pre/post-market)."""
    return [b for b in bars if clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE]


def session_bars(bars: list[Bar], day) -> list[Bar]:
    """Regular-session bars (09:30-16:00 ET) for ``day``, ascending."""
    out = [b for b in bars if b.time.date() == day
           and clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE]
    out.sort(key=lambda b: b.time)
    return out


def completed_bars(bars: list[Bar], now: datetime, bar_minutes: int) -> list[Bar]:
    width = timedelta(minutes=bar_minutes)
    return [b for b in bars if b.time + width <= now]


class OpeningRangeBreakout:
    name = "Opening Range Breakout"
    intraday_days = 5
    include_premarket = False
    scan_kind = "orb"

    def __init__(self, params: StrategyParams | None = None, allow_shorts: bool = False):
        self.p = params or StrategyParams()
        self.allow_shorts = allow_shorts
        self.name = self.p.name
        self.window_start = self.p.window_start
        self.window_end = self.p.window_end

    # -- helpers ---------------------------------------------------------
    def _completed(self, bars: list[Bar], now: datetime) -> list[Bar]:
        """Only bars whose close is already known at ``now``."""
        width = timedelta(minutes=self.p.bar_minutes)
        return [b for b in bars if b.time + width <= now]

    def opening_range(self, today: list[Bar]) -> tuple[float, float, list[Bar]] | None:
        n = self.p.opening_range_minutes // self.p.bar_minutes
        or_bars = [b for b in today
                   if clock.minutes_since_open(b.time) < self.p.opening_range_minutes]
        if len(or_bars) < n:
            return None
        return max(b.high for b in or_bars), min(b.low for b in or_bars), or_bars

    def relative_volume(self, today: list[Bar], daily: list[Bar], now: datetime) -> float | None:
        """Today's session volume vs the average daily volume pro-rated by time."""
        prior = [d for d in daily if d.time.date() < now.date()]
        if len(prior) < 5:
            return None
        avg_daily = sum(d.volume for d in prior[-20:]) / len(prior[-20:])
        elapsed = max(clock.minutes_since_open(today[-1].time) + self.p.bar_minutes, self.p.bar_minutes)
        expected = avg_daily * min(elapsed / 390.0, 1.0)
        if expected <= 0:
            return None
        return sum(b.volume for b in today) / expected

    # -- main ------------------------------------------------------------
    def evaluate(self, symbol: str, intraday: list[Bar], daily: list[Bar],
                 now: datetime) -> Signal | None:
        now = clock.to_et(now)
        p = self.p
        if not clock.in_window(now, p.window_start, p.window_end):
            return None
        done = rth_bars(self._completed(intraday, now))
        today = session_bars(done, now.date())
        if not today:
            return None
        rng = self.opening_range(today)
        if rng is None:
            return None
        or_high, or_low, or_bars = rng
        last = today[-1]
        if clock.minutes_since_open(last.time) < p.opening_range_minutes:
            return None  # the latest completed bar is still part of the opening range
        or_pct = (or_high - or_low) / last.close * 100.0
        if not (p.min_or_pct <= or_pct <= p.max_or_pct):
            return None

        post = [b for b in today if b not in or_bars]
        if not post or post[-1] is not last:
            return None
        earlier = post[:-1]

        long_break = last.close > or_high and all(b.close <= or_high for b in earlier)
        short_break = last.close < or_low and all(b.close >= or_low for b in earlier)
        if not long_break and not (self.allow_shorts and short_break):
            return None
        side = LONG if long_break else SHORT

        # confirmations
        if p.require_above_vwap:
            v = vwap_of(today)
            if v is None:
                return None
            if side == LONG and last.close <= v:
                return None
            if side == SHORT and last.close >= v:
                return None
        rv = self.relative_volume(today, daily, now)
        if rv is not None and rv < p.min_rel_volume:
            return None
        if p.require_daily_trend:
            closes = [d.close for d in daily if d.time.date() < now.date()]
            trend = ema(closes, p.trend_ema_days)
            if trend is not None:
                if side == LONG and last.close < trend:
                    return None
                if side == SHORT and last.close > trend:
                    return None

        # risk geometry
        a = atr_of(done[-(p.atr_period * 4):], p.atr_period) or (or_high - or_low)
        entry = last.close
        if side == LONG:
            stop = max(or_low, entry - p.stop_atr_mult * a)
            risk = entry - stop
            target = entry + p.target_r * risk
        else:
            stop = min(or_high, entry + p.stop_atr_mult * a)
            risk = stop - entry
            target = entry - p.target_r * risk
        if risk <= 0 or risk / entry * 100.0 > p.max_risk_pct_of_price:
            return None
        level = f"OR high {or_high:.2f}" if side == LONG else f"OR low {or_low:.2f}"
        reason = f"ORB {side} close {entry:.2f} through {level}, OR {or_pct:.2f}%"
        if rv is not None:
            reason += f", relvol {rv:.2f}"
        return Signal(symbol=symbol, side=side, entry=round(entry, 2), stop=round(stop, 2),
                      target=round(target, 2), atr=a, time=now, reason=reason)


@dataclass
class LoadedStrategy:
    """A strategy plus everything the loop/backtester needs to run it."""
    name: str
    strategy: object              # has evaluate(symbol, intraday, daily, now)
    exits: ExitRules
    intraday_days: int = 5        # how much 5-minute history the strategy wants
    include_premarket: bool = False
    scan_kind: str = "orb"        # orb = pre-market volatility scan, gap = post-open gap scan
    scan_at: time = time(9, 0)    # earliest time the watchlist scan may run
    force_close: time | None = None
    risk_overrides: dict = None   # settings fields the strategy file dictates
    continuous: bool = False      # 24/7 market: no session, no forced close
    fractional: bool = False      # fractional quantities (crypto)
    cooldown_minutes: int = 0     # wait this long after closing a symbol before re-entering it
    universe: list[str] | None = None  # strategy-defined universe (overrides settings)

    def apply(self, settings) -> None:
        """Let the strategy file override risk/time settings it specifies."""
        for k, v in (self.risk_overrides or {}).items():
            setattr(settings, k, v)
        if self.force_close is not None:
            settings.force_close_time = self.force_close
        settings.continuous = self.continuous
        if self.universe:
            settings.universe = list(self.universe)
        settings.validate()


def build_strategy(params: StrategyParams, allow_shorts: bool = False):
    return OpeningRangeBreakout(params, allow_shorts=allow_shorts)


def load_strategy(path: str | Path, allow_shorts: bool = False) -> LoadedStrategy:
    """``rules.json`` (Trend Join Long) or ``strategy.json`` (ORB), by content."""
    p = Path(path)
    raw = json.loads(p.read_text()) if p.exists() else {}
    if raw.get("market") == "crypto":
        from .crypto import load_crypto
        return load_crypto(p)
    if "strategy_name" in raw or "daily_filters" in raw:
        from .tjl import load_tjl
        return load_tjl(p)
    params = StrategyParams.load(p)
    strat = OpeningRangeBreakout(params, allow_shorts=allow_shorts)
    return LoadedStrategy(name=params.name, strategy=strat, exits=params.to_exit_rules(),
                          intraday_days=5, include_premarket=False, scan_kind="orb",
                          scan_at=time(9, 0), force_close=None, risk_overrides={})
