"""Paper CFD broker: lot rounding, long/short fills, stops, P&L, persistence, MT5 mirror alerts."""

from datetime import timedelta

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.execution import Executor, StateStore
from tradebot.journal import Journal
from tradebot.models import LONG, SHORT, Signal
from tradebot.paper import PaperBroker, parse_symbol_map


class FakeData:
    def __init__(self, price=4000.0):
        self.price = price

    def last_price(self, symbol):
        return self.price

    def intraday_bars(self, *a, **k):
        return []

    def daily_bars(self, *a, **k):
        return []


class Recorder:
    def __init__(self):
        self.msgs = []

    def send(self, text, silent=False):
        self.msgs.append((text, silent))
        return True


def make(settings, tmp_path, price=4000.0):
    settings.broker, settings.paper_equity = "paper", 10_000.0
    data = FakeData(price)
    b = PaperBroker(settings, data, tmp_path / "paper_account.json", fee_bps=0.0, stop_slippage_bps=0.0,
                    mt5_symbols=parse_symbol_map("XAU/USD=XAUUSD"))
    b.connect()
    return b, data


def test_lots_round_down_and_tiny_orders_are_skipped(settings, tmp_path):
    b, _ = make(settings, tmp_path)
    assert b.lots(1.75) == pytest.approx(0.01) and b.lots(250) == pytest.approx(2.5)
    entry, stop = b.place_entry_with_stop("XAU/USD", LONG, 0.5, 3900)  # half an ounce < 0.01 lot
    assert entry.status == "Cancelled" and b.positions() == []


def test_long_stop_and_short_close_realise_pnl_and_persist(settings, tmp_path):
    b, data = make(settings, tmp_path)
    entry, stop = b.place_entry_with_stop("XAU/USD", LONG, 2.4, 3950)  # rounds to 2 oz
    assert entry.filled == pytest.approx(2.0) and b.positions()[0].qty == pytest.approx(2.0)
    data.price = 4050
    assert b.net_liquidation() == pytest.approx(10_100)
    assert b.refresh(stop).status == "Submitted"
    data.price = 3940
    ref = b.refresh(stop)
    assert ref.status == "Filled" and b.positions() == [] and b.cash == pytest.approx(10_000 - 2 * 60)
    # short, partly closed at a profit, then restart: cash and the open remainder survive
    e2, s2 = b.place_entry_with_stop("XAU/USD", SHORT, 300, 4000)
    data.price = 3900
    b.market_close("XAU/USD", SHORT, 100)
    assert b.cash == pytest.approx(9_880 + 100 * 40) and b.positions()[0].qty == pytest.approx(-200)
    assert s2.qty == pytest.approx(200)
    b2, _ = make(settings, tmp_path, price=3900)
    assert b2.cash == pytest.approx(b.cash) and b2.positions()[0].qty == pytest.approx(-200)


def test_costs_apply_to_fills(settings, tmp_path):
    settings.broker = "paper"
    data = FakeData(4000.0)
    b = PaperBroker(settings, data, tmp_path / "p.json", fee_bps=1.5, stop_slippage_bps=3.0)
    b.connect()
    entry, stop = b.place_entry_with_stop("XAU/USD", SHORT, 100, 4100)
    assert entry.avg_fill == pytest.approx(4000 * (1 - 1.5e-4))  # selling pays the spread
    data.price = 4110
    assert b.refresh(stop).avg_fill == pytest.approx(4110 * (1 + 4.5e-4))  # buy-to-cover + slippage


def test_executor_alerts_carry_mt5_instructions(settings, tmp_path):
    b, data = make(settings, tmp_path)
    rec = Recorder()
    ex = Executor(b, Journal(tmp_path / "j.jsonl"), rec, StateStore(tmp_path / "s.json"))
    now = clock.at(DAY, clock.parse_hhmm("10:00"))
    sig = Signal(symbol="XAU/USD", side=SHORT, entry=4000.0, stop=4060.0, target=3820.0, atr=20.0, time=now,
                 reason="breakdown")
    t = ex.open_trade(sig, 150, now)
    entry_msg = rec.msgs[-1][0]
    assert "MT5: SELL 1.50 lot XAUUSD" in entry_msg and "60.00 above" in entry_msg
    from tradebot.exits import ExitAction, MOVE_STOP, CLOSE
    ex.apply(t, [ExitAction(MOVE_STOP, 0, 4000.0, "breakeven")], now + timedelta(hours=4))
    stop_msg, silent = rec.msgs[-1]
    assert "move XAUUSD stop loss" in stop_msg and not silent
    data.price = 3900
    ex.apply(t, [ExitAction(CLOSE, t.qty_open, 3900.0, "manual")], now + timedelta(hours=8))
    assert "CLOSED" in rec.msgs[-1][0] and "MT5: close the XAUUSD position" in rec.msgs[-1][0]
    assert t.r_multiple == pytest.approx(100 / 60, rel=1e-3)


def test_paper_settings_and_factory(settings, tmp_path, monkeypatch):
    from tradebot.config import Settings
    env = tmp_path / ".env"
    env.write_text("BROKER=paper\nSTRATEGY_FILE=strategies_cfd/gold_trend_4h.json\nPAPER_EQUITY=5000\n"
                   f"DATA_DIR={tmp_path}\nDATA_PROVIDER=yfinance\n")
    for k in ("BROKER", "STRATEGY_FILE", "PAPER_EQUITY", "DATA_DIR"):
        monkeypatch.delenv(k, raising=False)
    s = Settings.load(env)
    assert s.is_paper and s.paper_equity == 5000 and "virtual CFD account" in s.describe()
