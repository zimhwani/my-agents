from datetime import date, timedelta

from tradebot import clock
from tradebot.events import find_gap_events, plan_ranges, summarize
from tradebot.models import Bar


def daily(day0: date, closes, opens=None, volume=1e6):
    out = []
    d = day0
    i = 0
    while i < len(closes):
        if clock.is_trading_day(d):
            o = opens[i] if opens else closes[i]
            out.append(Bar(clock.at(d, clock.MARKET_CLOSE), o, max(o, closes[i]) + 0.5,
                           min(o, closes[i]) - 0.5, closes[i], volume))
            i += 1
        d += timedelta(days=1)
    return out


def test_find_gap_events_filters():
    day0 = date(2025, 1, 6)
    closes = [100.0 + i * 0.1 for i in range(230)]  # steady uptrend -> above SMA200
    opens = list(closes)
    opens[225] = closes[224] * 1.05  # +5% gap on day 225
    opens[228] = closes[227] * 1.02  # +2% -> below threshold
    bars = daily(day0, closes, opens)
    ev = find_gap_events({"AAA": bars}, 3.0, 3.0, 1000.0, 200)
    assert len(ev) == 1 and ev[0].symbol == "AAA" and abs(ev[0].gap_pct - 5.0) < 1e-6
    assert ev[0].day == bars[225].time.date()
    # too illiquid
    assert find_gap_events({"AAA": bars}, 3.0, 3.0, 1e12, 200) == []
    # downtrend: prior close below SMA200 -> rejected unless SMA not required
    down = daily(day0, [300.0 - i * 0.5 for i in range(230)],
                 [300.0 - i * 0.5 for i in range(230)])
    down[225] = Bar(down[225].time, down[224].close * 1.05, down[224].close * 1.06, down[224].close, down[224].close * 1.04, 1e6)
    assert find_gap_events({"BBB": down}, 3.0, 3.0, 1000.0, 200) == []
    assert len(find_gap_events({"BBB": down}, 3.0, 3.0, 1000.0, 200, require_sma=False)) == 1
    # start filter
    assert find_gap_events({"AAA": bars}, 3.0, 3.0, 1000.0, 200, start=bars[226].time.date()) == []


def test_plan_ranges_merges_overlaps_and_summary():
    from tradebot.events import GapEvent
    ev = [GapEvent("X", date(2025, 3, 10), 4.0, 10, 10.4, 1e6),
          GapEvent("X", date(2025, 3, 20), 5.0, 10, 10.5, 1e6),
          GapEvent("X", date(2025, 6, 2), 3.5, 10, 10.35, 1e6),
          GapEvent("Y", date(2025, 3, 10), 6.0, 10, 10.6, 1e6)]
    plan = plan_ranges(ev, context_sessions=16)
    assert len(plan["X"]) == 2 and len(plan["Y"]) == 1  # the two March events overlap into one range
    s, e = plan["X"][0]
    assert e == date(2025, 3, 20) and s < date(2025, 3, 10) - timedelta(days=16)
    text = summarize(ev)
    assert "4 gap events" in text and "2 symbols" in text and "2025-03 3" in text
    assert summarize([]) == "no gap events found"
