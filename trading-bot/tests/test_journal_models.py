from conftest import DAY
from tradebot import clock
from tradebot.journal import Journal, compute_stats
from tradebot.models import LONG, SHORT, TradeRecord


def mk(i, side=LONG, entry=100.0, stop=99.0, qty=100):
    return TradeRecord(id=f"t{i}", symbol="T", side=side, qty_initial=qty, entry_price=entry,
                       entry_time=clock.at(DAY, clock.parse_hhmm("10:00")), stop_initial=stop,
                       stop=stop, target=entry + 2, atr=0.5)


def test_r_multiple_math():
    t = mk(1)
    t.record_exit(t.entry_time, 50, 101.0, "partial")  # +$50
    t.record_exit(t.entry_time, 50, 100.0, "stop")     # 0
    assert t.status == "CLOSED"
    assert abs(t.realized_pnl - 50) < 1e-9
    assert abs(t.r_multiple - 0.5) < 1e-9
    s = mk(2, side=SHORT, entry=100.0, stop=101.0)
    s.record_exit(s.entry_time, 100, 101.0, "stop")
    assert abs(s.r_multiple + 1.0) < 1e-9


def test_jsonl_roundtrip(tmp_path):
    j = Journal(tmp_path / "trades.jsonl")
    t = mk(1)
    t.record_exit(t.entry_time, 100, 98.0, "stop")
    j.append(t)
    back = j.load()
    assert len(back) == 1 and back[0].r_multiple == -2.0
    assert back[0].exits[0].time == t.exits[0].time
    assert back[0].entry_time.tzinfo is not None


def test_stats():
    trades = []
    for i, r in enumerate([1.0, -1.0, 2.0, -1.0, 0.0]):
        t = mk(i)
        t.record_exit(t.entry_time, 100, 100.0 + r, "x")
        trades.append(t)
    st = compute_stats(trades)
    assert st.trades == 5 and st.wins == 2 and st.losses == 2 and st.scratches == 1
    assert st.win_rate == 0.5
    assert abs(st.total_r - 1.0) < 1e-9
    assert abs(st.profit_factor - 1.5) < 1e-9
    assert st.max_drawdown_r == -1.0
    assert compute_stats([]).trades == 0
