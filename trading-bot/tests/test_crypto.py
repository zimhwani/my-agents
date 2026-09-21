"""Crypto momentum strategy, fractional sizing, the continuous backtester and the Alpaca broker."""

import json
from datetime import timedelta
from urllib.parse import urlparse

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.alpaca_broker import AlpacaBroker, AlpacaCryptoData, fname, norm
from tradebot.crypto import CryptoMomentum, CryptoRules
from tradebot.data import synthetic_continuous
from tradebot.models import LONG, Bar
from tradebot.risk import position_size
from tradebot.strategy import load_strategy


def bars_24h(n=260, bar_minutes=15, base=100.0, breakout_at=None, vol=100.0):
    """Flat, gently rising 15-min bars; optionally a breakout bar at index breakout_at."""
    out = []
    t = clock.at(DAY, clock.parse_hhmm("00:00")) - timedelta(minutes=bar_minutes * n)
    for i in range(n):
        p = base + i * 0.01
        o, c, h, lo, v = p, p + 0.005, p + 0.05, p - 0.05, vol
        if breakout_at is not None and i == breakout_at:
            c, h, v = p + 0.5, p + 0.55, vol * 3
        out.append(Bar(t, o, h, lo, c, v))
        t += timedelta(minutes=bar_minutes)
    return out


def test_crypto_rules_and_exits():
    ls = load_strategy("crypto.json")
    assert ls.continuous and ls.fractional and ls.force_close is None and ls.scan_kind == "static"
    assert ls.exits.trail_mode == "atr" and ls.exits.trail_atr_mult == 3.0 and ls.exits.fractional
    assert ls.exits.final_target_r == 0 and ls.exits.time_stop_minutes == 1440
    assert ls.cooldown_minutes == 0 and "BTC/USD" in ls.universe
    assert ls.risk_overrides["max_positions"] == 4


def test_crypto_signal_and_filters():
    s = CryptoMomentum(CryptoRules(breakout_bars=20, trend_ema_bars=100, min_rel_volume=1.5))
    now = clock.at(DAY, clock.parse_hhmm("00:00"))
    bars = bars_24h(breakout_at=259)
    sig = s.evaluate("BTC/USD", bars, [], now)
    assert sig is not None and sig.side == LONG and sig.stop < sig.entry and "breakout" in sig.reason
    # same bar still forming -> nothing
    assert s.evaluate("BTC/USD", bars, [], now - timedelta(minutes=5)) is None
    # no breakout
    assert s.evaluate("BTC/USD", bars_24h(), [], now) is None
    # low volume on the breakout bar
    quiet = bars_24h(breakout_at=259)
    quiet[-1].volume = 100.0
    assert s.evaluate("BTC/USD", quiet, [], now) is None
    # previous bar already broke out -> only the first bar signals
    two = bars_24h(breakout_at=258)
    two[-1] = Bar(two[-1].time, two[-2].close, two[-2].close + 0.6, two[-2].close, two[-2].close + 0.55, 300)
    assert s.evaluate("BTC/USD", two, [], now) is None
    # stop too wide
    wide = CryptoMomentum(CryptoRules(breakout_bars=20, trend_ema_bars=100, max_initial_risk_pct=0.01))
    assert wide.evaluate("BTC/USD", bars, [], now) is None
    # not enough history
    assert s.evaluate("BTC/USD", bars[-50:], [], now) is None


def test_fractional_sizing():
    q = position_size(10_000, 60_000.0, 58_800.0, 1.0, 1e9, 100, fractional=True)
    assert 0 < q < 1 and abs(q * 1200 - 100) < 1  # $100 risk at $1,200/coin
    assert position_size(10_000, 60_000.0, 58_800.0, 1.0, 1e9, 25, fractional=True) == pytest.approx(2500 / 60_000, abs=1e-6)
    assert position_size(10_000, 60_000.0, 58_800.0, 1.0, 1e9, 25, fractional=True, min_notional=1e6) == 0.0
    assert position_size(10_000, 100.0, 99.0, 1.0, 1e9, 100) == 100  # whole shares unchanged


def test_continuous_backtest_on_synthetic(settings):
    from tradebot.backtest import Backtester
    ls = load_strategy("crypto.json")
    ls.cooldown_minutes = 120  # crypto.json ships with no cooldown; exercise the mechanism here
    ls.apply(settings)
    settings.max_risk_per_trade_usd = 1e9
    bars = {s: synthetic_continuous(s, 30, 15, seed=i + 1, start_price=100 * (i + 1),
                                    end=clock.at(DAY, clock.parse_hhmm("00:00")))
            for i, s in enumerate(["BTC/USD", "ETH/USD"])}
    res = Backtester(settings, ls, bars).run()
    assert res.trades, "expected breakout trades on synthetic momentum data"
    for t in res.trades:
        assert t.status == "CLOSED" and t.side == LONG
        assert isinstance(t.qty_initial, float) and 0 < t.qty_initial
        assert all(f.reason != "eod" for f in t.exits)  # no forced daily close in a 24/7 market
    reasons = {f.reason for t in res.trades for f in t.exits}
    assert reasons & {"partial", "stop", "time", "end"}
    # cooldown: no re-entry within 120 minutes of an exit in the same symbol
    by_sym = {}
    for t in sorted(res.trades, key=lambda t: t.entry_time):
        prev = by_sym.get(t.symbol)
        if prev is not None:
            assert t.entry_time - prev.last_exit_time >= timedelta(minutes=120)
        by_sym[t.symbol] = t


class FakeAlpacaTrading:
    def __init__(self):
        self.orders = {}
        self.positions = {}
        self.price = 100.0
        self.n = 0
        self.fee = 0.0  # fraction of a buy deducted from the coin, like Alpaca's crypto fee

    def __call__(self, method, url, headers, body):
        assert headers["APCA-API-KEY-ID"] == "K"
        u = urlparse(url)
        data = json.loads(body) if body else {}
        if u.path == "/v2/account":
            eq = 10_000 + sum(q * self.price for q in self.positions.values())
            return 200, json.dumps({"id": "acct1", "currency": "USD", "equity": str(eq), "cash": "10000", "status": "ACTIVE"}).encode()
        if u.path == "/v2/positions" and method == "GET":
            return 200, json.dumps([{"symbol": s.replace("/", ""), "qty": str(q), "avg_entry_price": "100"}
                                    for s, q in self.positions.items() if q]).encode()
        if u.path == "/v2/orders" and method == "POST":
            self.n += 1
            oid = f"o{self.n}"
            qty = float(data["qty"])
            sym = data["symbol"]
            if data["side"] == "sell" and qty > self.positions.get(sym, 0.0) + 1e-12:
                return 403, json.dumps({"code": 40310000, "message": "insufficient qty available for order"}).encode()
            credited = qty * (1 - self.fee) if data["side"] == "buy" else -qty
            self.positions[sym] = self.positions.get(sym, 0.0) + credited
            self.orders[oid] = {"id": oid, "symbol": sym, "qty": str(qty), "side": data["side"], "status": "filled",
                                "filled_qty": str(qty), "filled_avg_price": str(self.price)}
            return 200, json.dumps({**self.orders[oid], "status": "accepted", "filled_qty": "0"}).encode()
        if u.path.startswith("/v2/orders/") and method == "GET":
            o = self.orders.get(u.path.rsplit("/", 1)[1])
            return (200, json.dumps(o).encode()) if o else (404, b"")
        if u.path == "/v2/orders" and method == "DELETE":
            return 207, b"[]"
        if "/v1beta3/crypto/us/latest/trades" in u.path:
            return 200, json.dumps({"trades": {"BTC/USD": {"p": self.price}}}).encode()
        if "/v1beta3/crypto/us/bars" in u.path:
            return 200, json.dumps({"bars": {"BTC/USD": [{"t": "2026-09-15T00:00:00Z", "o": 1, "h": 2, "l": 0.5, "c": 1.5, "v": 3},
                                                         {"t": "2026-09-15T00:15:00Z", "o": 1.5, "h": 2, "l": 1, "c": 1.8, "v": 4}]},
                                    "next_page_token": None}).encode()
        raise AssertionError(f"{method} {url}")


def test_alpaca_broker_entry_partial_and_software_stop(settings, monkeypatch):
    monkeypatch.setattr("tradebot.alpaca_broker._time.sleep", lambda s: None)
    settings.broker, settings.alpaca_api_key, settings.alpaca_api_secret = "alpaca", "K", "S"
    fake = FakeAlpacaTrading()
    data = AlpacaCryptoData("K", "S", transport=fake, sleep=lambda s: None)
    b = AlpacaBroker(settings, data, transport=fake)
    b.connect()
    assert b.account_id == "acct1" and b.net_liquidation() == pytest.approx(10_000)
    entry, stop = b.place_entry_with_stop("BTC/USD", LONG, 0.05, 95.0)
    assert entry.status == "Filled" and entry.filled == 0.05 and entry.avg_fill == 100.0
    assert stop.order_id < 0 and stop.qty == 0.05 and stop.price == 95.0
    assert b.positions()[0].symbol == "BTC/USD" and b.positions()[0].qty == pytest.approx(0.05)
    b.modify_stop(stop, price=100.0)
    fake.price = 103.0
    data._cache.clear()
    ref = b.market_close("BTC/USD", LONG, 0.02)  # partial
    assert ref.status == "Filled" and ref.avg_fill == 103.0 and stop.qty == pytest.approx(0.03)
    fake.price = 99.5
    data._cache.clear()
    ref = b.refresh(stop)  # software stop fires
    assert ref.status == "Filled" and ref.filled == pytest.approx(0.03) and b._stops == {}
    assert b.positions() == []
    bars = data.intraday_bars("BTC/USD", 15, 2)
    assert len(bars) == 2 and bars[1].close == 1.8 and bars[0].time.tzinfo is not None


def test_symbol_normalisation():
    assert norm("BTCUSD") == "BTC/USD" and norm("btc/usd") == "BTC/USD" and norm("ETHUSDT") == "ETH/USDT"
    assert fname("BTC/USD") == "BTC-USD"


def test_alpaca_broker_sells_what_it_holds_after_fees(settings, monkeypatch):
    """Alpaca deducts the crypto fee from the coin bought; closing the ordered qty used to 403 forever."""
    monkeypatch.setattr("tradebot.alpaca_broker._time.sleep", lambda s: None)
    settings.broker, settings.alpaca_api_key, settings.alpaca_api_secret = "alpaca", "K", "S"
    fake = FakeAlpacaTrading()
    fake.fee = 0.0025
    data = AlpacaCryptoData("K", "S", transport=fake, sleep=lambda s: None)
    b = AlpacaBroker(settings, data, transport=fake)
    b.connect()
    entry, stop = b.place_entry_with_stop("BTC/USD", LONG, 0.05, 95.0)
    assert entry.filled == pytest.approx(0.049875) and stop.qty == pytest.approx(0.049875)
    # a caller still holding the ordered qty (e.g. state from before the fix) closes cleanly
    ref = b.market_close("BTC/USD", LONG, 0.05)
    assert ref.status == "Filled" and ref.filled == pytest.approx(0.049875) and b.positions() == []
    # closing again is a no-op instead of an exception
    ref = b.market_close("BTC/USD", LONG, 0.05)
    assert ref.status == "Filled" and ref.filled == 0.0
    # held qty is floored, never rounded up past what the account has
    fake.positions["BTC/USD"] = 0.0498755
    ref = b.market_close("BTC/USD", LONG, 0.05)
    assert ref.status == "Filled" and ref.filled == pytest.approx(0.049875)
    # dust under $1 is treated as flat rather than retried forever
    fake.positions["BTC/USD"] = 0.000005
    ref = b.market_close("BTC/USD", LONG, 0.000005)
    assert ref.status == "Filled" and ref.filled == 0.0
    # a genuine auth failure still names the keys
    from tradebot.alpaca import AlpacaError
    bad = AlpacaBroker(settings, data, transport=lambda m, u, h, body: (403, b'{"message":"forbidden"}'))
    with pytest.raises(AlpacaError, match="ALPACA_API_KEY"):
        bad._req("GET", "/v2/account")


def test_crypto_explain_names_the_failing_gate():
    s = CryptoMomentum(CryptoRules(breakout_bars=20, trend_ema_bars=100, min_rel_volume=1.5))
    now = clock.at(DAY, clock.parse_hhmm("00:00"))
    assert s.explain("BTC/USD", bars_24h(breakout_at=259), now) == "signal"
    assert s.explain("BTC/USD", bars_24h(), now) == "no_breakout"
    quiet = bars_24h(breakout_at=259)
    quiet[-1].volume = 100.0
    assert s.explain("BTC/USD", quiet, now) == "low_relvol"
    assert s.explain("BTC/USD", bars_24h()[-50:], now) == "history"
    assert set(s.GATES) >= {"signal", "no_breakout", "low_relvol", "history", "below_ema"}
