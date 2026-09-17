"""Position sizing and the pre-trade risk gate."""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from .config import Settings
from .models import TradeRecord


def position_size(equity: float, entry: float, stop: float, risk_pct: float,
                  max_risk_usd: float, max_position_pct: float) -> int:
    """Shares such that (entry - stop) * shares <= min(risk_pct% of equity, cap),
    and shares * entry <= max_position_pct% of equity. 0 if the trade doesn't fit."""
    risk_per_share = abs(entry - stop)
    if risk_per_share <= 0 or equity <= 0 or entry <= 0:
        return 0
    risk_budget = min(equity * risk_pct / 100.0, max_risk_usd)
    by_risk = math.floor(risk_budget / risk_per_share)
    by_size = math.floor(equity * max_position_pct / 100.0 / entry)
    return max(0, min(by_risk, by_size))


@dataclass
class DayStats:
    start_equity: float
    realized_r: float = 0.0
    realized_pnl: float = 0.0
    trades_opened: int = 0


class RiskGate:
    def __init__(self, settings: Settings):
        self.s = settings

    def kill_switch_on(self) -> bool:
        return Path(self.s.kill_switch_file).exists()

    def blockers(self, open_trades: list[TradeRecord], day: DayStats,
                 equity: float, now: datetime) -> list[str]:
        """Reasons a NEW entry is not allowed right now (empty = OK)."""
        out: list[str] = []
        if self.kill_switch_on():
            out.append(f"kill switch file present ({self.s.kill_switch_file})")
        if len(open_trades) >= self.s.max_positions:
            out.append(f"max positions ({self.s.max_positions}) reached")
        if day.realized_r <= self.s.max_daily_loss_r:
            out.append(f"daily loss limit hit ({day.realized_r:.2f}R)")
        if day.start_equity > 0:
            dd = (equity - day.start_equity) / day.start_equity * 100.0
            if dd <= -abs(self.s.max_daily_loss_pct):
                out.append(f"daily equity drawdown {dd:.2f}% beyond limit")
        if now.time() >= self.s.force_close_time:
            out.append("past force-close time")
        return out
