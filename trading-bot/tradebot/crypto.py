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
from .models import LONG, SHORT, Bar, Signal
from .strategy import LoadedStrategy

DEFAULT_UNIVERSE = ["BTC/USD", "ETH/USD", "SOL/USD", "DOGE/USD", "AVAX/USD", "LINK/USD", "LTC/USD", "DOT/USD"]


@dataclass
class CryptoRules:
    name: str = "Crypto Momentum Breakout"
    universe: list[str] = field(default_factory=lambda: list(DEFAULT_UNIVERSE))
    bar_minutes: int = 15
    mode: str = "breakout"          # breakout = first close above the N-bar high; pullback = RSI dip in an uptrend;
                                    # fade = the breakout signal traded SHORT (backtest only: Alpaca spot can't short)
    rsi_bars: int = 14
    rsi_buy: float = 30.0           # pullback: previous bar's RSI must be below this
    squeeze_bars: int = 20          # squeeze: Bollinger length used for bandwidth
    squeeze_lookback: int = 180     # squeeze: bars of bandwidth history to rank against
    squeeze_pct: float = 0.2        # squeeze: bandwidth must sit in the lowest this-fraction of that history
    box_bars: int = 6               # squeeze: the compression box whose high must be broken
    final_target_r: float = 0.0     # close everything at this R (0 = no target; mean reversion uses one)
    trail_from_entry: bool = False  # True: trail from the first bar (chandelier); False: only after breakeven
    thesis: str = ""                # why the edge might exist (shown in the research report)
    risks: str = ""                 # what would break it (shown in the research report)
    direction: str = "long_only"    # long_only | both | short_only (shorts need a venue that allows them: CFDs)
    market: str = "crypto"          # crypto trades 7 days a week; cfd/fx close at weekends (fewer bars per day)
    first_bar_only: bool = True     # breakouts: only the first bar through the level (anti-chase for fast
                                    # entries); trend following sets False: any close beyond the channel counts
    session_start_utc: str = "00:00"  # session mode: the range is built from these bars (UTC) ...
    session_end_utc: str = "07:00"    # ... e.g. the Asian session before London opens
    entry_end_utc: str = "12:00"      # session mode: last bar close that may trigger an entry (UTC)
    fee_bps: float | None = None          # per-side cost for this market (None = backtester default)
    stop_slippage_bps: float | None = None
    stop_fill_lambda: float | None = None
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
            market=str(raw.get("market", "crypto")).lower(),
            first_bar_only=bool(e.get("first_bar_only", True)),
            universe=[s.upper() for s in raw.get("universe", DEFAULT_UNIVERSE)],
            bar_minutes=int(raw.get("bar_minutes", 15)),
            mode=str(raw.get("mode", e.get("mode", "breakout"))).lower(),
            rsi_bars=int(e.get("rsi_bars", 14)), rsi_buy=float(e.get("rsi_buy", 30.0)),
            squeeze_bars=int(e.get("squeeze_bars", 20)), squeeze_lookback=int(e.get("squeeze_lookback", 180)),
            squeeze_pct=float(e.get("squeeze_pct", 0.2)), box_bars=int(e.get("box_bars", 6)),
            final_target_r=float(x.get("final_target_R", 0.0)),
            trail_from_entry=bool(x.get("trail_from_entry", False)),
            thesis=str(raw.get("thesis", "")), risks=str(raw.get("risks", "")),
            direction=str(raw.get("direction", "long_only")).lower(),
            session_start_utc=str(e.get("session_start_utc", "00:00")),
            session_end_utc=str(e.get("session_end_utc", "07:00")),
            entry_end_utc=str(e.get("entry_end_utc", "12:00")),
            fee_bps=(lambda c: None if c.get("fee_bps_per_side") is None else float(c["fee_bps_per_side"]))(raw.get("costs", {})),
            stop_slippage_bps=(lambda c: None if c.get("stop_slippage_bps") is None else float(c["stop_slippage_bps"]))(raw.get("costs", {})),
            stop_fill_lambda=(lambda c: None if c.get("stop_fill_lambda") is None else float(c["stop_fill_lambda"]))(raw.get("costs", {})),
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
                         trail_after_breakeven_only=not self.trail_from_entry, trail_min_r=1.0,
                         final_target_r=self.final_target_r,
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
        bars_needed = self.r.trend_ema_bars + self._pattern_bars() + 5
        days = bars_needed * self.bar_minutes / 1440
        if self.r.market != "crypto":  # 5-day markets: ~5 trading days per 7, plus holidays and short sessions
            days = days * 7 / 5 * 1.25 + 4
        self.intraday_days = max(3, int(days) + 2)

    # gates, in the order they are checked; explain() reports the first one that fails
    GATES = ("history", "no_breakout", "not_first_bar", "below_ema", "low_relvol", "no_dip", "no_turn",
             "no_squeeze", "outside_window", "no_range", "no_atr", "stop_too_wide", "signal")

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
        need = r.trend_ema_bars + self._pattern_bars() + 2
        if len(bars) < need:
            return None, "history"
        if r.mode == "pullback":
            return self._eval_pullback(symbol, bars, now)
        if r.mode == "squeeze":
            return self._eval_squeeze(symbol, bars, now)
        if r.mode == "session":
            return self._eval_session(symbol, bars, now)
        last, prev = bars[-1], bars[-2]
        window = bars[-(r.breakout_bars + 1):-1]
        prev_window = bars[-(r.breakout_bars + 2):-2]
        hh, ll = max(b.high for b in window), min(b.low for b in window)
        can_long = r.direction != "short_only" or r.mode == "fade"
        can_short = r.direction in ("both", "short_only") and r.mode != "fade"
        if can_long and last.close > hh:
            short = False
            if r.first_bar_only and prev.close > max(b.high for b in prev_window):
                return None, "not_first_bar"  # already broke out on the previous bar; take the first bar only
        elif can_short and last.close < ll:
            short = True
            if r.first_bar_only and prev.close < min(b.low for b in prev_window):
                return None, "not_first_bar"
        else:
            return None, "no_breakout"
        closes = [b.close for b in bars[-(r.trend_ema_bars * 4):]]  # 4x warm-up is plenty; keeps replays fast
        trend = ema(closes, r.trend_ema_bars)
        if trend is None or (last.close >= trend if short else last.close <= trend):
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
        dist = r.stop_atr_mult * a
        if r.min_initial_risk_pct > 0:
            dist = max(dist, entry * r.min_initial_risk_pct / 100.0)
        if dist <= 0 or dist / entry * 100.0 > r.max_initial_risk_pct:
            return None, "stop_too_wide"
        if short:
            reason = f"breakdown < {ll:.4g} ({r.breakout_bars} bars), EMA{r.trend_ema_bars} {trend:.4g}, ATR {a:.4g}"
            return Signal(symbol=symbol, side=SHORT, entry=entry, stop=entry + dist, target=entry - 3 * dist,
                          atr=a, time=now, reason=reason), "signal"
        reason = f"breakout > {hh:.4g} ({r.breakout_bars} bars), EMA{r.trend_ema_bars} {trend:.4g}, relvol {rel:.2f}, ATR {a:.4g}"
        if r.mode == "fade":  # same trigger, opposite side: short the breakout, stop the same distance above
            return Signal(symbol=symbol, side=SHORT, entry=entry, stop=entry + dist, target=entry - 3 * dist,
                          atr=a, time=now, reason="fade " + reason), "signal"
        return Signal(symbol=symbol, side=LONG, entry=entry, stop=entry - dist, target=entry + 3 * dist,
                      atr=a, time=now, reason=reason), "signal"


    def _pattern_bars(self) -> int:
        """Bars of history the entry pattern needs on top of the trend EMA."""
        r = self.r
        if r.mode == "squeeze":
            return r.squeeze_lookback + r.squeeze_bars + r.box_bars
        if r.mode == "pullback":
            return r.rsi_bars * 6
        if r.mode == "session":
            return max(r.atr_bars * 4, int(1440 / max(1, r.bar_minutes)) + 2)
        return r.breakout_bars

    def _eval_session(self, symbol: str, bars: list[Bar], now: datetime) -> tuple[Signal | None, str]:
        """Opening-range breakout of a session: the high/low of session_start..session_end (UTC, e.g. the
        Asian range) is broken by a bar that closes before entry_end. First break of the day only, each
        side. Stop on the far side of the range (at least stop_atr_mult ATRs / min_initial_risk_pct)."""
        from datetime import timezone as _tz
        r = self.r
        width = timedelta(minutes=self.bar_minutes)
        last = bars[-1]
        utc = lambda b: b.time.astimezone(_tz.utc)  # noqa: E731
        day = utc(last).date()
        t_close = (utc(last) + width).time()
        s0, s1, e1 = (clock.parse_hhmm(x) for x in (r.session_start_utc, r.session_end_utc, r.entry_end_utc))
        if not (s1 < t_close <= e1):
            return None, "outside_window"
        rng = [b for b in bars if utc(b).date() == day and s0 <= utc(b).time() and (utc(b) + width).time() <= s1]
        if len(rng) < 3:
            return None, "no_range"
        hi, lo = max(b.high for b in rng), min(b.low for b in rng)
        earlier = [b for b in bars[:-1] if utc(b).date() == day and (utc(b) + width).time() > s1]
        allow_short = r.direction in ("both", "short_only")
        if r.direction != "short_only" and last.close > hi:
            short = False
            if any(b.close > hi for b in earlier):
                return None, "not_first_bar"
        elif allow_short and last.close < lo:
            short = True
            if any(b.close < lo for b in earlier):
                return None, "not_first_bar"
        else:
            return None, "no_breakout"
        if r.trend_ema_bars > 0:
            trend = ema([b.close for b in bars[-(r.trend_ema_bars * 4):]], r.trend_ema_bars)
            if trend is None or (last.close >= trend if short else last.close <= trend):
                return None, "below_ema"
        a = atr_of(bars[-(r.atr_bars * 4):], r.atr_bars) or 0.0
        entry = last.close
        dist = (entry - lo) if not short else (hi - entry)
        dist = max(dist, r.stop_atr_mult * a, entry * r.min_initial_risk_pct / 100.0)
        if dist <= 0 or dist / entry * 100.0 > r.max_initial_risk_pct:
            return None, "stop_too_wide"
        reason = (f"session {'breakdown' if short else 'breakout'} of {r.session_start_utc}-{r.session_end_utc} UTC "
                  f"range {lo:.5g}-{hi:.5g}, ATR {a:.4g}")
        if short:
            return Signal(symbol=symbol, side=SHORT, entry=entry, stop=entry + dist, target=entry - 2 * dist,
                          atr=a, time=now, reason=reason), "signal"
        return Signal(symbol=symbol, side=LONG, entry=entry, stop=entry - dist, target=entry + 2 * dist,
                      atr=a, time=now, reason=reason), "signal"

    @staticmethod
    def _bandwidth(closes: list[float]) -> float:
        n = len(closes)
        mean = sum(closes) / n
        var = sum((c - mean) ** 2 for c in closes) / n
        return 4.0 * var ** 0.5 / mean if mean > 0 else 0.0

    def _eval_squeeze(self, symbol: str, bars: list[Bar], now: datetime) -> tuple[Signal | None, str]:
        """Volatility-compression breakout: Bollinger bandwidth in the bottom squeeze_pct of its recent
        history, then the first close above the compression box's high, in an uptrend. Stop under the
        box (at least stop_atr_mult ATRs)."""
        r = self.r
        last, prev = bars[-1], bars[-2]
        box = bars[-(r.box_bars + 1):-1]
        box_high, box_low = max(b.high for b in box), min(b.low for b in box)
        if last.close <= box_high:
            return None, "no_breakout"
        if prev.close > max(b.high for b in bars[-(r.box_bars + 2):-2]):
            return None, "not_first_bar"
        closes = [b.close for b in bars]
        trend = ema(closes[-(r.trend_ema_bars * 4):], r.trend_ema_bars)
        if trend is None or last.close <= trend:
            return None, "below_ema"
        # bandwidth of the window ending on the bar before the breakout, ranked against its history
        hist = [self._bandwidth(closes[i - r.squeeze_bars:i])
                for i in range(len(closes) - 1 - r.squeeze_lookback, len(closes))]
        now_bw = hist[-2]
        # share of the history at or below today's bandwidth: a flat history ranks 1.0 (no squeeze)
        rank = sum(1 for h in hist[:-2] if h <= now_bw) / max(1, len(hist) - 2)
        if rank > r.squeeze_pct:
            return None, "no_squeeze"
        if r.min_rel_volume > 0:
            avg_vol = sum(b.volume for b in box) / len(box)
            if avg_vol <= 0 or last.volume / avg_vol < r.min_rel_volume:
                return None, "low_relvol"
        a = atr_of(bars[-(r.atr_bars * 4):], r.atr_bars)
        if not a or a <= 0:
            return None, "no_atr"
        entry = last.close
        stop = min(box_low, entry - r.stop_atr_mult * a)
        if r.min_initial_risk_pct > 0:
            stop = min(stop, entry * (1 - r.min_initial_risk_pct / 100.0))
        risk = entry - stop
        if risk <= 0 or risk / entry * 100.0 > r.max_initial_risk_pct:
            return None, "stop_too_wide"
        reason = (f"squeeze bw rank {rank:.2f} <= {r.squeeze_pct:.2f}, box {box_low:.4g}-{box_high:.4g} "
                  f"({r.box_bars} bars), EMA{r.trend_ema_bars} {trend:.4g}, ATR {a:.4g}")
        return Signal(symbol=symbol, side=LONG, entry=entry, stop=stop, target=entry + 3 * risk,
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
        return Signal(symbol=symbol, side=LONG, entry=entry, stop=stop, target=entry + 3 * risk,
                      atr=a, time=now, reason=reason), "signal"


def loaded_from_rules(rules: CryptoRules) -> LoadedStrategy:
    strat = CryptoMomentum(rules)
    return LoadedStrategy(
        name=rules.name, strategy=strat, exits=rules.exit_rules(), intraday_days=strat.intraday_days,
        include_premarket=True, scan_kind="static", scan_at=time(0, 0), force_close=None,
        risk_overrides={"risk_per_trade_pct": rules.max_risk_per_trade_pct,
                        "max_position_pct": rules.max_position_pct, "max_positions": rules.max_positions,
                        "allow_shorts": rules.mode == "fade" or rules.direction != "long_only"},
        continuous=True, fractional=True, cooldown_minutes=rules.cooldown_minutes, universe=list(rules.universe),
    )


def load_crypto(path: str | Path = "crypto.json") -> LoadedStrategy:
    return loaded_from_rules(CryptoRules.load(path))
