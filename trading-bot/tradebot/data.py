"""Bar data utilities: CSV persistence, IB download, daily aggregation and a
synthetic generator so the whole pipeline can be demoed with no broker."""

from __future__ import annotations

import csv
import logging
import random
from datetime import date, datetime, timedelta
from pathlib import Path

from . import clock
from .models import Bar

log = logging.getLogger("tradebot.data")

CSV_FIELDS = ["time", "open", "high", "low", "close", "volume"]


def save_csv(bars: list[Bar], path: str | Path) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(CSV_FIELDS)
        for b in bars:
            w.writerow([b.time.isoformat(), b.open, b.high, b.low, b.close, b.volume])


def load_csv(path: str | Path) -> list[Bar]:
    out = []
    with Path(path).open() as fh:
        for row in csv.DictReader(fh):
            out.append(Bar(clock.to_et(datetime.fromisoformat(row["time"])), float(row["open"]),
                           float(row["high"]), float(row["low"]), float(row["close"]),
                           float(row["volume"])))
    out.sort(key=lambda b: b.time)
    return out


def load_dir(directory: str | Path, suffix: str = "_5min.csv") -> dict[str, list[Bar]]:
    d = Path(directory)
    out = {}
    for p in sorted(d.glob(f"*{suffix}")):
        out[p.name[: -len(suffix)]] = load_csv(p)
    return out


def load_daily_dir(directory: str | Path) -> dict[str, list[Bar]]:
    return load_dir(directory, suffix="_1d.csv")


def aggregate_daily(intraday: list[Bar]) -> list[Bar]:
    """Daily bars from intraday session bars (stamped at 16:00 ET)."""
    days: dict[date, Bar] = {}
    for b in sorted(intraday, key=lambda b: b.time):
        d = b.time.date()
        cur = days.get(d)
        if cur is None:
            days[d] = Bar(clock.at(d, clock.MARKET_CLOSE), b.open, b.high, b.low, b.close, b.volume)
        else:
            cur.high = max(cur.high, b.high)
            cur.low = min(cur.low, b.low)
            cur.close = b.close
            cur.volume += b.volume
    return [days[d] for d in sorted(days)]


def synthetic_daily(symbol: str, days: int = 300, seed: int | None = None, end_price: float = 100.0,
                    end: date | None = None, drift: float = 0.0004) -> list[Bar]:
    """Daily history ending the session BEFORE ``end`` at ``end_price`` (walked
    backwards), so it lines up with ``synthetic_bars`` for the same symbol."""
    rng = random.Random((seed if seed is not None else hash(symbol) & 0xFFFF) + 7)
    end = end or clock.now_et().date()
    d = end - timedelta(days=1)
    out: list[Bar] = []
    price = end_price
    while len(out) < days:
        if clock.is_trading_day(d):
            c = price
            o = c / (1 + rng.gauss(drift, 0.015))
            h = max(o, c) * (1 + abs(rng.gauss(0, 0.006)))
            lo = min(o, c) * (1 - abs(rng.gauss(0, 0.006)))
            out.append(Bar(clock.at(d, clock.MARKET_CLOSE), round(o, 2), round(h, 2), round(lo, 2),
                           round(c, 2), round(rng.uniform(1.5e6, 4e6))))
            price = o
        d -= timedelta(days=1)
    out.reverse()
    return out


def synthetic_bars(symbol: str, days: int = 40, bar_minutes: int = 5, seed: int | None = None,
                   start_price: float = 100.0, end: date | None = None,
                   gap_days: float = 0.0) -> list[Bar]:
    """Random-walk session bars with realistic U-shaped volume and, on some
    days, a persistent post-open drift so the ORB strategy has something to
    catch. ``gap_days`` is the share of days that open with a 3-7% gap and a
    high-volume trend (for the gap-and-go strategy). Purely for demos/tests."""
    rng = random.Random(seed if seed is not None else hash(symbol) & 0xFFFF)
    end = end or clock.now_et().date()
    day = end
    trading_days: list[date] = []
    while len(trading_days) < days:
        if clock.is_trading_day(day):
            trading_days.append(day)
        day -= timedelta(days=1)
    trading_days.reverse()
    per_day = 390 // bar_minutes
    price = start_price
    daily_vol = 0.018
    out: list[Bar] = []
    for d in trading_days:
        gap_day = rng.random() < gap_days
        if gap_day:
            price *= 1 + rng.uniform(0.03, 0.07)  # gap up
        else:
            price *= 1 + rng.gauss(0.0, 0.006)  # overnight noise
        regime = rng.random()
        drift = 0.0
        if gap_day:
            drift = rng.choice([-1, 1, 1]) * daily_vol / per_day * 2.0  # gaps usually (not always) run
        elif regime < 0.25:
            drift = rng.choice([-1, 1]) * daily_vol / per_day * 1.6  # trend day
        bar_sigma = daily_vol / (per_day ** 0.5)
        vol_mult = rng.uniform(2.5, 4.0) if gap_day else 1.0
        t = clock.session_open(d)
        for i in range(per_day):
            u = abs(i - per_day / 2) / (per_day / 2)
            vol = 40_000 * (0.5 + 1.5 * u ** 2) * rng.uniform(0.6, 1.4) * vol_mult
            o = price
            step = rng.gauss(drift if i >= 3 else 0.0, bar_sigma)
            c = o * (1 + step)
            wick = abs(rng.gauss(0, bar_sigma * 0.6)) * o
            h = max(o, c) + wick
            lo = min(o, c) - abs(rng.gauss(0, bar_sigma * 0.6)) * o
            out.append(Bar(t, round(o, 2), round(h, 2), round(lo, 2), round(c, 2), round(vol)))
            price = c
            t += timedelta(minutes=bar_minutes)
    return out


def fetch_history(broker, symbol: str, days: int, bar_minutes: int = 5) -> list[Bar]:
    """Download intraday history from IB in 5-day chunks (IB pacing / duration
    limits) and return ascending, de-duplicated bars."""
    import time as _time

    chunk = 5
    end = ""
    seen: dict[datetime, Bar] = {}
    fetched_days = 0
    while fetched_days < days:
        raw = broker.ib.reqHistoricalData(
            broker.contract(symbol), endDateTime=end, durationStr=f"{chunk} D",
            barSizeSetting=f"{bar_minutes} mins", whatToShow="TRADES", useRTH=True, formatDate=2)
        if not raw:
            break
        for b in raw:
            t = clock.to_et(b.date)
            seen[t] = Bar(t, float(b.open), float(b.high), float(b.low), float(b.close), float(b.volume))
        first = clock.to_et(raw[0].date)
        end = (first - timedelta(minutes=1)).astimezone(clock.ET).strftime("%Y%m%d %H:%M:%S US/Eastern")
        fetched_days += chunk
        _time.sleep(2)  # be gentle with IB's historical pacing limits
        log.info("%s: %d bars so far (back to %s)", symbol, len(seen), first.date())
    return [seen[k] for k in sorted(seen)]
