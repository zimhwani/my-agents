"""Trade journal: append-only JSONL of closed trades plus summary statistics."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .models import TradeRecord


class Journal:
    """``path=None`` keeps trades in memory only (backtests, tests)."""

    def __init__(self, path: str | Path | None):
        self.path = Path(path) if path else None
        self._memory: list[TradeRecord] = []
        if self.path:
            self.path.parent.mkdir(parents=True, exist_ok=True)

    def append(self, trade: TradeRecord) -> None:
        if self.path is None:
            self._memory.append(trade)
            return
        with self.path.open("a") as fh:
            fh.write(json.dumps(trade.to_dict()) + "\n")

    def load(self) -> list[TradeRecord]:
        if self.path is None:
            return sorted(self._memory, key=lambda t: t.entry_time)
        if not self.path.exists():
            return []
        out = []
        for line in self.path.read_text().splitlines():
            line = line.strip()
            if line:
                out.append(TradeRecord.from_dict(json.loads(line)))
        out.sort(key=lambda t: t.entry_time)
        return out


@dataclass
class Stats:
    trades: int = 0
    wins: int = 0
    losses: int = 0
    scratches: int = 0
    win_rate: float = 0.0
    total_r: float = 0.0
    avg_r: float = 0.0
    avg_win_r: float = 0.0
    avg_loss_r: float = 0.0
    expectancy_r: float = 0.0
    profit_factor: float = 0.0
    max_drawdown_r: float = 0.0
    best_r: float = 0.0
    worst_r: float = 0.0
    total_pnl: float = 0.0

    def as_dict(self) -> dict:
        return {k: (round(v, 3) if isinstance(v, float) else v) for k, v in self.__dict__.items()}


def compute_stats(trades: list[TradeRecord], scratch_band: float = 0.1) -> Stats:
    closed = [t for t in trades if t.status == "CLOSED"]
    st = Stats(trades=len(closed))
    if not closed:
        return st
    rs = [t.r_multiple for t in closed]
    wins = [r for r in rs if r > scratch_band]
    losses = [r for r in rs if r < -scratch_band]
    st.wins, st.losses = len(wins), len(losses)
    st.scratches = len(rs) - len(wins) - len(losses)
    decided = st.wins + st.losses
    st.win_rate = st.wins / decided if decided else 0.0
    st.total_r = sum(rs)
    st.avg_r = st.total_r / len(rs)
    st.avg_win_r = sum(wins) / len(wins) if wins else 0.0
    st.avg_loss_r = sum(losses) / len(losses) if losses else 0.0
    st.expectancy_r = st.win_rate * st.avg_win_r + (1 - st.win_rate) * st.avg_loss_r if decided else 0.0
    gross_win = sum(r for r in rs if r > 0)
    gross_loss = -sum(r for r in rs if r < 0)
    st.profit_factor = gross_win / gross_loss if gross_loss > 0 else (float("inf") if gross_win > 0 else 0.0)
    peak = cum = 0.0
    dd = 0.0
    for r in rs:
        cum += r
        peak = max(peak, cum)
        dd = min(dd, cum - peak)
    st.max_drawdown_r = dd
    st.best_r, st.worst_r = max(rs), min(rs)
    st.total_pnl = sum(t.realized_pnl for t in closed)
    return st
