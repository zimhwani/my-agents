"""Trading 212 adapter (public API v0, current spec).

Docs: https://docs.trading212.com/api  Create the key in the app under
Settings -> API with the *orders execute* scope. You get an **API key** and an
**API secret**; both are needed (HTTP Basic auth). Create them while the app
is in **Practice** mode to get practice credentials (demo.trading212.com),
which is the paper-trading equivalent.

What differs from a classic broker API and how this adapter copes:

* **No market data.** Bars/quotes come from a ``DataProvider`` (marketdata.py).
* **No bracket orders, no order modification.** Entry is a market buy; the
  protective stop is managed separately.
* **Live accounts accept market orders only** (per the API docs), so on live a
  broker-side stop is impossible. ``T212_STOP_MODE=software`` (the default,
  on practice too so behaviour matches) keeps the stop in the bot: every poll
  compares the last price with the stop and fires a market sell when crossed.
  ``T212_STOP_MODE=broker`` places real GTC stop orders (practice only).
* **Long only.** Invest/ISA accounts cannot short.
* **Rate limits per endpoint.** A client-side throttle plus 429 back-off.
* Sells are expressed as a **negative quantity**.
"""

from __future__ import annotations

import base64
import json
import logging
import time as _time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional, Tuple

from .broker import OrderRef, PositionInfo
from .config import Settings
from .marketdata import DataProvider
from .models import LONG, Bar

log = logging.getLogger("tradebot.t212")

BASES = {"demo": "https://demo.trading212.com", "live": "https://live.trading212.com"}

# seconds between calls per endpoint family; documented limits in comments
THROTTLE = {
    "summary": 5.0,      # 1 req / 5s
    "positions": 1.0,    # 1 req / 1s
    "instruments": 50.0,  # 1 req / 50s
    "orders": 5.0,       # 1 req / 5s
    "order": 1.0,        # 1 req / 1s
    "cancel": 1.3,       # 50 req / min
    "market": 1.3,       # 50 req / min
    "stop": 2.0,         # 1 req / 2s
    "history": 10.0,     # 6 req / min
}

PENDING = {"LOCAL", "UNCONFIRMED", "CONFIRMED", "NEW", "PARTIALLY_FILLED", "REPLACING"}
DONE = {"FILLED"}
DEAD = {"CANCELLED", "CANCELLING", "REJECTED", "REPLACED"}

Transport = Callable[[str, str, dict, Optional[bytes]], Tuple[int, bytes]]


class T212Error(RuntimeError):
    pass


def _urllib_transport(method: str, url: str, headers: dict, body: bytes | None) -> tuple[int, bytes]:
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise T212Error(f"cannot reach {urllib.parse.urlparse(url).netloc}: {exc}. "
                        "Check your internet connection / VPN / firewall.") from exc


def auth_header(api_key: str, api_secret: str) -> str:
    """Basic base64(key:secret); legacy raw key if no secret was given."""
    if not api_secret:
        return api_key
    token = base64.b64encode(f"{api_key}:{api_secret}".encode()).decode()
    return f"Basic {token}"


class T212Client:
    def __init__(self, api_key: str, api_secret: str = "", env: str = "demo",
                 transport: Transport | None = None, sleep: Callable[[float], None] = _time.sleep):
        if env not in BASES:
            raise T212Error(f"T212_ENV must be demo or live, got {env!r}")
        self.base = BASES[env]
        self.env = env
        self._auth = auth_header(api_key, api_secret)
        self.has_secret = bool(api_secret)
        self._t = transport or _urllib_transport
        self._sleep = sleep
        self._last: dict[str, float] = {}

    def _throttle(self, family: str) -> None:
        gap = THROTTLE.get(family, 1.0)
        last = self._last.get(family)
        if last is not None:
            wait = gap - (_time.monotonic() - last)
            if wait > 0:
                self._sleep(wait)
        self._last[family] = _time.monotonic()

    def request(self, method: str, path: str, family: str, params: dict | None = None,
                body: dict | None = None, retries: int = 4):
        url = self.base + path
        if params:
            url += "?" + urllib.parse.urlencode({k: v for k, v in params.items() if v is not None})
        headers = {"Authorization": self._auth, "Accept": "application/json"}
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode()
        for attempt in range(retries + 1):
            self._throttle(family)
            status, raw = self._t(method, url, headers, data)
            if status == 429 and attempt < retries:
                wait = 5.0 * (attempt + 1)
                log.warning("T212 rate limited on %s; retrying in %.0fs", path, wait)
                self._sleep(wait)
                continue
            text = raw.decode(errors="replace") if raw else ""
            if status == 401:
                hint = ("Both T212_API_KEY and T212_API_SECRET are required (HTTP Basic auth)."
                        if not self.has_secret else
                        "Check T212_API_KEY / T212_API_SECRET and that they were created in "
                        f"{'Practice' if self.env == 'demo' else 'Live'} mode.")
                raise T212Error(f"Trading 212 rejected the credentials (401). {hint}")
            if status == 403:
                raise T212Error("Trading 212 refused (403): the key lacks a required scope. "
                                "Re-create it with account, portfolio, orders read AND orders execute.")
            if status == 404:
                return None
            if status >= 400:
                raise T212Error(f"Trading 212 {method} {path} -> {status}: {text[:300]}")
            return json.loads(text) if text.strip() else None
        raise T212Error(f"Trading 212 {path}: still rate limited after {retries} retries")

    # -- endpoints ---------------------------------------------------------------
    def summary(self) -> dict:
        return self.request("GET", "/api/v0/equity/account/summary", "summary") or {}

    def positions(self, ticker: str | None = None) -> list[dict]:
        return self.request("GET", "/api/v0/equity/positions", "positions",
                            params={"ticker": ticker} if ticker else None) or []

    def instruments(self) -> list[dict]:
        return self.request("GET", "/api/v0/equity/metadata/instruments", "instruments") or []

    def orders(self) -> list[dict]:
        return self.request("GET", "/api/v0/equity/orders", "orders") or []

    def order(self, order_id: int) -> dict | None:
        return self.request("GET", f"/api/v0/equity/orders/{order_id}", "order")

    def cancel(self, order_id: int) -> None:
        self.request("DELETE", f"/api/v0/equity/orders/{order_id}", "cancel")

    def market_order(self, ticker: str, quantity: float) -> dict:
        return self.request("POST", "/api/v0/equity/orders/market", "market",
                            body={"ticker": ticker, "quantity": quantity, "extendedHours": False})

    def stop_order(self, ticker: str, quantity: float, stop_price: float,
                   validity: str = "GOOD_TILL_CANCEL") -> dict:
        return self.request("POST", "/api/v0/equity/orders/stop", "stop",
                            body={"ticker": ticker, "quantity": quantity,
                                  "stopPrice": round(stop_price, 2), "timeValidity": validity})

    def order_history(self, ticker: str | None = None, limit: int = 20) -> list[dict]:
        res = self.request("GET", "/api/v0/equity/history/orders", "history",
                           params={"ticker": ticker, "limit": limit})
        return (res or {}).get("items", [])


@dataclass
class Instrument:
    symbol: str
    ticker: str
    currency: str


def _ticker_of(obj: dict) -> str:
    inst = obj.get("instrument") or {}
    return obj.get("ticker") or inst.get("ticker") or ""


def _qty(v) -> int | float:
    q = abs(float(v or 0))
    return int(q) if q == int(q) else q


@dataclass
class T212Broker:
    """Implements the ``Broker`` protocol on Trading 212 + a DataProvider."""

    settings: Settings
    data: DataProvider
    client: T212Client | None = None
    account_currency: str = ""
    account_id: str = ""
    _instruments: dict[str, Instrument] = field(default_factory=dict)
    _by_ticker: dict[str, str] = field(default_factory=dict)
    _stops: dict[str, OrderRef] = field(default_factory=dict)  # symbol -> working stop
    _virtual_seq: int = 0
    _connected: bool = False

    def __post_init__(self) -> None:
        if self.client is None:
            self.client = T212Client(self.settings.t212_api_key, self.settings.t212_api_secret,
                                     self.settings.t212_env)

    @property
    def software_stops(self) -> bool:
        mode = self.settings.t212_stop_mode
        if mode == "broker" and self.settings.t212_env == "live":
            log.warning("T212_STOP_MODE=broker is not supported on live (market orders only); using software")
            return True
        return mode != "broker"

    # -- connection ----------------------------------------------------------------
    def connect(self) -> None:
        s = self.settings
        s.validate()
        if not s.t212_api_key:
            raise T212Error("T212_API_KEY is not set")
        if not s.t212_api_secret:
            raise T212Error("T212_API_SECRET is not set (Trading 212 keys come as a key + secret pair)")
        summary = self.client.summary()
        self.account_currency = str(summary.get("currency", "USD"))
        self.account_id = str(summary.get("id", ""))
        self._load_instruments()
        self._connected = True
        cash = summary.get("cash") or {}
        log.info("Trading 212 %s account %s (%s): total %.2f, available %.2f, %d instruments, stops=%s",
                 s.t212_env.upper(), self.account_id, self.account_currency,
                 float(summary.get("totalValue", 0)), float(cash.get("availableToTrade", 0)),
                 len(self._instruments), "software" if self.software_stops else "broker")

    def _load_instruments(self) -> None:
        cache = Path(self.settings.data_dir) / "t212_instruments.json"
        raw: list[dict] | None = None
        if cache.exists() and _time.time() - cache.stat().st_mtime < 86_400:
            raw = json.loads(cache.read_text())
        if raw is None:
            raw = self.client.instruments()
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_text(json.dumps(raw))
        self._instruments.clear()
        for it in raw:
            if it.get("type") != "STOCK":
                continue
            ticker = it.get("ticker", "")
            sym = it.get("shortName") or ticker.split("_")[0]
            # prefer the US listing when a symbol exists on several exchanges
            if sym in self._instruments and not ticker.endswith("_US_EQ"):
                continue
            self._instruments[sym] = Instrument(sym, ticker, it.get("currencyCode", "USD"))
        self._by_ticker = {i.ticker: i.symbol for i in self._instruments.values()}

    def instrument(self, symbol: str) -> Instrument:
        try:
            return self._instruments[symbol]
        except KeyError:
            raise T212Error(f"{symbol} is not tradable on this Trading 212 account") from None

    def _symbol_of(self, ticker: str) -> str:
        return self._by_ticker.get(ticker, ticker.split("_")[0])

    def disconnect(self) -> None:
        self._connected = False

    def is_connected(self) -> bool:
        return self._connected

    def sleep(self, seconds: float) -> None:
        _time.sleep(seconds)

    # -- account -------------------------------------------------------------------
    def net_liquidation(self) -> float:
        """Account value in ``TRADING_CURRENCY`` (the currency the universe trades in)."""
        total = float(self.client.summary().get("totalValue", 0.0))
        return total * self.data.fx_rate(self.account_currency, self.settings.trading_currency)

    def positions(self) -> list[PositionInfo]:
        out = []
        for p in self.client.positions():
            qty = _qty(p.get("quantity"))
            if qty:
                out.append(PositionInfo(self._symbol_of(_ticker_of(p)), qty,  # type: ignore[arg-type]
                                        float(p.get("averagePricePaid") or 0)))
        return out

    def _position_qty(self, ticker: str) -> int | float:
        for p in self.client.positions(ticker):
            if _ticker_of(p) == ticker:
                return _qty(p.get("quantity"))
        return 0

    # -- market data (delegated) -----------------------------------------------------
    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        return self.data.daily_bars(symbol, days)

    def intraday_bars(self, symbol: str, bar_minutes: int = 5, days: int = 5,
                      include_premarket: bool = False) -> list[Bar]:
        return self.data.intraday_bars(symbol, bar_minutes, days, include_premarket)

    def is_tradable(self, symbol: str) -> bool:
        return symbol in self._instruments

    def last_price(self, symbol: str) -> float | None:
        return self.data.last_price(symbol)

    # -- order helpers -----------------------------------------------------------------
    @staticmethod
    def _status(t212_status: str | None) -> str:
        if t212_status in DONE:
            return "Filled"
        if t212_status in DEAD:
            return "Cancelled"
        return "Submitted"

    def _ref_from_order(self, o: dict, kind: str, symbol: str) -> OrderRef:
        return OrderRef(order_id=int(o["id"]), perm_id=int(o["id"]), symbol=symbol, kind=kind,
                        qty=int(round(_qty(o.get("quantity")))),
                        price=float(o.get("stopPrice") or o.get("limitPrice") or 0),
                        status=self._status(o.get("status")),
                        filled=int(round(_qty(o.get("filledQuantity")))), raw=o)

    def _history_fill(self, ref: OrderRef) -> tuple[float | None, int, str | None]:
        """(avg fill price, filled qty, status) for an order from history, else (None, 0, None)."""
        ticker = self.instrument(ref.symbol).ticker
        for h in self.client.order_history(ticker, 20):
            o = h.get("order") or {}
            if int(o.get("id", -1)) != ref.order_id:
                continue
            fill = h.get("fill") or {}
            price = fill.get("price")
            qty = int(round(_qty(fill.get("quantity") or o.get("filledQuantity") or 0)))
            return (float(price) if price else None), qty, o.get("status")
        return None, 0, None

    def _fill_price(self, ref: OrderRef) -> float:
        price, _, _ = self._history_fill(ref)
        if price:
            return price
        if ref.kind == "ENTRY":
            for p in self.client.positions(self.instrument(ref.symbol).ticker):
                if p.get("averagePricePaid"):
                    return float(p["averagePricePaid"])
        return self.last_price(ref.symbol) or ref.price

    def _is_virtual(self, ref: OrderRef) -> bool:
        return ref.order_id < 0

    def _new_virtual_stop(self, symbol: str, qty: int, stop: float) -> OrderRef:
        self._virtual_seq -= 1
        ref = OrderRef(order_id=self._virtual_seq, perm_id=self._virtual_seq, symbol=symbol, kind="STOP",
                       qty=qty, price=round(stop, 2), status="Submitted")
        self._stops[symbol] = ref
        log.info("software stop %s x%d @ %.2f", symbol, qty, stop)
        return ref

    def _check_virtual_stop(self, ref: OrderRef) -> OrderRef:
        """Fire the software stop if the last price is at or through it."""
        if ref.status != "Submitted":
            return ref
        px = self.last_price(ref.symbol)
        if px is None or px > ref.price:
            return ref
        log.warning("%s software stop hit: last %.2f <= stop %.2f; selling %d", ref.symbol, px, ref.price, ref.qty)
        try:
            fill = self._market_sell(ref.symbol, ref.qty)
        except T212Error as exc:
            log.error("%s: software stop sell failed: %s (will retry next poll)", ref.symbol, exc)
            return ref
        ref.status, ref.filled, ref.avg_fill = "Filled", fill.filled or ref.qty, fill.avg_fill or px
        self._stops.pop(ref.symbol, None)
        return ref

    def _market_sell(self, symbol: str, qty: int) -> OrderRef:
        inst = self.instrument(symbol)
        o = self.client.market_order(inst.ticker, -qty)
        ref = self._ref_from_order(o, "CLOSE", symbol)
        ref.qty = qty
        return self.wait_fill(ref, timeout=60)

    def wait_fill(self, ref: OrderRef, timeout: float = 45) -> OrderRef:
        deadline = _time.time() + timeout
        while True:
            o = self.client.order(ref.order_id)
            if o is None or o.get("status") in DONE:  # gone from pending = executed (or cancelled)
                price, qty, status = self._history_fill(ref)
                if o is None and status in DEAD:
                    ref.status = "Cancelled"
                    return ref
                ref.status = "Filled"
                ref.filled = qty or (int(round(_qty(o.get("filledQuantity")))) if o else 0) or ref.qty
                ref.avg_fill = price or self._fill_price(ref)
                return ref
            if o.get("status") in DEAD:
                ref.status = "Cancelled"
                return ref
            if _time.time() >= deadline:
                return self.refresh(ref)
            _time.sleep(1.0)

    def refresh(self, ref: OrderRef) -> OrderRef:
        if self._is_virtual(ref):
            return self._check_virtual_stop(ref)
        o = self.client.order(ref.order_id)
        if o is not None:
            new = self._ref_from_order(o, ref.kind, ref.symbol)
            ref.status, ref.filled, ref.qty, ref.price = new.status, new.filled, new.qty, new.price
            return ref
        price, qty, status = self._history_fill(ref)
        if status is None:
            ref.status = "Cancelled"
        elif price or status in DONE:
            ref.status, ref.filled, ref.avg_fill = "Filled", qty or ref.qty, price or ref.avg_fill or ref.price
            if self._stops.get(ref.symbol) is ref:
                self._stops.pop(ref.symbol, None)
        else:
            ref.status = self._status(status)
        return ref

    def _place_stop_retry(self, symbol: str, qty: int, stop: float) -> OrderRef:
        if self.software_stops:
            return self._new_virtual_stop(symbol, qty, stop)
        inst = self.instrument(symbol)
        last: Exception | None = None
        for attempt in range(3):
            try:
                o = self.client.stop_order(inst.ticker, -qty, stop)
                ref = self._ref_from_order(o, "STOP", symbol)
                ref.qty, ref.price = qty, round(stop, 2)
                self._stops[symbol] = ref
                return ref
            except T212Error as exc:  # position may not be bookable for a moment after the fill
                last = exc
                log.warning("%s stop placement attempt %d failed: %s", symbol, attempt + 1, exc)
                _time.sleep(2.0)
        raise T212Error(f"{symbol}: could not place protective stop: {last}")

    # -- Broker protocol: orders -------------------------------------------------------
    def place_stop(self, symbol: str, side: str, qty: int, stop: float) -> OrderRef:
        if side != LONG:
            raise T212Error("Trading 212 Invest accounts are long-only")
        return self._place_stop_retry(symbol, qty, stop)

    def place_entry_with_stop(self, symbol: str, side: str, qty: int, stop: float,
                              limit: float | None = None) -> tuple[OrderRef, OrderRef]:
        if side != LONG:
            raise T212Error("Trading 212 Invest accounts are long-only; set ALLOW_SHORTS=false")
        inst = self.instrument(symbol)
        o = self.client.market_order(inst.ticker, qty)
        entry = self._ref_from_order(o, "ENTRY", symbol)
        entry.qty = qty
        log.info("T212 BUY %s x%d (order %s)", symbol, qty, entry.order_id)
        entry = self.wait_fill(entry, timeout=45)
        if entry.status != "Filled" or entry.filled <= 0:
            self.cancel(entry)
            return entry, OrderRef(order_id=-10**9, symbol=symbol, kind="STOP", status="Cancelled")
        try:
            stop_ref = self._place_stop_retry(symbol, entry.filled, stop)
        except T212Error:
            log.error("%s: stop rejected; closing the naked position immediately", symbol)
            self.client.market_order(inst.ticker, -entry.filled)
            raise
        log.info("T212 stop %s x%d @ %.2f (%s)", symbol, entry.filled, stop,
                 "software" if self._is_virtual(stop_ref) else f"order {stop_ref.order_id}")
        return entry, stop_ref

    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: int | None = None) -> OrderRef:
        new_price = round(price, 2) if price is not None else ref.price
        new_qty = qty if qty is not None else ref.qty
        if new_price == ref.price and new_qty == ref.qty and ref.status == "Submitted":
            return ref
        if self._is_virtual(ref):
            ref.price, ref.qty = new_price, new_qty
            self._stops[ref.symbol] = ref
            return ref
        self.cancel(ref)
        new = self._place_stop_retry(ref.symbol, new_qty, new_price)
        ref.order_id, ref.perm_id, ref.qty, ref.price, ref.status = new.order_id, new.perm_id, new_qty, new_price, "Submitted"
        self._stops[ref.symbol] = ref
        return ref

    def cancel(self, ref: OrderRef) -> None:
        if ref.status != "Submitted":
            return
        if not self._is_virtual(ref):
            try:
                self.client.cancel(ref.order_id)
            except T212Error as exc:
                log.warning("cancel %s: %s", ref.order_id, exc)
        ref.status = "Cancelled"
        if self._stops.get(ref.symbol) is ref:
            self._stops.pop(ref.symbol, None)

    def market_close(self, symbol: str, side: str, qty: int) -> OrderRef:
        inst = self.instrument(symbol)
        stop = self._stops.get(symbol)
        stop_price = stop.price if stop else None
        broker_stop = stop is not None and not self._is_virtual(stop) and stop.status == "Submitted"
        if broker_stop:
            self.cancel(stop)  # free the shares held by the pending sell stop
        ref = self._market_sell(symbol, qty)
        remaining = int(round(self._position_qty(inst.ticker)))
        if stop is not None and stop_price:
            if remaining > 0:
                if broker_stop:
                    new = self._place_stop_retry(symbol, remaining, stop_price)
                    stop.order_id, stop.perm_id = new.order_id, new.perm_id
                stop.qty, stop.status = remaining, "Submitted"
                self._stops[symbol] = stop
            else:
                stop.status = "Cancelled"
                self._stops.pop(symbol, None)
        return ref

    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None:
        if order_id < 0:  # software stops don't survive a restart; caller re-places
            return None
        o = self.client.order(order_id)
        if o is None or o.get("status") not in PENDING:
            return None
        symbol = self._symbol_of(_ticker_of(o))
        kind = "STOP" if str(o.get("type", "")).upper().startswith("STOP") else "ENTRY"
        ref = self._ref_from_order(o, kind, symbol)
        if kind == "STOP":
            self._stops[symbol] = ref
        return ref

    def cancel_all(self) -> None:
        for o in self.client.orders():
            if o.get("status") in PENDING:
                try:
                    self.client.cancel(int(o["id"]))
                except T212Error as exc:
                    log.warning("cancel_all %s: %s", o.get("id"), exc)
        self._stops.clear()
