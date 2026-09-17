"""The decision loop: one trading day, tick by tick.

    pre-market  -> universe scan -> watchlist (Telegram)
    09:30-15:50 -> every POLL_SECONDS: manage exits, look for entries,
                   30-minute status report
    15:50       -> force-close everything, daily summary, stop

``tick(now)`` is side-effect-complete for one iteration so it can be driven
by a real clock (``run``) or by the backtester.
"""

from __future__ import annotations

import logging
import time as _time
import traceback
from datetime import datetime, timedelta

from . import clock
from .broker import Broker
from .config import Settings
from .execution import Executor, StateStore
from .exits import ExitManager
from .indicators import atr as atr_of
from .journal import Journal, compute_stats
from .models import Bar
from .risk import DayStats, RiskGate, position_size
from .strategy import StrategyParams, build_strategy, session_bars
from .telegram import Notifier, esc
from .universe import Candidate, UniverseScanner

log = logging.getLogger("tradebot.loop")


class TradingLoop:
    def __init__(self, settings: Settings, broker: Broker, params: StrategyParams,
                 notifier: Notifier, journal: Journal | None = None,
                 executor: Executor | None = None):
        self.s = settings
        self.b = broker
        self.p = params
        self.notify = notifier
        self.journal = journal or Journal(settings.journal_file)
        self.exec = executor or Executor(broker, self.journal, notifier,
                                         StateStore(settings.state_file), dry_run=settings.dry_run)
        self.strategy = build_strategy(params, allow_shorts=settings.allow_shorts)
        self.exits = ExitManager(params, settings.force_close_time)
        self.gate = RiskGate(settings)
        self.scanner = UniverseScanner(broker, settings)
        self.watchlist: list[Candidate] = []
        self.day: DayStats | None = None
        self.day_done = False
        self._bars: dict[str, list[Bar]] = {}
        self._daily: dict[str, list[Bar]] = {}
        self._bars_at: dict[str, datetime] = {}
        self._last_status: datetime | None = None
        self._scanned_for: object = None

    # -- helpers ---------------------------------------------------------------
    def _bar_boundary(self, now: datetime) -> datetime:
        m = self.p.bar_minutes
        return now.replace(minute=(now.minute // m) * m, second=0, microsecond=0)

    def bars_for(self, symbol: str, now: datetime) -> list[Bar]:
        """Intraday bars, refreshed only once per completed bar (IB pacing)."""
        boundary = self._bar_boundary(now)
        if self._bars_at.get(symbol) != boundary or symbol not in self._bars:
            self._bars[symbol] = self.b.intraday_bars(symbol, self.p.bar_minutes, 5)
            self._bars_at[symbol] = boundary
        return self._bars[symbol]

    def daily_for(self, symbol: str) -> list[Bar]:
        if symbol not in self._daily:
            self._daily[symbol] = self.b.daily_bars(symbol, 60)
        return self._daily[symbol]

    def atr_for(self, symbol: str, now: datetime) -> float:
        bars = [b for b in self.bars_for(symbol, now) if b.time + timedelta(minutes=self.p.bar_minutes) <= now]
        return atr_of(bars[-(self.p.atr_period * 4):], self.p.atr_period) or 0.0

    def _ensure_day(self, now: datetime) -> None:
        if self.day is None or self._scanned_for != now.date():
            equity = self.b.net_liquidation()
            self.day = DayStats(start_equity=equity)
            self.day_done = False
            self._daily.clear()
            self._bars.clear()
            self._bars_at.clear()
            self.exec.closed_today = [t for t in self.journal.load() if t.entry_time.date() == now.date()]
            self._scanned_for = now.date()
            self.watchlist = self.scanner.scan()
            names = "\n".join(esc(c.line()) for c in self.watchlist) or "(nothing passed the filters)"
            self.notify.send(f"📋 <b>Watchlist {now:%a %b %d}</b> · equity ${equity:,.0f}\n<pre>{names}</pre>")
            log.info("Watchlist: %s", [c.symbol for c in self.watchlist])

    def _update_day_stats(self) -> None:
        assert self.day is not None
        closed = self.exec.closed_today
        self.day.realized_r = sum(t.r_multiple for t in closed)
        self.day.realized_pnl = sum(t.realized_pnl for t in closed)

    # -- one iteration -----------------------------------------------------------
    def tick(self, now: datetime | None = None) -> None:
        now = clock.to_et(now or clock.now_et())
        if not clock.is_trading_day(now.date()):
            return
        self._ensure_day(now)
        if self.day_done:
            return
        if now < clock.session_open(now.date()):
            return

        # 1. exits on open trades
        self.exec.check_stop_fills(now)
        for t in list(self.exec.open_trades):
            price = self.b.last_price(t.symbol)
            if price is None:
                continue
            actions = self.exits.manage(t, price, self.atr_for(t.symbol, now), now)
            if actions:
                self.exec.apply(t, actions, now)
        self._update_day_stats()

        # 2. force close
        if now.time() >= self.s.force_close_time:
            self.exec.flatten_all("eod", now)
            self._update_day_stats()
            self._daily_summary(now)
            self.day_done = True
            return

        # 3. entries
        equity = self.b.net_liquidation()
        blockers = self.gate.blockers(self.exec.open_trades, self.day, equity, now)
        if not blockers and clock.in_window(now, self.p.window_start, self.p.window_end):
            held = {t.symbol for t in self.exec.open_trades}
            for c in self.watchlist:
                if c.symbol in held or len(self.exec.open_trades) >= self.s.max_positions:
                    continue
                sig = self.strategy.evaluate(c.symbol, self.bars_for(c.symbol, now),
                                             self.daily_for(c.symbol), now)
                if sig is None:
                    continue
                qty = position_size(equity, sig.entry, sig.stop, self.s.risk_per_trade_pct,
                                    self.s.max_risk_per_trade_usd, self.s.max_position_pct)
                log.info("SIGNAL %s qty=%d %s", sig.symbol, qty, sig.reason)
                if qty <= 0:
                    continue
                t = self.exec.open_trade(sig, qty, now)
                if t is not None:
                    self.day.trades_opened += 1
                    held.add(t.symbol)
        elif blockers and self._last_status is None:
            log.info("Entries blocked: %s", "; ".join(blockers))

        # 4. periodic status
        if self._last_status is None or now - self._last_status >= timedelta(minutes=self.s.telegram_status_minutes):
            self.notify.send(self.status_text(now, equity, blockers), silent=True)
            self._last_status = now
        self.exec.persist(day=self.day.__dict__, watchlist=[c.symbol for c in self.watchlist])

    # -- reporting ---------------------------------------------------------------
    def status_text(self, now: datetime, equity: float, blockers: list[str]) -> str:
        assert self.day is not None
        lines = [f"🕒 <b>{now:%H:%M} ET status</b> · equity ${equity:,.0f} "
                 f"({(equity - self.day.start_equity):+,.0f} today)"]
        if self.exec.open_trades:
            for t in self.exec.open_trades:
                px = self.b.last_price(t.symbol) or t.entry_price
                lines.append(f"• {esc(t.symbol)} {esc(t.side)} x{t.qty_open} @ {t.entry_price:.2f} "
                             f"now {px:.2f} ({t.unrealized_r(px):+.2f}R) stop {t.stop:.2f}"
                             f"{' · partial taken' if t.partial_taken else ''}")
        else:
            lines.append("• no open positions")
        lines.append(f"closed today: {len(self.exec.closed_today)} trades, {self.day.realized_r:+.2f}R "
                     f"(${self.day.realized_pnl:+,.0f})")
        lines.append("watchlist: " + esc(", ".join(c.symbol for c in self.watchlist)))
        if blockers:
            lines.append("⛔ entries blocked: " + esc("; ".join(blockers)))
        return "\n".join(lines)

    def _daily_summary(self, now: datetime) -> None:
        assert self.day is not None
        st = compute_stats(self.journal.load())
        closed = self.exec.closed_today
        rows = "\n".join(f"{t.symbol:<6} {t.r_multiple:+.2f}R  ${t.realized_pnl:+.0f}  "
                         f"{','.join(f.reason for f in t.exits)}" for t in closed) or "no trades"
        self.notify.send(
            f"🏁 <b>Day complete {now:%a %b %d}</b>\n<pre>{esc(rows)}</pre>\n"
            f"today: {self.day.realized_r:+.2f}R (${self.day.realized_pnl:+,.0f})\n"
            f"all-time: {st.trades} trades · win {st.win_rate*100:.0f}% · "
            f"{st.total_r:+.1f}R · expectancy {st.expectancy_r:+.2f}R")
        try:
            from .dashboard import write_dashboard
            write_dashboard(self.journal.load(), self.s.dashboard_file, self.p.name)
        except Exception as exc:  # pragma: no cover
            log.warning("dashboard: %s", exc)

    # -- real-time driver ----------------------------------------------------------
    def run(self) -> None:
        self.b.connect()
        self.notify.send(f"🤖 <b>Bot online</b> · {esc(self.s.describe())}\nstrategy: {esc(self.p.name)}")
        extra = self.exec.restore()
        if extra.get("day") and self.exec.open_trades:
            log.info("Recovered %d open trades from state", len(self.exec.open_trades))
        backoff = 5
        try:
            while True:
                now = clock.now_et()
                if not clock.is_trading_day(now.date()) or now.time() >= clock.MARKET_CLOSE or self.day_done:
                    if self.day_done or now.time() >= clock.MARKET_CLOSE:
                        log.info("Session over; exiting.")
                        break
                    nxt = clock.session_open(clock.next_trading_day(now.date()))
                    log.info("Market closed; sleeping until %s", nxt)
                    self.b.sleep(min(3600, max(60, (nxt - now).total_seconds())))
                    continue
                if now < clock.session_open(now.date()) - timedelta(minutes=20):
                    self.b.sleep(60)
                    continue
                try:
                    if not self.b.is_connected():
                        raise ConnectionError("broker disconnected")
                    self.tick(now)
                    backoff = 5
                except (ConnectionError, OSError) as exc:
                    log.error("Connection problem: %s; reconnecting in %ss", exc, backoff)
                    self.notify.send(f"🔌 connection problem: {esc(exc)}; reconnecting in {backoff}s")
                    _time.sleep(backoff)
                    backoff = min(backoff * 2, 120)
                    try:
                        self.b.disconnect()
                        self.b.connect()
                        self.exec.restore()
                    except Exception as exc2:  # pragma: no cover
                        log.error("Reconnect failed: %s", exc2)
                    continue
                except Exception as exc:
                    log.error("tick failed: %s\n%s", exc, traceback.format_exc())
                    self.notify.send(f"🚨 tick error: {esc(exc)}")
                self.b.sleep(self.s.poll_seconds)
        finally:
            self.exec.persist()
            self.b.disconnect()
            self.notify.send("🔴 bot offline")
