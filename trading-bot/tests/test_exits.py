from datetime import timedelta

from conftest import DAY
from tradebot import clock
from tradebot.exits import CLOSE, MOVE_STOP, PARTIAL, ExitManager
from tradebot.models import LONG, SHORT, TradeRecord
from tradebot.strategy import StrategyParams


def trade(side=LONG, qty=100, entry=100.0, stop=99.0):
    return TradeRecord(id="t1", symbol="T", side=side, qty_initial=qty, entry_price=entry,
                       entry_time=clock.at(DAY, clock.parse_hhmm("10:00")), stop_initial=stop,
                       stop=stop, target=entry + 2 * (entry - stop), atr=0.5)


def at(hhmm):
    return clock.at(DAY, clock.parse_hhmm(hhmm))


def test_partial_and_breakeven_at_one_r():
    em = ExitManager(StrategyParams())
    t = trade()
    assert em.manage(t, 100.8, 0.5, at("10:10")) == []
    actions = em.manage(t, 101.0, 0.5, at("10:15"))
    kinds = [a.kind for a in actions]
    assert kinds == [PARTIAL, MOVE_STOP]
    assert actions[0].qty == 50
    # stop tightens to at least breakeven (the ATR trail may already be tighter)
    assert actions[1].price >= 100.0 and actions[1].reason in ("breakeven", "trail")
    assert t.partial_taken


def test_breakeven_when_trail_is_looser():
    em = ExitManager(StrategyParams(trail_atr_mult=3.0))  # 101 - 3*0.5 = 99.5 < entry
    t = trade()
    actions = em.manage(t, 101.0, 0.5, at("10:15"))
    assert actions[1].kind == MOVE_STOP and actions[1].price == 100.0 and actions[1].reason == "breakeven"


def test_trail_follows_highest_and_never_loosens():
    em = ExitManager(StrategyParams(trail_atr_mult=1.0))
    t = trade()
    em.manage(t, 101.0, 0.5, at("10:15"))  # partial + breakeven
    t.stop = 100.0
    a = em.manage(t, 101.5, 0.5, at("10:20"))
    assert a == [] or a[0].price == 101.0  # 101.5 - 1.0*0.5 -> 101.0 beats breakeven
    assert a and a[0].kind == MOVE_STOP and a[0].price == 101.0
    t.stop = 101.0
    assert em.manage(t, 101.2, 0.5, at("10:25")) == []  # would loosen -> nothing
    a = em.manage(t, 102.0, 0.5, at("10:30"))
    assert a[0].price == 101.5


def test_hard_target_closes_remaining():
    em = ExitManager(StrategyParams())
    t = trade()
    t.partial_taken = True
    t.qty_open = 50
    a = em.manage(t, 103.0, 0.5, at("11:00"))
    assert a[0].kind == CLOSE and a[0].reason == "target" and a[0].qty == 50


def test_time_stop_only_when_not_working():
    em = ExitManager(StrategyParams(time_stop_minutes=60, time_stop_min_r=0.5))
    t = trade()
    assert em.manage(t, 100.2, 0.5, at("10:30")) == []
    a = em.manage(t, 100.2, 0.5, at("11:05"))
    assert a and a[0].kind == CLOSE and a[0].reason == "time"
    t2 = trade()
    assert em.manage(t2, 100.7, 0.5, at("11:05")) == []  # +0.7R: keep it


def test_forced_close_and_through_stop():
    em = ExitManager(StrategyParams())
    t = trade()
    a = em.manage(t, 100.5, 0.5, at("15:50"))
    assert a[0].kind == CLOSE and a[0].reason == "eod"
    t = trade()
    a = em.manage(t, 98.9, 0.5, at("10:30"))
    assert a[0].kind == CLOSE and a[0].reason == "stop"


def test_short_side_mirrors():
    em = ExitManager(StrategyParams(trail_atr_mult=1.0))
    t = trade(side=SHORT, entry=100.0, stop=101.0)
    a = em.manage(t, 99.0, 0.5, at("10:15"))
    assert [x.kind for x in a] == [PARTIAL, MOVE_STOP] and a[1].price <= 100.0
    t.stop = 100.0
    a = em.manage(t, 98.0, 0.5, at("10:20"))
    assert a[0].kind == MOVE_STOP and a[0].price == 98.5


def test_single_share_trade_skips_partial():
    em = ExitManager(StrategyParams())
    t = trade(qty=1)
    a = em.manage(t, 101.0, 0.5, at("10:15"))
    assert [x.kind for x in a] == [MOVE_STOP]
