import json
from datetime import timedelta
from urllib.parse import parse_qs, urlparse

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.alpaca import AlpacaData, AlpacaError


class FakeAlpaca:
    def __init__(self):
        self.calls = []
        self.rate_limit_once = False

    def __call__(self, url, headers):
        assert headers["APCA-API-KEY-ID"] == "K" and headers["APCA-API-SECRET-KEY"] == "S"
        u = urlparse(url)
        q = parse_qs(u.query)
        self.calls.append(u.path)
        if self.rate_limit_once:
            self.rate_limit_once = False
            return 429, b""
        if u.path == "/v2/stocks/AAPL/bars":
            assert q["feed"] == ["iex"]
            if q["timeframe"] == ["1Day"]:
                bars = [{"t": "2026-09-14T04:00:00Z", "o": 100, "h": 101, "l": 99, "c": 100.5, "v": 1e6},
                        {"t": "2026-09-15T04:00:00Z", "o": 101, "h": 102, "l": 100, "c": 101.5, "v": 1e6}]
                return 200, json.dumps({"bars": bars, "next_page_token": None}).encode()
            # 5-min: two pages; includes a premarket bar (13:00Z = 09:00 ET) and RTH bars
            if q.get("page_token") == ["p2"]:
                bars = [{"t": "2026-09-15T13:35:00Z", "o": 1, "h": 2, "l": 0.5, "c": 1.5, "v": 10}]
                return 200, json.dumps({"bars": bars, "next_page_token": None}).encode()
            bars = [{"t": "2026-09-15T13:00:00Z", "o": 1, "h": 2, "l": 0.5, "c": 1.2, "v": 5},
                    {"t": "2026-09-15T13:30:00Z", "o": 1, "h": 2, "l": 0.5, "c": 1.4, "v": 10}]
            return 200, json.dumps({"bars": bars, "next_page_token": "p2"}).encode()
        if u.path == "/v2/stocks/AAPL/trades/latest":
            return 200, json.dumps({"trade": {"p": 123.45}}).encode()
        if u.path == "/v2/stocks/snapshots":
            syms = q["symbols"][0].split(",")
            snap = {s: {"latestTrade": {"p": 110.0 if s == "GAP" else 100.5},
                        "dailyBar": {"o": 108.0 if s == "GAP" else 100.2},
                        "prevDailyBar": {"c": 100.0}} for s in syms}
            return 200, json.dumps(snap).encode()
        if u.path == "/v2/stocks/BAD/bars":
            return 403, b'{"message":"subscription does not permit"}'
        raise AssertionError(url)


class Aux:
    def market_cap(self, symbol):
        return 5e9 if symbol in ("GAP", "SCRN") else 5e8

    def fx_rate(self, base, quote):
        return 0.7

    def gappers(self, min_gap_pct, min_price, min_market_cap, limit=100):
        from tradebot.marketdata import Gapper
        return [Gapper("SCRN", 40.0, 8.0, 5e9), Gapper("GAP", 110.0, 10.0, 5e9, 100.0)]


@pytest.fixture
def data():
    fake = FakeAlpaca()
    return AlpacaData("K", "S", "iex", universe=["GAP", "FLAT", "TINY"], transport=fake,
                      sleep=lambda s: None, aux=Aux()), fake


def test_requires_keys():
    with pytest.raises(AlpacaError):
        AlpacaData("", "", aux=Aux())


def test_bars_pagination_and_rth_filter(data, monkeypatch):
    d, fake = data
    monkeypatch.setattr("tradebot.alpaca.clock.now_et", lambda: clock.at(DAY, clock.parse_hhmm("12:00")))
    bars = d.intraday_bars("AAPL", 5, 5, include_premarket=True)
    assert len(bars) == 3 and bars[0].time.time() == clock.parse_hhmm("09:00")
    assert bars[0].time.tzinfo is not None
    rth = d.intraday_bars("AAPL", 5, 5)
    assert [b.time.time() for b in rth] == [clock.parse_hhmm("09:30"), clock.parse_hhmm("09:35")]
    assert fake.calls.count("/v2/stocks/AAPL/bars") == 2  # two pages, then served from cache
    daily = d.daily_bars("AAPL", 60)  # today's still-forming daily bar is dropped
    assert len(daily) == 1 and daily[-1].time.time() == clock.MARKET_CLOSE and daily[-1].close == 100.5


def test_last_price_snapshots_and_gappers(data):
    d, fake = data
    assert d.last_price("AAPL") == 123.45
    g = d.gappers(3.0, 3.0, 1e9)
    # screener results merged with the static-universe snapshot scan, de-duplicated, sorted by gap
    assert [x.symbol for x in g] == ["GAP", "SCRN"]  # FLAT has no gap, TINY fails the market-cap check
    assert g[0].gap_pct == pytest.approx(10.0) and g[0].prev_close == 100.0
    assert d.fx_rate("AUD", "USD") == 0.7 and d.fx_rate("USD", "USD") == 1.0


def test_rate_limit_retry_and_auth_error(data):
    d, fake = data
    fake.rate_limit_once = True
    assert d.last_price("AAPL") == 123.45
    with pytest.raises(AlpacaError, match="rejected"):
        d.bars("BAD", "5Min", clock.at(DAY, clock.MARKET_OPEN))
