"""Gold / forex / index CFD support: Deriv candles, two-sided breakouts, session breakout, per-market costs."""

import asyncio
from datetime import datetime, timedelta, timezone

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.backtest import Backtester, default_costs
from tradebot.crypto import CryptoMomentum, CryptoRules
from tradebot.data import synthetic_continuous
from tradebot.deriv import SYMBOLS, candles_to_bars, fetch_candles
from tradebot.models import LONG, SHORT, Bar
from tradebot.strategy import load_strategy


def test_deriv_pagination_and_symbols():
    start, end, gran = 1_700_000_000, 1_700_000_000 + 3600 * 12000, 3600
    calls = []

    async def request(payload):
        calls.append(payload)
        assert payload["ticks_history"] == "frxXAUUSD" and payload["style"] == "candles"
        lo, hi = payload["start"], payload["end"]
        eps = [e for e in range(start, end + 1, gran) if lo <= e <= hi][-payload["count"]:]
        return {"candles": [{"epoch": e, "open": 1.0, "high": 2.0, "low": 0.5, "close": 1.5} for e in eps]}

    bars = asyncio.run(fetch_candles(request, "XAU/USD", gran, start, end))
    assert len(bars) == 12001 and len(calls) >= 3
    assert all(b.time.timestamp() < c.time.timestamp() for b, c in zip(bars, bars[1:]))  # sorted, unique
    assert bars[0].volume == 0.0 and bars[0].time.tzinfo is not None
    assert "R_75" not in SYMBOLS.values()  # synthetic indices are deliberately excluded
    with pytest.raises(ValueError):
        asyncio.run(fetch_candles(request, "XAU/USD", 250, start, end))

    async def err(payload):
        return {"error": {"message": "Unknown symbol"}}
    with pytest.raises(RuntimeError, match="Unknown symbol"):
        asyncio.run(fetch_candles(err, "XAU/USD", 3600, start, end))


def _series(n, start=100.0, step=0.05, width=0.3):
    t = clock.at(DAY, clock.parse_hhmm("00:00")) - timedelta(hours=n)
    out = []
    for i in range(n):
        p = start + i * step
        out.append(Bar(t, p, p + width, p - width, p + step / 2, 0))
        t += timedelta(hours=1)
    return out


def test_two_sided_breakout():
    rules = dict(breakout_bars=20, trend_ema_bars=50, min_rel_volume=0, stop_atr_mult=2.0,
                 max_initial_risk_pct=20, direction="both")
    s = CryptoMomentum(CryptoRules(**rules))
    down = _series(120, start=200.0, step=-0.05)
    last = down[-1]
    brk = Bar(last.time + timedelta(hours=1), last.close, last.close + 0.1, last.close - 3, last.close - 2.5, 0)
    sig, why = s.evaluate_explained("XAU/USD", down + [brk], [], brk.time + timedelta(hours=1))
    assert why == "signal" and sig.side == SHORT and sig.stop > sig.entry > sig.target
    long_only = CryptoMomentum(CryptoRules(**{**rules, "direction": "long_only"}))
    assert long_only.explain("XAU/USD", down + [brk], brk.time + timedelta(hours=1)) == "no_breakout"
    up = _series(120)
    last = up[-1]
    brk2 = Bar(last.time + timedelta(hours=1), last.close, last.close + 3, last.close - 0.1, last.close + 2.5, 0)
    sig2, why2 = s.evaluate_explained("XAU/USD", up + [brk2], [], brk2.time + timedelta(hours=1))
    assert why2 == "signal" and sig2.side == LONG


def test_session_breakout_first_break_only():
    s = CryptoMomentum(CryptoRules(mode="session", bar_minutes=15, session_start_utc="00:00",
                                   session_end_utc="07:00", entry_end_utc="12:00", trend_ema_bars=0,
                                   stop_atr_mult=0, min_initial_risk_pct=0.1, max_initial_risk_pct=5,
                                   direction="both"))
    day = datetime(2026, 9, 29, tzinfo=timezone.utc)
    t = day - timedelta(hours=24)
    bars = []
    while t < day + timedelta(hours=7):  # a flat day before plus the Asian range 2000 +/- 2
        bars.append(Bar(clock.to_et(t), 2000, 2002, 1998, 2000, 0))
        t += timedelta(minutes=15)
    brk = Bar(clock.to_et(t), 2000, 2006, 1999, 2005, 0)  # 07:00-07:15 closes above the range
    close_at = clock.to_et(t + timedelta(minutes=15))
    sig, why = s.evaluate_explained("XAU/USD", bars + [brk], [], close_at)
    assert why == "signal" and sig.side == LONG and sig.stop == pytest.approx(1998) and sig.target > sig.entry
    back = Bar(clock.to_et(t + timedelta(minutes=15)), 2005, 2005, 2000, 2001, 0)
    again = Bar(clock.to_et(t + timedelta(minutes=30)), 2001, 2008, 2000, 2007, 0)
    assert s.explain("XAU/USD", bars + [brk, back, again], clock.to_et(t + timedelta(minutes=45))) == "not_first_bar"
    late = Bar(clock.to_et(day + timedelta(hours=13)), 2000, 2010, 1999, 2009, 0)
    assert s.explain("XAU/USD", bars + [late], clock.to_et(day + timedelta(hours=13, minutes=15))) == "outside_window"
    brk_dn = Bar(clock.to_et(t), 2000, 2001, 1990, 1994, 0)
    sig_dn, why_dn = s.evaluate_explained("XAU/USD", bars + [brk_dn], [], close_at)
    assert why_dn == "signal" and sig_dn.side == SHORT and sig_dn.stop == pytest.approx(2002)


def test_cfd_rules_load_with_their_own_costs_and_backtest_shorts(settings):
    ls = load_strategy("strategies_cfd/gold_trend_4h.json")
    assert ls.continuous and ls.risk_overrides["allow_shorts"] and default_costs(ls) == (1.5, 0.5, 3.0)
    assert default_costs(load_strategy("crypto_swing.json")) == (25.0, 0.5, 20.0)
    ls.apply(settings, validate=False)
    end = clock.at(DAY, clock.parse_hhmm("00:00"))
    bars = {"XAU/USD": synthetic_continuous("XAU/USD", 200, 240, seed=5, start_price=2000, end=end)}
    res = Backtester(settings, ls, bars, fee_bps=1.5).run()
    assert res.trades and res.equity_curve
    assert {t.side for t in res.trades} <= {LONG, SHORT}
