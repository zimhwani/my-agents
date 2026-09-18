"""Trading 212 adapter against a fake HTTP transport (no network)."""

import json
from urllib.parse import parse_qs, urlparse

import pytest

from conftest import DAY, session
from tradebot import clock
from tradebot.broker import OrderRef
from tradebot.marketdata import frame_to_bars
from tradebot.models import LONG, SHORT
from tradebot.t212 import T212Broker, T212Client, T212Error


class FakeT212:
    """Minimal stateful stand-in for the T212 REST API."""

    def __init__(self):
        self.orders: dict[int, dict] = {}
        self.history: list[dict] = []
        self.positions: dict[str, dict] = {}
        self.next_id = 100
        self.calls: list[tuple[str, str]] = []
        self.fill_price = 100.0
        self.reject_stops = 0
        self.rate_limit_once = False

    def __call__(self, method, url, headers, body):
        assert headers["Authorization"] == "KEY"
        u = urlparse(url)
        path, q = u.path, parse_qs(u.query)
        self.calls.append((method, path))
        if self.rate_limit_once:
            self.rate_limit_once = False
            return 429, b""
        data = json.loads(body) if body else {}
        if path == "/api/v0/equity/account/info":
            return 200, json.dumps({"currencyCode": "GBP", "id": 42}).encode()
        if path == "/api/v0/equity/account/cash":
            return 200, json.dumps({"total": 8000.0, "free": 7000.0}).encode()
        if path == "/api/v0/equity/metadata/instruments":
            return 200, json.dumps([
                {"ticker": "AAPL_US_EQ", "type": "STOCK", "shortName": "AAPL", "currencyCode": "USD", "minTradeQuantity": 0.01},
                {"ticker": "AAPLl_EQ", "type": "STOCK", "shortName": "AAPL", "currencyCode": "GBX", "minTradeQuantity": 1},
                {"ticker": "VUSA_EQ", "type": "ETF", "shortName": "VUSA", "currencyCode": "GBP", "minTradeQuantity": 1},
            ]).encode()
        if path == "/api/v0/equity/portfolio":
            return 200, json.dumps([{"ticker": t, **p} for t, p in self.positions.items() if p["quantity"]]).encode()
        if path.startswith("/api/v0/equity/portfolio/"):
            t = path.rsplit("/", 1)[1]
            p = self.positions.get(t)
            return (200, json.dumps({"ticker": t, **p}).encode()) if p and p["quantity"] else (404, b"")
        if path == "/api/v0/equity/orders" and method == "GET":
            return 200, json.dumps(list(self.orders.values())).encode()
        if path == "/api/v0/equity/history/orders":
            items = [h for h in self.history if not q.get("ticker") or h["ticker"] == q["ticker"][0]]
            return 200, json.dumps({"items": items[::-1]}).encode()
        if path.startswith("/api/v0/equity/orders/") and method == "GET":
            o = self.orders.get(int(path.rsplit("/", 1)[1]))
            return (200, json.dumps(o).encode()) if o else (404, b"")
        if path.startswith("/api/v0/equity/orders/") and method == "DELETE":
            o = self.orders.pop(int(path.rsplit("/", 1)[1]), None)
            if o:
                self.history.append({**o, "status": "CANCELLED"})
            return 200, b""
        if path == "/api/v0/equity/orders/market":
            oid = self.next_id
            self.next_id += 1
            qty = data["quantity"]
            pos = self.positions.setdefault(data["ticker"], {"quantity": 0, "averagePrice": 0.0})
            if qty < 0 and abs(qty) > pos["quantity"] - self.pending_sells(data["ticker"]):
                return 400, b'{"code":"InsufficientResources"}'
            if qty > 0:
                tot = pos["quantity"] + qty
                pos["averagePrice"] = (pos["averagePrice"] * pos["quantity"] + self.fill_price * qty) / tot
            pos["quantity"] += qty
            rec = {"id": oid, "ticker": data["ticker"], "quantity": qty, "type": "MARKET", "status": "FILLED",
                   "filledQuantity": qty, "fillPrice": self.fill_price}
            self.history.append(rec)  # filled immediately, never appears as pending
            return 200, json.dumps({"id": oid, "ticker": data["ticker"], "quantity": qty, "type": "MARKET",
                                    "status": "NEW", "filledQuantity": 0}).encode()
        if path == "/api/v0/equity/orders/stop":
            if self.reject_stops:
                self.reject_stops -= 1
                return 400, b'{"code":"BusinessException"}'
            oid = self.next_id
            self.next_id += 1
            o = {"id": oid, "ticker": data["ticker"], "quantity": data["quantity"], "type": "STOP",
                 "status": "NEW", "stopPrice": data["stopPrice"], "filledQuantity": 0}
            self.orders[oid] = o
            return 200, json.dumps(o).encode()
        raise AssertionError(f"unexpected {method} {path}")

    def pending_sells(self, ticker):
        return sum(-o["quantity"] for o in self.orders.values() if o["ticker"] == ticker and o["quantity"] < 0)

    def trigger_stop(self, oid, price):
        o = self.orders.pop(oid)
        self.positions[o["ticker"]]["quantity"] += o["quantity"]
        self.history.append({**o, "status": "FILLED", "filledQuantity": o["quantity"], "fillPrice": price})


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


@pytest.fixture
def broker(settings, monkeypatch):
    monkeypatch.setattr("tradebot.t212._time.sleep", lambda s: None)
    fake = FakeT212()
    client = T212Client("KEY", "demo", transport=fake, sleep=lambda s: None)
    settings.t212_api_key = "KEY"
    b = T212Broker(settings, FakeData(), client=client)
    b.connect()
    return b, fake


def test_connect_maps_instruments_and_converts_equity(broker):
    b, fake = broker
    assert b.account_currency == "GBP"
    assert b.instrument("AAPL").ticker == "AAPL_US_EQ"  # US listing preferred over the LSE one
    assert "VUSA" not in b._instruments  # ETFs are skipped
    assert b.net_liquidation() == pytest.approx(8000 * 1.25)
    with pytest.raises(T212Error):
        b.instrument("ZZZZ")


def test_entry_then_stop_then_partial_replaces_stop(broker):
    b, fake = broker
    entry, stop = b.place_entry_with_stop("AAPL", LONG, 10, 98.0)
    assert entry.status == "Filled" and entry.filled == 10 and entry.avg_fill == 100.0
    assert stop.kind == "STOP" and stop.qty == 10 and stop.price == 98.0
    assert fake.orders[stop.order_id]["quantity"] == -10
    assert b.positions()[0].qty == 10
    # breakeven move = cancel + re-place
    old = stop.order_id
    b.modify_stop(stop, price=100.0)
    assert stop.order_id != old and old not in fake.orders and fake.orders[stop.order_id]["stopPrice"] == 100.0
    assert b.modify_stop(stop, price=100.0) is stop and len(fake.orders) == 1  # no-op
    # partial: the pending stop must be cancelled first, then re-placed for the remainder
    fake.fill_price = 102.0
    ref = b.market_close("AAPL", LONG, 5)
    assert ref.status == "Filled" and ref.avg_fill == 102.0
    assert len(fake.orders) == 1 and fake.orders[stop.order_id]["quantity"] == -5
    assert stop.qty == 5 and stop.price == 100.0
    # stop fires at the broker -> refresh sees it filled with the fill price
    fake.trigger_stop(stop.order_id, 99.9)
    ref = b.refresh(stop)
    assert ref.status == "Filled" and ref.avg_fill == 99.9 and ref.filled == 5
    assert b.positions() == []


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
    assert stop.status == "Submitted" and fake.orders[stop.order_id]["quantity"] == -3


def test_long_only_and_find_order_and_cancel_all(broker):
    b, fake = broker
    with pytest.raises(T212Error):
        b.place_entry_with_stop("AAPL", SHORT, 1, 101.0)
    _, stop = b.place_entry_with_stop("AAPL", LONG, 2, 98.0)
    found = b.find_order(stop.order_id, stop.order_id)
    assert found and found.kind == "STOP" and found.symbol == "AAPL" and found.qty == 2
    assert b.find_order(999999, 0) is None
    b.cancel_all()
    assert fake.orders == {}


def test_rate_limit_retry_and_auth_errors():
    fake = FakeT212()
    fake.rate_limit_once = True
    c = T212Client("KEY", "demo", transport=fake, sleep=lambda s: None)
    assert c.info()["currencyCode"] == "GBP"
    assert ("GET", "/api/v0/equity/account/info") in fake.calls

    def unauthorized(method, url, headers, body):
        return 401, b""
    with pytest.raises(T212Error, match="API key"):
        T212Client("BAD", "demo", transport=unauthorized, sleep=lambda s: None).info()
    with pytest.raises(T212Error):
        T212Client("K", "staging")


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


def test_executor_partial_and_close_through_t212(broker, tmp_path):
    from tradebot.execution import Executor, StateStore
    from tradebot.exits import CLOSE, MOVE_STOP, PARTIAL, ExitAction
    from tradebot.journal import Journal
    from tradebot.models import Signal
    from tradebot.telegram import Notifier

    b, fake = broker
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    ex = Executor(b, Journal(None), Notifier(quiet=True), StateStore(tmp_path / "s.json"))
    t = ex.open_trade(Signal("AAPL", LONG, 100.0, 98.0, 104.0, 0.5, now), 10, now)
    assert t and t.entry_price == 100.0 and len(fake.orders) == 1
    fake.fill_price = 102.0
    ex.apply(t, [ExitAction(PARTIAL, 5, 102.0, "partial"), ExitAction(MOVE_STOP, price=100.0, reason="breakeven")], now)
    assert t.qty_open == 5 and t.stop == 100.0
    (o,) = fake.orders.values()
    assert o["quantity"] == -5 and o["stopPrice"] == 100.0
    fake.fill_price = 103.0
    ex.apply(t, [ExitAction(CLOSE, 5, 103.0, "target")], now)
    assert t.status == "CLOSED" and fake.orders == {} and fake.positions["AAPL_US_EQ"]["quantity"] == 0
    assert t.r_multiple == pytest.approx((2 * 5 + 3 * 5) / 20)
