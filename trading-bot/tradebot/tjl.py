"""Trend Join Long: gap-and-go momentum continuation, defined by ``rules.json``.

    Daily    D1 price above the prior day's high
             D2 prior close above the 200-day SMA
             D3 today's open gapped >= 3% above the prior close
    Intraday I1 price above the premarket high (when premarket bars exist)
             I2 the bar closes at a new high of day  <- this is the trigger
             I3 relative volume >= 2.0 vs the same time of day over 14 sessions
    Time     entries 10:05-15:30 ET, everything flat at 15:51
    Exit     stop = low of day - 1%; a third off at +0.75R; breakeven at +1R;
             then trail under confirmed 5-minute swing lows (2 bars each side)
    Risk     1% per trade, 10% of equity per position, 5 positions

Long-only, one trade per symbol per day (enforced by the loop/backtester).
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, time, timedelta
from pathlib import Path

from . import clock
from .exits import ExitRules
from .indicators import sma
from .models import LONG, Bar, Signal
from .strategy import LoadedStrategy, rth_bars


@dataclass
class TJLRules:
    name: str = "Trend Join Long"
    min_market_cap_usd: float = 1e9
    min_price_usd: float = 3.0
    index: str = ""
    above_prior_day_high: bool = True
    prior_close_above_sma200: bool = True
    sma_days: int = 200
    min_gap_pct: float = 3.0
    above_premarket_high: bool = True
    above_today_hod: bool = True
    rvol_min: float = 2.0
    rvol_lookback_days: int = 14
    earliest_entry: str = "10:05"
    latest_entry: str = "15:30"
    force_close: str = "15:51"
    initial_stop_rule: str = "lod_minus_1pct"
    partial_r: float = 0.75
    partial_fraction: float = 1 / 3
    breakeven_r: float = 1.0
    trail: str = "swing_low_5m_2_2"
    max_risk_per_trade_pct: float = 1.0
    max_position_pct: float = 10.0
    max_positions: int = 5

    @classmethod
    def from_dict(cls, raw: dict) -> "TJLRules":
        u, d, i, t, e, r = (raw.get(k, {}) for k in
                            ("universe_filters", "daily_filters", "intraday_filters", "time_filter", "exit", "risk"))
        return cls(
            name=raw.get("strategy_name", cls.name),
            min_market_cap_usd=float(u.get("min_market_cap_usd", 0) or 0),
            min_price_usd=float(u.get("min_price_usd", 0) or 0),
            index=str(u.get("index", "")),
            above_prior_day_high=bool(d.get("D1_above_prior_day_high", True)),
            prior_close_above_sma200=bool(d.get("D2_prior_close_above_sma200", True)),
            min_gap_pct=float(d.get("D3_min_gap_pct_from_prior_close", 3.0)),
            above_premarket_high=bool(i.get("I1_above_premarket_high", True)),
            above_today_hod=bool(i.get("I2_above_today_hod", True)),
            rvol_min=float(i.get("I3_rvol_min", 2.0)),
            rvol_lookback_days=int(i.get("I3_rvol_lookback_days", 14)),
            earliest_entry=str(t.get("earliest_entry_et", "10:05")),
            latest_entry=str(t.get("latest_entry_et", "15:30")),
            force_close=str(t.get("force_close_et", "15:51")),
            initial_stop_rule=str(e.get("initial_stop_rule", "lod_minus_1pct")),
            partial_r=float(e.get("partial_profit_trigger_R", 0.75)),
            partial_fraction=float(e.get("partial_profit_fraction", 1 / 3)),
            breakeven_r=float(e.get("breakeven_trigger_R", 1.0)),
            trail=str(e.get("post_breakeven_trail", "swing_low_5m_2_2")),
            max_risk_per_trade_pct=float(r.get("max_risk_per_trade_pct", 1.0)),
            max_position_pct=float(r.get("max_position_size_pct_of_portfolio", 10)),
            max_positions=int(r.get("max_concurrent_positions", 5)),
        )

    @classmethod
    def load(cls, path: str | Path = "rules.json") -> "TJLRules":
        return cls.from_dict(json.loads(Path(path).read_text()))

    def exit_rules(self) -> ExitRules:
        mode, left, right = "swing_low", 2, 2
        parts = self.trail.split("_")  # swing_low_5m_2_2
        if self.trail.startswith("swing_low") and len(parts) >= 5:
            left, right = int(parts[-2]), int(parts[-1])
        elif self.trail.startswith("atr"):
            mode = "atr"
        elif self.trail in ("none", ""):
            mode = "none"
        return ExitRules(partial_r=self.partial_r, partial_fraction=self.partial_fraction,
                         breakeven_r=self.breakeven_r, trail_mode=mode, swing_left=left, swing_right=right,
                         trail_after_breakeven_only=True, final_target_r=0.0, time_stop_minutes=0)

    def stop_for(self, lod: float) -> float:
        if self.initial_stop_rule.startswith("lod_minus_") and self.initial_stop_rule.endswith("pct"):
            pct = float(self.initial_stop_rule[len("lod_minus_"):-3])
            return lod * (1 - pct / 100.0)
        if self.initial_stop_rule == "lod":
            return lod
        raise ValueError(f"unknown initial_stop_rule {self.initial_stop_rule!r}")


def premarket_high(bars_today: list[Bar]) -> float | None:
    pm = [b for b in bars_today if b.time.time() < clock.MARKET_OPEN]
    return max(b.high for b in pm) if pm else None


def relative_volume(all_rth: list[Bar], today: list[Bar], lookback: int,
                    daily: list[Bar] | None = None) -> float | None:
    """Today's cumulative volume vs the average cumulative volume at the same
    time of day over the previous ``lookback`` sessions. Falls back to a
    daily-volume pro-rata when there is not enough intraday history."""
    if not today:
        return None
    elapsed = clock.minutes_since_open(today[-1].time)
    by_day: dict = {}
    for b in all_rth:
        if b.time.date() < today[-1].time.date():
            by_day.setdefault(b.time.date(), []).append(b)
    sessions = sorted(by_day)[-lookback:]
    cum_today = sum(b.volume for b in today)
    if len(sessions) >= 5:
        refs = [sum(b.volume for b in by_day[d] if clock.minutes_since_open(b.time) <= elapsed) for d in sessions]
        refs = [v for v in refs if v > 0]
        if refs:
            return cum_today / (sum(refs) / len(refs))
    if daily:
        prior = [d for d in daily if d.time.date() < today[-1].time.date()][-max(lookback, 5):]
        if len(prior) >= 5:
            avg = sum(d.volume for d in prior) / len(prior)
            expected = avg * min((elapsed + 5) / 390.0, 1.0)
            if expected > 0:
                return cum_today / expected
    return None


class TrendJoinLong:
    scan_kind = "gap"
    include_premarket = True

    def __init__(self, rules: TJLRules | None = None):
        self.r = rules or TJLRules()
        self.name = self.r.name
        self.window_start: time = clock.parse_hhmm(self.r.earliest_entry)
        self.window_end: time = clock.parse_hhmm(self.r.latest_entry)
        self.intraday_days = self.r.rvol_lookback_days + 4
        self.bar_minutes = 5

    def day_ok(self, open_price: float, prior_daily: list[Bar]) -> bool:
        """Cheap once-per-day check (gap + SMA); lets the backtester skip the rest."""
        if not prior_daily:
            return False
        prior = prior_daily[-1]
        if self.r.prior_close_above_sma200:
            avg = sma([d.close for d in prior_daily], self.r.sma_days)
            if avg is None or prior.close <= avg:
                return False
        gap = (open_price - prior.close) / prior.close * 100.0 if prior.close else 0.0
        return gap >= self.r.min_gap_pct

    def evaluate(self, symbol: str, intraday: list[Bar], daily: list[Bar],
                 now: datetime) -> Signal | None:
        now = clock.to_et(now)
        r = self.r
        if not clock.in_window(now, self.window_start, self.window_end):
            return None
        # today's completed bars, taken from the (ascending) tail without scanning history
        width = timedelta(minutes=self.bar_minutes)
        today_all: list[Bar] = []
        for b in reversed(intraday):
            if b.time.date() != now.date():
                if b.time.date() < now.date():
                    break
                continue
            if b.time + width <= now:
                today_all.append(b)
        today_all.reverse()
        today = [b for b in today_all if clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE]
        if len(today) < 2:
            return None
        prior_daily = daily if (daily and daily[-1].time.date() < now.date()) \
            else [d for d in daily if d.time.date() < now.date()]
        if not prior_daily:
            return None
        prior = prior_daily[-1]
        last, earlier = today[-1], today[:-1]

        # daily filters (cheap, checked first)
        if not self.day_ok(today[0].open, prior_daily):
            return None
        gap = (today[0].open - prior.close) / prior.close * 100.0
        if r.above_prior_day_high and last.close <= prior.high:
            return None

        # intraday filters
        if r.above_premarket_high:
            pm_high = premarket_high(today_all)
            if pm_high is not None and last.close <= pm_high:
                return None
        hod_before = max(b.high for b in earlier)
        if r.above_today_hod and last.close <= hod_before:
            return None
        # only now pay for the volume profile over the lookback history
        history = [b for b in intraday if b.time + width <= now]
        rvol = relative_volume(rth_bars(history), today, r.rvol_lookback_days, daily)
        if rvol is None or rvol < r.rvol_min:
            return None
        if last.close < r.min_price_usd:
            return None

        # risk geometry
        lod = min(b.low for b in today)
        entry = last.close
        stop = round(r.stop_for(lod), 2)
        risk = entry - stop
        if risk <= 0:
            return None
        reason = (f"TJL gap {gap:+.1f}% new HOD > {hod_before:.2f}, prior high {prior.high:.2f}, "
                  f"relvol {rvol:.2f}, LOD {lod:.2f}")
        return Signal(symbol=symbol, side=LONG, entry=round(entry, 2), stop=stop,
                      target=round(entry + 2 * risk, 2), atr=risk, time=now, reason=reason)


def load_tjl(path: str | Path = "rules.json") -> LoadedStrategy:
    rules = TJLRules.load(path)
    strat = TrendJoinLong(rules)
    return LoadedStrategy(
        name=rules.name, strategy=strat, exits=rules.exit_rules(),
        intraday_days=strat.intraday_days, include_premarket=True, scan_kind="gap",
        scan_at=time(9, 36), force_close=clock.parse_hhmm(rules.force_close),
        risk_overrides={"risk_per_trade_pct": rules.max_risk_per_trade_pct,
                        "max_position_pct": rules.max_position_pct,
                        "max_positions": rules.max_positions,
                        "allow_shorts": False},
    )
