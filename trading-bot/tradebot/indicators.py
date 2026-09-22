"""Small, dependency-free indicator functions over lists of Bars."""

from __future__ import annotations

from .models import Bar


def sma(values: list[float], period: int) -> float | None:
    if len(values) < period or period <= 0:
        return None
    return sum(values[-period:]) / period


def ema_series(values: list[float], period: int) -> list[float]:
    if not values:
        return []
    k = 2.0 / (period + 1)
    out = [values[0]]
    for v in values[1:]:
        out.append(v * k + out[-1] * (1 - k))
    return out


def ema(values: list[float], period: int) -> float | None:
    if len(values) < period:
        return None
    return ema_series(values, period)[-1]


def true_ranges(bars: list[Bar]) -> list[float]:
    out: list[float] = []
    prev_close: float | None = None
    for b in bars:
        if prev_close is None:
            out.append(b.high - b.low)
        else:
            out.append(max(b.high - b.low, abs(b.high - prev_close), abs(b.low - prev_close)))
        prev_close = b.close
    return out


def atr(bars: list[Bar], period: int = 14) -> float | None:
    """Wilder's ATR. Returns None when fewer than ``period`` bars are available."""
    trs = true_ranges(bars)
    if len(trs) < period:
        return None
    value = sum(trs[:period]) / period
    for tr in trs[period:]:
        value = (value * (period - 1) + tr) / period
    return value


def vwap(bars: list[Bar]) -> float | None:
    vol = sum(b.volume for b in bars)
    if vol <= 0:
        return None
    return sum(b.typical * b.volume for b in bars) / vol


def rsi(values: list[float], period: int = 14) -> float | None:
    """Wilder's RSI of the last value; None until there is enough history."""
    if period <= 0 or len(values) < period + 1:
        return None
    gains, losses = 0.0, 0.0
    for a, b in zip(values[:period], values[1:period + 1]):
        d = b - a
        gains += max(d, 0.0)
        losses += max(-d, 0.0)
    avg_gain, avg_loss = gains / period, losses / period
    for a, b in zip(values[period:-1], values[period + 1:]):
        d = b - a
        avg_gain = (avg_gain * (period - 1) + max(d, 0.0)) / period
        avg_loss = (avg_loss * (period - 1) + max(-d, 0.0)) / period
    if avg_loss == 0:
        return 100.0
    return 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
