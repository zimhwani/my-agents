"""Trading 212 adapter against a fake HTTP server (no network), current API spec."""

import base64
import json
from urllib.parse import parse_qs, urlparse

import pytest

from conftest import DAY, session
from tradebot import clock
from tradebot.marketdata import frame_to_bars
from tradebot.models import LONG, SHORT
from tradebot.t212 import T212Broker, T212Client, T212Error, auth_header

GOOD_AUTH = "Basic " + base64.b64encode(b"KEY:SECRET").decode()


class FakeT212:
    """Minimal stateful stand-in for the T212 REST API (spec shapes)."""

    def __init__(self):
        self.orders: dict[int, dict] = {}
        self.history: list[dict] = []          # {"order": {...}, "fill": {...}|None}
        self.positions: dict[str, dict] = {}   # ticker -> {"quantity","averagePricePaid"}
        self.next_id = 100
        self.calls: list[tuple[str, str]] = []
        self.fill_price = 100.0
        self.reject_stops = 0
        self.rate_limit_once = False
        self.live_market_only = False

    def __call__(self, method, url, headers, body):
        if headers["Authorization"] != GOOD_AUTH:
            return 401, b""
        u = urlparse(url)
        path, q = u.path, parse_qs(u.query)
        self.calls.append((method, path))
        if self.rate_limit_once:
            self.rate_limit_once = False
            return 429, b""
        data = json.loads(body) if body else {}
        if path == "/api/v0/equity/account/summary":
            return 200, json.dumps({"currency": "GBP", "id": 42, "totalValue": 8000.0,
                                    "cash": {"availableToTrade": 7000.0}}).encode()
        if path == "/api/v0/equity/metadata/instruments":
            return 200, json.dumps([
                {"ticker": "AAPL_US_EQ", "type": "STOCK", "shortName": "AAPL", "currencyCode": "USD"},
                {"ticker": "AAPLl_EQ", "type": "STOCK", "shortName": "AAPL", "currencyCode": "GBX"},
                {"ticker": "VUSA_EQ", "type": "ETF", "shortName": "VUSA", "currencyCode": "GBP"},
            ]).encode()
        if path == "/api/v0/equity/positions":
            want = q.get("ticker", [None])[0]
            rows = [{"instrument": {"ticker": t, "currency": "USD"}, **p}
                    for t, p in self.positions.items() if p["quantity"] and (not want or want == t)]
            return 200, json.dumps(rows).encode()
        if path == "/api/v0/equity/orders" and method == "GET":
            return 200, json.dumps(list(self.orders.values())).encode()
        if path == "/api/v0/equity/history/orders":
            want = q.get("ticker", [None])[0]
            items = [h for h in self.history if not want or h["order"]["ticker"] == want]
            return 200, json.dumps({"items": items[::-1], "nextPagePath": None}).encode()
        if path.startswith("/api/v0/equity/orders/") and method == "GET":
            o = self.orders.get(int(path.rsplit("/", 1)[1]))
            return (200, json.dumps(o).encode()) if o else (404, b"")
        if path.startswith("/api/v0/equity/orders/") and method == "DELETE":
            o = self.orders.pop(int(path.rsplit("/", 1)[1]), None)
            if o:
                self.history.append({"order": {**o, "status": "CANCELLED"}, "fill": None})
            return 200, b""
        if path == "/api/v0/equity/orders/market":
            oid = self.next_id
            self.next_id += 1
            qty = data["quantity"]
            pos = self.positions.setdefault(data["ticker"], {"quantity": 0, "averagePricePaid": 0.0})
            if qty < 0 and abs(qty) > pos["quantity"] - self.pending_sells(data["ticker"]):
                return 400, b'{"code":"InsufficientResources"}'
            if qty > 0:
                tot = pos["quantity"] + qty
                pos["averagePricePaid"] = (pos["averagePricePaid"] * pos["quantity"] + self.fill_price * qty) / tot
            pos["quantity"] += qty
            order = {"id": oid, "ticker": data["ticker"], "instrument": {"ticker": data["ticker"]},
                     "quantity": abs(qty), "side": "BUY" if qty > 0 else "SELL", "type": "MARKET",
                     "status": "FILLED", "filledQuantity": abs(qty)}
            self.history.append({"order": order, "fill": {"price": self.fill_price, "quantity": abs(qty)}})
            return 200, json.dumps({**order, "status": "NEW", "filledQuantity": 0}).encode()
        if path == "/api/v0/equity/orders/stop":
            if self.live_market_only:
                return 400, b'{"code":"Only market orders are supported"}'
            if self.reject_stops:
                self.reject_stops -= 1
                return 400, b'{"code":"BusinessException"}'
            oid = self.next_id
            self.next_id += 1
            o = {"id": oid, "ticker": data["ticker"], "instrument": {"ticker": data["ticker"]},
                 "quantity": abs(data["quantity"]), "side": "SELL", "type": "STOP", "status": "NEW",
                 "stopPrice": data["stopPrice"], "filledQuantity": 0}
            self.orders[oid] = o
            return 200, json.dumps(o).encode()
        raise AssertionError(f"unexpected {method} {path}")

    def pending_sells(self, ticker):
        return sum(o["quantity"] for o in self.orders.values() if o["ticker"] == ticker and o["side"] == "SELL")

    def trigger_stop(self, oid, price):
        o = self.orders.pop(oid)
        self.positions[o["ticker"]]["quantity"] -= o["quantity"]
        self.history.append({"order": {**o, "status": "FILLED", "filledQuantity": o["quantity"]},
                             "fill": {"price": price, "quantity": o["quantity"]}})


class FakeData:
    def __init__(self):
        self.prices = {"AAPL": 100.0}

    def daily_bars(self, symbol, days):
        return []

    def intraday_bars(self, symbol, bar_minutes, days):
        return []

    def last_price(self, symbol):
        return self.prices.get(symbol)

    def fx_rate(self, base, quote):
        return 1.25 if (base, quote) == ("GBP", "USD") else 1.0


def make_broker(settings, monkeypatch, stop_mode="software"):
    monkeypatch.setattr("tradebot.t212._time.sleep", lambda s: None)
    fake = FakeT212()
    client = T212Client("KEY", "SECRET", "demo", transport=fake, sleep=lambda s: None)
    settings.t212_api_key, settings.t212_api_secret, settings.t212_stop_mode = "KEY", "SECRET", stop_mode
    b = T212Broker(settings, FakeData(), client=client)
    b.connect()
    return b, fake


@pytest.fixture
def broker(settings, monkeypatch):
    return make_broker(settings, monkeypatch, "broker")


@pytest.fixture
def soft(settings, monkeypatch):
    return make_broker(settings, monkeypatch, "software")


def test_auth_header_and_bad_credentials():
    assert auth_header("KEY", "SECRET") == GOOD_AUTH
    assert auth_header("LEGACY", "") == "LEGACY"
    fake = FakeT212()
    with pytest.raises(T212Error, match="401"):
        T212Client("KEY", "WRONG", "demo", transport=fake, sleep=lambda s: None).summary()
    with pytest.raises(T212Error, match="SECRET"):
        T212Client("KEY", "", "demo", transport=fake, sleep=lambda s: None).summary()


def test_connect_maps_instruments_and_converts_equity(broker):
    b, fake = broker
    assert b.account_currency == "GBP" and b.account_id == "42"
    assert b.instrument("AAPL").ticker == "AAPL_US_EQ"  # US listing preferred over the LSE one
    assert "VUSA" not in b._instruments  # ETFs are skipped
    assert b.net_liquidation() == pytest.approx(8000 * 1.25)
    with pytest.raises(T212Error):
        b.instrument("ZZZZ")


def test_broker_stop_mode_entry_partial_and_stop_fill(broker):
    b, fake = broker
    entry, stop = b.place_entry_with_stop("AAPL", LONG, 10, 98.0)
    assert entry.status == "Filled" and entry.filled == 10 and entry.avg_fill == 100.0
    assert stop.kind == "STOP" and stop.qty == 10 and stop.price == 98.0 and stop.order_id > 0
    assert b.positions()[0].qty == 10
    old = stop.order_id
    b.modify_stop(stop, price=100.0)  # breakeven = cancel + re-place
    assert stop.order_id != old and old not in fake.orders and fake.orders[stop.order_id]["stopPrice"] == 100.0
    assert b.modify_stop(stop, price=100.0) is stop and len(fake.orders) == 1  # no-op
    fake.fill_price = 102.0
    ref = b.market_close("AAPL", LONG, 5)  # partial: cancel stop, sell, re-place for the rest
    assert ref.status == "Filled" and ref.avg_fill == 102.0
    assert len(fake.orders) == 1 and fake.orders[stop.order_id]["quantity"] == 5
    assert stop.qty == 5 and stop.price == 100.0
    fake.trigger_stop(stop.order_id, 99.9)
    ref = b.refresh(stop)
    assert ref.status == "Filled" and ref.avg_fill == 99.9 and ref.filled == 5
    assert b.positions() == []


def test_software_stop_fires_on_price(soft):
    b, fake = soft
    entry, stop = b.place_entry_with_stop("AAPL", LONG, 10, 98.0)
    assert stop.order_id < 0 and fake.orders == {}  # nothing resting at the broker
    assert ("POST", "/api/v0/equity/orders/stop") not in fake.calls
    b.modify_stop(stop, price=99.0)
    assert stop.price == 99.0 and fake.orders == {}
    b.data.prices["AAPL"] = 99.5
    assert b.refresh(stop).status == "Submitted"
    b.data.prices["AAPL"] = 98.9
    fake.fill_price = 98.85
    ref = b.refresh(stop)
    assert ref.status == "Filled" and ref.filled == 10 and ref.avg_fill == 98.85
    assert fake.positions["AAPL_US_EQ"]["quantity"] == 0 and b._stops == {}


def test_software_stop_survives_partial(soft):
    b, fake = soft
    _, stop = b.place_entry_with_stop("AAPL", LONG, 10, 98.0)
    fake.fill_price = 101.0
    b.market_close("AAPL", LONG, 4)
    assert stop.qty == 6 and stop.status == "Submitted"
    b.market_close("AAPL", LONG, 6)
    assert stop.status == "Cancelled" and b._stops == {}


def test_broker_mode_falls_back_to_software_on_live(settings, monkeypatch):
    settings.t212_env = "live"
    settings.live_ack = "I_UNDERSTAND_LIVE_TRADING"
    b, fake = make_broker(settings, monkeypatch, "broker")
    fake.live_market_only = True
    assert b.software_stops
    _, stop = b.place_entry_with_stop("AAPL", LONG, 3, 98.0)
    assert stop.order_id < 0


def test_stop_rejection_closes_naked_position(broker):
    b, fake = broker
    fake.reject_stops = 5
    with pytest.raises(T212Error):
        b.place_entry_with_stop("AAPL", LONG, 3, 98.0)
    assert fake.positions["AAPL_US_EQ"]["quantity"] == 0


def test_stop_placement_retries_once_then_succeeds(broker):
    b, fake = broker
    fake.reject_stops = 1
    _, stop = b.place_entry_with_stop("AAPL", LONG, 3, 98.0)
    assert stop.status == "Submitted" and fake.orders[stop.order_id]["quantity"] == 3


def test_long_only_find_order_and_cancel_all(broker):
    b, fake = broker
    with pytest.raises(T212Error):
        b.place_entry_with_stop("AAPL", SHORT, 1, 101.0)
    _, stop = b.place_entry_with_stop("AAPL", LONG, 2, 98.0)
    found = b.find_order(stop.order_id, stop.order_id)
    assert found and found.kind == "STOP" and found.symbol == "AAPL" and found.qty == 2
    assert b.find_order(999999, 0) is None and b.find_order(-3, -3) is None
    b.cancel_all()
    assert fake.orders == {}


def test_rate_limit_retry():
    fake = FakeT212()
    fake.rate_limit_once = True
    c = T212Client("KEY", "SECRET", "demo", transport=fake, sleep=lambda s: None)
    assert c.summary()["currency"] == "GBP"
    with pytest.raises(T212Error):
        T212Client("K", "S", "staging")


def test_frame_to_bars_from_yfinance_shape():
    class Frame:
        def __init__(self, index, rows):
            self.index, self._rows = index, rows

        def to_dict(self, orient):
            return self._rows

    bars = session(DAY, [100, 101], spread=0.5)
    f = Frame([b.time for b in bars] + [bars[-1].time],
              [{"Open": b.open, "High": b.high, "Low": b.low, "Close": b.close, "Volume": b.volume} for b in bars]
              + [{"Open": float("nan"), "High": 1, "Low": 1, "Close": 1, "Volume": 0}])
    out = frame_to_bars(f)
    assert len(out) == 2 and out[0].time == bars[0].time and out[1].close == 101
    daily = frame_to_bars(f, daily=True)
    assert all(b.time.time() == clock.MARKET_CLOSE for b in daily)


def test_executor_partial_and_close_through_t212_software_stops(soft, tmp_path):
    from tradebot.execution import Executor, StateStore
    from tradebot.exits import CLOSE, MOVE_STOP, PARTIAL, ExitAction
    from tradebot.journal import Journal
    from tradebot.models import Signal
    from tradebot.telegram import Notifier

    b, fake = soft
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    ex = Executor(b, Journal(None), Notifier(quiet=True), StateStore(tmp_path / "s.json"))
    t = ex.open_trade(Signal("AAPL", LONG, 100.0, 98.0, 104.0, 0.5, now), 10, now)
    assert t and t.entry_price == 100.0
    fake.fill_price = 102.0
    ex.apply(t, [ExitAction(PARTIAL, 5, 102.0, "partial"), ExitAction(MOVE_STOP, price=100.0, reason="breakeven")], now)
    assert t.qty_open == 5 and t.stop == 100.0
    # price drops through the software stop: the executor's stop check sells the rest
    b.data.prices["AAPL"] = 99.7
    fake.fill_price = 99.6
    ex.check_stop_fills(now)
    assert t.status == "CLOSED" and fake.positions["AAPL_US_EQ"]["quantity"] == 0
    assert t.exits[-1].reason == "stop" and t.exits[-1].price == 99.6
    assert t.r_multiple == pytest.approx((2 * 5 - 0.4 * 5) / 20)
    # restart: software stop is re-created from state
    ex2 = Executor(b, Journal(None), Notifier(quiet=True), StateStore(tmp_path / "s.json"))
    t2 = ex2.open_trade(Signal("AAPL", LONG, 100.0, 98.0, 104.0, 0.5, now), 3, now)
    ex3 = Executor(b, Journal(None), Notifier(quiet=True), StateStore(tmp_path / "s.json"))
    ex3.restore()
    assert len(ex3.open_trades) == 1 and b._stops["AAPL"].qty == 3 and b._stops["AAPL"].price == 98.0
