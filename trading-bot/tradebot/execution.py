"""Order execution and open-trade bookkeeping.

Turns a Signal into a broker entry order with an attached hard stop, applies
ExitActions (partials, stop moves, closes), detects stop fills, and persists
open trades so the bot can be restarted mid-session without losing track.
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime
from pathlib import Path

from .broker import Broker, OrderRef
from .clock import now_et
from .exits import CLOSE, MOVE_STOP, PARTIAL, ExitAction
from .journal import Journal
from .models import Signal, TradeRecord
from .telegram import Notifier, esc

log = logging.getLogger("tradebot.execution")


class StateStore:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def save(self, trades: list[TradeRecord], extra: dict | None = None) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {"open_trades": [t.to_dict() for t in trades], **(extra or {})}
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, indent=1))
        tmp.replace(self.path)

    def load(self) -> tuple[list[TradeRecord], dict]:
        if not self.path.exists():
            return [], {}
        raw = json.loads(self.path.read_text())
        trades = [TradeRecord.from_dict(d) for d in raw.get("open_trades", [])]
        extra = {k: v for k, v in raw.items() if k != "open_trades"}
        return trades, extra


class Executor:
    def __init__(self, broker: Broker, journal: Journal, notifier: Notifier,
                 state: StateStore | None = None, dry_run: bool = False):
        self.b = broker
        self.journal = journal
        self.notify = notifier
        self.state = state
        self.dry_run = dry_run
        self.open_trades: list[TradeRecord] = []
        self.closed_today: list[TradeRecord] = []
        self._stops: dict[str, OrderRef] = {}

    # -- persistence -----------------------------------------------------------
    def persist(self, **extra) -> None:
        if self.state:
            self.state.save(self.open_trades, extra)

    def restore(self) -> dict:
        """Reload open trades and re-attach (or re-place) their stop orders."""
        if not self.state:
            return {}
        trades, extra = self.state.load()
        for t in trades:
            ref = self.b.find_order(t.stop_order_id or 0, t.stop_perm_id or 0)
            if ref is None:
                log.warning("%s: stop order not found at broker after restart; re-placing", t.symbol)
                ref = self.b.place_stop(t.symbol, t.side, t.qty_open, t.stop)
            if ref is not None:
                self._stops[t.id] = ref
                t.stop_order_id, t.stop_perm_id = ref.order_id, ref.perm_id
            self.open_trades.append(t)
            log.info("Restored open trade %s %s x%d stop %.2f", t.side, t.symbol, t.qty_open, t.stop)
        return extra

    # -- entries ---------------------------------------------------------------
    def open_trade(self, sig: Signal, qty: int, now: datetime | None = None) -> TradeRecord | None:
        now = now or now_et()
        if qty <= 0:
            return None
        if self.dry_run:
            msg = (f"DRY RUN: would {'BUY' if sig.is_long else 'SELL'} {qty} {sig.symbol} "
                   f"@ ~{sig.entry:.2f} stop {sig.stop:.2f} target {sig.target:.2f}")
            log.info(msg)
            self.notify.send("🧪 " + esc(msg))
            return None
        entry_ref, stop_ref = self.b.place_entry_with_stop(sig.symbol, sig.side, qty, sig.stop)
        entry_ref = self.b.wait_fill(entry_ref, timeout=45)
        if entry_ref.status != "Filled" or entry_ref.filled <= 0:
            log.warning("%s entry not filled (%s); cancelling", sig.symbol, entry_ref.status)
            self.b.cancel(entry_ref)
            self.b.cancel(stop_ref)
            self.notify.send(f"⚠️ {esc(sig.symbol)} entry not filled ({esc(entry_ref.status)}), cancelled")
            return None
        filled_qty = entry_ref.filled or qty
        if filled_qty != qty:
            stop_ref = self.b.modify_stop(stop_ref, qty=filled_qty)
        t = TradeRecord(
            id=uuid.uuid4().hex[:10], symbol=sig.symbol, side=sig.side, qty_initial=filled_qty,
            entry_price=entry_ref.avg_fill or sig.entry, entry_time=now, stop_initial=sig.stop,
            stop=sig.stop, target=sig.target, atr=sig.atr, reason=sig.reason,
            entry_order_id=entry_ref.order_id, stop_order_id=stop_ref.order_id,
            stop_perm_id=stop_ref.perm_id)
        self._stops[t.id] = stop_ref
        self.open_trades.append(t)
        self.persist()
        self.notify.send(
            f"🟢 <b>ENTRY {esc(t.side)} {esc(t.symbol)}</b> x{t.qty_initial} @ {t.entry_price:.2f}\n"
            f"stop {t.stop:.2f} (risk ${t.initial_risk_usd:.0f}) · target {t.target:.2f}\n"
            f"<i>{esc(t.reason)}</i>")
        return t

    # -- exits -----------------------------------------------------------------
    def _finish(self, t: TradeRecord) -> None:
        if t.status == "CLOSED":
            self.open_trades = [x for x in self.open_trades if x.id != t.id]
            self.closed_today.append(t)
            self.journal.append(t)
            self._stops.pop(t.id, None)
            icon = "✅" if t.r_multiple > 0.1 else ("❌" if t.r_multiple < -0.1 else "➖")
            self.notify.send(
                f"{icon} <b>CLOSED {esc(t.symbol)}</b> {t.r_multiple:+.2f}R  (${t.realized_pnl:+.0f})\n"
                f"entry {t.entry_price:.2f} → avg exit {t.exit_price_avg:.2f} · "
                f"{esc(', '.join(f'{f.reason} x{f.qty}@{f.price:.2f}' for f in t.exits))}")
        self.persist()

    def apply(self, t: TradeRecord, actions: list[ExitAction], now: datetime | None = None) -> None:
        now = now or now_et()
        for a in actions:
            if t.status != "OPEN":
                break
            if a.kind == PARTIAL:
                ref = self.b.market_close(t.symbol, t.side, a.qty)
                qty = ref.filled or a.qty
                t.record_exit(now, qty, ref.avg_fill or a.price, "partial")
                if t.id in self._stops and t.qty_open > 0:
                    self._stops[t.id] = self.b.modify_stop(self._stops[t.id], qty=t.qty_open)
                self.notify.send(f"💰 partial {esc(t.symbol)} x{qty} @ {ref.avg_fill or a.price:.2f} "
                                 f"(+{t.unrealized_r(ref.avg_fill or a.price):.1f}R), {t.qty_open} left", silent=True)
            elif a.kind == MOVE_STOP:
                if t.id in self._stops:
                    self._stops[t.id] = self.b.modify_stop(self._stops[t.id], price=a.price)
                t.stop = a.price
                log.info("%s stop -> %.2f (%s)", t.symbol, a.price, a.reason)
                self.notify.send(f"🔒 {esc(t.symbol)} stop → {a.price:.2f} ({esc(a.reason)})", silent=True)
            elif a.kind == CLOSE:
                if t.id in self._stops:
                    self.b.cancel(self._stops[t.id])
                ref = self.b.market_close(t.symbol, t.side, t.qty_open)
                t.record_exit(now, ref.filled or t.qty_open, ref.avg_fill or a.price, a.reason)
                if t.status != "CLOSED":  # partial fill on close: record the rest at last price
                    t.record_exit(now, t.qty_open, ref.avg_fill or a.price, a.reason)
        self._finish(t)

    def check_stop_fills(self, now: datetime | None = None) -> None:
        now = now or now_et()
        for t in list(self.open_trades):
            ref = self._stops.get(t.id)
            if ref is None:
                continue
            ref = self.b.refresh(ref)
            self._stops[t.id] = ref
            if ref.status == "Filled" and ref.filled > 0:
                t.record_exit(now, min(ref.filled, t.qty_open), ref.avg_fill or ref.price, "stop")
                if t.status != "CLOSED":
                    t.record_exit(now, t.qty_open, ref.avg_fill or ref.price, "stop")
                self._finish(t)

    def flatten_all(self, reason: str = "eod", now: datetime | None = None) -> None:
        now = now or now_et()
        for t in list(self.open_trades):
            price = self.b.last_price(t.symbol) or t.entry_price
            self.apply(t, [ExitAction(CLOSE, t.qty_open, price, reason)], now)
        # anything the bot doesn't know about (manual trades, restarts gone wrong)
        try:
            self.b.cancel_all()
            for p in self.b.positions():
                if p.qty != 0:
                    side = "LONG" if p.qty > 0 else "SHORT"
                    log.warning("Flattening unknown position %s %+d", p.symbol, p.qty)
                    self.b.market_close(p.symbol, side, abs(p.qty))
                    self.notify.send(f"⚠️ flattened unknown position {esc(p.symbol)} {p.qty:+d}")
        except Exception as exc:  # pragma: no cover - broker specific
            log.error("flatten_all: %s", exc)
        self.persist()
