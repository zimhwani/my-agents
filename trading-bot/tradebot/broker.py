"""Broker adapters.

``Broker`` is the small interface the rest of the bot talks to. ``IBBroker``
implements it on top of ``ib_async`` (Trader Workstation / IB Gateway).
``SimBroker`` implements it in memory for dry runs, tests and the backtester,
so the pipeline can be exercised end to end with no broker attached.
"""

from __future__ import annotations

import logging
import math
import time as _time
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Protocol

from . import clock
from .config import Settings
from .models import LONG, Bar

log = logging.getLogger("tradebot.broker")


@dataclass
class OrderRef:
    """Opaque handle to a working order at the broker."""
    order_id: int
    perm_id: int = 0
    symbol: str = ""
    kind: str = ""  # ENTRY / STOP / CLOSE
    qty: int = 0
    price: float = 0.0
    status: str = "Submitted"
    avg_fill: float = 0.0
    filled: int = 0
    raw: object = None  # broker-native object


@dataclass
class PositionInfo:
    symbol: str
    qty: int  # signed: >0 long, <0 short
    avg_cost: float


class Broker(Protocol):
    def connect(self) -> None: ...
    def disconnect(self) -> None: ...
    def is_connected(self) -> bool: ...
    def sleep(self, seconds: float) -> None: ...
    def net_liquidation(self) -> float: ...
    def positions(self) -> list[PositionInfo]: ...
    def daily_bars(self, symbol: str, days: int) -> list[Bar]: ...
    def intraday_bars(self, symbol: str, bar_minutes: int, days: int,
                      include_premarket: bool = False) -> list[Bar]: ...
    def last_price(self, symbol: str) -> float | None: ...
    def place_entry_with_stop(self, symbol: str, side: str, qty: int, stop: float,
                              limit: float | None = None) -> tuple[OrderRef, OrderRef]: ...
    def place_stop(self, symbol: str, side: str, qty: int, stop: float) -> OrderRef: ...
    def wait_fill(self, ref: OrderRef, timeout: float) -> OrderRef: ...
    def refresh(self, ref: OrderRef) -> OrderRef: ...
    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: int | None = None) -> OrderRef: ...
    def cancel(self, ref: OrderRef) -> None: ...
    def market_close(self, symbol: str, side: str, qty: int) -> OrderRef: ...
    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None: ...
    def cancel_all(self) -> None: ...


# ---------------------------------------------------------------------------
# Interactive Brokers
# ---------------------------------------------------------------------------
class IBBroker:
    def __init__(self, settings: Settings):
        self.s = settings
        try:
            import ib_async as ibmod  # noqa: WPS433
        except ImportError:  # pragma: no cover
            import ib_insync as ibmod  # type: ignore
        self._m = ibmod
        self.ib = ibmod.IB()
        self._contracts: dict[str, object] = {}
        self._tickers: dict[str, object] = {}
        self.account: str = settings.ib_account

    # -- connection --------------------------------------------------------
    def connect(self) -> None:
        s = self.s
        s.validate()
        log.info("Connecting to IB at %s:%s (client %s)", s.ib_host, s.ib_port, s.ib_client_id)
        self.ib.connect(s.ib_host, s.ib_port, clientId=s.ib_client_id, readonly=False, timeout=30)
        accounts = self.ib.managedAccounts()
        if not self.account:
            self.account = accounts[0] if accounts else ""
        if s.is_paper and self.account and not self.account.startswith("DU"):
            raise RuntimeError(
                f"Port {s.ib_port} is a paper port but account {self.account!r} does not look "
                "like a paper account (paper accounts start with DU). Refusing to trade.")
        if not s.is_paper and self.account.startswith("DU"):
            log.warning("Live port configured but account %s is a paper account.", self.account)
        self.ib.reqMarketDataType(s.market_data_type)
        log.info("Connected. accounts=%s using=%s server_version=%s",
                 accounts, self.account, self.ib.client.serverVersion())

    def disconnect(self) -> None:
        if self.ib.isConnected():
            self.ib.disconnect()

    def is_connected(self) -> bool:
        return self.ib.isConnected()

    def sleep(self, seconds: float) -> None:
        self.ib.sleep(seconds)

    # -- account -------------------------------------------------------------
    def net_liquidation(self) -> float:
        for v in self.ib.accountSummary(self.account):
            if v.tag == "NetLiquidation" and v.currency in ("USD", "BASE"):
                return float(v.value)
        for v in self.ib.accountValues(self.account):
            if v.tag == "NetLiquidation":
                return float(v.value)
        raise RuntimeError("NetLiquidation not available from IB")

    def positions(self) -> list[PositionInfo]:
        out = []
        for p in self.ib.positions(self.account):
            if getattr(p.contract, "secType", "") != "STK":
                continue
            out.append(PositionInfo(p.contract.symbol, int(p.position), float(p.avgCost)))
        return out

    # -- market data ---------------------------------------------------------
    def contract(self, symbol: str):
        c = self._contracts.get(symbol)
        if c is None:
            c = self._m.Stock(symbol, "SMART", "USD")
            self.ib.qualifyContracts(c)
            self._contracts[symbol] = c
        return c

    def _bars(self, symbol: str, duration: str, size: str, rth: bool = True) -> list[Bar]:
        raw = self.ib.reqHistoricalData(
            self.contract(symbol), endDateTime="", durationStr=duration,
            barSizeSetting=size, whatToShow="TRADES", useRTH=rth, formatDate=2)
        out = []
        for b in raw:
            t = b.date
            if isinstance(t, datetime):
                t = clock.to_et(t)
            else:  # daily bars come back as date
                t = clock.at(t, clock.MARKET_CLOSE)
            out.append(Bar(t, float(b.open), float(b.high), float(b.low), float(b.close),
                           float(b.volume)))
        return out

    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        return self._bars(symbol, f"{days} D", "1 day")

    def intraday_bars(self, symbol: str, bar_minutes: int = 5, days: int = 5,
                      include_premarket: bool = False) -> list[Bar]:
        return self._bars(symbol, f"{days} D", f"{bar_minutes} mins", rth=not include_premarket)

    def last_price(self, symbol: str) -> float | None:
        t = self._tickers.get(symbol)
        if t is None:
            t = self.ib.reqMktData(self.contract(symbol), "", False, False)
            self._tickers[symbol] = t
            self.ib.sleep(2)
        for candidate in (t.marketPrice(), t.last, t.close):
            if candidate and not math.isnan(candidate) and candidate > 0:
                return float(candidate)
        return None

    # -- orders ----------------------------------------------------------------
    def _ref(self, trade, kind: str, symbol: str) -> OrderRef:
        o, st = trade.order, trade.orderStatus
        price = float(o.auxPrice or 0) if kind == "STOP" else float(o.lmtPrice or 0)
        return OrderRef(order_id=o.orderId, perm_id=o.permId or 0, symbol=symbol, kind=kind,
                        qty=int(o.totalQuantity), price=price, status=st.status,
                        avg_fill=float(st.avgFillPrice or 0), filled=int(st.filled or 0),
                        raw=trade)

    def place_entry_with_stop(self, symbol: str, side: str, qty: int, stop: float,
                              limit: float | None = None) -> tuple[OrderRef, OrderRef]:
        m = self._m
        c = self.contract(symbol)
        action, reverse = ("BUY", "SELL") if side == LONG else ("SELL", "BUY")
        if limit is None:
            parent = m.MarketOrder(action, qty)
        else:
            parent = m.LimitOrder(action, qty, round(limit, 2))
        parent.orderId = self.ib.client.getReqId()
        parent.tif = "DAY"
        parent.outsideRth = False
        parent.transmit = False
        if self.account:
            parent.account = self.account
        child = m.StopOrder(reverse, qty, round(stop, 2))
        child.orderId = self.ib.client.getReqId()
        child.parentId = parent.orderId
        child.tif = "GTC"
        child.outsideRth = False
        child.transmit = True
        if self.account:
            child.account = self.account
        t1 = self.ib.placeOrder(c, parent)
        t2 = self.ib.placeOrder(c, child)
        self.ib.sleep(0.5)
        log.info("Placed %s %s x%d with stop %.2f (ids %s/%s)", action, symbol, qty, stop,
                 parent.orderId, child.orderId)
        return self._ref(t1, "ENTRY", symbol), self._ref(t2, "STOP", symbol)

    def place_stop(self, symbol: str, side: str, qty: int, stop: float) -> OrderRef:
        """Stand-alone protective stop (used when re-attaching after a restart)."""
        reverse = "SELL" if side == LONG else "BUY"
        o = self._m.StopOrder(reverse, qty, round(stop, 2))
        o.tif = "GTC"
        o.outsideRth = False
        if self.account:
            o.account = self.account
        t = self.ib.placeOrder(self.contract(symbol), o)
        self.ib.sleep(0.5)
        return self._ref(t, "STOP", symbol)

    def wait_fill(self, ref: OrderRef, timeout: float = 30) -> OrderRef:
        deadline = _time.time() + timeout
        while _time.time() < deadline:
            ref = self.refresh(ref)
            if ref.status == "Filled" or ref.status in ("Cancelled", "Inactive", "ApiCancelled"):
                return ref
            self.ib.sleep(0.5)
        return self.refresh(ref)

    def refresh(self, ref: OrderRef) -> OrderRef:
        trade = ref.raw
        if trade is None:
            found = self.find_order(ref.order_id, ref.perm_id)
            return found or ref
        return self._ref(trade, ref.kind, ref.symbol)

    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: int | None = None) -> OrderRef:
        trade = ref.raw
        if trade is None:
            raise RuntimeError(f"stop order {ref.order_id} not attached to a live trade object")
        o = trade.order
        if price is not None:
            o.auxPrice = round(price, 2)
        if qty is not None:
            o.totalQuantity = qty
        o.transmit = True
        t = self.ib.placeOrder(self.contract(ref.symbol), o)
        self.ib.sleep(0.3)
        log.info("Modified stop %s -> price %.2f qty %s", ref.order_id, o.auxPrice, o.totalQuantity)
        return self._ref(t, "STOP", ref.symbol)

    def cancel(self, ref: OrderRef) -> None:
        trade = ref.raw
        if trade is not None and not trade.isDone():
            self.ib.cancelOrder(trade.order)
            self.ib.sleep(0.3)

    def market_close(self, symbol: str, side: str, qty: int) -> OrderRef:
        action = "SELL" if side == LONG else "BUY"
        o = self._m.MarketOrder(action, qty)
        o.tif = "DAY"
        if self.account:
            o.account = self.account
        t = self.ib.placeOrder(self.contract(symbol), o)
        ref = self._ref(t, "CLOSE", symbol)
        return self.wait_fill(ref, timeout=60)

    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None:
        for t in self.ib.openTrades():
            if (perm_id and t.order.permId == perm_id) or t.order.orderId == order_id:
                kind = "STOP" if t.order.orderType in ("STP", "STP LMT") else "ENTRY"
                return self._ref(t, kind, t.contract.symbol)
        return None

    def cancel_all(self) -> None:
        self.ib.reqGlobalCancel()
        self.ib.sleep(1)


# ---------------------------------------------------------------------------
# In-memory simulator (dry run / tests / backtest)
# ---------------------------------------------------------------------------
@dataclass
class SimBroker:
    equity: float = 100_000.0
    slippage_bps: float = 2.0
    prices: dict[str, float] = field(default_factory=dict)
    daily: dict[str, list[Bar]] = field(default_factory=dict)
    intraday: dict[str, list[Bar]] = field(default_factory=dict)
    _orders: dict[int, OrderRef] = field(default_factory=dict)
    _positions: dict[str, PositionInfo] = field(default_factory=dict)
    _next_id: int = 1
    now: datetime | None = None
    connected: bool = False
    realized_pnl: float = 0.0

    def connect(self) -> None:
        self.connected = True

    def disconnect(self) -> None:
        self.connected = False

    def is_connected(self) -> bool:
        return self.connected

    def sleep(self, seconds: float) -> None:  # simulation: time is driven externally
        pass

    def net_liquidation(self) -> float:
        return self.equity + self.realized_pnl + sum(
            (self.prices.get(p.symbol, p.avg_cost) - p.avg_cost) * p.qty for p in self._positions.values())

    def positions(self) -> list[PositionInfo]:
        return [p for p in self._positions.values() if p.qty != 0]

    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        bars = self.daily.get(symbol, [])
        if self.now:
            bars = [b for b in bars if b.time <= self.now]
        return bars[-days:]

    def intraday_bars(self, symbol: str, bar_minutes: int = 5, days: int = 5,
                      include_premarket: bool = False) -> list[Bar]:
        bars = self.intraday.get(symbol, [])
        if self.now:
            bars = [b for b in bars if b.time + timedelta(minutes=bar_minutes) <= self.now]
        cutoff = (self.now or clock.now_et()) - timedelta(days=days + 2)
        bars = [b for b in bars if b.time >= cutoff]
        if not include_premarket:
            bars = [b for b in bars if clock.MARKET_OPEN <= b.time.time() < clock.MARKET_CLOSE]
        return bars

    def last_price(self, symbol: str) -> float | None:
        return self.prices.get(symbol)

    # -- fills ---------------------------------------------------------------
    def _slip(self, price: float, buying: bool) -> float:
        adj = price * self.slippage_bps / 10_000.0
        return round(price + adj if buying else price - adj, 4)

    def _apply_fill(self, symbol: str, signed_qty: int, price: float) -> None:
        pos = self._positions.get(symbol, PositionInfo(symbol, 0, 0.0))
        new_qty = pos.qty + signed_qty
        if pos.qty == 0 or (pos.qty > 0) == (signed_qty > 0):
            total = abs(pos.qty) + abs(signed_qty)
            avg = (pos.avg_cost * abs(pos.qty) + price * abs(signed_qty)) / total if total else 0.0
            self._positions[symbol] = PositionInfo(symbol, new_qty, avg)
        else:  # reducing
            closed = min(abs(pos.qty), abs(signed_qty))
            direction = 1 if pos.qty > 0 else -1
            self.realized_pnl += (price - pos.avg_cost) * direction * closed
            self._positions[symbol] = PositionInfo(symbol, new_qty, pos.avg_cost if new_qty else 0.0)

    def place_entry_with_stop(self, symbol: str, side: str, qty: int, stop: float,
                              limit: float | None = None) -> tuple[OrderRef, OrderRef]:
        px = self.prices.get(symbol)
        if px is None:
            raise RuntimeError(f"no price for {symbol}")
        buying = side == LONG
        fill = self._slip(px, buying)
        entry = OrderRef(self._next_id, self._next_id, symbol, "ENTRY", qty, fill, "Filled", fill, qty)
        self._next_id += 1
        self._apply_fill(symbol, qty if buying else -qty, fill)
        stop_ref = OrderRef(self._next_id, self._next_id, symbol, "STOP", qty, round(stop, 2), "Submitted")
        self._next_id += 1
        self._orders[entry.order_id] = entry
        self._orders[stop_ref.order_id] = stop_ref
        log.info("[sim] %s %s x%d @ %.2f stop %.2f", "BUY" if buying else "SELL", symbol, qty, fill, stop)
        return entry, stop_ref

    def place_stop(self, symbol: str, side: str, qty: int, stop: float) -> OrderRef:
        ref = OrderRef(self._next_id, self._next_id, symbol, "STOP", qty, round(stop, 2), "Submitted")
        self._next_id += 1
        self._orders[ref.order_id] = ref
        return ref

    def wait_fill(self, ref: OrderRef, timeout: float = 30) -> OrderRef:
        return self.refresh(ref)

    def refresh(self, ref: OrderRef) -> OrderRef:
        return self._orders.get(ref.order_id, ref)

    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: int | None = None) -> OrderRef:
        o = self._orders[ref.order_id]
        if price is not None:
            o.price = round(price, 2)
        if qty is not None:
            o.qty = qty
        return o

    def cancel(self, ref: OrderRef) -> None:
        o = self._orders.get(ref.order_id)
        if o and o.status not in ("Filled",):
            o.status = "Cancelled"

    def market_close(self, symbol: str, side: str, qty: int) -> OrderRef:
        px = self.prices[symbol]
        buying = side != LONG  # closing a long = selling
        fill = self._slip(px, buying)
        self._apply_fill(symbol, qty if buying else -qty, fill)
        ref = OrderRef(self._next_id, self._next_id, symbol, "CLOSE", qty, fill, "Filled", fill, qty)
        self._next_id += 1
        self._orders[ref.order_id] = ref
        return ref

    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None:
        return self._orders.get(order_id)

    def cancel_all(self) -> None:
        for o in self._orders.values():
            if o.status == "Submitted":
                o.status = "Cancelled"

    # -- simulation drivers ---------------------------------------------------
    def set_price(self, symbol: str, price: float, now: datetime | None = None) -> None:
        self.prices[symbol] = price
        if now is not None:
            self.now = now

    def process_bar(self, symbol: str, bar: Bar) -> list[OrderRef]:
        """Advance one bar: fill any working stop that the bar traded through.
        Returns the stop orders that filled."""
        self.now = bar.time + timedelta(minutes=5)
        self.prices[symbol] = bar.close
        filled = []
        for o in list(self._orders.values()):
            if o.kind != "STOP" or o.symbol != symbol or o.status != "Submitted":
                continue
            pos = self._positions.get(symbol)
            if pos is None or pos.qty == 0:
                continue
            is_long = pos.qty > 0
            hit = bar.low <= o.price if is_long else bar.high >= o.price
            if hit:
                # gap through the stop fills at the open
                px = min(o.price, bar.open) if is_long else max(o.price, bar.open)
                px = self._slip(px, not is_long)
                o.status, o.avg_fill, o.filled = "Filled", px, o.qty
                self._apply_fill(symbol, -o.qty if is_long else o.qty, px)
                filled.append(o)
        return filled
