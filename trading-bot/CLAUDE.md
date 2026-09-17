# Operating rules for Claude Code in `trading-bot/`

This folder is an autonomous trading bot that places real orders through
Interactive Brokers. Treat every change as one that can lose money.

## Never
- Change `IB_PORT` to a live port (7496 / 4001), remove the `LIVE_TRADING_ACK`
  check in `tradebot/config.py`, or weaken `Settings.validate()`.
- Remove or bypass: the kill-switch file, `MAX_POSITIONS`, `MAX_DAILY_LOSS_*`,
  the forced close at `FORCE_CLOSE_TIME`, or the hard stop attached to every entry.
- Commit `.env`, `data/`, API tokens or account numbers.
- Skip or weaken a test to get green.

## Always
- Run `python -m pytest tests -q` before finishing any change.
- Keep strategy tunables in `strategy.json` and re-run
  `python -m tradebot backtest` (with real data from `fetch-data`, or `--demo`)
  after changing them; report trades, win rate, expectancy, profit factor, max DD in R.
- Keep the same code path for backtest and live: entry/exit rules live in
  `tradebot/strategy.py` and `tradebot/exits.py` only, and must stay pure
  (no I/O) so both the backtester and the live loop use them unchanged.
- Any new broker call goes through the `Broker` protocol in `tradebot/broker.py`
  and gets a `SimBroker` implementation too.

## Layout
| Module | Role |
|---|---|
| `config.py` | env settings + safety validation |
| `clock.py` | ET market hours, holidays |
| `universe.py` | pre-market scan -> watchlist |
| `strategy.py` | signals (Opening Range Breakout) |
| `risk.py` | position size, daily limits, kill switch |
| `execution.py` | orders, partials, stop moves, state persistence |
| `exits.py` | partial / breakeven / trail / target / time / EOD rules |
| `loop.py` | the decision loop (`tick`) and real-time driver (`run`) |
| `backtest.py` | same pipeline on historical bars via `SimBroker` |
| `journal.py` | trade JSONL + R-multiple stats |
| `telegram.py` | alerts |
| `dashboard.py` | self-contained HTML dashboard |
