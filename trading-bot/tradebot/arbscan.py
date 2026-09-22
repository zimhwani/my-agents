"""Cross-venue spread monitor: is there an arbitrage edge to chase, or not?

Streams Coinbase and Kraken tickers over websockets, polls Alpaca's latest crypto quotes once a
second, and every second computes, per coin, the best executable cross-venue spread
(highest bid on one venue minus lowest ask on another) gross and net of both venues' taker fees.
Seconds where the net spread is positive are "windows"; they are logged with their size and
duration so the question "does this ever pay after fees?" gets a measured answer.

Nothing here trades. It is a measuring instrument.
"""

from __future__ import annotations

import asyncio
import csv
import json
import logging
import time as _time
from dataclasses import dataclass, field
from pathlib import Path

log = logging.getLogger(__name__)

# taker fees in bps, low-volume tiers (override on the command line)
DEFAULT_FEES_BPS = {"alpaca": 25.0, "coinbase": 60.0, "kraken": 40.0}


@dataclass
class Quote:
    bid: float
    ask: float
    ts: float  # time.time() when received


@dataclass
class Window:
    symbol: str
    buy_venue: str
    sell_venue: str
    start: float
    end: float
    max_gross_pct: float
    max_net_pct: float

    @property
    def seconds(self) -> float:
        return self.end - self.start


@dataclass
class SpreadBook:
    """Pure logic: latest quotes per venue per symbol -> spreads and windows. Testable offline."""
    fees_bps: dict[str, float] = field(default_factory=lambda: dict(DEFAULT_FEES_BPS))
    stale_seconds: float = 5.0
    dislocation_pct: float = 0.5
    quotes: dict[str, dict[str, Quote]] = field(default_factory=dict)   # symbol -> venue -> quote
    open_windows: dict[tuple, Window] = field(default_factory=dict)      # (symbol, buy, sell) -> window
    closed: list[Window] = field(default_factory=list)
    samples: dict[str, int] = field(default_factory=dict)
    max_gross: dict[str, float] = field(default_factory=dict)
    max_net: dict[str, float] = field(default_factory=dict)
    positive_seconds: dict[str, int] = field(default_factory=dict)
    dislocations: dict[str, int] = field(default_factory=dict)

    def update(self, venue: str, symbol: str, bid: float, ask: float, ts: float | None = None) -> None:
        if bid <= 0 or ask <= 0 or ask < bid * 0.9:  # ignore garbage
            return
        self.quotes.setdefault(symbol, {})[venue] = Quote(bid, ask, ts if ts is not None else _time.time())

    def best_spread(self, symbol: str, now: float | None = None):
        """(buy_venue, sell_venue, gross_pct, net_pct) for the best executable pair, or None."""
        now = now if now is not None else _time.time()
        live = {v: q for v, q in self.quotes.get(symbol, {}).items() if now - q.ts <= self.stale_seconds}
        if len(live) < 2:
            return None
        best = None
        for bv, bq in live.items():          # buy at bv's ask
            for sv, sq in live.items():      # sell at sv's bid
                if bv == sv:
                    continue
                gross = (sq.bid - bq.ask) / bq.ask * 100.0
                net = gross - (self.fees_bps.get(bv, 0.0) + self.fees_bps.get(sv, 0.0)) / 100.0
                if best is None or net > best[3]:
                    best = (bv, sv, gross, net)
        return best

    def dislocated(self, symbol: str, now: float | None = None) -> str | None:
        """Venue whose mid sits more than dislocation_pct away from the median of the others."""
        now = now if now is not None else _time.time()
        live = {v: q for v, q in self.quotes.get(symbol, {}).items() if now - q.ts <= self.stale_seconds}
        if len(live) < 3:
            return None
        mids = {v: (q.bid + q.ask) / 2 for v, q in live.items()}
        vals = sorted(mids.values())
        med = vals[len(vals) // 2] if len(vals) % 2 else (vals[len(vals) // 2 - 1] + vals[len(vals) // 2]) / 2
        worst, worst_dev = None, 0.0
        for v, m in mids.items():
            dev = abs(m - med) / med * 100.0
            if dev >= self.dislocation_pct and dev > worst_dev:
                worst, worst_dev = v, dev
        return worst

    def tick(self, now: float | None = None) -> list[Window]:
        """Sample every symbol once; returns windows that closed on this tick."""
        now = now if now is not None else _time.time()
        finished: list[Window] = []
        for symbol in list(self.quotes):
            res = self.best_spread(symbol, now)
            if res is None:
                continue
            bv, sv, gross, net = res
            self.samples[symbol] = self.samples.get(symbol, 0) + 1
            self.max_gross[symbol] = max(self.max_gross.get(symbol, -1e9), gross)
            self.max_net[symbol] = max(self.max_net.get(symbol, -1e9), net)
            if self.dislocated(symbol, now):
                self.dislocations[symbol] = self.dislocations.get(symbol, 0) + 1
            key = (symbol, bv, sv)
            if net > 0:
                self.positive_seconds[symbol] = self.positive_seconds.get(symbol, 0) + 1
                w = self.open_windows.get(key)
                if w is None:
                    self.open_windows[key] = Window(symbol, bv, sv, now, now, gross, net)
                else:
                    w.end, w.max_gross_pct, w.max_net_pct = now, max(w.max_gross_pct, gross), max(w.max_net_pct, net)
            # any open window for this symbol whose pair is no longer positive closes
            for k in [k for k in self.open_windows if k[0] == symbol and (k != key or net <= 0)]:
                w = self.open_windows.pop(k)
                w.end = now
                self.closed.append(w)
                finished.append(w)
        return finished

    def report(self) -> str:
        syms = sorted(self.samples)
        if not syms:
            return "no two-venue samples yet"
        lines = [f"{'pair':<10}{'samples':>8}{'max gross%':>12}{'max net%':>10}{'net>0 s':>9}{'disloc s':>10}"]
        for s in syms:
            lines.append(f"{s:<10}{self.samples[s]:>8}{self.max_gross[s]:>12.3f}{self.max_net[s]:>10.3f}"
                         f"{self.positive_seconds.get(s, 0):>9}{self.dislocations.get(s, 0):>10}")
        n = len(self.closed)
        if n:
            longest = max(self.closed, key=lambda w: w.seconds)
            biggest = max(self.closed, key=lambda w: w.max_net_pct)
            lines.append(f"windows closed: {n} · longest {longest.seconds:.0f}s ({longest.symbol} "
                         f"{longest.buy_venue}->{longest.sell_venue}) · biggest net {biggest.max_net_pct:.3f}% "
                         f"({biggest.symbol})")
        else:
            lines.append("windows closed: 0 (no second where a cross-venue spread beat both venues' fees)")
        return "\n".join(lines)


# -- venues -------------------------------------------------------------------------------
def coinbase_product(symbol: str) -> str:
    return symbol.replace("/", "-")


async def coinbase_feed(book: SpreadBook, symbols: list[str]) -> None:
    import websockets
    url = "wss://ws-feed.exchange.coinbase.com"
    sub = {"type": "subscribe", "product_ids": [coinbase_product(s) for s in symbols], "channels": ["ticker"]}
    while True:
        try:
            async with websockets.connect(url, ping_interval=20) as ws:
                await ws.send(json.dumps(sub))
                async for raw in ws:
                    m = json.loads(raw)
                    if m.get("type") == "ticker" and m.get("best_bid") and m.get("best_ask"):
                        book.update("coinbase", m["product_id"].replace("-", "/"),
                                    float(m["best_bid"]), float(m["best_ask"]))
        except Exception as exc:  # reconnect
            log.warning("coinbase feed: %s; reconnecting", exc)
            await asyncio.sleep(3)


async def kraken_feed(book: SpreadBook, symbols: list[str]) -> None:
    import websockets
    url = "wss://ws.kraken.com/v2"
    sub = {"method": "subscribe", "params": {"channel": "ticker", "symbol": symbols}}
    while True:
        try:
            async with websockets.connect(url, ping_interval=20) as ws:
                await ws.send(json.dumps(sub))
                async for raw in ws:
                    m = json.loads(raw)
                    if m.get("channel") == "ticker":
                        for d in m.get("data", []):
                            book.update("kraken", d["symbol"], float(d["bid"]), float(d["ask"]))
        except Exception as exc:
            log.warning("kraken feed: %s; reconnecting", exc)
            await asyncio.sleep(3)


async def alpaca_poll(book: SpreadBook, symbols: list[str], key: str, secret: str, every: float = 1.0) -> None:
    import urllib.parse
    import urllib.request
    url = "https://data.alpaca.markets/v1beta3/crypto/us/latest/quotes?" + urllib.parse.urlencode(
        {"symbols": ",".join(symbols)})
    headers = {"APCA-API-KEY-ID": key, "APCA-API-SECRET-KEY": secret, "Accept": "application/json"}

    def fetch():
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())

    while True:
        t0 = _time.time()
        try:
            data = await asyncio.get_running_loop().run_in_executor(None, fetch)
            for sym, q in (data.get("quotes") or {}).items():
                book.update("alpaca", sym, float(q.get("bp") or 0), float(q.get("ap") or 0))
        except Exception as exc:
            log.warning("alpaca quotes: %s", exc)
        await asyncio.sleep(max(0.0, every - (_time.time() - t0)))


async def run_monitor(book: SpreadBook, symbols: list[str], key: str, secret: str, out_csv: Path,
                      report_every: int = 60, duration: float | None = None) -> None:
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    new = not out_csv.exists()
    f = out_csv.open("a", newline="")
    w = csv.writer(f)
    if new:
        w.writerow(["start", "end", "seconds", "symbol", "buy_venue", "sell_venue", "max_gross_pct", "max_net_pct"])
    tasks = [asyncio.create_task(coinbase_feed(book, symbols)), asyncio.create_task(kraken_feed(book, symbols)),
             asyncio.create_task(alpaca_poll(book, symbols, key, secret))]
    started = _time.time()
    last_report = started
    try:
        while True:
            await asyncio.sleep(1.0)
            for win in book.tick():
                w.writerow([f"{win.start:.0f}", f"{win.end:.0f}", f"{win.seconds:.0f}", win.symbol, win.buy_venue,
                            win.sell_venue, f"{win.max_gross_pct:.4f}", f"{win.max_net_pct:.4f}"])
                f.flush()
                log.info("WINDOW %s buy %s / sell %s: %.0fs, net %.3f%%", win.symbol, win.buy_venue, win.sell_venue,
                         win.seconds, win.max_net_pct)
            now = _time.time()
            if now - last_report >= report_every:
                last_report = now
                print(f"\n--- {_time.strftime('%H:%M:%S')} after {(now - started) / 60:.0f} min ---\n{book.report()}",
                      flush=True)
            if duration and now - started >= duration:
                break
    finally:
        for t in tasks:
            t.cancel()
        f.close()
        print(f"\n=== final ===\n{book.report()}\nevents -> {out_csv}")
