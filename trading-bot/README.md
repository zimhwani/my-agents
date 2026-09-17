# IB Autonomous Trading Bot

A hands-off intraday trading pipeline for **Interactive Brokers** that scans a
universe before the open, takes its own entries, manages its own stops, takes
partials, trails winners, force-closes everything before the bell, sends
**Telegram** status every 30 minutes, and tracks every trade in **R multiples**
on a dashboard.

```
universe scan  →  decision loop  →  execution  →  exit logic  →  journal
   (pre-mkt)      (every 30 s)      (IB orders)   (partials,      (R multiples,
                                                   trail, EOD)    dashboard,
                                                                  Telegram)
```

Everything except the broker socket is standard-library Python and runs
offline, so the backtest, dashboard and tests work before you ever connect TWS.

> **Paper first.** The bot refuses to connect to a live port unless you set an
> explicit acknowledgement, and it should run clean on paper for weeks before
> that ever happens.

---

## 1. Prerequisites

1. **Trader Workstation (TWS)** from Interactive Brokers, logged into a
   **paper trading** account (free; works without market data subscriptions
   using delayed data).
2. **Python 3.11+** (3.12 recommended).
3. In TWS: **File → Global Configuration → API → Settings**
   - ✅ *Enable ActiveX and Socket Clients*
   - ❌ *Read-Only API* — must be **unchecked** so the bot can place orders
   - *Socket port*: **7497** (paper). Live is 7496 — leave it on paper.
   - *Trusted IPs*: add **127.0.0.1**
   - Apply → OK. You can minimise TWS after that; it just has to stay open.

## 2. Install

```bash
cd trading-bot
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                   # then edit .env
```

## 3. Connect Claude Code (or you) to the broker, safely

```bash
python -m tradebot check
```

prints the account (paper accounts start with `DU`), net liquidation, open
positions and a sample price. What keeps this safe:

| Guard | Where |
|---|---|
| Live ports refused unless `LIVE_TRADING_ACK=I_UNDERSTAND_LIVE_TRADING` | `config.py` |
| Paper port must be paired with a `DU…` account | `broker.py` |
| Every entry is sent with an attached hard stop in one transmit chain | `broker.py` |
| Risk per trade, dollar cap, position cap, max positions, daily loss in R and % | `.env`, `risk.py` |
| Kill switch: `python -m tradebot kill` blocks new entries; `flatten` closes all | `__main__.py` |
| Forced flat at `FORCE_CLOSE_TIME` (15:50 ET) and at any restart mismatch | `loop.py`, `execution.py` |
| `DRY_RUN=true` logs orders instead of sending them | `.env` |

`CLAUDE.md` in this folder tells Claude Code what it may never change.

## 4. Create your strategy (with Claude)

The shipped strategy is an **Opening Range Breakout** with VWAP, relative
volume and 20-day trend filters. All tunables are in `strategy.json`; the code
is `tradebot/strategy.py` (signals) and `tradebot/exits.py` (management).

Prompts you can paste into Claude Code inside this folder:

```
Read strategy.json and tradebot/strategy.py. Explain the entry rules in plain
English, then list which parameters most affect trade frequency.
```
```
Change the strategy to a 30-minute opening range and require relative volume
of 1.5. Update strategy.json only, then run the backtest on data/bars and
report trades, win rate, expectancy and max drawdown in R before and after.
```
```
Implement a new strategy class in tradebot/strategy.py: pullback to the 9 EMA
on the 5-minute chart in the direction of the 20-day trend, stop below the
pullback low, 2R target. Keep the same evaluate() signature, wire it into
build_strategy() behind a "strategy" key in strategy.json, add tests, and
backtest it.
```

Get history and backtest (the backtester runs the *same* strategy, exit and
execution code as live, against an in-memory broker):

```bash
python -m tradebot fetch-data --days 30            # 5-min bars → data/bars/*.csv (needs TWS)
python -m tradebot backtest                         # → data/backtest_dashboard.html
python -m tradebot backtest --demo                  # synthetic data, no TWS needed
```

## 5. Run the pipeline

```bash
python -m tradebot scan          # pre-market universe scan → watchlist
python -m tradebot run           # the full day: scan, trade, manage, close, report
```

What `run` does, in order:

1. **Universe scan** (`universe.py`): from `UNIVERSE`, keep names in the price
   band with enough dollar volume and ATR, rank by volatility and gap, keep
   the top `MAX_WATCHLIST`. Telegram gets the watchlist.
2. **Decision loop** (`loop.py`), every `POLL_SECONDS`: refresh bars once per
   completed 5-minute bar (respecting IB pacing), check for stop fills, run
   the exit manager on open trades, then look for new entries inside the
   entry window if the risk gate allows.
3. **Execution** (`execution.py`): size by risk, send a market entry with an
   attached GTC stop, wait for the fill, journal it, alert Telegram.
4. **Exit logic** (`exits.py`): at +1R sell half and move the stop to
   breakeven; trail the rest 1.5 ATR off the high; hard target at +3R; time
   stop if the trade hasn't worked in 2 hours; **flat by 15:50 ET** no matter what.
5. **Daily summary** to Telegram and a rebuilt dashboard.

State is saved to `data/state.json` after every change, so if the bot (or
your PC) restarts mid-session it re-attaches to its open trades and stop orders,
and re-places any stop the broker no longer has.

Emergency controls:

```bash
python -m tradebot kill            # no new entries (open trades still managed)
python -m tradebot kill --resume
python -m tradebot flatten         # cancel everything and close all positions now
```

## 6. Telegram alerts

1. Message **@BotFather** → `/newbot` → copy the token into `TELEGRAM_BOT_TOKEN`.
2. Send your new bot any message, then open
   `https://api.telegram.org/bot<TOKEN>/getUpdates` and copy `chat.id` into
   `TELEGRAM_CHAT_ID`.
3. `python -m tradebot telegram-test`

You get: bot online/offline, the watchlist, every entry, partial, stop move
and exit (with R), a status report every `TELEGRAM_STATUS_MINUTES` (30) with
open positions and today's R, a daily summary, and any errors.

## 7. Dashboard (R multiples per trade)

```bash
python -m tradebot dashboard            # → data/dashboard.html
python -m tradebot dashboard --serve    # http://127.0.0.1:8765/dashboard.html
```

Self-contained HTML (no internet needed): stat tiles (trades, win rate, total
R, expectancy, profit factor, max drawdown in R), R-per-trade bars with hover
detail, a cumulative-R curve, and a filterable trade table. Light and dark
mode. **1R = the dollars risked from entry to the initial stop**, so a full
stop-out is −1R regardless of share count.

## 8. Run it every day, hands off

The loop waits for the open and exits after the close, so schedule it once
per weekday shortly before 09:30 ET (TWS must already be logged in — enable
auto-restart in TWS settings so its daily restart doesn't need you):

- **Windows** Task Scheduler: action `python -m tradebot run`, start in the
  `trading-bot` folder, trigger weekdays 09:00 (your local equivalent).
- **macOS / Linux** cron: `0 9 * * 1-5 cd /path/to/trading-bot && .venv/bin/python -m tradebot run >> data/cron.log 2>&1`
  (adjust for your timezone; the bot itself always thinks in ET).

## 9. Going live (only after weeks of clean paper results)

1. Review `data/dashboard.html` and `data/trades.jsonl`: is expectancy
   positive, is drawdown tolerable, did every day end flat?
2. In TWS switch to the live login and set the API port to 7496.
3. In `.env`: `IB_PORT=7496` and `LIVE_TRADING_ACK=I_UNDERSTAND_LIVE_TRADING`.
4. Start with `RISK_PER_TRADE_PCT=0.25` and `MAX_POSITIONS=1`.

## Configuration reference

See `.env.example` — every setting is documented inline. Risk defaults:
0.5% of equity per trade, $250 hard cap, 25% max position, 3 positions,
stop trading after −3R or −2% on the day.

## Tests

```bash
python -m pytest tests -q
```

Covers the strategy, exit rules, sizing and gates, the live-port refusal, the
journal maths, the backtester, the executor on the simulated broker, restart
recovery, and a full scripted trading day through the real `TradingLoop`.

## Disclaimer

This is software, not advice. Markets can move through stops, brokers can
reject orders, connections drop. Paper trade first; risk only what you can lose.
