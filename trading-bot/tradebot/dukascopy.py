"""Free minute-level history for gold, silver and FX from Dukascopy's public datafeed (research only).

Each trading day is one LZMA-compressed file of 1-minute BID candles:
  https://datafeed.dukascopy.com/datafeed/XAUUSD/2026/08/29/BID_candles_min_1.bi5   (month is 0-based)
records are 24 bytes big-endian: seconds-from-midnight-UTC, open, close, low, high (int32, price x
divisor) and volume (float32). Days are aggregated to 5-minute bars as they arrive so two years of
gold stays small in memory, then rolled up to any slower timeframe.
"""

from __future__ import annotations

import logging
import lzma
import statistics
import struct
import time as _time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
from typing import Callable

from . import clock
from .models import Bar

log = logging.getLogger(__name__)

URL = "https://datafeed.dukascopy.com/datafeed/{inst}/{y}/{m:02d}/{d:02d}/BID_candles_min_1.bi5"
INSTRUMENTS = {"XAU/USD": "XAUUSD", "XAG/USD": "XAGUSD", "EUR/USD": "EURUSD", "GBP/USD": "GBPUSD",
               "USD/JPY": "USDJPY", "AUD/USD": "AUDUSD", "USD/CAD": "USDCAD", "USD/CHF": "USDCHF"}
DIVISORS = {"XAUUSD": 1000.0, "XAGUSD": 1000.0, "USDJPY": 1000.0}  # everything else: 100000
PLAUSIBLE = {"XAUUSD": (300.0, 20000.0), "XAGUSD": (3.0, 500.0), "USDJPY": (50.0, 400.0)}
RECORD = struct.Struct(">iiiiif")

Fetch = Callable[[str], bytes | None]


def _http(url: str, attempts: int = 4) -> bytes | None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (tradebot research)"})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return None  # weekend / holiday / not yet published
            err = exc
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            err = exc
        _time.sleep(2 ** attempt)  # the datafeed throttles bursts; back off 1, 2, 4, 8 s
    raise ConnectionError(f"{url}: {err}")


def decode_day(raw: bytes, day: date, divisor: float) -> list[Bar]:
    """1-minute bars from one day file (empty list for an empty file)."""
    if not raw:
        return []
    data = lzma.decompress(raw)
    base = datetime(day.year, day.month, day.day, tzinfo=timezone.utc)
    out = []
    for off in range(0, len(data) - RECORD.size + 1, RECORD.size):
        t, o, c, lo, hi, vol = RECORD.unpack_from(data, off)
        out.append(Bar(clock.to_et(base + timedelta(seconds=t)), o / divisor, hi / divisor, lo / divisor,
                       c / divisor, float(vol)))
    return out


def _roll(bars: list[Bar], minutes: int) -> list[Bar]:
    from .deriv import aggregate
    return aggregate(bars, minutes)


def download(symbol: str, days: int, fetch: Fetch | None = None, workers: int = 4,
             end: date | None = None, max_missing: float = 0.03) -> list[Bar]:
    """5-minute bars for ``symbol`` over the last ``days`` calendar days (weekends simply absent).

    A day whose file still fails after retries is skipped and reported (a gap of a day barely moves a
    two-year test); more than ``max_missing`` of the days failing means the feed is down: raise."""
    inst = INSTRUMENTS.get(symbol, symbol.replace("/", ""))
    divisor = DIVISORS.get(inst, 100000.0)
    fetch = fetch or _http
    end = end or datetime.now(timezone.utc).date() - timedelta(days=1)
    days_list = [end - timedelta(days=i) for i in range(days)][::-1]
    days_list = [d for d in days_list if d.weekday() != 5]  # Saturday never trades
    failed: list[str] = []

    def one(d: date) -> list[Bar]:
        url = URL.format(inst=inst, y=d.year, m=d.month - 1, d=d.day)
        try:
            raw = fetch(url)
        except ConnectionError as exc:
            failed.append(str(exc))
            return []
        return _roll(decode_day(raw or b"", d, divisor), 5)

    with ThreadPoolExecutor(max_workers=workers) as pool:
        chunks = list(pool.map(one, days_list))
    if failed:
        if len(failed) > max(1, max_missing * len(days_list)):
            raise ConnectionError(f"Dukascopy {inst}: {len(failed)} of {len(days_list)} days failed, e.g. {failed[0]}")
        log.warning("Dukascopy %s: skipped %d of %d days that would not download (e.g. %s)",
                    inst, len(failed), len(days_list), failed[0])
    bars = [b for chunk in chunks for b in chunk]
    lo_hi = PLAUSIBLE.get(inst)
    if bars and lo_hi:
        med = statistics.median(b.close for b in bars[:: max(1, len(bars) // 500)])
        if not lo_hi[0] <= med <= lo_hi[1]:
            raise ValueError(f"{inst}: median price {med:.4f} outside {lo_hi}; the price divisor looks wrong")
    log.info("Dukascopy %s: %d five-minute bars over %d days", inst, len(bars), days)
    return bars


def timeframes(bars_5m: list[Bar], minutes: list[int]) -> dict[int, list[Bar]]:
    """Roll 5-minute bars up to each requested timeframe (5 returns the input)."""
    return {m: (bars_5m if m == 5 else _roll(bars_5m, m)) for m in minutes}
