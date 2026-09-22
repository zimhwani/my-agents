"""Plain data structures shared by every stage of the pipeline."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Any

from .clock import to_et

LONG = "LONG"
SHORT = "SHORT"


def px(price: float) -> str:
    """Price for humans: 2dp for normal prices, more for sub-dollar and sub-cent coins."""
    a = abs(price)
    if a >= 1:
        return f"{price:.2f}"
    if a >= 0.01:
        return f"{price:.4f}"
    if a == 0:
        return "0.00"
    s = f"{price:.10f}".rstrip("0")  # plain decimals, 6 significant digits, no exponent
    digits = 0
    out = []
    for ch in s:
        out.append(ch)
        if ch.isdigit() and (digits or ch != "0"):
            digits += 1
        if digits == 6:
            break
    return "".join(out).rstrip("0") if "." in "".join(out) else "".join(out)


@dataclass(slots=True)
class Bar:
    time: datetime  # bar START time, tz-aware ET
    open: float
    high: float
    low: float
    close: float
    volume: float

    @property
    def typical(self) -> float:
        return (self.high + self.low + self.close) / 3.0


@dataclass
class Signal:
    symbol: str
    side: str  # LONG / SHORT
    entry: float
    stop: float
    target: float
    atr: float
    time: datetime
    reason: str = ""

    @property
    def risk_per_share(self) -> float:
        return abs(self.entry - self.stop)

    @property
    def is_long(self) -> bool:
        return self.side == LONG


@dataclass
class Fill:
    time: datetime
    qty: int
    price: float
    reason: str  # partial / trail / stop / target / time / eod / manual


@dataclass
class TradeRecord:
    """One round-trip trade: an entry plus one or more exits.

    R multiple = realized P&L / (initial risk per share x initial quantity),
    so a trade stopped out at its original stop is exactly -1R.
    """

    id: str
    symbol: str
    side: str
    qty_initial: int
    entry_price: float
    entry_time: datetime
    stop_initial: float
    stop: float
    target: float
    atr: float
    qty_open: int = 0
    partial_taken: bool = False
    highest: float = 0.0
    lowest: float = 0.0
    exits: list[Fill] = field(default_factory=list)
    status: str = "OPEN"
    entry_order_id: int | None = None
    stop_order_id: int | None = None
    stop_perm_id: int | None = None
    reason: str = ""

    def __post_init__(self) -> None:
        if self.qty_open == 0 and self.status == "OPEN":
            self.qty_open = self.qty_initial
        if self.highest == 0.0:
            self.highest = self.entry_price
        if self.lowest == 0.0:
            self.lowest = self.entry_price

    # ---- derived -------------------------------------------------------
    @property
    def is_long(self) -> bool:
        return self.side == LONG

    @property
    def direction(self) -> int:
        return 1 if self.is_long else -1

    @property
    def risk_per_share(self) -> float:
        return abs(self.entry_price - self.stop_initial)

    @property
    def initial_risk_usd(self) -> float:
        return self.risk_per_share * self.qty_initial

    @property
    def realized_pnl(self) -> float:
        return sum((f.price - self.entry_price) * self.direction * f.qty for f in self.exits)

    @property
    def r_multiple(self) -> float:
        risk = self.initial_risk_usd
        return self.realized_pnl / risk if risk > 0 else 0.0

    def unrealized_r(self, price: float) -> float:
        if self.risk_per_share <= 0:
            return 0.0
        return (price - self.entry_price) * self.direction / self.risk_per_share

    def open_pnl(self, price: float) -> float:
        return (price - self.entry_price) * self.direction * self.qty_open

    @property
    def exit_price_avg(self) -> float | None:
        q = sum(f.qty for f in self.exits)
        return sum(f.price * f.qty for f in self.exits) / q if q else None

    @property
    def last_exit_time(self) -> datetime | None:
        return self.exits[-1].time if self.exits else None

    # ---- mutation ------------------------------------------------------
    def touch(self, price: float) -> None:
        self.highest = max(self.highest, price)
        self.lowest = min(self.lowest, price)

    def record_exit(self, time: datetime, qty: int, price: float, reason: str) -> None:
        qty = min(qty, self.qty_open)
        if qty <= 0:
            return
        self.exits.append(Fill(time=to_et(time), qty=qty, price=price, reason=reason))
        self.qty_open -= qty
        if self.qty_open == 0:
            self.status = "CLOSED"

    # ---- serialization -------------------------------------------------
    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["entry_time"] = self.entry_time.isoformat()
        d["exits"] = [{**asdict(f), "time": f.time.isoformat()} for f in self.exits]
        d["realized_pnl"] = round(self.realized_pnl, 2)
        d["r_multiple"] = round(self.r_multiple, 3)
        return d

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "TradeRecord":
        d = dict(d)
        d.pop("realized_pnl", None)
        d.pop("r_multiple", None)
        d["entry_time"] = to_et(datetime.fromisoformat(d["entry_time"]))
        d["exits"] = [Fill(time=to_et(datetime.fromisoformat(f["time"])), qty=f["qty"],
                           price=f["price"], reason=f["reason"]) for f in d.get("exits", [])]
        return cls(**d)
