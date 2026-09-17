from datetime import timedelta

from conftest import DAY, session
from tradebot import clock
from tradebot.indicators import atr, ema, sma, vwap


def test_sma_and_ema():
    assert sma([1, 2, 3, 4], 2) == 3.5
    assert sma([1, 2], 3) is None
    e = ema([10] * 30, 20)
    assert abs(e - 10) < 1e-9
    assert ema([1, 2], 5) is None


def test_atr_and_vwap():
    bars = session(DAY, [100 + i * 0.1 for i in range(20)], spread=0.5)
    a = atr(bars, 14)
    assert a is not None and 0.9 < a < 1.5  # each bar ranges ~1.1
    assert atr(bars[:5], 14) is None
    v = vwap(bars)
    assert min(b.low for b in bars) < v < max(b.high for b in bars)
