# Operating rules for Claude Code in `trading-bot/`

This folder is an autonomous trading bot that places real orders through
Trading 212 (default) or Interactive Brokers. Treat every change as one that
can lose money.

## Never
- Set `T212_ENV=live`, `ALPACA_ENV=live` or `IB_PORT` to a live port, remove the `LIVE_TRADING_ACK`
  check in `tradebot/config.py`, or weaken `Settings.validate()`.
- Remove or bypass: the kill-switch file, `MAX_POSITIONS`, `MAX_DAILY_LOSS_*`,
  the forced close at `FORCE_CLOSE_TIME`, or the protective stop placed after
  every entry (and re-placed after every partial).
- Enable shorts on Trading 212 (Invest/ISA accounts are long-only).
- Commit `.env`, `data/`, API keys or account numbers.
- Skip or weaken a test to get green.

## Always
- Run `python -m pytest tests -q` before finishing any change.
- The primary strategy is Trend Join Long, defined by `rules.json`; ORB lives in
  `strategy.json`. `STRATEGY_FILE` in `.env` selects one. Keep tunables in
  those files and re-run
  `python -m tradebot backtest` (real data from `fetch-data`, or `--demo`)
  after changing them; report trades, win rate, expectancy, profit factor, max DD in R.
- Keep the same code path for backtest and live: entry/exit rules live in
  `tradebot/strategy.py` and `tradebot/exits.py` only, and must stay pure
  (no I/O) so both the backtester and the live loop use them unchanged.
- Any new broker call goes through the `Broker` protocol in `tradebot/broker.py`
  and gets a `SimBroker` implementation too; new price sources implement
  `DataProvider` in `tradebot/marketdata.py`.
- Remember Trading 212's live API accepts market orders only: the software
  stop in `t212.py` is the only protection on live, so never weaken
  `_check_virtual_stop` or the per-poll stop check in `execution.py`.
- Respect Trading 212 rate limits: go through `T212Client.request` (throttled,
  429-aware); never call the REST API directly from the loop.

## Layout
| Module | Role |
|---|---|
| `config.py` | env settings + safety validation |
| `clock.py` | ET market hours, holidays |
| `marketdata.py` | `DataProvider` protocol, Yahoo Finance implementation |
| `alpaca.py` | Alpaca Market Data implementation (long 5-minute history) |
| `t212.py` | Trading 212 REST client + `Broker` implementation |
| `broker.py` | `Broker` protocol, IB implementation, in-memory `SimBroker` |
| `universe.py` | pre-market scan -> watchlist |
| `strategy.py` | ORB signals, `load_strategy()` factory, `LoadedStrategy` |
| `tjl.py` | Trend Join Long (gap-and-go) from `rules.json` |
| `crypto.py` | Crypto Momentum Breakout (24/7, continuous mode) from `crypto.json` |
| `alpaca_broker.py` | Alpaca trading API as a crypto broker + crypto data |
| `risk.py` | position size, daily limits, kill switch |
| `execution.py` | orders, partials, stop moves, state persistence |
| `exits.py` | partial / breakeven / trail / target / time / EOD rules |
| `loop.py` | the decision loop (`tick`) and real-time driver (`run`) |
| `backtest.py` | same pipeline on historical bars via `SimBroker` |
| `events.py` | whole-market gap events + 5-min range planning (`fetch-gappers`) |
| `journal.py` | trade JSONL + R-multiple stats |
| `telegram.py` | alerts |
| `dashboard.py` | self-contained HTML dashboard |
