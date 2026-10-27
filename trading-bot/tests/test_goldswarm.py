import json
from datetime import datetime, timezone

import pytest

from tradebot import goldswarm
from tradebot.__main__ import main
from tradebot.publish import BlobPublisher


def feed(**over):
    """A Gold Swarm feed as the lab writes it (times are MT5 server time = UTC)."""
    f = {
        "generated_utc": "2026-10-28 13:00:00", "data_through_utc": "2026-10-28 12:58:00",
        "last_bid": 4120.0, "last_spread_pts": 15.0, "account": {"server": "Deriv-Demo", "mode": "demo"},
        "chart": {"symbol": "XAUUSD", "bars": [["08:50", 4110, 4121, 4109, 4120, 300]], "last": 4120.0},
        "eas": {
            "GS_USOpen": {
                "trades": [
                    # yesterday 08:35 ET long: +20.75 on a $50 stop -> +0.415R
                    {"open_srv": "2026-10-27 12:35:01", "dir": 1, "fill": 4101.35, "dist": 50.0, "lots": 0.01,
                     "risk_usd": 50.0, "close_srv": "2026-10-27 16:00:02", "exit": 4122.10, "reason": "ea",
                     "profit": 20.75, "swap": 0.0, "R": 0.415},
                    # today: short stopped out, -1.006R, -$50.30
                    {"open_srv": "2026-10-28 12:35:01", "dir": -1, "fill": 4117.90, "dist": 50.0, "lots": 0.01,
                     "risk_usd": 50.0, "close_srv": "2026-10-28 12:50:44", "exit": 4168.20, "reason": "sl",
                     "profit": -50.30, "swap": 0.0, "R": -1.006},
                ],
                "open": None, "halted": False, "alerts": {"OPEN_FAIL": 1},
                "decisions": [{"srv": "2026-10-28 12:35:01", "event": "SIGNAL", "detail": "dir=-1 move=-1.20"},
                              {"srv": "2026-10-28 12:35:02", "event": "OPEN_FAIL", "detail": "ret=10027"}],
                "lab_check": {"summary": "GS_USOpen: 2 decision days, 2 match the lab, 0 mismatch",
                              "issues": [], "checked": 2, "matched": 2},
            },
            "GS_Trend": {
                "trades": [],
                "open": {"open_srv": "2026-10-28 08:00:01", "dir": 1, "fill": 4100.00, "sl": 4080.00, "dist": 40.0,
                         "lots": 0.02, "mark": 4120.0, "floatR": 0.5},
                "halted": False, "alerts": {},
                "decisions": [{"srv": "2026-10-28 08:00:00", "event": "BAR", "detail": "sig=+1 flat=yes"}],
                "lab_check": {"summary": "GS_Trend: 3 H4 decisions, 2 match the lab, 1 mismatch",
                              "issues": ["  MISMATCH ..."], "checked": 3, "matched": 2},
            },
        },
    }
    f.update(over)
    return f


NOW = datetime(2026, 10, 28, 13, 0, tzinfo=timezone.utc)   # 09:00 ET, Wednesday


def test_trades_doc_rows_and_stats():
    doc = goldswarm.trades_doc(feed())
    rows = doc["rows"]
    assert [r["n"] for r in rows] == [1, 2]
    a, b = rows
    assert a["symbol"] == "XAUUSD·USOpen" and a["side"] == "LONG" and a["qty"] == 0.01
    assert a["date"] == "2026-10-27" and a["entry_time"] == "08:35" and a["exit_time"] == "12:00"   # ET (EDT)
    assert a["stop"] == pytest.approx(4051.35)          # initial stop = fill - dist, not a trailed stop
    assert a["r"] == pytest.approx(0.415, abs=0.006) and a["pnl"] == pytest.approx(20.75)
    assert b["side"] == "SHORT" and b["stop"] == pytest.approx(4167.90) and b["r"] == pytest.approx(-1.01)
    assert b["exits"].startswith("sl ")
    assert doc["stats"]["trades"] == 2 and doc["stats"]["total_r"] == pytest.approx(-0.59, abs=0.011)
    assert all(not k.startswith("_") for r in rows for k in r)   # internal fields never published


def test_r_and_pnl_fall_back_to_prices_when_the_log_lacks_them():
    f = feed()
    t = f["eas"]["GS_USOpen"]["trades"][0]
    t.pop("R"), t.pop("profit")
    row = goldswarm.trades_doc(f)["rows"][0]
    assert row["r"] == pytest.approx(round((4122.10 - 4101.35) / 50.0, 2))
    assert row["pnl"] == pytest.approx(round(20.75 * 0.01 * 100, 2))


def test_live_doc_equity_today_and_open_position():
    L = goldswarm.live_doc(feed(), start_equity=10_000.0, now=NOW)
    # realised: +20.75 (yesterday) - 50.30 (today); open trend long 0.02 lots, +20 $/oz -> +$40
    assert L["equity"] == pytest.approx(10_000 + 20.75 - 50.30 + 40.0)
    assert L["day_start_equity"] == pytest.approx(10_000 + 20.75)
    assert L["closed_today"] == 1 and L["realized_r"] == pytest.approx(-1.01)
    (o,) = L["open"]
    assert o["symbol"] == "XAUUSD·Trend" and o["pnl"] == pytest.approx(40.0) and o["r"] == pytest.approx(0.5)
    assert o["stop"] == pytest.approx(4080.0) and o["entry_time"] == "04:00"
    assert L["mode"].split(" ")[0] == "demo"              # the page shows the first word
    assert {w["symbol"] for w in L["watchlist"]} == {"XAUUSD·USOpen", "XAUUSD·Trend"}
    assert L["chart"]["symbol"] == "XAUUSD"


def test_live_doc_surfaces_alerts_mismatches_and_errors():
    L = goldswarm.live_doc(feed(), now=NOW)
    assert "USOpen: 1x OPEN_FAIL" in L["blockers"]
    assert any("Trend: 1 decision(s) differ from the lab" in b for b in L["blockers"])
    assert any(" E [USOpen] OPEN_FAIL" in line for line in L["log"])
    assert any(" I [Trend] BAR" in line for line in L["log"])
    # every log line matches the page's /^(\S+)\s+([IWE])\s+(.*)$/ shape
    import re
    assert all(re.match(r"^(\S+)\s+([IWE])\s+(.*)$", line) for line in L["log"])


def test_live_doc_flags_stale_mt5_data_on_weekdays():
    L = goldswarm.live_doc(feed(data_through_utc="2026-10-28 08:00:00"), now=NOW)
    assert any("MT5 price data" in b for b in L["blockers"])
    fresh = goldswarm.live_doc(feed(), now=NOW)
    assert not any("MT5 price data" in b for b in fresh["blockers"])


class FakeBlob:
    def __init__(self):
        self.store = {}

    def __call__(self, method, url, headers, body):
        assert headers["authorization"] == "Bearer TOK"
        name = url.split("blob.vercel-storage.com/")[1]
        self.store[name] = json.loads(body)
        return 200, json.dumps({"url": f"https://s.public.blob.vercel-storage.com/{name}"}).encode()


def test_publish_uploads_both_documents_under_the_prefix():
    fake = FakeBlob()
    pub = BlobPublisher("TOK", "gold", transport=fake)
    assert goldswarm.publish(feed(), pub, now=NOW) == (True, True)
    assert set(fake.store) == {"gold/live.json", "gold/trades.json"}
    assert fake.store["gold/live.json"]["strategy"] == "Gold Swarm · MT5 EAs"
    assert len(fake.store["gold/trades.json"]["rows"]) == 2


def test_cli_refuses_a_file_that_is_not_a_feed(tmp_path):
    env = tmp_path / ".env.gold"
    env.write_text("BROKER=paper\nSTRATEGY_FILE=strategies_cfd/gold_trend_4h.json\nVERCEL_BLOB_PREFIX=gold\n")
    bad = tmp_path / "feed.json"
    bad.write_text(json.dumps({"rows": []}))
    with pytest.raises(SystemExit) as e:
        main(["--env", str(env), "goldswarm-publish", "--feed", str(bad)])
    assert e.value.code == 2
    with pytest.raises(SystemExit) as e:
        main(["--env", str(env), "goldswarm-publish", "--feed", str(tmp_path / "missing.json")])
    assert e.value.code == 2
