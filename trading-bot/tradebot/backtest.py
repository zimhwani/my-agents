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
from .strategy import LoadedStrategy, StrategyParams, completed_bars, load_strategy, rth_bars, session_bars
from .telegram import Notifier

log = logging.getLogger("tradebot.backtest")


@dataclass
class BacktestResult:
    trades: list[TradeRecord]
    stats: Stats
    start_equity: float
    end_equity: float
    days: int


def _as_loaded(params_or_loaded, settings: Settings) -> LoadedStrategy:
    if isinstance(params_or_loaded, LoadedStrategy):
        return params_or_loaded
    from .strategy import OpeningRangeBreakout
    p: StrategyParams = params_or_loaded
    return LoadedStrategy(name=p.name, strategy=OpeningRangeBreakout(p, allow_shorts=settings.allow_shorts),
                          exits=p.to_exit_rules(), risk_overrides={})


class Backtester:
    def __init__(self, settings: Settings, params, intraday: dict[str, list[Bar]],
                 daily: dict[str, list[Bar]] | None = None, equity: float = 100_000.0,
                 slippage_bps: float = 2.0, fee_bps: float = 0.0, stop_fill_lambda: float = 0.0,
                 stop_slippage_bps: float = 0.0):
        self.s = settings
        self.loaded = _as_loaded(params, settings)
        self.strategy = self.loaded.strategy
        self.bar_minutes = getattr(self.strategy, "bar_minutes", 5)
        self.atr_period = getattr(getattr(self.strategy, "r", None), "atr_bars",
                                  getattr(getattr(self.strategy, "p", None), "atr_period", 14))
        self.intraday = intraday
        # explicit daily history when given (needed for 200-day filters); else aggregate
        self.daily = {sym: (daily or {}).get(sym) or aggregate_daily(b) for sym, b in intraday.items()}
        self.sim = SimBroker(equity=equity, slippage_bps=slippage_bps, fee_bps=fee_bps, intraday=intraday,
                             daily=self.daily, bar_minutes=self.bar_minutes, stop_fill_lambda=stop_fill_lambda,
                             stop_slippage_bps=stop_slippage_bps)
        self.journal = Journal(None)
        self.exec = Executor(self.sim, self.journal, Notifier(quiet=True))
        self.exits = ExitManager(self.loaded.exits, None if self.loaded.continuous else settings.force_close_time)
        self.gate = RiskGate(settings)

    def _atr(self, symbol: str, now: datetime) -> float:
        bars = self.sim.intraday_bars(symbol, self.bar_minutes, 5)
        return atr_of(bars[-(self.atr_period * 4):], self.atr_period) or 0.0

    def run(self, start=None, end=None) -> BacktestResult:
        if self.loaded.continuous:
            return self.run_continuous(start, end)
        width = timedelta(minutes=self.bar_minutes)
        by_day: dict = {}
        for sym, bars in self.intraday.items():
            for b in bars:
                d = b.time.date()
                if (start and d < start) or (end and d > end):
                    continue
                by_day.setdefault(d, {}).setdefault(sym, []).append(b)
        start_equity = self.sim.net_liquidation()
        day_ok = getattr(self.strategy, "day_ok", None)
        if day_ok is not None and by_day and not getattr(Backtester, "_warned_short", False):
            first = min(by_day)
            short = [sym for sym, d in self.daily.items()
                     if sum(1 for b in d if b.time.date() < first) < 200]
            if short:
                Backtester._warned_short = True
                log.warning("%d/%d symbols have <200 daily bars before %s; their early days are skipped "
                            "by the SMA filter. Re-run `fetch-data --daily-only` to extend daily history.",
                            len(short), len(self.daily), first)
        for d in sorted(by_day):
            day = DayStats(start_equity=self.sim.net_liquidation())
            symbols_today = by_day[d]
            # once-per-day prefilter (e.g. gap + SMA for Trend Join Long)
            eligible = set(symbols_today)
            order = sorted(symbols_today)
            if day_ok is not None:
                self.sim.now = clock.session_open(d)
                ranked: list[tuple[float, str]] = []
                for sym, bars in symbols_today.items():
                    first = next((b for b in sorted(bars, key=lambda b: b.time)
                                  if clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE), None)
                    prior = self.sim.daily_bars(sym, 260)
                    if first is not None and day_ok(first.open, prior):
                        gap = (first.open - prior[-1].close) / prior[-1].close if prior and prior[-1].close else 0.0
                        ranked.append((gap, sym))
                # like the live gap scan: biggest gaps first, capped at the watchlist size
                ranked.sort(key=lambda t: -t[0])
                order = [sym for _, sym in ranked[: self.s.max_watchlist]]
                eligible = set(order)
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
                if not (clock.MARKET_OPEN <= slot.time() < clock.MARKET_CLOSE):
                    continue  # pre/post-market bars only feed data, never decisions
                # exits
                self.exec.check_stop_fills(now)
                for t in list(self.exec.open_trades):
                    b = bar_at.get(t.symbol)
                    if b is None:
                        continue
                    today_bars = session_bars(self.sim.intraday_bars(t.symbol, self.bar_minutes, 1), d)
                    actions = self.exits.manage(t, b.close, self._atr(t.symbol, now), now, b.high, b.low,
                                                bars=today_bars)
                    if actions:
                        self.exec.apply(t, actions, now)
                day.realized_r = sum(t.r_multiple for t in self.exec.closed_today if t.entry_time.date() == d)
                # entries
                equity = self.sim.net_liquidation()
                if self.gate.blockers(self.exec.open_trades, day, equity, now):
                    continue
                if not clock.in_window(now, self.strategy.window_start, self.strategy.window_end):
                    continue
                held = {t.symbol for t in self.exec.open_trades} | \
                       {t.symbol for t in self.exec.closed_today if t.entry_time.date() == d}
                for sym in order:
                    if sym not in bar_at or sym in held or sym not in eligible \
                            or len(self.exec.open_trades) >= self.s.max_positions:
                        continue
                    sig = self.strategy.evaluate(
                        sym, self.sim.intraday_bars(sym, self.bar_minutes, self.loaded.intraday_days,
                                                    self.loaded.include_premarket),
                        self.sim.daily_bars(sym, 260), now)
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


    # -- 24/7 markets: one timeline across the whole dataset -----------------------------
    def run_continuous(self, start=None, end=None) -> BacktestResult:
        width = timedelta(minutes=self.bar_minutes)
        by_slot: dict = {}
        for sym, bars in self.intraday.items():
            for b in bars:
                d = b.time.date()
                if (start and d < start) or (end and d > end):
                    continue
                by_slot.setdefault(b.time, {})[sym] = b
        start_equity = self.sim.net_liquidation()
        day = None
        day_date = None
        days = set()
        last_exit: dict[str, datetime] = {}
        cd = timedelta(minutes=self.loaded.cooldown_minutes)
        for slot in sorted(by_slot):
            now = slot + width
            if day_date != now.date():
                day_date = now.date()
                days.add(day_date)
                day = DayStats(start_equity=self.sim.net_liquidation())
            bar_at = by_slot[slot]
            for sym, b in bar_at.items():
                self.sim.process_bar(sym, b)
            self.sim.now = now
            self.exec.check_stop_fills(now)
            for t in list(self.exec.open_trades):
                b = bar_at.get(t.symbol)
                if b is None:
                    continue
                recent = self.sim.intraday_bars(t.symbol, self.bar_minutes, 3)[-120:]
                actions = self.exits.manage(t, b.close, self._atr(t.symbol, now), now, b.high, b.low, bars=recent)
                if actions:
                    self.exec.apply(t, actions, now)
                    if t.status == "CLOSED":
                        last_exit[t.symbol] = now
            for t in self.exec.closed_today:
                if t.last_exit_time and (t.symbol not in last_exit or t.last_exit_time > last_exit[t.symbol]):
                    last_exit[t.symbol] = t.last_exit_time
            day.realized_r = sum(t.r_multiple for t in self.exec.closed_today if t.entry_time.date() == day_date)
            equity = self.sim.net_liquidation()
            if self.gate.blockers(self.exec.open_trades, day, equity, now):
                continue
            held = {t.symbol for t in self.exec.open_trades}
            for sym in sorted(bar_at):
                if sym in held or len(self.exec.open_trades) >= self.s.max_positions:
                    continue
                if sym in last_exit and now - last_exit[sym] < cd:
                    continue
                sig = self.strategy.evaluate(sym, self.sim.intraday_bars(sym, self.bar_minutes, self.loaded.intraday_days, True),
                                             self.sim.daily_bars(sym, 60), now)
                if sig is None:
                    continue
                qty = position_size(equity, sig.entry, sig.stop, self.s.risk_per_trade_pct,
                                    self.s.max_risk_per_trade_usd, self.s.max_position_pct, fractional=True)
                if qty > 0 and self.exec.open_trade(sig, qty, now):
                    held.add(sym)
        if self.exec.open_trades:
            self.exec.flatten_all("end", self.sim.now)
        trades = self.journal.load()
        return BacktestResult(trades=trades, stats=compute_stats(trades), start_equity=start_equity,
                              end_equity=self.sim.net_liquidation(), days=len(days))
