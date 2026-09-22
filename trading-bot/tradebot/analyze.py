"""Post-backtest analysis: where does the edge (or the bleed) come from?

``breakdown`` slices closed trades by exit mix, entry time, opening-range
width, relative volume, weekday and symbol. ``sweep`` re-runs the backtester
over a small parameter grid. Both are offline and read only the journal / CSV
bars, so they're safe to run as often as you like.

Caveat that applies to everything here: 55 days is a small sample. Prefer
changes that make sense (fewer, better-filtered trades) over ones that merely
look best in the table, and re-check them on the next month's data.
"""

from __future__ import annotations

import itertools
import re
from collections import defaultdict
from dataclasses import replace

from .journal import compute_stats
from .models import TradeRecord

_OR_RE = re.compile(r"OR ([0-9.]+)%")
_RV_RE = re.compile(r"relvol ([0-9.]+)")


def _bucket(value: float | None, edges: list[float], labels: list[str]) -> str:
    if value is None:
        return "n/a"
    for edge, label in zip(edges, labels):
        if value < edge:
            return label
    return labels[-1]


def _row(label: str, trades: list[TradeRecord]) -> str:
    st = compute_stats(trades)
    pf = "inf" if st.profit_factor == float("inf") else f"{st.profit_factor:4.2f}"
    return (f"{label:<22} {st.trades:>5} {st.win_rate*100:>5.0f}% {st.total_r:>+8.1f}R "
            f"{st.expectancy_r:>+6.2f}R  PF {pf}")


def _table(title: str, groups: dict[str, list[TradeRecord]], order: list[str] | None = None,
           min_trades: int = 1) -> list[str]:
    keys = order or sorted(groups, key=lambda k: -compute_stats(groups[k]).expectancy_r)
    lines = [f"\n{title}", f"{'':<22} {'n':>5} {'win':>6} {'total':>9} {'exp':>7}"]
    for k in keys:
        if k in groups and len(groups[k]) >= min_trades:
            lines.append(_row(k, groups[k]))
    return lines


def breakdown(trades: list[TradeRecord]) -> str:
    closed = [t for t in trades if t.status == "CLOSED"]
    if not closed:
        return "No closed trades."
    lines = ["OVERALL", _row("all trades", closed)]

    # exit mix: how did trades end?
    by_exit: dict[str, list[TradeRecord]] = defaultdict(list)
    for t in closed:
        by_exit[",".join(dict.fromkeys(f.reason for f in t.exits))].append(t)
    lines += _table("BY EXIT PATH (how the trade ended)", by_exit)

    by_hour: dict[str, list[TradeRecord]] = defaultdict(list)
    for t in closed:
        h, m = t.entry_time.hour, t.entry_time.minute
        by_hour[f"{h:02d}:{(m // 15) * 15:02d}"].append(t)
    lines += _table("BY ENTRY TIME (ET, 15-min buckets)", by_hour, order=sorted(by_hour))

    by_or: dict[str, list[TradeRecord]] = defaultdict(list)
    by_rv: dict[str, list[TradeRecord]] = defaultdict(list)
    for t in closed:
        m = _OR_RE.search(t.reason)
        r = _RV_RE.search(t.reason)
        by_or[_bucket(float(m.group(1)) if m else None, [0.5, 1.0, 1.5, 2.0],
                      ["OR <0.5%", "OR 0.5-1%", "OR 1-1.5%", "OR 1.5-2%", "OR >2%"])].append(t)
        by_rv[_bucket(float(r.group(1)) if r else None, [1.5, 2.0, 3.0],
                      ["relvol <1.5", "relvol 1.5-2", "relvol 2-3", "relvol >3"])].append(t)
    lines += _table("BY OPENING-RANGE WIDTH (% of price)", by_or,
                    order=["OR <0.5%", "OR 0.5-1%", "OR 1-1.5%", "OR 1.5-2%", "OR >2%", "n/a"])
    lines += _table("BY RELATIVE VOLUME AT ENTRY", by_rv,
                    order=["relvol <1.5", "relvol 1.5-2", "relvol 2-3", "relvol >3", "n/a"])

    by_dow: dict[str, list[TradeRecord]] = defaultdict(list)
    for t in closed:
        by_dow[t.entry_time.strftime("%a")].append(t)
    lines += _table("BY WEEKDAY", by_dow, order=["Mon", "Tue", "Wed", "Thu", "Fri"])

    by_sym: dict[str, list[TradeRecord]] = defaultdict(list)
    for t in closed:
        by_sym[t.symbol].append(t)
    ranked = sorted(by_sym, key=lambda k: -compute_stats(by_sym[k]).total_r)
    lines += _table("BEST SYMBOLS (by total R, >=3 trades)", {k: by_sym[k] for k in ranked[:8]},
                    order=ranked[:8], min_trades=3)
    lines += _table("WORST SYMBOLS (by total R, >=3 trades)", {k: by_sym[k] for k in ranked[-8:]},
                    order=ranked[-8:], min_trades=3)

    by_day: dict[str, float] = defaultdict(float)
    for t in closed:
        by_day[t.entry_time.strftime("%Y-%m-%d")] += t.r_multiple
    days = sorted(by_day.values())
    lines += [f"\nDAYS: {len(days)}  green {sum(1 for d in days if d > 0)}  red {sum(1 for d in days if d < 0)}  "
              f"best {max(days):+.1f}R  worst {min(days):+.1f}R  trades/day {len(closed)/len(days):.1f}"]
    return "\n".join(lines)


DEFAULT_GRID: dict[str, list] = {
    "opening_range_minutes": [15, 30],
    "min_rel_volume": [1.2, 1.5, 2.0],
    "entry_window_end": ["10:30", "11:30"],
    "stop_atr_mult": [1.0, 1.5],
}


TJL_GRID: dict[str, list] = {
    "max_initial_risk_pct": [0, 2.0, 3.0, 4.0],
    "max_initial_risk_mode": ["skip", "cap"],
    "latest_entry": ["10:30", "12:00", "15:30"],
}


CRYPTO_BREAKOUT_GRID: dict[str, list] = {
    "breakout_bars": [12, 24, 48],
    "min_rel_volume": [1.0, 1.5],
    "stop_atr_mult": [1.5, 2.5],
    "trail": ["atr_2.5", "atr_4.0"],
    "partial_r": [1.0, 2.0],
}


CRYPTO_PULLBACK_GRID: dict[str, list] = {
    "rsi_buy": [25.0, 30.0, 35.0],
    "trend_ema_bars": [100, 200],
    "stop_atr_mult": [1.5, 2.5],
    "trail": ["atr_2.5", "atr_4.0"],
    "partial_r": [1.0, 2.0],
}


def default_grid(params) -> dict[str, list]:
    name = params.__class__.__name__
    if name == "TJLRules":
        return TJL_GRID
    if name == "CryptoRules":
        return CRYPTO_PULLBACK_GRID if getattr(params, "mode", "") == "pullback" else CRYPTO_BREAKOUT_GRID
    return DEFAULT_GRID


def sweep(settings, params, bars, grid: dict[str, list] | None = None, equity: float = 100_000,
          daily=None, fee_bps: float = 0.0, progress=None):
    """Backtest every combination in ``grid``; returns rows sorted by expectancy.
    ``params`` is a StrategyParams (ORB), a TJLRules (Trend Join Long) or CryptoRules."""
    from .backtest import Backtester

    kind = params.__class__.__name__
    grid = grid or default_grid(params)
    keys = list(grid)
    rows = []
    combos = list(itertools.product(*(grid[k] for k in keys)))
    for i, combo in enumerate(combos, 1):
        p = replace(params, **dict(zip(keys, combo)))
        if kind == "TJLRules":
            from .tjl import loaded_from_rules
            loaded = loaded_from_rules(p)
            loaded.apply(settings)
            p = loaded
        elif kind == "CryptoRules":
            from .crypto import loaded_from_rules as crypto_loaded
            loaded = crypto_loaded(p)
            loaded.apply(settings)
            p = loaded
        if progress:
            progress(i, len(combos), dict(zip(keys, combo)))
        res = Backtester(settings, p, bars, daily=daily, equity=equity, fee_bps=fee_bps).run()
        st = res.stats
        rows.append({**dict(zip(keys, combo)), "trades": st.trades, "win_rate": st.win_rate,
                     "total_r": st.total_r, "expectancy": st.expectancy_r,
                     "profit_factor": st.profit_factor, "max_dd": st.max_drawdown_r})
    rows.sort(key=lambda r: (-r["expectancy"], -r["total_r"]))
    return rows


def format_sweep(rows: list[dict]) -> str:
    if not rows:
        return "no results"
    keys = [k for k in rows[0] if k not in ("trades", "win_rate", "total_r", "expectancy", "profit_factor", "max_dd")]
    head = "  ".join(f"{k[:14]:<14}" for k in keys) + f"  {'n':>4} {'win':>5} {'total':>8} {'exp':>7} {'PF':>5} {'maxDD':>7}"
    out = [head]
    for r in rows:
        pf = "inf" if r["profit_factor"] == float("inf") else f"{r['profit_factor']:.2f}"
        out.append("  ".join(f"{str(r[k]):<14}" for k in keys) +
                   f"  {r['trades']:>4} {r['win_rate']*100:>4.0f}% {r['total_r']:>+7.1f}R {r['expectancy']:>+6.2f}R "
                   f"{pf:>5} {r['max_dd']:>+6.1f}R")
    return "\n".join(out)
