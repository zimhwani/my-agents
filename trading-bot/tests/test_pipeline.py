"""End-to-end: backtester, executor on the simulator, dashboard, and the live
loop driven tick-by-tick against SimBroker."""

from datetime import timedelta

from conftest import DAY, daily_history, session
from tradebot import clock
from tradebot.backtest import Backtester
from tradebot.broker import SimBroker
from tradebot.dashboard import render
from tradebot.data import aggregate_daily, synthetic_bars
from tradebot.execution import Executor, StateStore
from tradebot.journal import Journal
from tradebot.loop import TradingLoop
from tradebot.models import LONG, Signal
from tradebot.strategy import StrategyParams
from tradebot.telegram import Notifier


def test_backtest_on_synthetic_data(settings, params):
    bars = {s: synthetic_bars(s, 25, seed=i + 1, end=DAY) for i, s in enumerate(["AAA", "BBB", "CCC"])}
    res = Backtester(settings, params, bars).run()
    assert res.days == 25
    assert res.trades, "expected at least one trade on 25 synthetic days"
    for t in res.trades:
        assert t.status == "CLOSED" and t.qty_open == 0
        assert t.exits and sum(f.qty for f in t.exits) == t.qty_initial
        # a full stop-out costs about -1R (slippage / gap can push it a little past)
        if len(t.exits) == 1 and t.exits[0].reason == "stop":
            assert -1.6 < t.r_multiple < -0.9
        assert t.initial_risk_usd <= settings.max_risk_per_trade_usd * 1.05  # entry slippage
        assert t.last_exit_time.time() <= clock.parse_hhmm("15:55")
    reasons = {f.reason for t in res.trades for f in t.exits}
    assert "stop" in reasons
    html = render(res.trades, "test")
    assert "__DATA__" not in html and res.trades[0].symbol in html


def test_executor_partial_and_stop_fill_on_sim(settings, tmp_path):
    sim = SimBroker(equity=50_000)
    sim.set_price("T", 100.0, clock.at(DAY, clock.parse_hhmm("10:00")))
    j = Journal(tmp_path / "j.jsonl")
    ex = Executor(sim, j, Notifier(quiet=True), StateStore(tmp_path / "state.json"))
    sig = Signal("T", LONG, 100.0, 99.0, 102.0, 0.5, sim.now)
    t = ex.open_trade(sig, 100, sim.now)
    assert t is not None and len(ex.open_trades) == 1
    assert (tmp_path / "state.json").exists()
    # partial via exit actions
    from tradebot.exits import CLOSE, MOVE_STOP, PARTIAL, ExitAction
    sim.set_price("T", 101.0)
    ex.apply(t, [ExitAction(PARTIAL, 50, 101.0, "partial"), ExitAction(MOVE_STOP, price=100.0, reason="breakeven")])
    assert t.qty_open == 50 and t.stop == 100.0
    stop = sim.find_order(t.stop_order_id, t.stop_perm_id)
    assert stop.qty == 50 and stop.price == 100.0
    # a bar trading through the stop fills it at the broker; executor picks it up
    bars = session(DAY, [100.5, 99.5], spread=0.1)
    sim.process_bar("T", bars[1])
    ex.check_stop_fills(sim.now)
    assert t.status == "CLOSED" and not ex.open_trades
    assert j.load()[0].r_multiple > 0.4  # +$50 partial, ~0 on the rest
    # restart: state has no open trades left
    ex2 = Executor(sim, j, Notifier(quiet=True), StateStore(tmp_path / "state.json"))
    ex2.restore()
    assert ex2.open_trades == []


def test_restore_reattaches_or_replaces_stop(settings, tmp_path):
    sim = SimBroker(equity=50_000)
    sim.set_price("T", 100.0, clock.at(DAY, clock.parse_hhmm("10:00")))
    j = Journal(None)
    store = StateStore(tmp_path / "state.json")
    ex = Executor(sim, j, Notifier(quiet=True), store)
    t = ex.open_trade(Signal("T", LONG, 100.0, 99.0, 102.0, 0.5, sim.now), 10, sim.now)
    # simulate a restart where the broker lost the stop
    sim._orders.pop(t.stop_order_id)
    ex2 = Executor(sim, j, Notifier(quiet=True), store)
    ex2.restore()
    assert len(ex2.open_trades) == 1
    new_stop = sim.find_order(ex2.open_trades[0].stop_order_id, 0)
    assert new_stop and new_stop.kind == "STOP" and new_stop.price == 99.0 and new_stop.qty == 10


def test_trading_loop_full_day(settings, params, tmp_path):
    """Drive the real TradingLoop against SimBroker through a scripted day."""
    settings.universe = ["GOOD", "DUD"]
    settings.max_watchlist = 2
    settings.telegram_status_minutes = 30
    # GOOD: clean breakout at 9:55 then trends up; DUD: never leaves its range
    good = [100.0, 100.5, 100.2, 100.3, 100.4, 101.2] + [101.2 + 0.15 * i for i in range(1, 73)]
    dud = [50.0, 50.2, 50.1] + [50.1 + (0.05 if i % 2 else -0.05) for i in range(75)]
    sim = SimBroker(equity=100_000)
    sim.intraday = {"GOOD": session(DAY, good, spread=0.15, volume=200_000),
                    "DUD": session(DAY, dud, spread=0.05, volume=200_000)}
    sim.daily = {"GOOD": daily_history(DAY, 40, 99.0, volume=100_000 * 78),
                 "DUD": daily_history(DAY, 40, 50.0, volume=100_000 * 78)}
    n = Notifier(quiet=True)
    from tradebot.backtest import _as_loaded
    loop = TradingLoop(settings, sim, _as_loaded(params, settings), n, journal=Journal(tmp_path / "j.jsonl"),
                       executor=Executor(sim, Journal(tmp_path / "j.jsonl"), n, StateStore(tmp_path / "s.json")))
    loop.journal = loop.exec.journal
    t = clock.at(DAY, clock.parse_hhmm("09:20"))
    end = clock.at(DAY, clock.parse_hhmm("16:00"))
    while t <= end:
        for sym, bars in sim.intraday.items():
            done = [b for b in bars if b.time + timedelta(minutes=5) <= t]
            if done:
                sim.process_bar(sym, done[-1])
        sim.now = t
        loop.tick(t)
        t += timedelta(minutes=5)
    trades = loop.journal.load()
    assert loop.day_done
    import json as _json
    live = _json.loads((settings.data_dir / "live.json").read_text())
    assert live["day_done"] and live["closed_today"] == 1 and live["strategy"]
    assert [x.symbol for x in trades] == ["GOOD"]
    tr = trades[0]
    assert tr.partial_taken and tr.status == "CLOSED"
    reasons = [f.reason for f in tr.exits]
    assert reasons[0] == "partial" and reasons[-1] in ("target", "stop", "eod")
    assert tr.r_multiple > 1.0
    assert not sim.positions()
    joined = "\n".join(n.sent)
    assert "Watchlist" in joined and "ENTRY LONG GOOD" in joined and "Day complete" in joined
    assert sum("ET status" in m for m in n.sent) >= 10  # ~every 30 min over the session
    assert "DUD" in joined  # on the watchlist, never traded


def test_aggregate_daily():
    bars = session(DAY, [1, 2, 3], spread=0.5, volume=10)
    d = aggregate_daily(bars)
    assert len(d) == 1 and d[0].open == 1 and d[0].close == 3 and d[0].volume == 30
    assert d[0].high == 3.5 and d[0].low == 0.5


def test_bars_for_refetches_until_newest_bar_arrives(settings, params, tmp_path):
    """A provider that hasn't published the just-closed bar must not be cached for the whole bar."""
    sim = SimBroker(equity=100_000)
    n = Notifier(quiet=True)
    from tradebot.backtest import _as_loaded
    loop = TradingLoop(settings, sim, _as_loaded(params, settings), n, journal=Journal(tmp_path / "j.jsonl"),
                       executor=Executor(sim, Journal(tmp_path / "j.jsonl"), n, StateStore(tmp_path / "s.json")))
    bars = session(DAY, [100 + 0.1 * i for i in range(20)])  # 5-min bars from 09:30
    calls = []
    state = {"published_until": clock.at(DAY, clock.parse_hhmm("09:55"))}

    def feed(symbol, minutes, days, pre):
        calls.append(symbol)
        return [b for b in bars if b.time < state["published_until"]]

    sim.intraday_bars = feed
    t = clock.at(DAY, clock.parse_hhmm("10:00"))  # the 09:55 bar has just completed
    out = loop.bars_for("GOOD", t)
    assert out[-1].time == clock.at(DAY, clock.parse_hhmm("09:50")) and len(calls) == 1 and "GOOD" in loop._stale
    loop.bars_for("GOOD", t + timedelta(seconds=30))
    assert len(calls) == 2  # still missing -> fetched again
    state["published_until"] = clock.at(DAY, clock.parse_hhmm("10:00"))
    out = loop.bars_for("GOOD", t + timedelta(seconds=60))
    assert out[-1].time == clock.at(DAY, clock.parse_hhmm("09:55")) and len(calls) == 3 and "GOOD" not in loop._stale
    loop.bars_for("GOOD", t + timedelta(seconds=90))
    assert len(calls) == 3  # fresh -> cached for the rest of the bar
    # a genuine gap in the data: give up after the grace period instead of hammering the provider
    t2 = clock.at(DAY, clock.parse_hhmm("10:05"))
    loop.bars_for("GOOD", t2)
    loop.bars_for("GOOD", t2 + timedelta(seconds=60))
    assert len(calls) == 5 and "GOOD" in loop._stale
    loop.bars_for("GOOD", t2 + loop._fresh_grace())
    assert len(calls) == 6 and loop._bars_at["GOOD"] == t2
    loop.bars_for("GOOD", t2 + loop._fresh_grace() + timedelta(seconds=30))
    assert len(calls) == 6
