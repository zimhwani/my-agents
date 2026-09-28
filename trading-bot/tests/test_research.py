"""Research harness: metrics, benchmark, timeframes, squeeze mode, daily-bar ATR, end-to-end report."""

import json
import math
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.alpaca_broker import alpaca_timeframe
from tradebot.crypto import CryptoMomentum, CryptoRules
from tradebot.data import synthetic_continuous
from tradebot.models import LONG, Bar
from tradebot.research import Options, benchmark_curve, curve_metrics, render, run_strategy
from tradebot.strategy import load_strategy


def test_alpaca_timeframes():
    assert [alpaca_timeframe(m) for m in (5, 15, 60, 240, 1440)] == ["5Min", "15Min", "1Hour", "4Hour", "1Day"]


def test_bar_boundary_aligns_hour_and_day_bars(settings):
    from tradebot.loop import TradingLoop
    from tradebot.broker import SimBroker
    from tradebot.telegram import Notifier
    ls = load_strategy("strategies/crypto_trend_4h.json")
    ls.apply(settings, validate=False)
    loop = TradingLoop(settings, SimBroker(), ls, Notifier(quiet=True))
    now = datetime(2026, 9, 28, 10, 37, tzinfo=timezone.utc)
    assert loop._bar_boundary(now) == datetime(2026, 9, 28, 8, 0, tzinfo=timezone.utc)
    loop.bar_minutes = 15
    assert loop._bar_boundary(now) == datetime(2026, 9, 28, 10, 30, tzinfo=timezone.utc)


def test_curve_metrics_known_values():
    d0 = date(2026, 1, 1)
    curve = [(d0 + timedelta(days=i), e) for i, e in enumerate([110.0, 99.0, 121.0])]
    m = curve_metrics(curve, 100.0)
    assert m.total_return == pytest.approx(0.21)
    assert m.max_dd == pytest.approx(99.0 / 110.0 - 1)
    rets = [0.10, -0.10, 121.0 / 99.0 - 1]
    mean = sum(rets) / 3
    sd = math.sqrt(sum((r - mean) ** 2 for r in rets) / 2)
    assert m.sharpe == pytest.approx(mean / sd * math.sqrt(365))
    assert m.sortino > m.sharpe  # only one down day
    assert curve_metrics([], 100.0).total_return == 0.0


def test_benchmark_is_equal_weight_buy_and_hold():
    t0 = clock.at(DAY, clock.parse_hhmm("00:00"))
    a = [Bar(t0 + timedelta(days=i), p, p, p, p, 1) for i, p in enumerate([100, 110, 120])]
    b = [Bar(t0 + timedelta(days=i), p, p, p, p, 1) for i, p in enumerate([50, 50, 25])]
    curve = benchmark_curve({"A": a, "B": b}, a[0].time.date(), a[-1].time.date(), 1000.0)
    assert [round(e, 6) for _, e in curve] == [1000.0, 1050.0, 850.0]


def test_squeeze_signal_after_compression():
    s = CryptoMomentum(CryptoRules(mode="squeeze", trend_ema_bars=20, squeeze_bars=20, squeeze_lookback=60,
                                   squeeze_pct=0.2, box_bars=6, min_rel_volume=0, stop_atr_mult=1.5,
                                   min_initial_risk_pct=0, max_initial_risk_pct=20))
    t = clock.at(DAY, clock.parse_hhmm("00:00")) - timedelta(hours=4 * 140)
    bars, p = [], 100.0
    for i in range(130):  # volatile uptrend: wide bands
        p += 0.3 + (1.5 if i % 2 else -1.2)
        bars.append(Bar(t, p - 0.5, p + 1.5, p - 1.5, p, 100))
        t += timedelta(hours=4)
    for i in range(10):  # compression: tiny range
        bars.append(Bar(t, p, p + 0.05, p - 0.05, p + (0.01 if i % 2 else -0.01), 100))
        t += timedelta(hours=4)
    brk = Bar(t, p, p + 3.0, p - 0.05, p + 2.5, 300)
    sig, why = s.evaluate_explained("BTC/USD", bars + [brk], [], brk.time + timedelta(hours=4))
    assert why == "signal" and sig.side == LONG and sig.stop < p and "squeeze" in sig.reason
    # expanding volatility (the opposite of a squeeze) -> no_squeeze
    wild, q, t2 = list(bars[:120]), bars[119].close, bars[119].time
    for i in range(20):
        t2 += timedelta(hours=4)
        q += 0.3 + (4.0 if i % 2 else -3.5)
        wild.append(Bar(t2, q - 0.5, q + 1.5, q - 1.5, q, 100))
    brk2 = Bar(t2 + timedelta(hours=4), q, q + 12, q - 1, q + 11, 300)
    assert s.explain("BTC/USD", wild + [brk2], brk2.time + timedelta(hours=4)) == "no_squeeze"


def test_daily_bar_backtest_has_atr_and_trails(settings):
    from tradebot.backtest import Backtester
    ls = load_strategy("strategies/crypto_trend_1d.json")
    ls.apply(settings, validate=False)
    settings.max_risk_per_trade_usd = 1e9
    end = clock.at(DAY, clock.parse_hhmm("00:00"))
    bars = {s: synthetic_continuous(s, 500, 1440, seed=i + 7, start_price=100 * (i + 1), end=end)
            for i, s in enumerate(["BTC/USD", "ETH/USD", "SOL/USD"])}
    bt = Backtester(settings, ls, bars, fee_bps=25.0)
    assert bt._atr("BTC/USD", end - timedelta(days=30)) > 0  # was 0: RTH filter dropped every daily bar
    res = bt.run()
    assert res.trades and res.equity_curve
    assert any(f.reason == "trail" for t in res.trades for f in t.exits) or \
        any(t.stop > t.stop_initial for t in res.trades)


def test_research_end_to_end_on_synthetic_data(settings, tmp_path):
    uni = ["BTC/USD", "ETH/USD", "SOL/USD"]
    end = clock.at(DAY, clock.parse_hhmm("00:00"))
    files = []
    for name in ("crypto_trend_1d.json", "crypto_meanrev_1d.json"):
        d = json.loads(Path("strategies", name).read_text())
        d["universe"] = uni
        f = tmp_path / name
        f.write_text(json.dumps(d))
        files.append(f)
    daily = {s: synthetic_continuous(s, 520, 1440, seed=i + 11, start_price=100 * (i + 1), end=end)
             for i, s in enumerate(uni)}
    opts = Options(equity=10_000, walk_forward=2, min_trades=5)
    reps = [run_strategy(settings, f, {1440: daily}, opts) for f in files]
    for r in reps:
        assert not r.error, r.error
        assert r.verdict in ("DEPLOY CANDIDATE", "PAPER-TRADE / WATCH", "REJECT")
        assert r.split and r.window[0] < r.split < r.window[1]
        assert r.ins.end < r.oos.start or r.ins.trades == 0 or r.oos.trades == 0 or r.ins.end <= r.oos.start
        assert r.sensitivity and all(len(x) == 5 for x in r.sensitivity)
        assert r.walk_forward and len(r.walk_forward["folds"]) == 2
        assert "enough trades (5+)" in r.criteria
    md = render(reps, opts)
    for heading in ("## 1. Executive summary", "## 2. Market analysis", "## 3. Strategy details",
                    "## 4. Backtest results", "## 5. Comparison and ranking", "## 6. Final recommendations",
                    "## 7. Deployment considerations", "## 8. What could go wrong"):
        assert heading in md
    assert "Daily Donchian Trend" in md and "Buy & hold" in md
    # missing data is reported, not crashed
    empty = run_strategy(settings, files[0], {240: daily}, opts)
    assert empty.verdict == "NO DATA"
