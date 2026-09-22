"""Crypto Momentum Breakout: a 24/7, long-only, let-it-run strategy from ``crypto.json``.

    Entry  a 15-minute bar closes above the highest high of the previous
           ``breakout_bars`` bars (first such bar only), price above the
           ``trend_ema_bars`` EMA, bar volume >= ``min_rel_volume`` x the
           20-bar average.
    Stop   ``stop_atr_mult`` x ATR below the entry (skip if wider than
           ``max_initial_risk_pct`` of price).
    Exit   a third off at +1.5R, breakeven at +1.5R, then a 3-ATR trail with
           no fixed target (winners can run for days); time stop after 24h if
           the trade never reached +0.5R. No forced close: crypto never closes.
    Risk   1% per trade, 25% of equity per position, 4 positions,
           optional cooldown per symbol after an exit (crypto.json, 0 = none).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, time, timedelta
from pathlib import Path

from . import clock
from .exits import ExitRules
from .indicators import atr as atr_of, ema, rsi
from .models import LONG, Bar, Signal
from .strategy import LoadedStrategy

DEFAULT_UNIVERSE = ["BTC/USD", "ETH/USD", "SOL/USD", "DOGE/USD", "AVAX/USD", "LINK/USD", "LTC/USD", "DOT/USD"]


@dataclass
class CryptoRules:
    name: str = "Crypto Momentum Breakout"
    universe: list[str] = field(default_factory=lambda: list(DEFAULT_UNIVERSE))
    bar_minutes: int = 15
    mode: str = "breakout"          # breakout = first close above the N-bar high; pullback = RSI dip in an uptrend
    rsi_bars: int = 14
    rsi_buy: float = 30.0           # pullback: previous bar's RSI must be below this
    breakout_bars: int = 20
    trend_ema_bars: int = 200
    min_rel_volume: float = 1.5
    atr_bars: int = 14
    stop_atr_mult: float = 2.0
    min_initial_risk_pct: float = 0.0  # widen tiny stops so fees stay a fraction of 1R
    max_initial_risk_pct: float = 6.0
    partial_r: float = 1.5
    partial_fraction: float = 1 / 3
    breakeven_r: float = 1.5
    trail: str = "atr_3.0"
    time_stop_minutes: int = 1440
    time_stop_min_r: float = 0.5
    cooldown_minutes: int = 120
    max_risk_per_trade_pct: float = 1.0
    max_position_pct: float = 25.0
    max_positions: int = 4

    @classmethod
    def from_dict(cls, raw: dict) -> "CryptoRules":
        e, x, r = raw.get("entry", {}), raw.get("exit", {}), raw.get("risk", {})
        return cls(
            name=raw.get("strategy_name", cls.name),
            universe=[s.upper() for s in raw.get("universe", DEFAULT_UNIVERSE)],
            bar_minutes=int(raw.get("bar_minutes", 15)),
            mode=str(raw.get("mode", e.get("mode", "breakout"))).lower(),
            rsi_bars=int(e.get("rsi_bars", 14)), rsi_buy=float(e.get("rsi_buy", 30.0)),
            breakout_bars=int(e.get("breakout_bars", 20)), trend_ema_bars=int(e.get("trend_ema_bars", 200)),
            min_rel_volume=float(e.get("min_rel_volume", 1.5)), atr_bars=int(e.get("atr_bars", 14)),
            stop_atr_mult=float(e.get("stop_atr_mult", 2.0)),
            min_initial_risk_pct=float(e.get("min_initial_risk_pct", 0.0)),
            max_initial_risk_pct=float(e.get("max_initial_risk_pct", 6.0)),
            partial_r=float(x.get("partial_profit_trigger_R", 1.5)),
            partial_fraction=float(x.get("partial_profit_fraction", 1 / 3)),
            breakeven_r=float(x.get("breakeven_trigger_R", 1.5)), trail=str(x.get("trail", "atr_3.0")),
            time_stop_minutes=int(x.get("time_stop_minutes", 1440)), time_stop_min_r=float(x.get("time_stop_min_r", 0.5)),
            cooldown_minutes=int(x.get("cooldown_minutes", 120)),
            max_risk_per_trade_pct=float(r.get("max_risk_per_trade_pct", 1.0)),
            max_position_pct=float(r.get("max_position_size_pct_of_portfolio", 25)),
            max_positions=int(r.get("max_concurrent_positions", 4)),
        )

    @classmethod
    def load(cls, path: str | Path = "crypto.json") -> "CryptoRules":
        return cls.from_dict(json.loads(Path(path).read_text()))

    def exit_rules(self) -> ExitRules:
        mode, mult = "atr", 3.0
        if self.trail.startswith("atr_"):
            mult = float(self.trail[4:])
        elif self.trail in ("none", ""):
            mode = "none"
        return ExitRules(partial_r=self.partial_r, partial_fraction=self.partial_fraction,
                         breakeven_r=self.breakeven_r, trail_mode=mode, trail_atr_mult=mult,
                         trail_after_breakeven_only=True, final_target_r=0.0,
                         time_stop_minutes=self.time_stop_minutes, time_stop_min_r=self.time_stop_min_r,
                         fractional=True)


class CryptoMomentum:
    scan_kind = "static"
    include_premarket = True  # irrelevant for crypto; keep every bar

    def __init__(self, rules: CryptoRules | None = None):
        self.r = rules or CryptoRules()
        self.name = self.r.name
        self.bar_minutes = self.r.bar_minutes
        self.window_start: time = time(0, 0)
        self.window_end: time = time(23, 59, 59)
        bars_needed = self.r.trend_ema_bars + max(self.r.breakout_bars, self.r.rsi_bars * 6) + 5
        self.intraday_days = max(3, int(bars_needed * self.bar_minutes / 1440) + 2)

    # gates, in the order they are checked; explain() reports the first one that fails
    GATES = ("history", "no_breakout", "not_first_bar", "below_ema", "low_relvol", "no_dip", "no_turn",
             "no_atr", "stop_too_wide", "signal")

    def evaluate(self, symbol: str, intraday: list[Bar], daily: list[Bar], now: datetime) -> Signal | None:
        return self._eval(symbol, intraday, now)[0]

    def evaluate_explained(self, symbol: str, intraday: list[Bar], daily: list[Bar],
                           now: datetime) -> tuple[Signal | None, str]:
        """evaluate() plus the name of the gate that decided it (the live loop logs these)."""
        return self._eval(symbol, intraday, now)

    def explain(self, symbol: str, intraday: list[Bar], now: datetime) -> str:
        """Name of the gate that rejected the latest completed bar ('signal' if it passed)."""
        return self._eval(symbol, intraday, now)[1]

    def _eval(self, symbol: str, intraday: list[Bar], now: datetime) -> tuple[Signal | None, str]:
        now = clock.to_et(now)
        r = self.r
        width = timedelta(minutes=self.bar_minutes)
        bars = [b for b in intraday if b.time + width <= now]
        need = r.trend_ema_bars + max(r.breakout_bars, r.rsi_bars * 3) + 2
        if len(bars) < need:
            return None, "history"
        if r.mode == "pullback":
            return self._eval_pullback(symbol, bars, now)
        last, prev = bars[-1], bars[-2]
        window = bars[-(r.breakout_bars + 1):-1]
        hh = max(b.high for b in window)
        if last.close <= hh:
            return None, "no_breakout"
        prev_window = bars[-(r.breakout_bars + 2):-2]
        if prev.close > max(b.high for b in prev_window):
            return None, "not_first_bar"  # already broke out on the previous bar; take the first bar only
        closes = [b.close for b in bars[-(r.trend_ema_bars * 4):]]  # 4x warm-up is plenty; keeps replays fast
        trend = ema(closes, r.trend_ema_bars)
        if trend is None or last.close <= trend:
            return None, "below_ema"
        vols = [b.volume for b in window]
        avg_vol = sum(vols) / len(vols) if vols else 0.0
        rel = last.volume / avg_vol if avg_vol > 0 else 0.0
        if rel < r.min_rel_volume:
            return None, "low_relvol"
        a = atr_of(bars[-(r.atr_bars * 4):], r.atr_bars)
        if not a or a <= 0:
            return None, "no_atr"
        entry = last.close
        stop = entry - r.stop_atr_mult * a
        if r.min_initial_risk_pct > 0:
            stop = min(stop, entry * (1 - r.min_initial_risk_pct / 100.0))
        risk = entry - stop
        if risk <= 0 or risk / entry * 100.0 > r.max_initial_risk_pct:
            return None, "stop_too_wide"
        reason = f"breakout > {hh:.4g} ({r.breakout_bars} bars), EMA{r.trend_ema_bars} {trend:.4g}, relvol {rel:.2f}, ATR {a:.4g}"
        return Signal(symbol=symbol, side=LONG, entry=entry, stop=round(stop, 6), target=round(entry + 3 * risk, 6),
                      atr=a, time=now, reason=reason), "signal"


    def _eval_pullback(self, symbol: str, bars: list[Bar], now: datetime) -> tuple[Signal | None, str]:
        """Buy the first green bar after an RSI dip while price holds above the trend EMA.
        Stop below the dip low (at least stop_atr_mult ATRs)."""
        r = self.r
        last, prev = bars[-1], bars[-2]
        closes = [b.close for b in bars[-(r.trend_ema_bars * 4):]]
        trend = ema(closes, r.trend_ema_bars)
        if trend is None or last.close <= trend:
            return None, "below_ema"
        rsi_prev = rsi([b.close for b in bars[-(r.rsi_bars * 6) - 1:-1]], r.rsi_bars)
        if rsi_prev is None or rsi_prev >= r.rsi_buy:
            return None, "no_dip"
        if last.close <= last.open or last.close <= prev.close:
            return None, "no_turn"
        rsi_before = rsi([b.close for b in bars[-(r.rsi_bars * 6) - 2:-2]], r.rsi_bars)
        if rsi_before is not None and rsi_before < r.rsi_buy and prev.close > prev.open and prev.close > bars[-3].close:
            return None, "not_first_bar"  # the turn already printed on the previous bar
        a = atr_of(bars[-(r.atr_bars * 4):], r.atr_bars)
        if not a or a <= 0:
            return None, "no_atr"
        entry = last.close
        dip_low = min(b.low for b in bars[-4:])
        stop = min(entry - r.stop_atr_mult * a, dip_low)
        if r.min_initial_risk_pct > 0:
            stop = min(stop, entry * (1 - r.min_initial_risk_pct / 100.0))
        risk = entry - stop
        if risk <= 0 or risk / entry * 100.0 > r.max_initial_risk_pct:
            return None, "stop_too_wide"
        reason = f"pullback RSI{r.rsi_bars} {rsi_prev:.0f} < {r.rsi_buy:.0f}, EMA{r.trend_ema_bars} {trend:.4g}, ATR {a:.4g}"
        return Signal(symbol=symbol, side=LONG, entry=entry, stop=round(stop, 6), target=round(entry + 3 * risk, 6),
                      atr=a, time=now, reason=reason), "signal"


def loaded_from_rules(rules: CryptoRules) -> LoadedStrategy:
    strat = CryptoMomentum(rules)
    return LoadedStrategy(
        name=rules.name, strategy=strat, exits=rules.exit_rules(), intraday_days=strat.intraday_days,
        include_premarket=True, scan_kind="static", scan_at=time(0, 0), force_close=None,
        risk_overrides={"risk_per_trade_pct": rules.max_risk_per_trade_pct,
                        "max_position_pct": rules.max_position_pct, "max_positions": rules.max_positions,
                        "allow_shorts": False},
        continuous=True, fractional=True, cooldown_minutes=rules.cooldown_minutes, universe=list(rules.universe),
    )


def load_crypto(path: str | Path = "crypto.json") -> LoadedStrategy:
    return loaded_from_rules(CryptoRules.load(path))
