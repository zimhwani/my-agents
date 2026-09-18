"""Trading 212 adapter (public API v0).

Docs: https://t212public-api-docs.redoc.ly/  Create the key in the app under
Settings -> API (Beta) with the *orders execute* scope. Create it while the
app is in **Practice** mode to get a practice key (base URL demo.trading212.com);
that is the paper-trading equivalent.

What differs from a classic broker API and how this adapter copes:

* **No market data.** Bars/quotes come from a ``DataProvider`` (see marketdata.py).
* **No bracket orders, no order modification.** The bot places a market buy,
  waits for the fill, then places a separate GTC stop. "Modifying" a stop is
  cancel + re-place. Partials cancel the stop, sell, and re-place it for the
  remainder (a pending sell blocks selling the same shares twice).
* **Long only.** Invest/ISA accounts cannot short.
* **Rate limits per endpoint.** A client-side throttle plus 429 back-off.
* Sells are expressed as a **negative quantity**.
"""

from __future__ import annotations

import json
import logging
import time as _time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from .broker import OrderRef, PositionInfo
from .config import Settings
from .marketdata import DataProvider
from .models import LONG, Bar

log = logging.getLogger("tradebot.t212")

BASES = {"demo": "https://demo.trading212.com", "live": "https://live.trading212.com"}

# seconds between calls, per endpoint family (conservative vs. documented limits)
THROTTLE = {
    "cash": 2.0, "info": 30.0, "portfolio": 5.0, "position": 1.0, "instruments": 50.0,
    "orders": 5.0, "order": 1.0, "cancel": 1.0, "place": 2.0, "history": 10.0,
}

PENDING = {"LOCAL", "UNCONFIRMED", "CONFIRMED", "NEW", "PARTIALLY_FILLED", "REPLACING"}
DONE = {"FILLED"}
DEAD = {"CANCELLED", "CANCELLING", "REJECTED", "REPLACED"}

Transport = Callable[[str, str, dict, bytes | None], tuple[int, bytes]]


class T212Error(RuntimeError):
    pass


def _urllib_transport(method: str, url: str, headers: dict, body: bytes | None) -> tuple[int, bytes]:
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


class T212Client:
    def __init__(self, api_key: str, env: str = "demo", transport: Transport | None = None,
                 sleep: Callable[[float], None] = _time.sleep):
        if env not in BASES:
            raise T212Error(f"T212_ENV must be demo or live, got {env!r}")
        self.base = BASES[env]
        self.env = env
        self.key = api_key
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
        headers = {"Authorization": self.key, "Accept": "application/json"}
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
                raise T212Error("Trading 212 rejected the API key (401). Check T212_API_KEY and that "
                                f"it was created in {'Practice' if self.env == 'demo' else 'Live'} mode.")
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
    def cash(self) -> dict:
        return self.request("GET", "/api/v0/equity/account/cash", "cash")

    def info(self) -> dict:
        return self.request("GET", "/api/v0/equity/account/info", "info")

    def portfolio(self) -> list[dict]:
        return self.request("GET", "/api/v0/equity/portfolio", "portfolio") or []

    def position(self, ticker: str) -> dict | None:
        return self.request("GET", f"/api/v0/equity/portfolio/{ticker}", "position")

    def instruments(self) -> list[dict]:
        return self.request("GET", "/api/v0/equity/metadata/instruments", "instruments") or []

    def orders(self) -> list[dict]:
        return self.request("GET", "/api/v0/equity/orders", "orders") or []

    def order(self, order_id: int) -> dict | None:
        return self.request("GET", f"/api/v0/equity/orders/{order_id}", "order")

    def cancel(self, order_id: int) -> None:
        self.request("DELETE", f"/api/v0/equity/orders/{order_id}", "cancel")

    def market_order(self, ticker: str, quantity: float) -> dict:
        return self.request("POST", "/api/v0/equity/orders/market", "place",
                            body={"ticker": ticker, "quantity": quantity, "extendedHours": False})

    def stop_order(self, ticker: str, quantity: float, stop_price: float,
                   validity: str = "GOOD_TILL_CANCEL") -> dict:
        return self.request("POST", "/api/v0/equity/orders/stop", "place",
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
    min_qty: float


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
    _connected: bool = False

    def __post_init__(self) -> None:
        if self.client is None:
            self.client = T212Client(self.settings.t212_api_key, self.settings.t212_env)

    # -- connection ----------------------------------------------------------------
    def connect(self) -> None:
        s = self.settings
        s.validate()
        if not s.t212_api_key:
            raise T212Error("T212_API_KEY is not set")
        info = self.client.info()
        self.account_currency = str(info.get("currencyCode", "USD"))
        self.account_id = str(info.get("id", ""))
        self._load_instruments()
        cash = self.client.cash()
        self._connected = True
        log.info("Trading 212 %s account %s (%s): total %.2f, free %.2f, %d instruments",
                 s.t212_env.upper(), self.account_id, self.account_currency,
                 float(cash.get("total", 0)), float(cash.get("free", 0)), len(self._instruments))

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
            self._instruments[sym] = Instrument(sym, ticker, it.get("currencyCode", "USD"),
                                                float(it.get("minTradeQuantity", 1)))
        self._by_ticker = {i.ticker: i.symbol for i in self._instruments.values()}

    def instrument(self, symbol: str) -> Instrument:
        try:
            return self._instruments[symbol]
        except KeyError:
            raise T212Error(f"{symbol} is not tradable on this Trading 212 account") from None

    def disconnect(self) -> None:
        self._connected = False

    def is_connected(self) -> bool:
        return self._connected

    def sleep(self, seconds: float) -> None:
        _time.sleep(seconds)

    # -- account -------------------------------------------------------------------
    def net_liquidation(self) -> float:
        """Account value in ``TRADING_CURRENCY`` (the currency the universe trades in)."""
        cash = self.client.cash()
        total = float(cash.get("total", 0.0))
        return total * self.data.fx_rate(self.account_currency, self.settings.trading_currency)

    def positions(self) -> list[PositionInfo]:
        out = []
        for p in self.client.portfolio():
            sym = self._by_ticker.get(p.get("ticker", ""), p.get("ticker", "").split("_")[0])
            qty = float(p.get("quantity", 0))
            if qty:
                out.append(PositionInfo(sym, int(qty) if qty == int(qty) else qty,  # type: ignore[arg-type]
                                        float(p.get("averagePrice", 0))))
        return out

    # -- market data (delegated) -----------------------------------------------------
    def daily_bars(self, symbol: str, days: int = 60) -> list[Bar]:
        return self.data.daily_bars(symbol, days)

    def intraday_bars(self, symbol: str, bar_minutes: int = 5, days: int = 5) -> list[Bar]:
        return self.data.intraday_bars(symbol, bar_minutes, days)

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
                        qty=abs(int(round(float(o.get("quantity") or 0)))),
                        price=float(o.get("stopPrice") or o.get("limitPrice") or 0),
                        status=self._status(o.get("status")),
                        filled=abs(int(round(float(o.get("filledQuantity") or 0)))), raw=o)

    def _fill_price(self, ref: OrderRef) -> float:
        """Average fill from order history (falls back to position avg / last)."""
        ticker = self.instrument(ref.symbol).ticker
        for h in self.client.order_history(ticker, 20):
            if int(h.get("id", -1)) == ref.order_id and h.get("fillPrice"):
                return float(h["fillPrice"])
        pos = self.client.position(ticker)
        if pos and pos.get("averagePrice") and ref.kind == "ENTRY":
            return float(pos["averagePrice"])
        return self.last_price(ref.symbol) or ref.price

    def wait_fill(self, ref: OrderRef, timeout: float = 45) -> OrderRef:
        deadline = _time.time() + timeout
        while True:
            o = self.client.order(ref.order_id)
            if o is None or o.get("status") in DONE:  # gone from pending = executed
                ref.status = "Filled"
                ref.filled = ref.filled or ref.qty
                if o is not None:
                    ref.filled = abs(int(round(float(o.get("filledQuantity") or ref.qty)))) or ref.qty
                ref.avg_fill = self._fill_price(ref)
                return ref
            if o.get("status") in DEAD:
                ref.status = "Cancelled"
                return ref
            if _time.time() >= deadline:
                return self.refresh(ref)
            _time.sleep(1.0)

    def refresh(self, ref: OrderRef) -> OrderRef:
        o = self.client.order(ref.order_id)
        if o is not None:
            new = self._ref_from_order(o, ref.kind, ref.symbol)
            ref.status, ref.filled, ref.qty, ref.price = new.status, new.filled, new.qty, new.price
            return ref
        # not pending any more: filled or cancelled - order history knows which
        ticker = self.instrument(ref.symbol).ticker
        for h in self.client.order_history(ticker, 20):
            if int(h.get("id", -1)) == ref.order_id:
                st = h.get("status")
                ref.status = "Filled" if h.get("fillPrice") or st in DONE else self._status(st)
                if ref.status == "Filled":
                    ref.filled = abs(int(round(float(h.get("filledQuantity") or ref.qty)))) or ref.qty
                    ref.avg_fill = float(h.get("fillPrice") or ref.avg_fill or ref.price)
                return ref
        ref.status = "Cancelled"
        return ref

    def _place_stop_retry(self, symbol: str, qty: int, stop: float) -> OrderRef:
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
            return entry, OrderRef(order_id=-1, symbol=symbol, kind="STOP", status="Cancelled")
        try:
            stop_ref = self._place_stop_retry(symbol, entry.filled, stop)
        except T212Error:
            log.error("%s: stop rejected; closing the naked position immediately", symbol)
            self.client.market_order(inst.ticker, -entry.filled)
            raise
        log.info("T212 stop %s x%d @ %.2f (order %s)", symbol, entry.filled, stop, stop_ref.order_id)
        return entry, stop_ref

    def modify_stop(self, ref: OrderRef, price: float | None = None, qty: int | None = None) -> OrderRef:
        new_price = round(price, 2) if price is not None else ref.price
        new_qty = qty if qty is not None else ref.qty
        if new_price == ref.price and new_qty == ref.qty and ref.status == "Submitted":
            return ref
        self.cancel(ref)
        new = self._place_stop_retry(ref.symbol, new_qty, new_price)
        ref.order_id, ref.perm_id, ref.qty, ref.price, ref.status = new.order_id, new.perm_id, new_qty, new_price, "Submitted"
        self._stops[ref.symbol] = ref
        return ref

    def cancel(self, ref: OrderRef) -> None:
        if ref.order_id is None or ref.order_id < 0 or ref.status != "Submitted":
            return
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
        if stop is not None and stop.status == "Submitted":
            self.cancel(stop)  # free the shares held by the pending sell stop
        o = self.client.market_order(inst.ticker, -qty)
        ref = self._ref_from_order(o, "CLOSE", symbol)
        ref.qty = qty
        ref = self.wait_fill(ref, timeout=60)
        remaining = 0
        pos = self.client.position(inst.ticker)
        if pos:
            remaining = int(round(float(pos.get("quantity") or 0)))
        if stop is not None and remaining > 0 and stop_price:
            new = self._place_stop_retry(symbol, remaining, stop_price)
            stop.order_id, stop.perm_id, stop.qty, stop.status = new.order_id, new.perm_id, remaining, "Submitted"
            self._stops[symbol] = stop
        return ref

    def find_order(self, order_id: int, perm_id: int) -> OrderRef | None:
        o = self.client.order(order_id)
        if o is None or o.get("status") not in PENDING:
            return None
        symbol = self._by_ticker.get(o.get("ticker", ""), o.get("ticker", "").split("_")[0])
        kind = "STOP" if o.get("type", "").upper().startswith("STOP") else "ENTRY"
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
