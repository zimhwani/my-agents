from conftest import DAY
from tradebot.analyze import DEFAULT_GRID, breakdown, format_sweep, sweep
from tradebot.backtest import Backtester
from tradebot.data import synthetic_bars


def test_breakdown_and_sweep_on_synthetic(settings, params):
    bars = {s: synthetic_bars(s, 20, seed=i + 1, end=DAY) for i, s in enumerate(["AAA", "BBB"])}
    res = Backtester(settings, params, bars).run()
    text = breakdown(res.trades)
    for section in ("OVERALL", "BY EXIT PATH", "BY ENTRY TIME", "BY OPENING-RANGE WIDTH",
                    "BY RELATIVE VOLUME", "BY WEEKDAY", "DAYS:"):
        assert section in text
    assert breakdown([]) == "No closed trades."
    rows = sweep(settings, params, bars, {"min_rel_volume": [1.2, 5.0], "stop_atr_mult": [1.5]})
    assert len(rows) == 2 and rows[0]["expectancy"] >= rows[1]["expectancy"]
    assert all("trades" in r and "max_dd" in r for r in rows)
    out = format_sweep(rows)
    assert "min_rel_volume" in out and "maxDD" in out
    assert len(DEFAULT_GRID) >= 3
