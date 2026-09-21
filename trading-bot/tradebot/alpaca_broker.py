"""Alpaca as a *broker* for 24/7 crypto (paper by default), plus its crypto data.

Trading API: https://docs.alpaca.markets/reference (paper-api.alpaca.markets
for paper). Crypto is spot and long-only; quantities are fractional; orders are
market with time-in-force GTC. Alpaca has no plain stop orders for crypto, so
the protective stop is a software stop checked every poll, like Trading 212.
Position symbols come back without the slash ("BTCUSD"); we normalise to "BTC/USD".
"""

from __future__ import annotations

import json
import logging
import threading
import time as _time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Callable, Optional, Tuple

from . import clock
from .alpaca import AlpacaError, _parse_ts, _urllib_transport
from .broker import OrderRef, PositionInfo
from .config import Settings
from .marketdata import Gapper
from .models import LONG, Bar

log = logging.getLogger("tradebot.alpaca_broker")

DATA_BASE = "https://data.alpaca.markets"
TRADING = {"paper": "https://paper-api.alpaca.markets", "live": "https://api.alpaca.markets"}

Transport = Callable[[str, str, dict, Optional[bytes]], Tuple[int, bytes]]


def _http(method: str, url: str, headers: dict, body: bytes | None, attempts: int = 4) -> tuple[int, bytes]:
    last: Exception | None = None
    for i in range(attempts):
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as exc:
            return exc.code, exc.read()
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last = exc
            _time.sleep(2.0 * (i + 1))
    raise AlpacaError(f"cannot reach Alpaca after {attempts} attempts: {last}")


def norm(symbol: str) -> str:
    """'BTCUSD' or 'BTC/USD' -> 'BTC/USD'."""
    if "/" in symbol:
        return symbol.upper()
    for quote in ("USDT", "USDC", "USD"):
        if symbol.upper().endswith(quote) and len(symbol) > len(quote):
            return f"{symbol[:-len(quote)].upper()}/{quote}"
    return symbol.upper()


def fname(symbol: str) -> str:
    return symbol.replace("/", "-")


class AlpacaCryptoData:
    """Crypto bars/quotes from Alpaca's v1beta3 crypto endpoints (24/7)."""

    def __init__(self, api_key: str, api_secret: str, transport: Transport | None = None,
                 cache_seconds: float = 20.0, aux=None, sleep: Callable[[float], None] = _time.sleep):
        self.headers = {"APCA-API-KEY-ID": api_key, "APCA-API-SECRET-KEY": api_secret, "Accept": "application/json"}
        self._t = transport or _http
        self._sleep = sleep
        self._lock = threading.Lock()
        self._last_call = 0.0
        self.cache_seconds = cache_seconds
        self._cache: dict[tuple, tuple[float, object]] = {}
        self._aux = aux

    def _get(self, path: str, params: dict, retries: int = 4) -> dict:
        url = DATA_BASE + path + "?" + urllib.parse.urlencode({k: v for k, v in params.items() if v is not None})
        for attempt in range(retries + 1):
            with self._lock:
                gap = 0.31 - (_time.monotonic() - self._last_call)
                if gap > 0:
                    self._sleep(gap)
                self._last_call = _time.monotonic()
            status, raw = self._t("GET", url, self.headers, None)
            if status == 429 and attempt < retries:
                self._sleep(3.0 * (attempt + 1))
                continue
            text = raw.decode(errors="replace") if raw else ""
            if status >= 400:
                raise AlpacaError(f"Alpaca GET {path} -> {status}: {text[:200]}")
            return json.loads(text) if text.strip() else {}
        raise AlpacaError(f"Alpaca {path}: rate limited")

    def _cached(self, key: tuple, ttl: float, fn):
        hit = self._cache.get(key)
        now = _time.time()
        if hit and now - hit[0] < ttl:
            return hit[1]
        val = fn()
        self._cache[key] = (now, val)
        return val

    def bars(self, symbol: str, timeframe: str, start: datetime, end: datetime | None = None) -> list[Bar]:
        out: list[Bar] = []
        token = None
        while True:
            res = self._get("/v1beta3/crypto/us/bars", {
                "symbols": norm(symbol), "timeframe": timeframe,
                "start": start.astimezone(timezone.utc).isoformat(),
                "end": end.astimezone(timezone.utc).isoformat() if end else None,
                "limit": 10000, "sort": "asc", "page_token": token})
            rows = (res.get("bars") or {}).get(norm(symbol)) or []
            out.extend(Bar(_parse_ts(b["t"]), float(b["o"]), float(b["h"]), float(b["l"]), float(b["c"]),
                           float(b.get("v") or 0)) for b in rows)
            token = res.get("next_page_token")
            if not token:
                break
        return out

    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        def fetch():
            return self.bars(symbol, "1Day", clock.now_et() - timedelta(days=int(days * 1.1) + 5))
        bars = self._cached(("d", symbol, days), 3600, fetch)
        today = clock.now_et().date()
        return [b for b in bars if b.time.date() < today][-days:]

    def intraday_bars(self, symbol: str, bar_minutes: int = 15, days: int = 5,
                      include_premarket: bool = False) -> list[Bar]:
        def fetch():
            return self.bars(symbol, f"{bar_minutes}Min", clock.now_et() - timedelta(days=days + 1))
        return self._cached(("i", symbol, bar_minutes, days), self.cache_seconds, fetch)

    def last_price(self, symbol: str) -> float | None:
        def fetch():
            res = self._get("/v1beta3/crypto/us/latest/trades", {"symbols": norm(symbol)})
            t = (res.get("trades") or {}).get(norm(symbol)) or {}
            return float(t["p"]) if t.get("p") else None
        return self._cached(("p", symbol), self.cache_seconds, fetch)

    def market_cap(self, symbol: str) -> float | None:
        return None

    def fx_rate(self, base: str, quote: str) -> float:
        if base.upper() == quote.upper():
            return 1.0
        if self._aux is not None:
            return self._aux.fx_rate(base, quote)
        return 1.0

    def gappers(self, min_gap_pct: float, min_price: float, min_market_cap: float, limit: int = 100) -> list[Gapper]:
        return []


PENDING = {"new", "accepted", "pending_new", "partially_filled", "accepted_for_bidding", "held"}
DONE = {"filled"}
DEAD = {"canceled", "expired", "rejected", "done_for_day", "replaced", "stopped", "suspended"}


@dataclass
class AlpacaBroker:
    """Broker protocol on Alpaca's trading API (crypto, long-only, software stops)."""

    settings: Settings
    data: AlpacaCryptoData
    transport: Transport | None = None
    account_currency: str = "USD"
    account_id: str = ""
    _stops: dict[str, OrderRef] = field(default_factory=dict)
    _virtual_seq: int = 0
    _connected: bool = False

    def __post_init__(self) -> None:
        self._t = self.transport or _http
        self.base = TRADING[self.settings.alpaca_env]
        self.headers = {"APCA-API-KEY-ID": self.settings.alpaca_api_key,
                        "APCA-API-SECRET-KEY": self.settings.alpaca_api_secret,
                        "Accept": "application/json", "Content-Type": "application/json"}

    # -- http -----------------------------------------------------------------------
    def _req(self, method: str, path: str, body: dict | None = None, params: dict | None = None):
        url = self.base + path + ("?" + urllib.parse.urlencode(params) if params else "")
        status, raw = self._t(method, url, self.headers, json.dumps(body).encode() if body is not None else None)
        text = raw.decode(errors="replace") if raw else ""
        if status in (401, 403):
            hint = "" if "insufficient" in text.lower() else " (check ALPACA_API_KEY/SECRET and ALPACA_ENV)"
            raise AlpacaError(f"Alpaca {method} {path} -> {status}: {text[:300]}{hint}")
        if status == 404:
            return None
        if status >= 400:
            raise AlpacaError(f"Alpaca {method} {path} -> {status}: {text[:300]}")
        return json.loads(text) if text.strip() else None

    # -- connection -------------------------------------------------------------------
    def connect(self) -> None:
        self.settings.validate()
        acct = self._req("GET", "/v2/account") or {}
        self.account_id = str(acct.get("account_number") or acct.get("id") or "")
        self.account_currency = str(acct.get("currency") or "USD")
        if self.settings.alpaca_env == "paper" and acct.get("status") not in (None, "ACTIVE"):
            log.warning("Alpaca account status: %s", acct.get("status"))
        self._connected = True
        log.info("Alpaca %s account %s: equity %.2f, cash %.2f (crypto 24/7)", self.settings.alpaca_env.upper(),
                 self.account_id, float(acct.get("equity") or 0), float(acct.get("cash") or 0))

    def disconnect(self) -> None:
        self._connected = False

    def is_connected(self) -> bool:
        return self._connected

    def sleep(self, seconds: float) -> None:
        _time.sleep(seconds)

    def is_tradable(self, symbol: str) -> bool:
        return True

    # -- account ------------------------------------------------------------------------
    def net_liquidation(self) -> float:
        acct = self._req("GET", "/v2/account") or {}
        return float(acct.get("equity") or 0.0)

    def positions(self) -> list[PositionInfo]:
        out = []
        for p in self._req("GET", "/v2/positions") or []:
            qty = float(p.get("qty") or 0)
            if abs(qty) >= 1e-9:
                out.append(PositionInfo(norm(p["symbol"]), qty, float(p.get("avg_entry_price") or 0)))  # type: ignore[arg-type]
        return out

    def _position_qty(self, symbol: str) -> float:
        for p in self.positions():
            if p.symbol == norm(symbol):
                return float(p.qty)
        return 0.0

    # -- data (delegated) ------------------------------------------------------------------
    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        return self.data.daily_bars(symbol, days)

    def intraday_bars(self, symbol: str, bar_minutes: int = 15, days: int = 5,
                      include_premarket: bool = False) -> list[Bar]:
        return self.data.intraday_bars(symbol, bar_minutes, days, include_premarket)

    def last_price(self, symbol: str) -> float | None:
        return self.data.last_price(symbol)

    # -- orders ----------------------------------------------------------------------------
    @staticmethod
    def _status(st: str | None) -> str:
        if st in DONE:
            return "Filled"
        if st in DEAD:
            return "Cancelled"
        return "Submitted"

    def _ref(self, o: dict, kind: str, symbol: str) -> OrderRef:
        return OrderRef(order_id=abs(hash(o["id"])) % (10 ** 9) + 1, perm_id=0, symbol=symbol, kind=kind,
                        qty=float(o.get("qty") or 0), price=float(o.get("filled_avg_price") or 0),
                        status=self._status(o.get("status")), avg_fill=float(o.get("filled_avg_price") or 0),
                        filled=float(o.get("filled_qty") or 0), raw=o)

    def _market(self, symbol: str, side: str, qty: float) -> OrderRef:
        body = {"symbol": norm(symbol), "qty": f"{qty:.6f}".rstrip("0").rstrip("."), "side": side,
                "type": "market", "time_in_force": "gtc"}
        o = self._req("POST", "/v2/orders", body)
        ref = self._ref(o, "ENTRY" if side == "buy" else "CLOSE", symbol)
        ref.qty = qty
        return self.wait_fill(ref, timeout=60)

    def _sell(self, symbol: str, qty: float) -> OrderRef:
        """Market-sell at most what the account holds. Alpaca deducts crypto fees from the
        asset bought, so a position is a little smaller than the order that opened it; selling
        the ordered qty is refused with 403 'insufficient qty'."""
        held = round(self._position_qty(symbol), 6)
        flat = OrderRef(order_id=-10**8, symbol=norm(symbol), kind="CLOSE", qty=qty, status="Filled",
                        filled=0.0, avg_fill=self.last_price(symbol) or 0.0)
        if held <= 0:
            log.warning("%s: nothing left to sell (position already flat)", norm(symbol))
            return flat
        if held < qty:
            log.info("%s: selling %.6f held instead of %.6f requested", norm(symbol), held, qty)
            qty = held
        try:
            return self._market(symbol, "sell", qty)
        except AlpacaError as exc:
            if "insufficient" not in str(exc).lower():
                raise
            log.warning("%s: sell of %.6f refused (%s); treating as flat", norm(symbol), qty, exc)
            return flat

    def wait_fill(self, ref: OrderRef, timeout: float = 45) -> OrderRef:
        deadline = _time.time() + timeout
        oid = ref.raw["id"] if isinstance(ref.raw, dict) else None
        while True:
            o = self._req("GET", f"/v2/orders/{oid}") if oid else None
            if o is not None:
                st = o.get("status")
                if st in DONE:
                    ref.status, ref.filled = "Filled", float(o.get("filled_qty") or ref.qty)
                    ref.avg_fill = float(o.get("filled_avg_price") or 0) or (self.last_price(ref.symbol) or 0)
                    ref.raw = o
                    return ref
                if st in DEAD:
                    ref.status = "Cancelled"
                    return ref
            if _time.time() >= deadline:
                return ref
            _time.sleep(1.0)

    def refresh(self, ref: OrderRef) -> OrderRef:
        if ref.order_id < 0:  # software stop
            if ref.status != "Submitted":
                return ref
            px = self.last_price(ref.symbol)
            if px is None or px > ref.price:
                return ref
            log.warning("%s software stop hit: %.4f <= %.4f; selling %s", ref.symbol, px, ref.price, ref.qty)
            try:
                fill = self._sell(ref.symbol, ref.qty)
            except AlpacaError as exc:
                log.error("%s stop sell failed: %s", ref.symbol, exc)
                return ref
            ref.status, ref.filled, ref.avg_fill = "Filled", fill.filled or ref.qty, fill.avg_fill or px
            self._stops.pop(ref.symbol, None)
            return ref
        oid = ref.raw["id"] if isinstance(ref.raw, dict) else None
        o = self._req("GET", f"/v2/orders/{oid}") if oid else None
        if o is not None:
            new = self._ref(o, ref.kind, ref.symbol)
            ref.status, ref.filled, ref.avg_fill = new.status, new.filled, new.avg_fill
        return ref

    def place_stop(self, symbol: str, side: str, qty: float, stop: float) -> OrderRef:
        if side != LONG:
            raise AlpacaError("Alpaca crypto is long-only")
        self._virtual_seq -= 1
        ref = OrderRef(order_id=self._virtual_seq, perm_id=self._virtual_seq, symbol=norm(symbol), kind="STOP",
                       qty=qty, price=stop, status="Submitted")
        self._stops[norm(symbol)] = ref
        return ref

    def place_entry_with_stop(self, symbol: str, side: str, qty: float, stop: float,
                              limit: float | None = None) -> tuple[OrderRef, OrderRef]:
        if side != LONG:
            raise AlpacaError("Alpaca crypto is long-only; set ALLOW_SHORTS=false")
        entry = self._market(symbol, "buy", qty)
        if entry.status != "Filled" or entry.filled <= 0:
            self.cancel(entry)
            return entry, OrderRef(order_id=-10**9, symbol=norm(symbol), kind="STOP", status="Cancelled")
        held = round(self._position_qty(symbol), 6)
        if 0 < held < entry.filled:  # fee was taken from the coin
            log.info("%s: filled %.6f, holding %.6f after fees", norm(symbol), entry.filled, held)
            entry.filled = held
        return entry, self.place_stop(symbol, side, entry.filled, stop)

    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: float | None = None) -> OrderRef:
        if price is not None:
            ref.price = price
        if qty is not None:
            ref.qty = qty
        return ref

    def cancel(self, ref: OrderRef) -> None:
        if ref.status != "Submitted":
            return
        if ref.order_id > 0 and isinstance(ref.raw, dict):
            try:
                self._req("DELETE", f"/v2/orders/{ref.raw['id']}")
            except AlpacaError as exc:
                log.warning("cancel: %s", exc)
        ref.status = "Cancelled"
        if self._stops.get(ref.symbol) is ref:
            self._stops.pop(ref.symbol, None)

    def market_close(self, symbol: str, side: str, qty: float) -> OrderRef:
        ref = self._sell(symbol, qty)
        stop = self._stops.get(norm(symbol))
        if stop is not None:
            remaining = round(self._position_qty(symbol), 6)
            if remaining > 0:
                stop.qty = remaining
            else:
                stop.status = "Cancelled"
                self._stops.pop(norm(symbol), None)
        return ref

    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None:
        return None  # software stops are re-created from state after a restart

    def cancel_all(self) -> None:
        try:
            self._req("DELETE", "/v2/orders")
        except AlpacaError as exc:
            log.warning("cancel_all: %s", exc)
        self._stops.clear()
