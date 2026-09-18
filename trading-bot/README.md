# Autonomous Trading Bot (Trading 212 / Interactive Brokers)

A hands-off intraday trading pipeline for **Trading 212** (default) or
**Interactive Brokers** that scans a universe before the open, takes its own
entries, manages its own stops, takes partials, trails winners, force-closes
everything before the bell, sends **Telegram** status every 30 minutes, and
tracks every trade in **R multiples** on a dashboard.

```
universe scan  →  decision loop  →  execution  →  exit logic  →  journal
   (pre-mkt)      (every 30 s)      (IB orders)   (partials,      (R multiples,
                                                   trail, EOD)    dashboard,
                                                                  Telegram)
```

Everything except the broker HTTP calls is standard-library Python and runs
offline, so the backtest, dashboard and tests work before you ever connect an
account.

> **Practice first.** The bot refuses a live account unless you set an explicit
> acknowledgement, and it should run clean on the practice account for weeks
> before that ever happens.

---

## 1. Prerequisites (Trading 212)

1. A **Trading 212 Invest** account with **Practice mode** enabled (the free
   virtual-money account; that is the paper-trading equivalent).
2. **Python 3.11+** (3.12 recommended). On a Mac the built-in `python3` is
   often older: `brew install python@3.12` and use `python3.12` below.
3. API credentials. In the app: switch to **Practice** → **Settings → API →
   Generate API key**. Tick the scopes *account*, *portfolio*, *orders (read)*
   and **orders (execute)** — without execute the bot cannot trade. You get an
   **API key** and an **API secret**; copy both, they are only shown once. Keys
   made in Practice mode only work on the practice account
   (`demo.trading212.com`), which is exactly what we want.
4. Trading 212 specifics the bot already handles (so you know why it behaves as
   it does):
   - **No price feed in the API** → bars and quotes come from Yahoo Finance
     (`yfinance`) by default, or from **Alpaca** (`DATA_PROVIDER=alpaca`, free
     plan, years of 5-minute history, see below). Swap in another source by
     implementing `DataProvider` in `tradebot/marketdata.py`.
   - **No bracket orders, no order editing**, and the **live API accepts market
     orders only**. So the protective stop lives in the bot
     (`T212_STOP_MODE=software`, the default): each poll compares the last
     price with the stop and sells at market the moment it is crossed. On the
     practice account you can also try `T212_STOP_MODE=broker`, which rests
     real GTC stop orders, but live cannot do that, so practice defaults to
     software too so that what you test is what you will run.
   - **Long only**, whole-share sizing, and per-endpoint **rate limits** (the
     client throttles itself and backs off on 429).
   - CFD accounts are not supported by Trading 212's API; use Invest or ISA.

<details>
<summary>Using Interactive Brokers instead</summary>

Set `BROKER=ib` in `.env` and `pip install -r requirements-ib.txt`. Run Trader Workstation logged into a **paper**
account and in **File → Global Configuration → API → Settings**: enable
*ActiveX and Socket Clients*, **uncheck** *Read-Only API*, socket port **7497**
(paper), trusted IP **127.0.0.1**, Apply → OK. IB supplies its own market data
and supports attached stops and order modification, which `tradebot/broker.py`
uses directly.
</details>

## 2. Install

```bash
cd trading-bot
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                   # paste T212_API_KEY + T212_API_SECRET, keep T212_ENV=demo
```

## 3. Connect Claude Code (or you) to the broker, safely

```bash
python -m tradebot check
```

prints the account id and currency, equity converted to `TRADING_CURRENCY`,
open positions, any `UNIVERSE` symbols that are not tradable on your account,
and a sample price from the data provider. What keeps this safe:

| Guard | Where |
|---|---|
| `T212_ENV=live` (or an IB live port) refused unless `LIVE_TRADING_ACK=I_UNDERSTAND_LIVE_TRADING` | `config.py` |
| Shorts rejected on Trading 212 | `config.py`, `t212.py` |
| A protective stop (software or broker) is armed right after every fill; if a broker stop is rejected the position is closed immediately | `t212.py` |
| Risk per trade, dollar cap, position cap, max positions, daily loss in R and % | `.env`, `risk.py` |
| Kill switch: `python -m tradebot kill` blocks new entries; `flatten` closes all | `__main__.py` |
| Forced flat at `FORCE_CLOSE_TIME` (15:50 ET) and at any restart mismatch | `loop.py`, `execution.py` |
| `DRY_RUN=true` logs orders instead of sending them | `.env` |

`CLAUDE.md` in this folder tells Claude Code what it may never change.

## 4. The strategy (and how to change it with Claude)

Two strategies ship. `STRATEGY_FILE` in `.env` picks one; both run through the
same scan → loop → execution → exit → journal pipeline.

**Trend Join Long** (`rules.json`, the default). Gap-and-go momentum continuation:

| | Rule |
|---|---|
| Universe | any US stock, market cap ≥ $1B, price ≥ $3 (Yahoo screener after the open, `universe_broad.txt` as fallback) |
| Daily | today gapped ≥ 3% above the prior close; prior close above the 200-day SMA; price above the prior day's high |
| Intraday | price above the premarket high; a 5-minute bar closes at a **new high of day** (the trigger); relative volume ≥ 2.0 vs the same time of day over 14 sessions |
| Time | entries 10:05–15:30 ET, everything flat at 15:51 |
| Stop | low of day − 1% |
| Management | a third off at +0.75R; stop to breakeven at +1R; then trail under confirmed 5-minute swing lows (2 bars each side); no fixed target |
| Risk | 1% per trade, 10% of equity per position, 5 positions (these override `.env`) |
| Optional | `max_initial_risk_pct` in the `exit` block caps the entry→stop distance as a % of price, with `max_initial_risk_mode` = `skip` (don't take the trade) or `cap` (tighten the stop). Off by default; `python -m tradebot sweep` grids it. |

**Opening Range Breakout** (`strategy.json`). Buy the first 5-minute close
above the 15-minute opening range, above VWAP, with elevated volume, in
names above their 20-day EMA. Half off at +1R, breakeven, ATR trail, +3R
target, time stop, flat at 15:50. Its numbers are tunable and `sweep` will
grid-search them.

Prompts you can paste into Claude Code inside this folder:

```
Read rules.json and tradebot/tjl.py. Explain the entry rules in plain English
and list which rule rejects most candidates in the last backtest (use
`python -m tradebot analyze`).
```
```
Change the partial to half off at +1R in rules.json, re-run
`python -m tradebot backtest`, and report trades, win rate, expectancy,
profit factor and max drawdown in R before and after.
```
```
Add a filter to Trend Join Long: skip entries where the stop is more than 6%
below the entry. Implement it in tradebot/tjl.py behind a new rules.json key,
add a test in tests/test_tjl.py, and backtest it.
```

**Longer history with Alpaca.** Yahoo only keeps ~60 days of 5-minute bars,
which is too little to judge a selective strategy. Alpaca's free plan serves
years of 5-minute bars from the IEX feed (plus real-time IEX quotes):

1. Create a free account at https://alpaca.markets, open the paper-trading
   dashboard and generate API keys (they are used for data only; the bot never
   sends Alpaca an order).
2. In `.env`: `DATA_PROVIDER=alpaca`, `ALPACA_API_KEY=...`, `ALPACA_API_SECRET=...`.
3. `python -m tradebot fetch-data --days 400` then `python -m tradebot backtest`.

Alpaca has no FX rates or market caps, so the bot still uses Yahoo for those.

Get history and backtest (the backtester runs the *same* strategy, exit and
execution code as live, against an in-memory broker):

```bash
python -m tradebot fetch-data --days 55            # 5-min bars incl. premarket + 2y daily → data/bars/
python -m tradebot backtest                         # Trend Join Long → data/backtest_dashboard.html
python -m tradebot backtest --strategy strategy.json   # the ORB for comparison
python -m tradebot analyze                          # where the R came from
python -m tradebot backtest --demo                  # synthetic data, no account needed
```

## 5. Run the pipeline

```bash
python -m tradebot scan          # pre-market universe scan → watchlist
python -m tradebot run           # the full day: scan, trade, manage, close, report
```

What `run` does, in order:

1. **Scan** (`universe.py`): Trend Join Long scans at 09:36 ET for stocks
   gapping 3%+ with market cap ≥ $1B and price ≥ $3 (Yahoo screener, or the
   static list if the screener is down), keeps the top `MAX_WATCHLIST` by gap
   size, and drops anything your broker can't trade. ORB scans pre-market for
   volatile, liquid names. Telegram gets the watchlist.
2. **Decision loop** (`loop.py`), every `POLL_SECONDS`: refresh bars once per
   completed 5-minute bar (respecting IB pacing), check for stop fills, run
   the exit manager on open trades, then look for new entries inside the
   entry window if the risk gate allows.
3. **Execution** (`execution.py`): size by risk, send a market entry, wait for
   the fill, place the GTC protective stop, journal it, alert Telegram.
4. **Exit logic** (`exits.py`): the strategy's rule set (partial, breakeven,
   swing-low or ATR trail, optional target and time stop) and **flat before
   the close** no matter what (15:51 for Trend Join Long, 15:50 for ORB).
5. **Daily summary** to Telegram and a rebuilt dashboard.

State is saved to `data/state.json` after every change, so if the bot (or
your PC) restarts mid-session it re-attaches to its open trades and stop orders,
and re-places any stop the broker no longer has.

Because the account may be in GBP or EUR while the universe trades in USD,
equity is converted into `TRADING_CURRENCY` with the provider's FX rate before
sizing, so "0.5% risk" means the same thing whatever your base currency.

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

## 8. Run it on a server (DigitalOcean droplet)

The bot is a single Python process with no GUI, so a $6 droplet is ideal:
always on, no laptop to keep awake, and a systemd timer starts each session
before the US open. `deploy/` has everything:

```bash
# on a fresh Ubuntu droplet, as root
git clone --branch claude/magical-allen-jan8gi https://github.com/zimhwani/my-agents.git /opt/my-agents
bash /opt/my-agents/trading-bot/deploy/setup-droplet.sh
```

Then from your Mac copy the `.env` you already have (keys never go through git):

```bash
scp trading-bot/.env root@YOUR_DROPLET_IP:/opt/my-agents/trading-bot/.env
ssh root@YOUR_DROPLET_IP "chown tradebot:tradebot /opt/my-agents/trading-bot/.env && chmod 600 /opt/my-agents/trading-bot/.env && cd /opt/my-agents/trading-bot && sudo -u tradebot .venv/bin/python -m tradebot check && systemctl start tradebot-dashboard"
```

What the setup installs:

| Unit | Does |
|---|---|
| `tradebot.timer` | starts `tradebot.service` Mon–Fri at 09:00 New York time (DST-aware) |
| `tradebot.service` | `python -m tradebot run`; exits after the close; restarts and re-attaches to open trades if it crashes mid-session |
| `tradebot-dashboard.service` | serves the dashboard on `127.0.0.1:8765` (never exposed to the internet) |

Day-to-day:

```bash
systemctl list-timers tradebot.timer      # when the next session starts
systemctl start tradebot                  # start today's session by hand
journalctl -u tradebot -f                 # live log
sudo -u tradebot /opt/my-agents/trading-bot/.venv/bin/python -m tradebot kill      # from /opt/my-agents/trading-bot
sudo -u tradebot /opt/my-agents/trading-bot/.venv/bin/python -m tradebot flatten
cd /opt/my-agents && git pull && systemctl restart tradebot-dashboard             # update
```

To view the dashboard, tunnel it rather than opening a port:

```bash
ssh -L 8765:127.0.0.1:8765 root@YOUR_DROPLET_IP
# then open http://127.0.0.1:8765/dashboard.html on your Mac
```

The **Live** panel at the top of the dashboard appears when the bot is
running (it reads `data/live.json`, refreshed every tick): equity and today's
R, each open position with its stop, last price and open R, the watchlist,
and anything currently blocking new entries. The rest of the page is rebuilt
every time a trade closes.

## 9. Host the dashboard on Vercel

The dashboard can also live at a public URL so you can check it from your
phone without an SSH tunnel. The page on Vercel is a static shell; the bot on
the droplet uploads `live.json` (every tick) and `trades.json` (every close)
to **Vercel Blob** storage, and the page reads them from there.

1. In Vercel: create a project (any name), then **Storage → Blob → Create**
   and copy the read/write token. Put it in the droplet's `.env` as
   `VERCEL_BLOB_TOKEN=...`.
2. On the droplet, publish once to learn the store's public URL:

   ```bash
   cd /opt/my-agents/trading-bot && sudo -u tradebot .venv/bin/python -m tradebot dashboard --publish
   ```

   It prints `DASHBOARD_DATA_URL=https://....public.blob.vercel-storage.com/tradebot`.
   Add that line to `.env` on the droplet **and** on your Mac.
3. On your Mac, generate the hosted page, commit it, and push:

   ```bash
   python -m tradebot dashboard --export-vercel deploy/trading-dashboard
   git add deploy/trading-dashboard && git commit -m "Dashboard config" && git push
   ```

   Then deploy the same way the other sites in this repo deploy
   (see `deploy/trading-dashboard/README.md`): **Path A**, Vercel → Add New →
   Project → import this repo → Root Directory = `trading-bot/deploy/trading-dashboard`
   (no secrets, auto-deploys on every push); or **Path B**, add `VERCEL_TOKEN`
   and `VERCEL_ORG_ID` as GitHub secrets and `.github/workflows/dashboard-deploy.yml`
   deploys on push; or **Path C**, `cd deploy/trading-dashboard && vercel deploy --prod`.
4. Restart the bot's services on the droplet so they pick up the token:
   `systemctl restart tradebot-dashboard` (the trading service reads `.env` at its next start).

The hosted page shows practice trades only and contains no keys, but it is
public unless you enable Vercel's deployment protection. Free Blob storage is
plenty: two small JSON files, rewritten in place.

## 10. Run it every day on your own machine instead

The loop waits for the open and exits after the close, so schedule it once
per weekday shortly before 09:30 ET (14:30 London / 15:30 Paris in summer).
With Trading 212 nothing else needs to be running; with IB, TWS must already be
logged in (enable its auto-restart):

- **Windows** Task Scheduler: action `python -m tradebot run`, start in the
  `trading-bot` folder, trigger weekdays 09:00 (your local equivalent).
- **macOS / Linux** cron: `0 9 * * 1-5 cd /path/to/trading-bot && .venv/bin/python -m tradebot run >> data/cron.log 2>&1`
  (adjust for your timezone; the bot itself always thinks in ET).

## 11. Going live (only after weeks of clean practice results)

1. Review `data/dashboard.html` and `data/trades.jsonl`: is expectancy
   positive, is drawdown tolerable, did every day end flat?
2. Generate a **new** key + secret with the app in **Live** mode (practice
   credentials do not work on the live account).
3. In `.env`: `T212_ENV=live`, the live key and secret, and
   `LIVE_TRADING_ACK=I_UNDERSTAND_LIVE_TRADING`. (IB: `IB_PORT=7496` plus the ack.)
4. Start with `RISK_PER_TRADE_PCT=0.25` and `MAX_POSITIONS=1`.
5. Remember Trading 212 Invest is a cash account: pattern-day-trading rules
   don't apply, but you are trading with settled cash and Yahoo quotes, and
   your stop is a software stop checked every `POLL_SECONDS`, so keep size
   small and expect fills a little worse than the backtest. Consider
   `POLL_SECONDS=15` on live.

## Configuration reference

See `.env.example` — every setting is documented inline. Risk defaults:
0.5% of equity per trade, $250 hard cap, 25% max position, 3 positions,
stop trading after −3R or −2% on the day.

## Tests

```bash
python -m pytest tests -q
```

Covers the strategy, exit rules, sizing and gates, the live-account refusals,
the journal maths, the backtester, the executor on the simulated broker,
restart recovery, a full scripted trading day through the real `TradingLoop`,
and the Trading 212 adapter against a fake REST server (key+secret auth,
entry → stop in both stop modes, cancel and re-place on breakeven, partials,
software and broker stop fills, restart recovery, rate limiting, auth errors).

## Disclaimer

This is software, not advice. Markets can move through stops, brokers can
reject orders, connections drop. Paper trade first; risk only what you can lose.
