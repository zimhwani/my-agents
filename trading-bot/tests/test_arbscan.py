"""Cross-venue spread book: spreads, fee netting, windows and dislocations (offline)."""

from tradebot.arbscan import SpreadBook


def test_best_spread_is_net_of_both_fees_and_picks_best_pair():
    b = SpreadBook(fees_bps={"alpaca": 25.0, "coinbase": 60.0, "kraken": 40.0})
    b.update("alpaca", "BTC/USD", 100_000, 100_010, ts=1000)
    b.update("coinbase", "BTC/USD", 100_400, 100_410, ts=1000)  # 0.39% above alpaca's ask
    b.update("kraken", "BTC/USD", 100_100, 100_110, ts=1000)
    bv, sv, gross, net = b.best_spread("BTC/USD", now=1000)
    assert (bv, sv) == ("alpaca", "coinbase")
    assert abs(gross - (100_400 - 100_010) / 100_010 * 100) < 1e-9
    assert abs(net - (gross - 0.85)) < 1e-9  # 25 + 60 bps
    assert net < 0  # a 0.39% gap does not pay after fees


def test_stale_quotes_are_ignored():
    b = SpreadBook(stale_seconds=5)
    b.update("alpaca", "ETH/USD", 3000, 3001, ts=1000)
    b.update("kraken", "ETH/USD", 3100, 3101, ts=990)  # 10s old
    assert b.best_spread("ETH/USD", now=1000) is None


def test_windows_open_and_close_and_report():
    b = SpreadBook(fees_bps={"a": 10.0, "b": 10.0}, dislocation_pct=0.5)
    # second 1-3: b bids 1% over a's ask -> positive net window
    for t in (1, 2, 3):
        b.update("a", "SOL/USD", 100.0, 100.1, ts=t)
        b.update("b", "SOL/USD", 101.2, 101.3, ts=t)
        assert b.tick(now=t) == []
    assert b.positive_seconds["SOL/USD"] == 3 and len(b.open_windows) == 1
    # second 4: gap gone -> window closes with 3s duration
    b.update("b", "SOL/USD", 100.0, 100.1, ts=4)
    done = b.tick(now=4)
    assert len(done) == 1 and done[0].seconds == 3 and done[0].buy_venue == "a" and done[0].sell_venue == "b"
    assert done[0].max_net_pct > 0.8
    rep = b.report()
    assert "SOL/USD" in rep and "windows closed: 1" in rep


def test_dislocation_detects_one_venue_off_the_others():
    b = SpreadBook(dislocation_pct=0.5)
    b.update("a", "DOGE/USD", 0.1000, 0.1001, ts=1)
    b.update("b", "DOGE/USD", 0.1000, 0.1001, ts=1)
    b.update("c", "DOGE/USD", 0.1010, 0.1011, ts=1)  # ~1% high
    assert b.dislocated("DOGE/USD", now=1) == "c"
    b.update("c", "DOGE/USD", 0.1001, 0.1002, ts=1)
    assert b.dislocated("DOGE/USD", now=1) is None
