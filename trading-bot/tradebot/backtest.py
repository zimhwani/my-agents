"""Bar-by-bar backtester that runs the *same* strategy, exit manager and
executor as live trading, against :class:`SimBroker`.

Fill model: entries at the signal bar's close (plus slippage), stops at the
stop price (or the next open if the bar gaps through), partials/targets/time
exits at the bar close where the rule fires, forced flat at FORCE_CLOSE_TIME.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta

from . import clock
from .broker import SimBroker
from .config import Settings
from .data import aggregate_daily
from .execution import Executor
from .exits import ExitManager
from .indicators import atr as atr_of
from .journal import Journal, Stats, compute_stats
from .models import Bar, TradeRecord
from .risk import DayStats, RiskGate, position_size
from .strategy import StrategyParams, build_strategy, session_bars
from .telegram import Notifier

log = logging.getLogger("tradebot.backtest")


@dataclass
class BacktestResult:
    trades: list[TradeRecord]
    stats: Stats
    start_equity: float
    end_equity: float
    days: int


class Backtester:
    def __init__(self, settings: Settings, params: StrategyParams, intraday: dict[str, list[Bar]],
                 daily: dict[str, list[Bar]] | None = None, equity: float = 100_000.0,
                 slippage_bps: float = 2.0):
        self.s = settings
        self.p = params
        self.intraday = intraday
        self.daily = daily or {sym: aggregate_daily(b) for sym, b in intraday.items()}
        self.sim = SimBroker(equity=equity, slippage_bps=slippage_bps, intraday=intraday, daily=self.daily)
        self.journal = Journal(None)
        self.exec = Executor(self.sim, self.journal, Notifier(quiet=True))
        self.strategy = build_strategy(params, allow_shorts=settings.allow_shorts)
        self.exits = ExitManager(params, settings.force_close_time)
        self.gate = RiskGate(settings)

    def _atr(self, symbol: str, now: datetime) -> float:
        bars = self.sim.intraday_bars(symbol, self.p.bar_minutes, 5)
        return atr_of(bars[-(self.p.atr_period * 4):], self.p.atr_period) or 0.0

    def run(self, start=None, end=None) -> BacktestResult:
        width = timedelta(minutes=self.p.bar_minutes)
        by_day: dict = {}
        for sym, bars in self.intraday.items():
            for b in bars:
                d = b.time.date()
                if (start and d < start) or (end and d > end):
                    continue
                by_day.setdefault(d, {}).setdefault(sym, []).append(b)
        start_equity = self.sim.net_liquidation()
        for d in sorted(by_day):
            day = DayStats(start_equity=self.sim.net_liquidation())
            symbols_today = by_day[d]
            slots = sorted({b.time for bars in symbols_today.values() for b in bars})
            for slot in slots:
                now = slot + width
                bar_at = {}
                for sym, bars in symbols_today.items():
                    for b in bars:
                        if b.time == slot:
                            bar_at[sym] = b
                            self.sim.process_bar(sym, b)
                self.sim.now = now
                # exits
                self.exec.check_stop_fills(now)
                for t in list(self.exec.open_trades):
                    b = bar_at.get(t.symbol)
                    if b is None:
                        continue
                    actions = self.exits.manage(t, b.close, self._atr(t.symbol, now), now, b.high, b.low)
                    if actions:
                        self.exec.apply(t, actions, now)
                day.realized_r = sum(t.r_multiple for t in self.exec.closed_today if t.entry_time.date() == d)
                # entries
                equity = self.sim.net_liquidation()
                if self.gate.blockers(self.exec.open_trades, day, equity, now):
                    continue
                if not clock.in_window(now, self.p.window_start, self.p.window_end):
                    continue
                held = {t.symbol for t in self.exec.open_trades}
                for sym in sorted(bar_at):
                    if sym in held or len(self.exec.open_trades) >= self.s.max_positions:
                        continue
                    sig = self.strategy.evaluate(sym, self.sim.intraday_bars(sym, self.p.bar_minutes, 5),
                                                 self.sim.daily_bars(sym, 60), now)
                    if sig is None:
                        continue
                    qty = position_size(equity, sig.entry, sig.stop, self.s.risk_per_trade_pct,
                                        self.s.max_risk_per_trade_usd, self.s.max_position_pct)
                    if qty > 0 and self.exec.open_trade(sig, qty, now):
                        held.add(sym)
            if self.exec.open_trades:  # data ended before the forced close
                self.exec.flatten_all("eod", clock.at(d, self.s.force_close_time))
        trades = self.journal.load()
        return BacktestResult(trades=trades, stats=compute_stats(trades), start_equity=start_equity,
                              end_equity=self.sim.net_liquidation(), days=len(by_day))
