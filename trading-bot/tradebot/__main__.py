"""Command line entry point: ``python -m tradebot <command>``."""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

if sys.version_info < (3, 10):  # pragma: no cover
    sys.exit(f"tradebot needs Python 3.10+ (3.12 recommended); this is {sys.version.split()[0]} "
             f"at {sys.executable}.\nOn a Mac: brew install python@3.12, then\n"
             "  deactivate; rm -rf .venv; python3.12 -m venv .venv; source .venv/bin/activate; "
             "pip install -r requirements.txt")

from . import clock
from .config import Settings, UnsafeConfig
from .strategy import StrategyParams
from .telegram import Notifier, esc


def _logging(settings: Settings | None) -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]
    if settings is not None:
        handlers.append(logging.FileHandler(settings.log_file))
    logging.basicConfig(level=logging.INFO, handlers=handlers,
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")


_ENV_PATH = ".env"


def args_env_path() -> str:
    return _ENV_PATH


def _settings(args) -> Settings:
    global _ENV_PATH
    _ENV_PATH = str(args.env)
    try:
        s = Settings.load(args.env)
    except UnsafeConfig as exc:
        print(f"REFUSED: {exc}")
        sys.exit(2)
    return s


def _notifier(s: Settings) -> Notifier:
    return Notifier(s.telegram_bot_token, s.telegram_chat_id)


def _data(s: Settings):
    if s.data_provider == "yfinance":
        from .marketdata import YFinanceData
        return YFinanceData()
    print(f"Unknown DATA_PROVIDER={s.data_provider!r} (implement tradebot.marketdata.DataProvider)")
    sys.exit(2)


def _broker(s: Settings, connect: bool = True):
    """Build the configured broker (Trading 212 by default, IB with BROKER=ib)."""
    if s.broker == "t212":
        from .t212 import T212Broker, T212Error
        b = T212Broker(s, _data(s))
        if connect:
            try:
                b.connect()
            except T212Error as exc:
                def mask(v: str) -> str:
                    return f"{v[:4]}…{v[-4:]} ({len(v)} chars)" if len(v) > 8 else ("(empty)" if not v else "(too short)")
                print(f"Trading 212: {exc}\n"
                      f"Loaded from {args_env_path()}: key {mask(s.t212_api_key)}, secret {mask(s.t212_api_secret)}; "
                      f"env={s.t212_env} -> {'demo' if s.t212_env == 'demo' else 'live'}.trading212.com\n"
                      "Checklist: in the Trading 212 app switch to Practice mode -> Settings -> API\n"
                      "  -> generate a key with account/portfolio/orders read AND orders execute scopes,\n"
                      "  put BOTH values in .env as T212_API_KEY and T212_API_SECRET, keep T212_ENV=demo.")
                sys.exit(1)
        return b
    from .broker import IBBroker
    b = IBBroker(s)
    if connect:
        try:
            b.connect()
        except (ConnectionRefusedError, TimeoutError, OSError) as exc:
            print(f"Could not connect to TWS/Gateway at {s.ib_host}:{s.ib_port}: {exc}\n"
                  "Checklist: TWS is running and logged in -> File > Global Configuration > API > Settings:\n"
                  "  [x] Enable ActiveX and Socket Clients   [ ] Read-Only API (must be UNCHECKED)\n"
                  f"  Socket port = {s.ib_port} ({'paper' if s.is_paper else 'LIVE'})   Trusted IP 127.0.0.1 added\n"
                  "  Then Apply / OK and retry.")
            sys.exit(1)
    return b


# ---------------------------------------------------------------------------
def cmd_check(args) -> None:
    s = _settings(args)
    _logging(s)
    print("Config:", s.describe())
    params = StrategyParams.load(s.strategy_file)
    print("Strategy:", params.name)
    b = _broker(s)
    try:
        if s.broker == "t212":
            print(f"Account: {b.account_id} ({b.account_currency}) on Trading 212 {s.t212_env}")
            missing = [sym for sym in s.universe if sym not in b._instruments]
            if missing:
                print("Not tradable on this account (remove from UNIVERSE):", ", ".join(missing))
        else:
            print("Account:", b.account)
        print(f"Equity ({s.trading_currency}): {b.net_liquidation():,.2f}")
        print("Positions:", b.positions() or "none")
        bars = b.daily_bars("SPY", 5)
        print("SPY daily bars (%d): last close %.2f" % (len(bars), bars[-1].close if bars else 0))
        px = b.last_price("SPY")
        print("SPY last price:", px if px else "unavailable (check your data provider / IB_MARKET_DATA_TYPE)")
    finally:
        b.disconnect()
    n = _notifier(s)
    print("Telegram:", "configured" if n.configured else "not configured")
    print("OK")


def cmd_scan(args) -> None:
    s = _settings(args)
    _logging(s)
    from .universe import UniverseScanner
    b = _broker(s)
    try:
        watch = UniverseScanner(b, s).scan()
    finally:
        b.disconnect()
    print("\nWatchlist:")
    for c in watch:
        print("  " + c.line())
    if args.telegram and watch:
        _notifier(s).send("📋 <b>Scan</b>\n<pre>" + esc("\n".join(c.line() for c in watch)) + "</pre>")


def cmd_run(args) -> None:
    s = _settings(args)
    _logging(s)
    from .loop import TradingLoop
    params = StrategyParams.load(s.strategy_file)
    loop = TradingLoop(s, _broker(s, connect=False), params, _notifier(s))
    try:
        loop.run()
    except Exception as exc:  # surface broker/auth errors without a stack trace
        if type(exc).__name__ == "T212Error":
            print(f"Trading 212: {exc}")
            sys.exit(1)
        raise


def cmd_flatten(args) -> None:
    s = _settings(args)
    _logging(s)
    from .execution import Executor, StateStore
    from .journal import Journal
    b = _broker(s)
    try:
        ex = Executor(b, Journal(s.journal_file), _notifier(s), StateStore(s.state_file))
        ex.restore()
        ex.flatten_all("manual")
        print("Flat. Positions now:", b.positions() or "none")
    finally:
        b.disconnect()


def cmd_kill(args) -> None:
    s = _settings(args)
    if args.resume:
        s.kill_switch_file.unlink(missing_ok=True)
        print("Kill switch removed; new entries allowed again.")
    else:
        s.kill_switch_file.write_text("created by `python -m tradebot kill`\n")
        print(f"Kill switch ON ({s.kill_switch_file}). No new entries; open trades still managed. "
              "Use `flatten` to close everything now.")


def cmd_telegram_test(args) -> None:
    s = _settings(args)
    n = _notifier(s)
    ok = n.send("✅ Telegram alerts are working. " + esc(s.describe()))
    print("sent" if ok else "not sent (check TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID)")


def cmd_fetch_data(args) -> None:
    s = _settings(args)
    _logging(s)
    from .data import fetch_history, save_csv
    b = _broker(s)
    out = Path(args.out)
    try:
        for sym in (args.symbols or s.universe):
            if s.broker == "ib":
                bars = fetch_history(b, sym, args.days, 5)
            else:  # data provider (Yahoo allows up to ~60 days of 5-minute bars)
                bars = b.intraday_bars(sym, 5, args.days)
            save_csv(bars, out / f"{sym}_5min.csv")
            print(f"{sym}: {len(bars)} bars -> {out / f'{sym}_5min.csv'}")
    finally:
        b.disconnect()


def cmd_backtest(args) -> None:
    s = _settings(args)
    _logging(s)
    from .backtest import Backtester
    from .dashboard import write_dashboard
    from .data import load_dir, synthetic_bars
    from .journal import Journal
    params = StrategyParams.load(s.strategy_file)
    if args.demo:
        syms = args.symbols or ["AAPL", "NVDA", "TSLA", "AMD", "META", "AMZN"]
        bars = {sym: synthetic_bars(sym, args.days, seed=i + 1, start_price=80 + 40 * i)
                for i, sym in enumerate(syms)}
        print(f"Synthetic data: {len(syms)} symbols x {args.days} days")
    else:
        bars = load_dir(args.data)
        if args.symbols:
            bars = {k: v for k, v in bars.items() if k in args.symbols}
        if not bars:
            print(f"No *_5min.csv files in {args.data}. Run `fetch-data` first or use --demo.")
            sys.exit(1)
    bt = Backtester(s, params, bars, equity=args.equity)
    res = bt.run()
    st = res.stats
    print(f"\n{params.name} · {res.days} days · {len(bars)} symbols")
    print(f"trades {st.trades}  win {st.win_rate*100:.0f}%  total {st.total_r:+.1f}R  "
          f"avg {st.avg_r:+.2f}R  expectancy {st.expectancy_r:+.2f}R  PF {st.profit_factor:.2f}  "
          f"maxDD {st.max_drawdown_r:.1f}R")
    print(f"equity ${res.start_equity:,.0f} -> ${res.end_equity:,.0f}")
    j = Journal(s.data_dir / "backtest_trades.jsonl")
    if j.path and j.path.exists():
        j.path.unlink()
    for t in res.trades:
        j.append(t)
    out = write_dashboard(res.trades, s.data_dir / "backtest_dashboard.html", f"Backtest · {params.name}")
    print(f"journal  -> {j.path}\ndashboard -> {out}")


def cmd_analyze(args) -> None:
    s = _settings(args)
    from .analyze import breakdown
    from .journal import Journal
    path = args.journal or (s.data_dir / "backtest_trades.jsonl")
    trades = Journal(path).load()
    print(f"{len(trades)} trades from {path}")
    print(breakdown(trades))


def cmd_sweep(args) -> None:
    s = _settings(args)
    from .analyze import DEFAULT_GRID, format_sweep, sweep
    from .data import load_dir
    import json as _json
    params = StrategyParams.load(s.strategy_file)
    bars = load_dir(args.data)
    if args.symbols:
        bars = {k: v for k, v in bars.items() if k in args.symbols}
    if not bars:
        print(f"No *_5min.csv files in {args.data}. Run `fetch-data` first.")
        sys.exit(1)
    grid = _json.loads(args.grid) if args.grid else DEFAULT_GRID
    n = 1
    for v in grid.values():
        n *= len(v)
    print(f"Sweeping {n} combinations over {len(bars)} symbols (base: {s.strategy_file})...")
    rows = sweep(s, params, bars, grid, equity=args.equity)
    print(format_sweep(rows))
    print("\nCaveat: a small sample rewards luck. Prefer settings that win for a reason you can explain.")


def cmd_dashboard(args) -> None:
    s = _settings(args)
    from .dashboard import write_dashboard
    from .journal import Journal, compute_stats
    params = StrategyParams.load(s.strategy_file)
    trades = Journal(args.journal or s.journal_file).load()
    out = write_dashboard(trades, args.out or s.dashboard_file, params.name)
    st = compute_stats(trades)
    print(f"{st.trades} closed trades, {st.total_r:+.2f}R -> {out}")
    if args.serve:
        import http.server
        import functools
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(out.parent))
        print(f"Serving http://127.0.0.1:{args.serve}/{out.name}  (Ctrl+C to stop)")
        http.server.ThreadingHTTPServer(("127.0.0.1", args.serve), handler).serve_forever()


# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(prog="tradebot", description="IB autonomous intraday trading bot")
    ap.add_argument("--env", default=".env", help="path to .env file")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("check", help="connect to TWS and verify account, data and safety config")
    p = sub.add_parser("scan", help="run the pre-market universe scan")
    p.add_argument("--telegram", action="store_true", help="also send the watchlist to Telegram")
    sub.add_parser("run", help="run the trading loop for today's session")
    sub.add_parser("flatten", help="EMERGENCY: cancel all orders and close all positions")
    p = sub.add_parser("kill", help="block new entries (creates data/KILL)")
    p.add_argument("--resume", action="store_true", help="remove the kill switch")
    sub.add_parser("telegram-test", help="send a test message")
    p = sub.add_parser("fetch-data", help="download 5-min history from IB to CSV for backtests")
    p.add_argument("--days", type=int, default=30)
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--out", default="data/bars")
    p = sub.add_parser("backtest", help="run the strategy over CSV history (or --demo synthetic data)")
    p.add_argument("--data", default="data/bars")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--days", type=int, default=60, help="(demo) days of synthetic data")
    p.add_argument("--equity", type=float, default=100_000)
    p.add_argument("--demo", action="store_true")
    p = sub.add_parser("analyze", help="break a backtest (or live) journal down by exit, time, filters, symbol")
    p.add_argument("--journal", help="default: data/backtest_trades.jsonl")
    p = sub.add_parser("sweep", help="backtest a grid of strategy parameters over CSV history")
    p.add_argument("--data", default="data/bars")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--equity", type=float, default=100_000)
    p.add_argument("--grid", help='JSON, e.g. \'{"min_rel_volume":[1.5,2],"opening_range_minutes":[15,30]}\'')
    p = sub.add_parser("dashboard", help="build the R-multiple dashboard from the trade journal")
    p.add_argument("--journal")
    p.add_argument("--out")
    p.add_argument("--serve", type=int, nargs="?", const=8765, help="serve on localhost:PORT")

    args = ap.parse_args(argv)
    {"check": cmd_check, "scan": cmd_scan, "run": cmd_run, "flatten": cmd_flatten, "kill": cmd_kill,
     "telegram-test": cmd_telegram_test, "fetch-data": cmd_fetch_data, "backtest": cmd_backtest,
     "analyze": cmd_analyze, "sweep": cmd_sweep, "dashboard": cmd_dashboard}[args.cmd](args)


if __name__ == "__main__":
    main()
