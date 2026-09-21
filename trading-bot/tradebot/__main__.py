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
from .strategy import StrategyParams, load_strategy
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
    return Notifier(s.telegram_bot_token, s.telegram_chat_id, prefix=s.telegram_prefix)


def _data(s: Settings):
    if s.data_provider == "alpaca":
        from .alpaca import AlpacaData, AlpacaError
        try:
            return AlpacaData(s.alpaca_api_key, s.alpaca_api_secret, s.alpaca_feed, universe=s.universe)
        except AlpacaError as exc:
            print(f"Alpaca: {exc}")
            sys.exit(2)
    if s.data_provider == "yfinance":
        from .marketdata import YFinanceData
        return YFinanceData()
    print(f"Unknown DATA_PROVIDER={s.data_provider!r} (implement tradebot.marketdata.DataProvider)")
    sys.exit(2)


def _broker(s: Settings, connect: bool = True):
    """Build the configured broker (Trading 212 by default, IB with BROKER=ib, Alpaca crypto with BROKER=alpaca)."""
    if s.broker == "alpaca":
        from .alpaca import AlpacaError
        from .alpaca_broker import AlpacaBroker, AlpacaCryptoData
        aux = None
        try:
            from .marketdata import YFinanceData
            aux = YFinanceData()
        except Exception:
            pass
        b = AlpacaBroker(s, AlpacaCryptoData(s.alpaca_api_key, s.alpaca_api_secret, aux=aux))
        if connect:
            try:
                b.connect()
            except AlpacaError as exc:
                print(f"Alpaca: {exc}")
                sys.exit(1)
        return b
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
    loaded = load_strategy(s.strategy_file, s.allow_shorts)
    loaded.apply(s)
    print("Config:", s.describe())
    print(f"Strategy: {loaded.name} ({s.strategy_file}) · universe {len(s.universe)} symbols"
          f"{f' from {s.universe_file}' if s.universe_file else ''}")
    b = _broker(s)
    try:
        sample = "SPY"
        if s.broker == "t212":
            print(f"Account: {b.account_id} ({b.account_currency}) on Trading 212 {s.t212_env}")
            missing = [sym for sym in s.universe if sym not in b._instruments]
            if missing:
                print("Not tradable on this account (remove from UNIVERSE):", ", ".join(missing))
        elif s.broker == "alpaca":
            print(f"Account: {b.account_id} ({b.account_currency}) on Alpaca {s.alpaca_env}")
            sample = s.universe[0] if s.universe else "BTC/USD"
        else:
            print("Account:", b.account)
        print(f"Equity ({s.trading_currency}): {b.net_liquidation():,.2f}")
        print("Positions:", b.positions() or "none")
        bars = b.daily_bars(sample, 5)
        print("%s daily bars (%d): last close %.4g" % (sample, len(bars), bars[-1].close if bars else 0))
        px = b.last_price(sample)
        print(f"{sample} last price:", px if px else "unavailable (check your data provider / IB_MARKET_DATA_TYPE)")
    finally:
        b.disconnect()
    n = _notifier(s)
    print("Telegram:", "configured" if n.configured else "not configured")
    print("OK")


def cmd_scan(args) -> None:
    s = _settings(args)
    _logging(s)
    from .universe import GapScanner, UniverseScanner
    loaded = load_strategy(s.strategy_file, s.allow_shorts)
    loaded.apply(s)
    b = _broker(s)
    try:
        if loaded.scan_kind == "gap":
            r = loaded.strategy.r
            watch = GapScanner(b, s, r.min_gap_pct, r.min_price_usd, r.min_market_cap_usd).scan()
        else:
            watch = UniverseScanner(b, s).scan()
    finally:
        b.disconnect()
    print(f"\nWatchlist ({loaded.name}):")
    for c in watch:
        print("  " + (f"{c.symbol:<6} ${c.price:>8.2f}  gap {c.gap_pct:+5.1f}%" if loaded.scan_kind == "gap" else c.line()))
    if args.telegram and watch:
        _notifier(s).send("📋 <b>Scan</b>\n<pre>" + esc("\n".join(c.line() for c in watch)) + "</pre>")


def cmd_run(args) -> None:
    s = _settings(args)
    _logging(s)
    from .loop import TradingLoop
    loaded = load_strategy(s.strategy_file, s.allow_shorts)
    loaded.apply(s)
    loop = TradingLoop(s, _broker(s, connect=False), loaded, _notifier(s))
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
    from concurrent.futures import ThreadPoolExecutor, as_completed
    from .data import fetch_history, save_csv
    b = _broker(s)
    out = Path(args.out)
    symbols = args.symbols or s.universe
    if args.skip_existing and not args.daily_only:
        before = len(symbols)
        symbols = [x for x in symbols if not ((out / f"{x}_5min.csv").exists() and (out / f"{x}_1d.csv").exists())]
        print(f"Skipping {before - len(symbols)} symbols already in {out}")
    workers = args.workers or (4 if s.broker != "ib" and s.data_provider == "alpaca" else 1)
    print(f"Fetching {args.days} days of 5-min bars (+ premarket) and 2y daily for {len(symbols)} symbols "
          f"-> {out} ({workers} parallel)")

    # daily history must reach 200+ sessions before the first intraday day (SMA filter)
    daily_days = int(args.days * 0.7) + 260

    def one(sym: str) -> str:
        daily = b.daily_bars(sym, daily_days)
        if args.daily_only:
            save_csv(daily, out / f"{sym}_1d.csv")
            return f"{sym}: {len(daily)} daily"
        if s.broker == "ib":
            bars = fetch_history(b, sym, args.days, 5)
        else:  # data provider (Yahoo allows ~60 days of 5-minute bars; Alpaca years)
            bars = b.intraday_bars(sym, 5, args.days, include_premarket=True)
        if not bars:
            return f"{sym}: no intraday data, skipped"
        save_csv(bars, out / f"{sym}_5min.csv")
        save_csv(daily, out / f"{sym}_1d.csv")
        return f"{sym}: {len(bars)} 5-min bars, {len(daily)} daily"

    done = 0
    try:
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(one, sym): sym for sym in symbols}
            for fut in as_completed(futures):
                done += 1
                sym = futures[fut]
                try:
                    print(f"[{done}/{len(symbols)}] {fut.result()}")
                except Exception as exc:
                    print(f"[{done}/{len(symbols)}] {sym}: skipped ({exc})")
    finally:
        b.disconnect()


def cmd_fetch_gappers(args) -> None:
    """Whole-market gap events -> data/gappers/*.csv (event-driven backtest data)."""
    s = _settings(args)
    _logging(s)
    if s.data_provider != "alpaca":
        print("fetch-gappers needs DATA_PROVIDER=alpaca (bulk history).")
        sys.exit(2)
    from concurrent.futures import ThreadPoolExecutor, as_completed
    from datetime import timedelta
    from .alpaca import AlpacaData
    from .data import save_csv
    from .events import find_gap_events, plan_ranges, summarize
    from .tjl import TJLRules
    rules = TJLRules.load(s.strategy_file) if Path(s.strategy_file).exists() and "rules" in str(s.strategy_file) else TJLRules()
    d: AlpacaData = _data(s)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    now = clock.now_et()
    first_event_day = (now - timedelta(days=args.days)).date()
    daily_start = now - timedelta(days=int(args.days * 1.0) + 320)

    import json as _json
    from datetime import date as _date
    from .events import GapEvent
    cache = out / "events.json"
    if args.skip_existing and cache.exists():
        raw = _json.loads(cache.read_text())
        events = [GapEvent(e["symbol"], _date.fromisoformat(e["day"]), e["gap_pct"], e["prev_close"],
                           e["open"], e["dollar_volume"]) for e in raw]
        print(f"1-2/3 reusing {len(events)} cached gap events from {cache}")
    else:
        print("1/3 listing US stocks...")
        symbols = d.assets()
        if args.max_symbols:
            symbols = symbols[: args.max_symbols]
        print(f"    {len(symbols)} symbols")
        print(f"2/3 daily bars since {daily_start.date()} (bulk)...")
        daily = d.multi_daily_bars(symbols, daily_start)
        print(f"    {sum(len(v) for v in daily.values()):,} daily bars for {len(daily)} symbols")
        events = find_gap_events(daily, rules.min_gap_pct, max(rules.min_price_usd, args.min_price),
                                 args.min_dollar_volume, rules.sma_days, start=first_event_day)
        if args.max_events and len(events) > args.max_events:
            events = sorted(events, key=lambda e: -e.gap_pct)[: args.max_events]
            events.sort(key=lambda e: (e.day, -e.gap_pct))
        if not events:
            print("    no gap events found")
            sys.exit(1)
        for sym in {e.symbol for e in events}:
            save_csv(daily[sym], out / f"{sym}_1d.csv")
        cache.write_text(_json.dumps([{"symbol": e.symbol, "day": e.day.isoformat(), "gap_pct": e.gap_pct,
                                       "prev_close": e.prev_close, "open": e.open, "dollar_volume": e.dollar_volume}
                                      for e in events]))
    print("    " + summarize(events).replace("\n", "\n    "))
    plan = plan_ranges(events, args.context)
    total_ranges = sum(len(r) for r in plan.values())
    print(f"3/3 5-min bars for {len(plan)} symbols / {total_ranges} date ranges ({args.workers} parallel)...")

    def one(sym: str) -> str:
        if args.skip_existing and (out / f"{sym}_5min.csv").exists():
            return f"{sym}: exists"
        bars = []
        for start, end in plan[sym]:
            bars.extend(d.bars_between(sym, "5Min", clock.at(start, clock.parse_hhmm("04:00")),
                                       clock.at(end, clock.parse_hhmm("20:00"))))
        seen = {}
        for b in bars:
            seen[b.time] = b
        bars = [seen[k] for k in sorted(seen)]
        if bars:
            save_csv(bars, out / f"{sym}_5min.csv")
        return f"{sym}: {len(bars)} bars over {len(plan[sym])} range(s)"

    done = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(one, sym): sym for sym in plan}
        for fut in as_completed(futs):
            done += 1
            try:
                msg = fut.result()
            except Exception as exc:
                msg = f"{futs[fut]}: failed ({exc})"
            if done % 25 == 0 or done == len(futs):
                print(f"[{done}/{len(futs)}] {msg}")
    print(f"done -> {out}   next: python -m tradebot backtest --data {out} && python -m tradebot analyze")


def cmd_fetch_crypto(args) -> None:
    """Crypto bars for the strategy's universe -> data/crypto/*.csv (Alpaca, no keys needed for data)."""
    s = _settings(args)
    _logging(s)
    from datetime import timedelta
    from .alpaca_broker import AlpacaCryptoData, fname
    from .data import save_csv
    loaded = load_strategy(s.strategy_file, s.allow_shorts)
    symbols = args.symbols or loaded.universe or s.universe
    minutes = getattr(loaded.strategy, "bar_minutes", 15)
    d = AlpacaCryptoData(s.alpaca_api_key, s.alpaca_api_secret)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    start = clock.now_et() - timedelta(days=args.days)
    print(f"Fetching {args.days} days of {minutes}-min crypto bars for {len(symbols)} symbols -> {out}")
    for sym in symbols:
        bars = d.bars(sym, f"{minutes}Min", start)
        daily = d.bars(sym, "1Day", start - timedelta(days=30))
        save_csv(bars, out / f"{fname(sym)}_{minutes}min.csv")
        save_csv(daily, out / f"{fname(sym)}_1d.csv")
        print(f"{sym}: {len(bars)} bars, {len(daily)} daily")
    print(f"done -> {out}   next: python -m tradebot backtest --data {out}")


def cmd_backtest(args) -> None:
    s = _settings(args)
    _logging(s)
    from .backtest import Backtester
    from .dashboard import write_dashboard
    from .data import load_daily_dir, load_dir, synthetic_bars, synthetic_daily
    from .journal import Journal
    strategy_file = Path(args.strategy) if args.strategy else s.strategy_file
    loaded = load_strategy(strategy_file, s.allow_shorts)
    loaded.apply(s)
    daily = None
    if args.demo and loaded.continuous:
        from .data import synthetic_continuous
        syms = args.symbols or (loaded.universe or ["BTC/USD", "ETH/USD", "SOL/USD"])[:4]
        minutes = getattr(loaded.strategy, "bar_minutes", 15)
        bars = {sym: synthetic_continuous(sym, args.days, minutes, seed=i + 1, start_price=50 * (i + 1))
                for i, sym in enumerate(syms)}
        print(f"Synthetic 24/7 data: {len(syms)} symbols x {args.days} days")
    elif args.demo:
        syms = args.symbols or ["AAPL", "NVDA", "TSLA", "AMD", "META", "AMZN"]
        gap_share = 0.12 if loaded.scan_kind == "gap" else 0.0
        bars = {sym: synthetic_bars(sym, args.days, seed=i + 1, start_price=80 + 40 * i, gap_days=gap_share)
                for i, sym in enumerate(syms)}
        daily = {sym: synthetic_daily(sym, 300, seed=i + 1, end_price=b[0].open, end=b[0].time.date())
                 for i, (sym, b) in enumerate(bars.items())}
        print(f"Synthetic data: {len(syms)} symbols x {args.days} days")
    else:
        minutes = getattr(loaded.strategy, "bar_minutes", 5)
        bars = load_dir(args.data, suffix=f"_{minutes}min.csv")
        if loaded.continuous:  # crypto files are named BTC-USD_15min.csv
            bars = {k.replace("-", "/"): v for k, v in bars.items()}
        daily = load_daily_dir(args.data) or None
        if daily and loaded.continuous:
            daily = {k.replace("-", "/"): v for k, v in daily.items()}
        if args.symbols:
            bars = {k: v for k, v in bars.items() if k in args.symbols}
        if not bars:
            print(f"No *_{minutes}min.csv files in {args.data}. Run `fetch-data`/`fetch-crypto` first or use --demo.")
            sys.exit(1)
        if loaded.scan_kind == "gap" and not daily:
            print("Note: no *_1d.csv daily files found; the 200-day SMA filter needs them. "
                  "Re-run `fetch-data` to download daily history.")
    bt = Backtester(s, loaded, bars, daily=daily, equity=args.equity)
    res = bt.run()
    st = res.stats
    params = loaded
    print(f"\n{loaded.name} · {res.days} days · {len(bars)} symbols · {s.describe()}")
    print(f"trades {st.trades}  win {st.win_rate*100:.0f}%  total {st.total_r:+.1f}R  "
          f"avg {st.avg_r:+.2f}R  expectancy {st.expectancy_r:+.2f}R  PF {st.profit_factor:.2f}  "
          f"maxDD {st.max_drawdown_r:.1f}R")
    print(f"equity ${res.start_equity:,.0f} -> ${res.end_equity:,.0f}")
    j = Journal(s.data_dir / "backtest_trades.jsonl")
    if j.path and j.path.exists():
        j.path.unlink()
    for t in res.trades:
        j.append(t)
    out = write_dashboard(res.trades, s.data_dir / "backtest_dashboard.html", f"Backtest · {loaded.name}")
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
    from .analyze import DEFAULT_GRID, TJL_GRID, format_sweep, sweep
    from .data import load_daily_dir, load_dir
    import json as _json
    strategy_file = Path(args.strategy) if args.strategy else s.strategy_file
    raw = _json.loads(strategy_file.read_text()) if strategy_file.exists() else {}
    if "strategy_name" in raw or "daily_filters" in raw:
        from .tjl import TJLRules
        params = TJLRules.load(strategy_file)
        default_grid = TJL_GRID
    else:
        params = StrategyParams.load(strategy_file)
        default_grid = DEFAULT_GRID
    bars = load_dir(args.data)
    daily = load_daily_dir(args.data) or None
    if args.symbols:
        bars = {k: v for k, v in bars.items() if k in args.symbols}
    if not bars:
        print(f"No *_5min.csv files in {args.data}. Run `fetch-data` first.")
        sys.exit(1)
    grid = _json.loads(args.grid) if args.grid else default_grid
    n = 1
    for v in grid.values():
        n *= len(v)
    print(f"Sweeping {n} combinations over {len(bars)} symbols (base: {strategy_file})...")
    rows = sweep(s, params, bars, grid, equity=args.equity, daily=daily)
    print(format_sweep(rows))
    print("\nCaveat: a small sample rewards luck. Prefer settings that win for a reason you can explain.")


def cmd_dashboard(args) -> None:
    s = _settings(args)
    from .dashboard import export_static, trades_payload, write_dashboard
    from .journal import Journal, compute_stats
    name = load_strategy(s.strategy_file, s.allow_shorts).name
    trades = Journal(args.journal or s.journal_file).load()
    out = write_dashboard(trades, args.out or s.dashboard_file, name)
    st = compute_stats(trades)
    print(f"{st.trades} closed trades, {st.total_r:+.2f}R -> {out}")
    if args.export_vercel:
        sources_raw = args.sources or s.dashboard_sources
        if sources_raw:
            sources = [tuple(part.split("=", 1)) for part in sources_raw.split(",") if "=" in part]
            target = [(n.strip(), u.strip()) for n, u in sources]
            print("multi-bot page: " + ", ".join(f"{n} -> {u}" for n, u in target))
        elif s.dashboard_data_url:
            target = s.dashboard_data_url
        else:
            print("Set DASHBOARD_DATA_URL (one bot) or DASHBOARD_SOURCES=Name=url,Name=url (tabs) first; "
                  "`python -m tradebot dashboard --publish` prints the base URL.")
            sys.exit(2)
        idx = export_static(args.export_vercel, target, name)
        print(f"static site -> {idx.parent}  (commit it and deploy; see {idx.parent}/README.md)")
    if args.publish:
        import json as _json
        from .publish import BlobPublisher, PublishError
        try:
            pub = BlobPublisher(s.vercel_blob_token, s.vercel_blob_prefix)
            url = pub.put("trades.json", _json.dumps(trades_payload(trades)).encode())
            live = s.data_dir / "live.json"
            snapshot = _json.loads(live.read_text()) if live.exists() else None
            if snapshot is None or snapshot.get("offline") or args.snapshot:
                # no session snapshot yet: publish an "offline" one with the real account equity
                b = _broker(s)
                try:
                    equity = b.net_liquidation()
                    currency = getattr(b, "account_currency", "") or s.trading_currency
                finally:
                    b.disconnect()
                snapshot = {"updated": clock.now_et().isoformat(), "strategy": name, "mode": s.describe(),
                            "offline": True, "currency": currency, "equity": round(equity, 2),
                            "day_start_equity": round(equity, 2), "realized_r": 0.0, "realized_pnl": 0.0,
                            "closed_today": 0, "open": [], "watchlist": [], "blockers": [], "scanned": False,
                            "day_done": False, "chart": None, "log": []}
            pub.put("live.json", _json.dumps(snapshot).encode())
            print(f"published trades.json + live.json -> {url}\nDASHBOARD_DATA_URL={pub.base_url}")
        except PublishError as exc:
            print(f"publish failed: {exc}")
            sys.exit(1)
    if args.serve:
        import http.server
        import functools
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(out.parent))
        print(f"Serving http://{args.host}:{args.serve}/{out.name}  (Ctrl+C to stop)")
        http.server.ThreadingHTTPServer((args.host, args.serve), handler).serve_forever()


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
    p.add_argument("--days", type=int, default=55, help="calendar days of 5-min bars (Yahoo max ~59, Alpaca 730+)")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--out", default="data/bars")
    p.add_argument("--skip-existing", action="store_true", help="don't re-download symbols already saved")
    p.add_argument("--daily-only", action="store_true", help="only (re)download the daily files (fast)")
    p.add_argument("--workers", type=int, help="parallel downloads (default 4 for Alpaca, 1 for Yahoo)")
    p = sub.add_parser("fetch-gappers", help="whole-market gap events + the 5-min bars to replay them (Alpaca)")
    p.add_argument("--days", type=int, default=730, help="how far back to look for gap events")
    p.add_argument("--out", default="data/gappers")
    p.add_argument("--min-price", type=float, default=3.0)
    p.add_argument("--min-dollar-volume", type=float, default=500_000,
                   help="20-day avg close*volume floor in the feed's units (IEX volume is ~2-3%% of consolidated)")
    p.add_argument("--context", type=int, default=16, help="sessions of 5-min history before each event (RVOL lookback)")
    p.add_argument("--max-symbols", type=int, default=0, help="debug: cap the symbol list")
    p.add_argument("--max-events", type=int, default=0, help="cap events (keeps the largest gaps)")
    p.add_argument("--workers", type=int, default=4)
    p.add_argument("--skip-existing", action="store_true")
    p = sub.add_parser("fetch-crypto", help="download crypto bars for the crypto strategy's universe (Alpaca)")
    p.add_argument("--days", type=int, default=365)
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--out", default="data/crypto")
    p = sub.add_parser("backtest", help="run the strategy over CSV history (or --demo synthetic data)")
    p.add_argument("--data", default="data/bars")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--days", type=int, default=60, help="(demo) days of synthetic data")
    p.add_argument("--equity", type=float, default=100_000)
    p.add_argument("--demo", action="store_true")
    p.add_argument("--strategy", help="strategy file (default: STRATEGY_FILE / rules.json)")
    p = sub.add_parser("analyze", help="break a backtest (or live) journal down by exit, time, filters, symbol")
    p.add_argument("--journal", help="default: data/backtest_trades.jsonl")
    p = sub.add_parser("sweep", help="backtest a grid of strategy parameters over CSV history")
    p.add_argument("--data", default="data/bars")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--equity", type=float, default=100_000)
    p.add_argument("--strategy", help="strategy file to sweep (default: STRATEGY_FILE / rules.json)")
    p.add_argument("--grid", help='JSON, e.g. \'{"min_rel_volume":[1.5,2],"opening_range_minutes":[15,30]}\'')
    p = sub.add_parser("dashboard", help="build the R-multiple dashboard from the trade journal")
    p.add_argument("--journal")
    p.add_argument("--out")
    p.add_argument("--serve", type=int, nargs="?", const=8765, help="serve data/ on PORT (live panel needs this)")
    p.add_argument("--host", default="127.0.0.1", help="bind address for --serve (keep 127.0.0.1; use an SSH tunnel)")
    p.add_argument("--export-vercel", metavar="DIR", help="write a hosted copy (index.html, config.js, vercel.json) that reads DASHBOARD_DATA_URL / DASHBOARD_SOURCES")
    p.add_argument("--sources", help='multi-bot page: "Equities=https://.../tradebot,Crypto=https://.../crypto"')
    p.add_argument("--publish", action="store_true", help="upload trades.json + live.json to Vercel Blob now")
    p.add_argument("--snapshot", action="store_true", help="with --publish: refresh the offline equity snapshot even if a session snapshot exists")

    args = ap.parse_args(argv)
    {"check": cmd_check, "scan": cmd_scan, "run": cmd_run, "flatten": cmd_flatten, "kill": cmd_kill,
     "telegram-test": cmd_telegram_test, "fetch-data": cmd_fetch_data, "backtest": cmd_backtest,
     "analyze": cmd_analyze, "sweep": cmd_sweep, "dashboard": cmd_dashboard,
     "fetch-gappers": cmd_fetch_gappers, "fetch-crypto": cmd_fetch_crypto}[args.cmd](args)


if __name__ == "__main__":
    main()
