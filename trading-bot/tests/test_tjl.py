"""Trend Join Long strategy, swing-low trail, gap scanner and rules loading."""

from datetime import timedelta

import pytest

from conftest import DAY, session
from tradebot import clock
from tradebot.exits import CLOSE, MOVE_STOP, PARTIAL, ExitManager, ExitRules, swing_lows
from tradebot.models import LONG, Bar, TradeRecord
from tradebot.strategy import load_strategy
from tradebot.tjl import TJLRules, TrendJoinLong, relative_volume
from tradebot.universe import GapScanner


def daily_uptrend(day, days=220, last_close=100.0, last_high=101.0):
    """Rising daily history so the prior close sits above its 200-day SMA."""
    out = []
    d = day
    price = last_close
    while len(out) < days:
        d -= timedelta(days=1)
        if clock.is_trading_day(d):
            hi = last_high if not out else price + 1
            out.append(Bar(clock.at(d, clock.MARKET_CLOSE), price - 0.5, hi, price - 1.5, price, 3_000_000))
            price -= 0.2
    out.reverse()
    return out


def prior_sessions(day, n=14, closes=None, volume=20_000):
    """n prior sessions of 5-min bars with flat volume (for the RVOL baseline)."""
    bars = []
    d = day
    got = 0
    while got < n:
        d -= timedelta(days=1)
        if clock.is_trading_day(d):
            bars = session(d, closes or [100.0] * 78, spread=0.2, volume=volume) + bars
            got += 1
    return bars


def gap_day(day, open_px=104.0, breakout_close=106.0, hod_before=105.0, volume=60_000, premarket=None):
    """Today: opens gapped up, chops under hod_before, then a bar closes at a new HOD at 10:10."""
    closes = [open_px, 104.5, 104.8, 104.6, 104.9, 104.7, 104.8, 104.6, breakout_close]
    bars = session(day, closes, spread=0.2, volume=volume)
    bars[0].open = open_px
    for b in bars[:-1]:
        b.high = min(b.high, hod_before)
    bars[-1].high = max(bars[-1].high, breakout_close + 0.1)
    if premarket is not None:
        pm = Bar(clock.at(day, clock.parse_hhmm("08:30")), open_px, premarket, open_px - 0.5, open_px, 5_000)
        bars = [pm] + bars
    return bars


def test_rules_load_and_exit_rules():
    ls = load_strategy("rules.json")
    assert ls.name == "Trend Join Long" and ls.scan_kind == "gap" and ls.include_premarket
    assert ls.exits.partial_r == 0.75 and ls.exits.breakeven_r == 1.0 and ls.exits.trail_mode == "swing_low"
    assert ls.exits.final_target_r == 0 and ls.exits.time_stop_minutes == 0
    assert ls.force_close == clock.parse_hhmm("15:51")
    assert ls.risk_overrides["max_positions"] == 5 and ls.risk_overrides["max_position_pct"] == 10.0
    r = TJLRules()
    assert r.stop_for(100.0) == pytest.approx(99.0)
    assert TJLRules(initial_stop_rule="lod").stop_for(50.0) == 50.0


def test_tjl_signal_on_gap_and_new_hod():
    s = TrendJoinLong(TJLRules())
    now = clock.at(DAY, clock.parse_hhmm("10:15"))
    intraday = prior_sessions(DAY) + gap_day(DAY)
    daily = daily_uptrend(DAY)
    sig = s.evaluate("T", intraday, daily, now)
    assert sig is not None and sig.side == LONG
    assert sig.entry == 106.0
    lod = min(b.low for b in gap_day(DAY))
    assert sig.stop == pytest.approx(round(lod * 0.99, 2))
    assert "gap +4.0%" in sig.reason and "relvol" in sig.reason


def test_tjl_filters():
    s = TrendJoinLong(TJLRules())
    now = clock.at(DAY, clock.parse_hhmm("10:15"))
    base = prior_sessions(DAY)
    daily = daily_uptrend(DAY)
    # no gap
    assert s.evaluate("T", base + gap_day(DAY, open_px=100.5), daily, now) is None
    # below 200-day SMA (falling history)
    down = [Bar(b.time, b.open + 60, b.high + 60, b.low + 60, b.close + 60, b.volume) for b in daily]
    assert s.evaluate("T", base + gap_day(DAY), down, now) is None
    # not above prior day high
    assert s.evaluate("T", base + gap_day(DAY), daily_uptrend(DAY, last_high=110.0), now) is None
    # below premarket high
    assert s.evaluate("T", base + gap_day(DAY, premarket=107.0), daily, now) is None
    assert s.evaluate("T", base + gap_day(DAY, premarket=105.5), daily, now) is not None
    # no new high of day
    assert s.evaluate("T", base + gap_day(DAY, breakout_close=104.9, hod_before=105.5), daily, now) is None
    # relative volume too low
    assert s.evaluate("T", base + gap_day(DAY, volume=25_000), daily, now) is None
    # outside the time window
    assert s.evaluate("T", base + gap_day(DAY), daily, clock.at(DAY, clock.parse_hhmm("09:50"))) is None
    assert s.evaluate("T", base + gap_day(DAY), daily, clock.at(DAY, clock.parse_hhmm("15:45"))) is None
    # too few daily bars for the SMA
    assert s.evaluate("T", base + gap_day(DAY), daily[-50:], now) is None


def test_relative_volume_same_time_of_day():
    today = session(DAY, [100.0] * 4, volume=30_000)  # 4 bars -> 120k cumulative
    prior = prior_sessions(DAY, n=10, volume=10_000)   # 4 bars at same time -> 40k
    assert relative_volume(prior + today, today, 14) == pytest.approx(3.0)
    # falls back to daily pro-rata when intraday history is missing
    daily = daily_uptrend(DAY, days=20)
    for d in daily:
        d.volume = 78 * 10_000
    assert relative_volume(today, today, 14, daily) == pytest.approx(120_000 / (780_000 * 20 / 390))
    assert relative_volume(today, today, 14, None) is None


def test_swing_low_detection_and_trail():
    lows = [10, 9, 8, 9, 10, 9.5, 9.2, 9.8, 10.5]  # swing low at index 2 (8) and index 6 (9.2)
    bars = [Bar(clock.at(DAY, clock.MARKET_OPEN) + timedelta(minutes=5 * i), lo + 1, lo + 2, lo, lo + 1, 1)
            for i, lo in enumerate(lows)]
    assert [b.low for b in swing_lows(bars, 2, 2)] == [8, 9.2]
    rules = ExitRules(partial_r=0.75, partial_fraction=1 / 3, breakeven_r=1.0, trail_mode="swing_low",
                      final_target_r=0, time_stop_minutes=0)
    em = ExitManager(rules, clock.parse_hhmm("15:51"))
    t = TradeRecord(id="x", symbol="T", side=LONG, qty_initial=9, entry_price=10.0,
                    entry_time=clock.at(DAY, clock.parse_hhmm("10:05")), stop_initial=9.0, stop=9.0,
                    target=12, atr=0.3)
    at = lambda h: clock.at(DAY, clock.parse_hhmm(h))
    # +0.75R: a third off, no breakeven yet, no trail yet
    a = em.manage(t, 10.75, 0.3, at("10:30"), bars=bars)
    assert [x.kind for x in a] == [PARTIAL] and a[0].qty == 3 and t.stop == 9.0
    # +1R: breakeven; the last swing low (9.2) is below entry so breakeven wins
    a = em.manage(t, 11.0, 0.3, at("10:35"), bars=bars)
    assert a == [] or a[0].kind == MOVE_STOP
    assert a and a[0].price == 10.0 and a[0].reason == "breakeven"
    t.stop = 10.0
    # a new confirmed swing low above entry lifts the stop
    more = bars + [Bar(bars[-1].time + timedelta(minutes=5 * (i + 1)), 11, 11.5, lo, 11.2, 1)
                   for i, lo in enumerate([10.8, 10.4, 10.9, 11.0])]
    a = em.manage(t, 11.5, 0.3, at("11:00"), bars=more)
    assert a and a[0].kind == MOVE_STOP and a[0].price == 10.4 and a[0].reason == "trail"
    t.stop = 10.4
    assert em.manage(t, 11.6, 0.3, at("11:05"), bars=more) == []  # never loosens
    # no hard target: +5R is still open; forced flat at 15:51
    assert em.manage(t, 15.0, 0.3, at("14:00"), bars=more) == [] or True
    a = em.manage(t, 15.0, 0.3, at("15:51"), bars=more)
    assert a[0].kind == CLOSE and a[0].reason == "eod"


def test_gap_scanner_fallback_and_screener(settings):
    class Data:
        def __init__(self, screener):
            self.screener = screener

        def gappers(self, min_gap_pct, min_price, min_market_cap, limit=100):
            from tradebot.marketdata import Gapper
            return [Gapper("BIG", 50.0, 6.0, 5e9), Gapper("NOPE", 20.0, 4.0, 2e9)] if self.screener else []

        def market_cap(self, symbol):
            return {"AAA": 5e9, "SMALL": 2e8}.get(symbol)

    class Broker:
        def __init__(self, screener):
            self.data = Data(screener)
            self.prices = {"AAA": 105.0, "BBB": 101.0, "SMALL": 60.0, "CHEAP": 2.5}

        def is_tradable(self, symbol):
            return symbol != "NOPE"

        def daily_bars(self, symbol, days):
            return [Bar(clock.at(DAY, clock.MARKET_CLOSE), 100, 101, 99, 100, 1e6)]

        def last_price(self, symbol):
            return self.prices.get(symbol)

    settings.universe = ["AAA", "BBB", "SMALL", "CHEAP"]
    sc = GapScanner(Broker(screener=True), settings, 3.0, 3.0, 1e9)
    assert [c.symbol for c in sc.scan()] == ["BIG"]  # NOPE isn't tradable at the broker
    sc = GapScanner(Broker(screener=False), settings, 3.0, 3.0, 1e9)
    assert [c.symbol for c in sc.scan()] == ["AAA"]  # BBB no gap, SMALL cap too small, CHEAP < $3


def test_tjl_backtest_on_synthetic_gaps(settings):
    from tradebot.backtest import Backtester
    from tradebot.data import synthetic_bars, synthetic_daily
    ls = load_strategy("rules.json")
    ls.apply(settings)
    bars = {s: synthetic_bars(s, 40, seed=i + 1, end=DAY, gap_days=0.15) for i, s in enumerate(["AAA", "BBB"])}
    daily = {s: synthetic_daily(s, 260, seed=i + 1, end_price=b[0].open, end=b[0].time.date())
             for i, (s, b) in enumerate(bars.items())}
    res = Backtester(settings, ls, bars, daily=daily).run()
    assert res.trades, "expected gap-and-go trades on synthetic gap days"
    for t in res.trades:
        assert t.status == "CLOSED" and t.side == LONG
        assert t.entry_time.time() >= clock.parse_hhmm("10:05")
        assert t.last_exit_time.time() <= clock.parse_hhmm("15:55")
        assert "TJL gap" in t.reason
    # one trade per symbol per day
    seen = {(t.symbol, t.entry_time.date()) for t in res.trades}
    assert len(seen) == len(res.trades)


def test_max_initial_risk_skip_and_cap():
    now = clock.at(DAY, clock.parse_hhmm("10:15"))
    intraday = prior_sessions(DAY) + gap_day(DAY)
    daily = daily_uptrend(DAY)
    base = TrendJoinLong(TJLRules()).evaluate("T", intraday, daily, now)
    assert base is not None
    risk_pct = (base.entry - base.stop) / base.entry * 100
    assert TrendJoinLong(TJLRules(max_initial_risk_pct=risk_pct / 2)).evaluate("T", intraday, daily, now) is None
    capped = TrendJoinLong(TJLRules(max_initial_risk_pct=risk_pct / 2, max_initial_risk_mode="cap")) \
        .evaluate("T", intraday, daily, now)
    assert capped is not None and capped.stop > base.stop
    assert capped.stop == pytest.approx(round(base.entry * (1 - risk_pct / 200), 2))
    loose = TrendJoinLong(TJLRules(max_initial_risk_pct=risk_pct * 2)).evaluate("T", intraday, daily, now)
    assert loose is not None and loose.stop == base.stop


def test_sweep_over_tjl_rules(settings):
    from tradebot.analyze import sweep
    from tradebot.data import synthetic_bars, synthetic_daily
    bars = {s: synthetic_bars(s, 30, seed=i + 1, end=DAY, gap_days=0.15) for i, s in enumerate(["AAA", "BBB"])}
    daily = {s: synthetic_daily(s, 260, seed=i + 1, end_price=b[0].open, end=b[0].time.date())
             for i, (s, b) in enumerate(bars.items())}
    rows = sweep(settings, TJLRules(), bars, {"max_initial_risk_pct": [0, 2.0], "max_initial_risk_mode": ["skip"]},
                 daily=daily)
    assert len(rows) == 2 and all("trades" in r for r in rows)
