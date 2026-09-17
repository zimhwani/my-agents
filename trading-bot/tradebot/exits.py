"""Exit management, as pure functions over an open trade and the latest price.

The broker always holds a hard stop order; this module decides when to move
it, when to take partial profit, and when to get flat. Being pure (no I/O)
means the exact same rules run in the backtest and in live trading.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time

from .clock import to_et
from .models import TradeRecord
from .strategy import StrategyParams

PARTIAL = "PARTIAL"
MOVE_STOP = "MOVE_STOP"
CLOSE = "CLOSE"


@dataclass
class ExitAction:
    kind: str
    qty: int = 0
    price: float = 0.0
    reason: str = ""


class ExitManager:
    def __init__(self, params: StrategyParams, force_close_time: time = time(15, 50)):
        self.p = params
        self.force_close_time = force_close_time

    def manage(self, trade: TradeRecord, price: float, atr: float, now: datetime,
               bar_high: float | None = None, bar_low: float | None = None) -> list[ExitAction]:
        now = to_et(now)
        actions: list[ExitAction] = []
        if trade.status != "OPEN" or trade.qty_open <= 0:
            return actions
        trade.touch(price)
        if bar_high is not None:
            trade.touch(bar_high)
        if bar_low is not None:
            trade.touch(bar_low)

        # 1. forced flat before the close
        if now.time() >= self.force_close_time:
            return [ExitAction(CLOSE, trade.qty_open, price, "eod")]

        r = trade.unrealized_r(price)
        p = self.p

        # 2. belt and braces: if price is through the stop, get out (the
        #    broker stop should already have fired; this covers a missing one)
        through_stop = price <= trade.stop if trade.is_long else price >= trade.stop
        if through_stop:
            return [ExitAction(CLOSE, trade.qty_open, price, "stop")]

        # 3. hard target on whatever is left
        if r >= p.final_target_r:
            return [ExitAction(CLOSE, trade.qty_open, price, "target")]

        # 4. partial at +partial_r, then breakeven
        candidates: list[tuple[float, str]] = []
        if not trade.partial_taken and r >= p.partial_r:
            qty = int(round(trade.qty_open * p.partial_fraction))
            if 0 < qty < trade.qty_open:
                actions.append(ExitAction(PARTIAL, qty, price, "partial"))
            trade.partial_taken = True  # a 1-share trade just moves to breakeven
            if p.breakeven_after_partial:
                candidates.append((trade.entry_price, "breakeven"))

        # 5. trail once we are in the money (after the partial)
        if trade.partial_taken and atr > 0:
            trail = (trade.highest - p.trail_atr_mult * atr) if trade.is_long \
                else (trade.lowest + p.trail_atr_mult * atr)
            candidates.append((round(trail, 2), "trail"))

        # tighten the stop to the best candidate, never loosen it
        best = None
        for level, why in candidates:
            if self._better(trade, level) and (best is None or self._better_than(trade, level, best[0])):
                best = (level, why)
        if best:
            actions.append(ExitAction(MOVE_STOP, price=best[0], reason=best[1]))

        # 6. time stop: not working after N minutes -> free the capital
        if not trade.partial_taken and p.time_stop_minutes > 0:
            age = (now - to_et(trade.entry_time)).total_seconds() / 60.0
            if age >= p.time_stop_minutes and r < p.time_stop_min_r:
                return [ExitAction(CLOSE, trade.qty_open, price, "time")]
        return actions

    # -- helpers -------------------------------------------------------------
    def _better(self, trade: TradeRecord, new_stop: float) -> bool:
        """Would ``new_stop`` tighten the current stop?"""
        return self._better_than(trade, new_stop, trade.stop)

    @staticmethod
    def _better_than(trade: TradeRecord, a: float, b: float) -> bool:
        return a > b if trade.is_long else a < b
