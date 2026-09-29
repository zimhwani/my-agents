"""Gold day trading: flat-by time, UTC trading window, two-sided pullback, Dukascopy decoding."""

import lzma
import struct
from datetime import date, datetime, timedelta, timezone

import pytest

from tradebot import clock
from tradebot.crypto import CryptoMomentum, CryptoRules
from tradebot.exits import CLOSE, ExitManager, ExitRules
from tradebot.models import LONG, SHORT, Bar, TradeRecord
from tradebot.strategy import load_strategy


def U(y, m, d, h, mi=0):
    return clock.to_et(datetime(y, m, d, h, mi, tzinfo=timezone.utc))


def test_flat_at_utc_closes_day_trades_only_after_the_cut():
    em = ExitManager(ExitRules(partial_r=0, breakeven_r=0, trail_mode="none", final_target_r=0,
                               time_stop_minutes=0, flat_at_utc="20:30", fractional=True), None)
    t = TradeRecord(id="t", symbol="XAU/USD", side=LONG, qty_initial=1, entry_price=4000, entry_time=U(2026, 9, 29, 9),
                    stop_initial=3990, stop=3990, target=4020, atr=5, qty_open=1)
    assert em.manage(t, 4005, 5, U(2026, 9, 29, 20, 25)) == []
    acts = em.manage(t, 4005, 5, U(2026, 9, 29, 20, 30))
    assert acts and acts[0].kind == CLOSE and acts[0].reason == "eod"
    late = TradeRecord(id="u", symbol="XAU/USD", side=SHORT, qty_initial=1, entry_price=4000,
                       entry_time=U(2026, 9, 29, 21), stop_initial=4010, stop=4010, target=3980, atr=5, qty_open=1)
    assert em.manage(late, 3999, 5, U(2026, 9, 29, 22)) == []  # opened after the cut: tomorrow's cut applies


def _bars(n, start, step, t0):
    out, p, t = [], start, t0
    for i in range(n):
        out.append(Bar(clock.to_et(t), p, p + 0.3, p - 0.3, p + step / 2, 0))
        p += step
        t += timedelta(minutes=15)
    return out


def test_trade_window_blocks_entries_outside_london_new_york():
    r = CryptoRules(bar_minutes=15, breakout_bars=16, trend_ema_bars=50, min_rel_volume=0, stop_atr_mult=1.5,
                    max_initial_risk_pct=5, direction="both", trade_start_utc="07:00", trade_end_utc="19:00")
    s = CryptoMomentum(r)
    base = _bars(150, 4000, 0.05, datetime(2026, 9, 28, 20, 0, tzinfo=timezone.utc))
    last = base[-1]
    brk = Bar(last.time + timedelta(minutes=15), last.close, last.close + 5, last.close - 0.1, last.close + 4, 0)
    close_at = brk.time + timedelta(minutes=15)
    hour = close_at.astimezone(timezone.utc).hour
    expect = "signal" if 7 <= hour < 19 else "outside_window"
    assert s.explain("XAU/USD", base + [brk], close_at) == expect
    s.r.trade_start_utc, s.r.trade_end_utc = "00:00", "23:59"
    assert s.explain("XAU/USD", base + [brk], close_at) == "signal"


def test_pullback_fades_rallies_in_a_downtrend():
    s = CryptoMomentum(CryptoRules(mode="pullback", bar_minutes=15, rsi_bars=3, rsi_buy=10, trend_ema_bars=50,
                                   stop_atr_mult=1.0, max_initial_risk_pct=5, direction="both"))
    t0 = datetime(2026, 9, 29, 7, 0, tzinfo=timezone.utc)
    down = _bars(120, 4200, -0.4, t0)
    p, t = down[-1].close, down[-1].time + timedelta(minutes=15)
    rally = []
    for i in range(4):  # sharp bounce: RSI(3) above 90, still under the EMA
        rally.append(Bar(t, p, p + 1.3, p - 0.05, p + 1.2, 0))
        p += 1.2
        t += timedelta(minutes=15)
    turn = Bar(t, p, p + 0.05, p - 1.0, p - 0.8, 0)
    sig, why = s.evaluate_explained("XAU/USD", down + rally + [turn], [], t + timedelta(minutes=15))
    assert why == "signal" and sig.side == SHORT and sig.stop > sig.entry
    s.r.direction = "long_only"
    assert s.explain("XAU/USD", down + rally + [turn], t + timedelta(minutes=15)) == "below_ema"


def test_breakout_without_trend_filter_trades_both_ways():
    r = CryptoRules(bar_minutes=15, breakout_bars=16, trend_ema_bars=0, min_rel_volume=0, stop_atr_mult=1.5,
                    max_initial_risk_pct=5, direction="both")
    s = CryptoMomentum(r)
    t0 = datetime(2026, 9, 29, 7, 0, tzinfo=timezone.utc)
    down = _bars(80, 4400, -1.0, t0)[:-16] + _bars(16, 4336, 0.0, t0 + timedelta(minutes=15 * 64))
    last = down[-1]
    pop = Bar(last.time + timedelta(minutes=15), last.close, last.close + 6, last.close - 0.1, last.close + 5, 0)
    at = pop.time + timedelta(minutes=15)
    sig, why = s.evaluate_explained("XAU/USD", down + [pop], [], at)
    assert why == "signal" and sig.side == LONG and sig.stop < sig.entry  # buys a bounce inside a downtrend
    up = _bars(80, 4000, 1.0, t0)[:-16] + _bars(16, 4064, 0.0, t0 + timedelta(minutes=15 * 64))
    last = up[-1]
    drop = Bar(last.time + timedelta(minutes=15), last.close, last.close + 0.1, last.close - 6, last.close - 5, 0)
    sig, why = s.evaluate_explained("XAU/USD", up + [drop], [], drop.time + timedelta(minutes=15))
    assert why == "signal" and sig.side == SHORT and sig.stop > sig.entry  # sells a drop inside an uptrend
    s.r.trend_ema_bars = 50  # with the trend filter back on, the counter-trend buy is refused
    assert s.explain("XAU/USD", down + [pop], at) == "below_ema"


def test_live_gold_rules_trade_both_ways_without_trend_filter():
    ls = load_strategy("strategies_cfd/gold_day_breakout_15m.json")
    r = ls.strategy.r
    assert r.direction == "both" and r.trend_ema_bars == 0 and ls.risk_overrides["allow_shorts"]


def _bi5(rows):
    raw = b"".join(struct.pack(">iiiiif", *r) for r in rows)
    return lzma.compress(raw, format=lzma.FORMAT_ALONE)


def test_dukascopy_decode_download_and_rollup():
    from tradebot import dukascopy as dk
    day = date(2026, 9, 28)  # a Monday
    rows = [(60 * i, 4_000_000 + i * 100, 4_000_050 + i * 100, 3_999_900 + i * 100, 4_000_200 + i * 100, 1.5)
            for i in range(30)]
    bars = dk.decode_day(_bi5(rows), day, 1000.0)
    assert len(bars) == 30 and bars[0].open == pytest.approx(4000.0) and bars[0].high == pytest.approx(4000.2)
    assert bars[0].time.astimezone(timezone.utc) == datetime(2026, 9, 28, tzinfo=timezone.utc)
    assert dk.decode_day(b"", day, 1000.0) == []
    urls = []

    def fetch(url):
        urls.append(url)
        return _bi5(rows) if "/2026/08/28/" in url else None  # month is 0-based: 08 = September

    out = dk.download("XAU/USD", 3, fetch=fetch, workers=2, end=day)
    assert len(out) == 6 and out[0].open == pytest.approx(4000.0)  # 30 minutes -> six 5-minute bars
    assert all("XAUUSD" in u and u.endswith("BID_candles_min_1.bi5") for u in urls)
    tf = dk.timeframes(out, [5, 15])
    assert len(tf[15]) == 2 and tf[15][0].high == pytest.approx(max(b.high for b in out[:3]))
    wrong = [(0, 4_000, 4_000, 4_000, 4_000, 1.0)]
    with pytest.raises(ValueError, match="divisor"):
        dk.download("XAU/USD", 1, fetch=lambda u: _bi5(wrong), workers=1, end=day)


def test_dukascopy_skips_a_day_that_times_out_but_not_a_dead_feed():
    from tradebot import dukascopy as dk
    day = date(2026, 9, 28)
    rows = [(60 * i, 4_000_000, 4_000_050, 3_999_900, 4_000_200, 1.0) for i in range(10)]

    def flaky(url):
        if "/2026/08/25/" in url:
            raise ConnectionError(url + ": The read operation timed out")
        return _bi5(rows)

    out = dk.download("XAU/USD", 60, fetch=flaky, workers=2, end=day)
    assert len({b.time.date() for b in out}) == 50  # 60 days - 9 Saturdays - the one that timed out

    def dead(url):
        raise ConnectionError(url + ": timed out")

    with pytest.raises(ConnectionError, match="days failed"):
        dk.download("XAU/USD", 60, fetch=dead, workers=2, end=day)


def test_day_rule_files_load_as_day_traders():
    for name in ("gold_day_breakout_15m", "gold_day_breakout_5m", "gold_day_pullback_15m",
                 "gold_day_london_15m", "gold_day_newyork_15m"):
        ls = load_strategy(f"strategies_cfd/{name}.json")
        assert ls.exits.flat_at_utc == "20:30" and ls.universe == ["XAU/USD"] and ls.risk_overrides["allow_shorts"]
