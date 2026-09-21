"""Exit management, as pure functions over an open trade and the latest price.

The broker (or the bot's software stop) always holds a hard stop; this module
decides when to move it, when to take partial profit, and when to get flat.
Being pure (no I/O) means the exact same rules run in the backtest and live.

``ExitRules`` describes a rule set. Two ship with the bot:

* ORB: half off at +1R, breakeven at +1R, ATR trail, hard target +3R, time stop.
* Trend Join Long: a third off at +0.75R, breakeven at +1R, then trail under
  confirmed 5-minute swing lows (2 bars either side).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time

from .clock import to_et
from .models import Bar, TradeRecord

PARTIAL = "PARTIAL"
MOVE_STOP = "MOVE_STOP"
CLOSE = "CLOSE"


@dataclass
class ExitRules:
    partial_r: float = 1.0            # take partial_fraction off at this R (0 = never)
    partial_fraction: float = 0.5
    breakeven_r: float = 1.0          # move the stop to entry at this R (0 = never)
    trail_mode: str = "atr"           # atr | swing_low | none
    trail_atr_mult: float = 1.5
    swing_left: int = 2               # swing low = lower than N bars before ...
    swing_right: int = 2              # ... and N bars after (confirmation)
    trail_after_breakeven_only: bool = True
    final_target_r: float = 3.0       # close the remainder here (0 = none)
    time_stop_minutes: int = 120      # 0 = none
    time_stop_min_r: float = 0.5
    fractional: bool = False          # crypto: partial quantities are fractional


@dataclass
class ExitAction:
    kind: str
    qty: int = 0
    price: float = 0.0
    reason: str = ""


def swing_lows(bars: list[Bar], left: int = 2, right: int = 2) -> list[Bar]:
    """Bars whose low is below the ``left`` bars before and ``right`` bars after."""
    out = []
    for i in range(left, len(bars) - right):
        lo = bars[i].low
        if all(bars[j].low > lo for j in range(i - left, i)) and \
           all(bars[j].low > lo for j in range(i + 1, i + right + 1)):
            out.append(bars[i])
    return out


def swing_highs(bars: list[Bar], left: int = 2, right: int = 2) -> list[Bar]:
    out = []
    for i in range(left, len(bars) - right):
        hi = bars[i].high
        if all(bars[j].high < hi for j in range(i - left, i)) and \
           all(bars[j].high < hi for j in range(i + 1, i + right + 1)):
            out.append(bars[i])
    return out


class ExitManager:
    def __init__(self, rules, force_close_time: time | None = time(15, 50)):
        # accept a StrategyParams (ORB) as well as an ExitRules; force_close_time=None = 24/7 market
        self.r: ExitRules = rules.to_exit_rules() if hasattr(rules, "to_exit_rules") else rules
        self.force_close_time = force_close_time

    def manage(self, trade: TradeRecord, price: float, atr: float, now: datetime,
               bar_high: float | None = None, bar_low: float | None = None,
               bars: list[Bar] | None = None) -> list[ExitAction]:
        """``bars``: today's completed session bars (needed for the swing trail)."""
        now = to_et(now)
        actions: list[ExitAction] = []
        if trade.status != "OPEN" or trade.qty_open <= 0:
            return actions
        trade.touch(price)
        if bar_high is not None:
            trade.touch(bar_high)
        if bar_low is not None:
            trade.touch(bar_low)

        # 1. forced flat before the close (not for 24/7 markets)
        if self.force_close_time is not None and now.time() >= self.force_close_time:
            return [ExitAction(CLOSE, trade.qty_open, price, "eod")]

        r = trade.unrealized_r(price)
        rules = self.r

        # 2. belt and braces: if price is through the stop, get out (the
        #    broker/software stop should already have fired; this covers a missing one)
        through_stop = price <= trade.stop if trade.is_long else price >= trade.stop
        if through_stop:
            return [ExitAction(CLOSE, trade.qty_open, price, "stop")]

        # 3. hard target on whatever is left
        if rules.final_target_r > 0 and r >= rules.final_target_r:
            return [ExitAction(CLOSE, trade.qty_open, price, "target")]

        # 4. partial
        if rules.partial_r > 0 and not trade.partial_taken and r >= rules.partial_r:
            qty = round(trade.qty_open * rules.partial_fraction, 6) if rules.fractional \
                else int(round(trade.qty_open * rules.partial_fraction))
            if 0 < qty < trade.qty_open:
                actions.append(ExitAction(PARTIAL, qty, price, "partial"))
            trade.partial_taken = True  # a 1-share trade just carries on to breakeven

        # 5. breakeven and trail candidates; the stop only ever tightens
        candidates: list[tuple[float, str]] = []
        at_breakeven = self._better_or_equal(trade, trade.stop, trade.entry_price)
        if rules.breakeven_r > 0 and r >= rules.breakeven_r and not at_breakeven:
            candidates.append((trade.entry_price, "breakeven"))
            at_breakeven = True
        if rules.trail_mode != "none" and (at_breakeven or not rules.trail_after_breakeven_only):
            level = self._trail_level(trade, atr, bars)
            if level is not None:
                candidates.append((round(level, 2), "trail"))
        best = None
        for level, why in candidates:
            if self._better(trade, level) and (best is None or self._better_than(trade, level, best[0])):
                best = (level, why)
        if best:
            actions.append(ExitAction(MOVE_STOP, price=best[0], reason=best[1]))

        # 6. time stop: not working after N minutes -> free the capital
        if rules.time_stop_minutes > 0 and not trade.partial_taken:
            age = (now - to_et(trade.entry_time)).total_seconds() / 60.0
            if age >= rules.time_stop_minutes and r < rules.time_stop_min_r:
                return [ExitAction(CLOSE, trade.qty_open, price, "time")]
        return actions

    # -- helpers -------------------------------------------------------------
    def _trail_level(self, trade: TradeRecord, atr: float, bars: list[Bar] | None) -> float | None:
        rules = self.r
        if rules.trail_mode == "atr":
            if atr <= 0:
                return None
            return (trade.highest - rules.trail_atr_mult * atr) if trade.is_long \
                else (trade.lowest + rules.trail_atr_mult * atr)
        if rules.trail_mode == "swing_low":
            if not bars:
                return None
            pivots = swing_lows(bars, rules.swing_left, rules.swing_right) if trade.is_long \
                else swing_highs(bars, rules.swing_left, rules.swing_right)
            if not pivots:
                return None
            last = pivots[-1]
            return last.low if trade.is_long else last.high
        return None

    def _better(self, trade: TradeRecord, new_stop: float) -> bool:
        return self._better_than(trade, new_stop, trade.stop)

    @staticmethod
    def _better_than(trade: TradeRecord, a: float, b: float) -> bool:
        return a > b if trade.is_long else a < b

    @staticmethod
    def _better_or_equal(trade: TradeRecord, a: float, b: float) -> bool:
        return a >= b if trade.is_long else a <= b
