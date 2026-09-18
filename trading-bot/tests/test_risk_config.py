import os

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.config import LIVE_ACK, Settings, UnsafeConfig, load_dotenv
from tradebot.models import LONG, TradeRecord
from tradebot.risk import DayStats, RiskGate, position_size


def test_position_size_respects_risk_and_size_caps():
    # $100k, 0.5% = $500 risk, $1 per share -> 500 shares, but cap $250 -> 250
    assert position_size(100_000, 100, 99, 0.5, 250, 25) == 250
    # size cap: 25% of 10k = 2500 / 100 = 25 shares
    assert position_size(10_000, 100, 99, 0.5, 10_000, 25) == 25
    assert position_size(100_000, 100, 100, 0.5, 250, 25) == 0
    assert position_size(0, 100, 99, 0.5, 250, 25) == 0


def test_risk_gate_blockers(settings):
    gate = RiskGate(settings)
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    day = DayStats(start_equity=100_000)
    assert gate.blockers([], day, 100_000, now) == []
    settings.kill_switch_file.write_text("x")
    assert any("kill switch" in b for b in gate.blockers([], day, 100_000, now))
    settings.kill_switch_file.unlink()
    day.realized_r = -3.5
    assert any("daily loss" in b for b in gate.blockers([], day, 100_000, now))
    day.realized_r = 0
    assert any("drawdown" in b for b in gate.blockers([], day, 97_000, now))
    trades = [TradeRecord(id=str(i), symbol="A", side=LONG, qty_initial=1, entry_price=1,
                          entry_time=now, stop_initial=0.5, stop=0.5, target=2, atr=0.1) for i in range(3)]
    assert any("max positions" in b for b in gate.blockers(trades, day, 100_000, now))
    assert any("force-close" in b for b in gate.blockers([], day, 100_000, clock.at(DAY, clock.parse_hhmm("15:55"))))


def test_t212_live_refused_without_ack(tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    monkeypatch.setenv("BROKER", "t212")
    monkeypatch.setenv("T212_ENV", "live")
    monkeypatch.delenv("LIVE_TRADING_ACK", raising=False)
    with pytest.raises(UnsafeConfig):
        Settings.load(tmp_path / "none.env")
    monkeypatch.setenv("T212_ENV", "demo")
    s = Settings.load(tmp_path / "none.env")
    assert s.is_paper and "Trading 212 demo" in s.describe()
    monkeypatch.setenv("ALLOW_SHORTS", "true")
    with pytest.raises(UnsafeConfig):  # long-only broker
        Settings.load(tmp_path / "none.env")


def test_live_port_refused_without_ack(tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    monkeypatch.setenv("BROKER", "ib")
    monkeypatch.setenv("IB_PORT", "7496")
    monkeypatch.delenv("LIVE_TRADING_ACK", raising=False)
    with pytest.raises(UnsafeConfig):
        Settings.load(tmp_path / "none.env")
    monkeypatch.setenv("LIVE_TRADING_ACK", LIVE_ACK)
    s = Settings.load(tmp_path / "none.env")
    assert not s.is_paper and "LIVE" in s.describe()


def test_dotenv_and_limits(tmp_path, monkeypatch):
    env = tmp_path / ".env"
    env.write_text("BROKER=ib\nIB_PORT=4002\nRISK_PER_TRADE_PCT=1.0  # comment\n# ignored\nUNIVERSE=aapl, msft\n")
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    for k in ("BROKER", "IB_PORT", "RISK_PER_TRADE_PCT", "UNIVERSE"):
        monkeypatch.delenv(k, raising=False)
    s = Settings.load(env)
    assert s.ib_port == 4002 and s.is_paper
    assert s.risk_per_trade_pct == 1.0
    assert s.universe == ["AAPL", "MSFT"]
    monkeypatch.setenv("RISK_PER_TRADE_PCT", "5")
    with pytest.raises(UnsafeConfig):
        Settings.load(env)
