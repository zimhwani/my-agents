"""Paper trading for CFDs (gold first): a Broker that fills virtual trades on live Yahoo prices,
plus MT5 "mirror" instructions for every alert so the same trades can be copied by hand onto a
MetaTrader 5 demo (Deriv blocks automated connections from the server).

Accounting is CFD-style: opening a position doesn't move cash; realised P&L does. Costs match the
research: a per-side spread/fee and extra slippage on stops, both applied to the fill price so the
journal's R is net of costs. The account (cash, positions) survives restarts in paper_account.json;
open trades and their stops are restored by the executor as for the other brokers.
"""

from __future__ import annotations

import json
import logging
import math
import time as _time
from dataclasses import dataclass, field
from pathlib import Path

from .broker import OrderRef, PositionInfo
from .config import Settings
from .models import LONG, Bar, px

log = logging.getLogger(__name__)


class YahooCFDData:
    """Live bars and prices for CFD symbols (XAU/USD -> GC=F etc.) from Yahoo Finance."""

    def __init__(self, cache_seconds: float = 20.0):
        from .marketdata import YFinanceData
        self._yf = YFinanceData(cache_seconds=cache_seconds)
        self._bars: dict[tuple, tuple[float, list[Bar]]] = {}

    @staticmethod
    def ticker(symbol: str) -> str:
        from .deriv import YAHOO
        return YAHOO.get(symbol, symbol)

    def intraday_bars(self, symbol: str, bar_minutes: int = 60, days: int = 30,
                      include_premarket: bool = True) -> list[Bar]:
        from .deriv import yahoo_bars
        key = (symbol, bar_minutes, days)
        hit = self._bars.get(key)
        if hit and _time.time() - hit[0] < 60:
            return hit[1]
        bars, _ = yahoo_bars(symbol, bar_minutes, days)
        self._bars[key] = (_time.time(), bars)
        return bars

    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        return self._yf.daily_bars(self.ticker(symbol), days)

    def last_price(self, symbol: str) -> float | None:
        return self._yf.last_price(self.ticker(symbol))

    def fx_rate(self, base: str, quote: str) -> float:
        return 1.0

    def market_cap(self, symbol: str) -> float | None:
        return None


def parse_symbol_map(text: str) -> dict[str, str]:
    """"XAU/USD=XAUUSD,EUR/USD=EURUSD" -> {"XAU/USD": "XAUUSD", ...}."""
    out = {}
    for part in (text or "").split(","):
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip().upper()] = v.strip()
    return out


@dataclass
class PaperBroker:
    settings: Settings
    data: object
    state_file: Path
    fee_bps: float = 1.5
    stop_slippage_bps: float = 3.0
    contract_size: float = 100.0      # units per lot on the mirror platform (gold: 100 oz)
    lot_step: float = 0.01
    mt5_symbols: dict = field(default_factory=dict)
    account_currency: str = "USD"
    account_id: str = "PAPER"
    cash: float = 0.0
    _pos: dict = field(default_factory=dict)       # symbol -> [signed qty, avg price]
    _stops: dict = field(default_factory=dict)     # symbol -> OrderRef
    _seq: int = 0
    _connected: bool = False

    # -- lifecycle ---------------------------------------------------------------------------
    def connect(self) -> None:
        if self.state_file.exists():
            st = json.loads(self.state_file.read_text())
            self.cash = float(st.get("cash", self.settings.paper_equity))
            self._pos = {k: [float(q), float(a)] for k, (q, a) in st.get("positions", {}).items()}
        else:
            self.cash = float(self.settings.paper_equity)
            self._save()
        self._connected = True
        log.info("Paper account: cash %.2f, %d open position(s), costs %.1f bps/side + %.1f bps stop slippage",
                 self.cash, len(self._pos), self.fee_bps, self.stop_slippage_bps)

    def disconnect(self) -> None:
        self._save()
        self._connected = False

    def is_connected(self) -> bool:
        return self._connected

    def sleep(self, seconds: float) -> None:
        _time.sleep(seconds)

    def _save(self) -> None:
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        self.state_file.write_text(json.dumps({"cash": round(self.cash, 6), "positions": self._pos}, indent=1))

    # -- account ------------------------------------------------------------------------------
    def net_liquidation(self) -> float:
        eq = self.cash
        for sym, (q, avg) in self._pos.items():
            last = self.last_price(sym)
            if last is not None:
                eq += q * (last - avg)
        return eq

    def positions(self) -> list[PositionInfo]:
        return [PositionInfo(sym, q, avg) for sym, (q, avg) in self._pos.items() if abs(q) > 1e-12]  # type: ignore[arg-type]

    def is_tradable(self, symbol: str) -> bool:
        return True

    # -- data (delegated) -------------------------------------------------------------------------
    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        return self.data.daily_bars(symbol, days)

    def intraday_bars(self, symbol: str, bar_minutes: int = 60, days: int = 5,
                      include_premarket: bool = True) -> list[Bar]:
        return self.data.intraday_bars(symbol, bar_minutes, days, include_premarket)

    def last_price(self, symbol: str) -> float | None:
        return self.data.last_price(symbol)

    # -- fills --------------------------------------------------------------------------------------
    def lots(self, qty: float) -> float:
        return math.floor(abs(qty) / self.contract_size / self.lot_step + 1e-9) * self.lot_step

    def _round_qty(self, qty: float) -> float:
        return round(self.lots(qty) * self.contract_size, 8)

    def _apply(self, symbol: str, signed_qty: float, price: float) -> None:
        q0, a0 = self._pos.get(symbol, [0.0, 0.0])
        q1 = q0 + signed_qty
        if q0 == 0 or (q0 > 0) == (signed_qty > 0):  # open or add
            a1 = (q0 * a0 + signed_qty * price) / q1 if q1 else 0.0
        else:  # reduce, close or flip: realise P&L on the closed part
            closed = min(abs(signed_qty), abs(q0))
            self.cash += closed * (price - a0) * (1 if q0 > 0 else -1)
            a1 = a0 if (q1 == 0 or (q1 > 0) == (q0 > 0)) else price
        if abs(q1) < 1e-9:
            self._pos.pop(symbol, None)
        else:
            self._pos[symbol] = [q1, a1]
        self._save()

    def _next(self) -> int:
        self._seq -= 1
        return self._seq

    def _cost(self, price: float, buying: bool, extra_bps: float = 0.0) -> float:
        adj = price * (self.fee_bps + extra_bps) / 10_000.0
        return price + adj if buying else price - adj

    def place_entry_with_stop(self, symbol: str, side: str, qty: float, stop: float,
                              limit: float | None = None) -> tuple[OrderRef, OrderRef]:
        last = self.last_price(symbol)
        q = self._round_qty(qty)
        if last is None or q <= 0:
            why = "no price" if last is None else f"size below one {self.lot_step} lot"
            log.warning("%s paper entry skipped: %s (wanted %.4f units)", symbol, why, qty)
            dead = OrderRef(order_id=self._next(), symbol=symbol, kind="ENTRY", qty=qty, status="Cancelled")
            return dead, OrderRef(order_id=self._next(), symbol=symbol, kind="STOP", status="Cancelled")
        buying = side == LONG
        fill = self._cost(last, buying)
        self._apply(symbol, q if buying else -q, fill)
        entry = OrderRef(order_id=self._next(), symbol=symbol, kind="ENTRY", qty=q, price=fill, status="Filled",
                         avg_fill=fill, filled=q)
        log.info("[paper] %s %s x%s @ %s stop %s", "BUY" if buying else "SELL", symbol, q, px(fill), px(stop))
        return entry, self.place_stop(symbol, side, q, stop)

    def place_stop(self, symbol: str, side: str, qty: float, stop: float) -> OrderRef:
        ref = OrderRef(order_id=self._next(), perm_id=0, symbol=symbol, kind="STOP", qty=qty, price=stop,
                       status="Submitted", raw={"side": side})
        self._stops[symbol] = ref
        return ref

    def wait_fill(self, ref: OrderRef, timeout: float = 0) -> OrderRef:
        return ref

    def refresh(self, ref: OrderRef) -> OrderRef:
        if ref.kind != "STOP" or ref.status != "Submitted":
            return ref
        last = self.last_price(ref.symbol)
        if last is None:
            return ref
        long_pos = (ref.raw or {}).get("side", LONG) == LONG
        if (long_pos and last > ref.price) or (not long_pos and last < ref.price):
            return ref
        held = abs(self._pos.get(ref.symbol, [0.0, 0.0])[0])
        q = min(ref.qty, held)
        fill = self._cost(last, not long_pos, self.stop_slippage_bps)
        if q > 0:
            self._apply(ref.symbol, -q if long_pos else q, fill)
        log.warning("[paper] %s stop hit at %s (stop %s)", ref.symbol, px(last), px(ref.price))
        ref.status, ref.filled, ref.avg_fill = "Filled", q or ref.qty, fill
        self._stops.pop(ref.symbol, None)
        return ref

    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: float | None = None) -> OrderRef:
        if price is not None:
            ref.price = price
        if qty is not None:
            ref.qty = qty
        return ref

    def cancel(self, ref: OrderRef) -> None:
        if ref.status == "Submitted":
            ref.status = "Cancelled"
        if self._stops.get(ref.symbol) is ref:
            self._stops.pop(ref.symbol, None)

    def market_close(self, symbol: str, side: str, qty: float) -> OrderRef:
        last = self.last_price(symbol)
        held = abs(self._pos.get(symbol, [0.0, 0.0])[0])
        q = min(qty, held)
        long_pos = side == LONG
        fill = self._cost(last, not long_pos) if last is not None else 0.0
        if q > 0 and last is not None:
            self._apply(symbol, -q if long_pos else q, fill)
        stop = self._stops.get(symbol)
        if stop is not None:
            left = abs(self._pos.get(symbol, [0.0, 0.0])[0])
            if left > 0:
                stop.qty = left
            else:
                stop.status = "Cancelled"
                self._stops.pop(symbol, None)
        return OrderRef(order_id=self._next(), symbol=symbol, kind="CLOSE", qty=q, price=fill,
                        status="Filled", avg_fill=fill, filled=q)

    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None:
        return None

    def cancel_all(self) -> None:
        self._stops.clear()

    # -- MT5 mirror instructions --------------------------------------------------------------------
    def mirror_note(self, event: str, symbol: str, side: str, qty: float, price: float | None = None,
                    stop: float | None = None) -> str:
        name = self.mt5_symbols.get(symbol.upper(), symbol.replace("/", ""))
        lots = self.lots(qty)
        last = self.last_price(symbol)
        if event == "entry":
            dist = abs((price or 0) - (stop or 0))
            return (f"MT5: {'BUY' if side == LONG else 'SELL'} {lots:.2f} lot {name}, stop loss {dist:.2f} "
                    f"{'below' if side == LONG else 'above'} your fill (here {px(stop or 0)}; prices here are "
                    f"futures, keep the distance on spot)")
        if event == "stop":
            dist = abs((last or 0) - (stop or 0))
            return (f"MT5: move {name} stop loss to {dist:.2f} {'below' if side == LONG else 'above'} the current "
                    f"price (here {px(stop or 0)} vs price {px(last or 0)})")
        if event == "partial":
            return f"MT5: close {lots:.2f} lot of {name}"
        return f"MT5: close the {name} position if your stop loss hasn't already closed it"
