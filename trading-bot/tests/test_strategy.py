from datetime import timedelta

from conftest import DAY, daily_history, session
from tradebot import clock
from tradebot.models import LONG, SHORT
from tradebot.strategy import OpeningRangeBreakout, StrategyParams


def make_day(breakout=True, above_vwap=True):
    # opening range 9:30-9:45: closes 100.0, 100.5, 100.2 -> high ~100.7, low ~99.8
    closes = [100.0, 100.5, 100.2]
    closes += [100.3, 100.4]  # 9:45, 9:50 inside the range
    closes += [101.2 if breakout else 100.6]  # 9:55 bar closes above OR high (100.7)
    bars = session(DAY, closes, spread=0.2, volume=120_000)
    if not above_vwap:  # crank up volume on early high-priced bars so VWAP sits above the close
        bars[1].volume = 5_000_000
        bars[1].close = 104.0
        bars[1].high = 104.2
    return bars


def test_breakout_produces_long_signal():
    s = OpeningRangeBreakout(StrategyParams())
    bars = make_day()
    daily = daily_history(DAY, 30, close=99.0)
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    sig = s.evaluate("TEST", bars, daily, now)
    assert sig is not None
    assert sig.side == LONG
    assert sig.entry == 101.2
    assert sig.stop < sig.entry
    assert sig.stop >= 99.8 - 1e-9  # never below the OR low
    assert abs(sig.target - (sig.entry + 2 * (sig.entry - sig.stop))) < 1e-6
    assert "relvol" in sig.reason


def test_no_breakout_no_signal():
    s = OpeningRangeBreakout(StrategyParams())
    daily = daily_history(DAY, 30, close=99.0)
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    assert s.evaluate("TEST", make_day(breakout=False), daily, now) is None


def test_bar_not_yet_complete_is_ignored():
    s = OpeningRangeBreakout(StrategyParams())
    daily = daily_history(DAY, 30, close=99.0)
    now = clock.at(DAY, clock.parse_hhmm("09:58"))  # 9:55 bar still forming
    assert s.evaluate("TEST", make_day(), daily, now) is None


def test_outside_entry_window():
    s = OpeningRangeBreakout(StrategyParams())
    daily = daily_history(DAY, 30, close=99.0)
    assert s.evaluate("TEST", make_day(), daily, clock.at(DAY, clock.parse_hhmm("13:00"))) is None


def test_filters_block_signal():
    daily = daily_history(DAY, 30, close=99.0)
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    # below the 20-day EMA -> no long
    s = OpeningRangeBreakout(StrategyParams())
    assert s.evaluate("TEST", make_day(), daily_history(DAY, 30, close=150.0), now) is None
    # relative volume too low
    quiet = OpeningRangeBreakout(StrategyParams(min_rel_volume=50.0))
    assert quiet.evaluate("TEST", make_day(), daily, now) is None
    # opening range too wide relative to price
    tight = OpeningRangeBreakout(StrategyParams(max_or_pct=0.1))
    assert tight.evaluate("TEST", make_day(), daily, now) is None
    # below VWAP
    assert s.evaluate("TEST", make_day(above_vwap=False), daily, now) is None


def test_only_first_breakout_bar_signals():
    s = OpeningRangeBreakout(StrategyParams())
    daily = daily_history(DAY, 30, close=99.0)
    bars = make_day() + session(DAY, [101.4], volume=120_000)
    bars[-1].time = bars[-2].time + timedelta(minutes=5)
    bars[-1].open = 101.2
    now = clock.at(DAY, clock.parse_hhmm("10:05"))
    assert s.evaluate("TEST", bars, daily, now) is None


def test_shorts_only_when_allowed():
    closes = [100.0, 99.5, 99.8, 99.7, 99.6, 98.6]
    bars = session(DAY, closes, spread=0.2, volume=120_000)
    daily = daily_history(DAY, 30, close=101.0)
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    assert OpeningRangeBreakout(StrategyParams()).evaluate("T", bars, daily, now) is None
    sig = OpeningRangeBreakout(StrategyParams(), allow_shorts=True).evaluate("T", bars, daily, now)
    assert sig is not None and sig.side == SHORT and sig.stop > sig.entry


def test_params_load_rejects_unknown_keys(tmp_path):
    p = tmp_path / "s.json"
    p.write_text('{"bogus": 1}')
    try:
        StrategyParams.load(p)
    except ValueError as exc:
        assert "bogus" in str(exc)
    else:
        raise AssertionError("expected ValueError")
    assert StrategyParams.load(tmp_path / "missing.json").name
