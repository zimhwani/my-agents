import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tradebot import clock  # noqa: E402
from tradebot.config import Settings  # noqa: E402
from tradebot.models import Bar  # noqa: E402
from tradebot.strategy import StrategyParams  # noqa: E402

DAY = date(2026, 9, 15)  # a Tuesday, not a holiday


def bar(t: datetime, o, h, l, c, v=50_000) -> Bar:
    return Bar(t, o, h, l, c, v)


def session(day: date, closes: list[float], spread: float = 0.2, volume: float = 50_000,
            bar_minutes: int = 5) -> list[Bar]:
    """5-minute bars for ``day`` whose closes follow ``closes``; each bar's
    high/low straddle the open/close by ``spread``."""
    out = []
    t = clock.session_open(day)
    prev = closes[0]
    for c in closes:
        out.append(Bar(t, prev, max(prev, c) + spread, min(prev, c) - spread, c, volume))
        prev = c
        t += timedelta(minutes=bar_minutes)
    return out


def daily_history(day: date, days: int, close: float, volume: float = 50_000 * 78) -> list[Bar]:
    """Flat daily history ending the trading day before ``day``."""
    out = []
    d = day
    while len(out) < days:
        d -= timedelta(days=1)
        if clock.is_trading_day(d):
            out.append(Bar(clock.at(d, clock.MARKET_CLOSE), close, close + 1, close - 1, close, volume))
    out.reverse()
    return out


@pytest.fixture
def settings(tmp_path, monkeypatch):
    for k in list(__import__("os").environ):
        if k.startswith(("IB_", "T212_", "BROKER", "TELEGRAM_", "RISK_", "MAX_", "UNIVERSE", "DRY_RUN", "LIVE_")):
            monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv("DATA_DIR", str(tmp_path / "data"))
    return Settings.load(tmp_path / "nonexistent.env")


@pytest.fixture
def params():
    return StrategyParams()
