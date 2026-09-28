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
    if (loaded.risk_overrides or {}).get("allow_shorts") and s.broker in ("alpaca", "t212"):
        raise SystemExit(f"{loaded.name} trades short; {s.broker} is long-only here. It is a backtest-only rule set.")
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
    from .alpaca_broker import AlpacaCryptoData, alpaca_timeframe, fname
    from .data import save_csv
    loaded = load_strategy(args.strategy or s.strategy_file, s.allow_shorts)
    symbols = args.symbols or loaded.universe or s.universe
    minutes = getattr(loaded.strategy, "bar_minutes", 15)
    d = AlpacaCryptoData(s.alpaca_api_key, s.alpaca_api_secret)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    start = clock.now_et() - timedelta(days=args.days)
    print(f"Fetching {args.days} days of {minutes}-min crypto bars for {len(symbols)} symbols -> {out}")
    for sym in symbols:
        bars = d.bars(sym, alpaca_timeframe(minutes), start)
        daily = d.bars(sym, "1Day", start - timedelta(days=30))
        save_csv(bars, out / f"{fname(sym)}_{minutes}min.csv")
        save_csv(daily, out / f"{fname(sym)}_1d.csv")
        print(f"{sym}: {len(bars)} bars, {len(daily)} daily")
    print(f"done -> {out}   next: python -m tradebot backtest --data {out}")


def cmd_crypto_explain(args) -> None:
    """Replay the last N days bar by bar and count which gate rejected each bar, per pair."""
    s = _settings(args)
    _logging(s)
    from datetime import timedelta
    from .alpaca_broker import AlpacaCryptoData, alpaca_timeframe
    from .crypto import CryptoMomentum, ema
    loaded = load_strategy(args.strategy or s.strategy_file, s.allow_shorts)
    strat = loaded.strategy
    if not isinstance(strat, CryptoMomentum):
        raise SystemExit("crypto-explain needs a crypto rules file (STRATEGY_FILE=crypto.json or --strategy)")
    symbols = args.symbols or loaded.universe or s.universe
    minutes = strat.bar_minutes
    width = timedelta(minutes=minutes)
    d = AlpacaCryptoData(s.alpaca_api_key, s.alpaca_api_secret)
    warmup = strat.intraday_days
    start = clock.now_et() - timedelta(days=args.days + warmup)
    gates = [g for g in strat.GATES if g != "history"]
    print(f"{strat.r.name}: last {args.days} days, {minutes}-min bars, counting the gate that stopped each bar")
    print(f"{'pair':<10}{'bars':>6}{'above_ema':>11}" + "".join(f"{g:>15}" for g in gates))
    totals = {g: 0 for g in gates}
    for sym in symbols:
        bars = d.bars(sym, alpaca_timeframe(minutes), start)
        cutoff = clock.now_et() - timedelta(days=args.days)
        counts = {g: 0 for g in gates}
        n = 0
        for i, b in enumerate(bars):
            if b.time < cutoff:
                continue
            why = strat.explain(sym, bars[: i + 1], b.time + width)
            if why in counts:
                counts[why] += 1
                n += 1
        trend = ema([b.close for b in bars], strat.r.trend_ema_bars) if bars else None
        above = "yes" if bars and trend and bars[-1].close > trend else "no"
        print(f"{sym:<10}{n:>6}{above:>11}" + "".join(f"{counts[g]:>15}" for g in gates))
        for g in gates:
            totals[g] += counts[g]
    print(f"{'total':<10}{'':>6}{'':>11}" + "".join(f"{totals[g]:>15}" for g in gates))
    print("\nRead left to right: a bar has to clear every gate before the one that stopped it. 'signal' bars are the"
          " ones the live bot would have bought (before cooldown/max positions).")


def cmd_arb_monitor(args) -> None:
    """Measure cross-venue crypto spreads (Coinbase, Kraken, Alpaca) net of fees; trades nothing."""
    s = _settings(args)
    _logging(s)
    import asyncio
    from .arbscan import DEFAULT_FEES_BPS, SpreadBook, run_monitor
    try:
        import websockets  # noqa: F401
    except ImportError:
        raise SystemExit("pip install websockets   (needed for the Coinbase/Kraken feeds)")
    loaded = load_strategy(s.strategy_file, s.allow_shorts)
    symbols = args.symbols or loaded.universe or s.universe
    fees = dict(DEFAULT_FEES_BPS)
    for item in args.fees or []:
        venue, bps = item.split("=", 1)
        fees[venue.strip().lower()] = float(bps)
    book = SpreadBook(fees_bps=fees, dislocation_pct=args.dislocation_pct)
    print(f"Monitoring {len(symbols)} pairs on coinbase + kraken (websocket) + alpaca (1s poll); "
          f"fees bps {fees}; report every {args.report_every}s; ctrl-c to stop")
    asyncio.run(run_monitor(book, symbols, s.alpaca_api_key, s.alpaca_api_secret, s.data_dir / "arb_events.csv",
                            report_every=args.report_every, duration=args.minutes * 60 if args.minutes else None))


def cmd_news(args) -> None:
    """World Monitor: upcoming macro events, earnings for symbols, finance headlines (or raw JSON)."""
    s = _settings(args)
    import json as _json
    from datetime import timedelta
    from .worldmonitor import FF_CALENDAR, PATHS, YAHOO_RSS, FreeNews, WorldMonitor, blackout, make_news, mentions
    if not s.worldmonitor_api_key and not args.worldmonitor:
        fn = FreeNews(s.macro_calendar_url or FF_CALENDAR)
        print("No WORLDMONITOR_API_KEY: using free sources (Forex Factory calendar, Yahoo Finance RSS)")
        if args.raw:
            for url in [fn.calendar_url] + [YAHOO_RSS.format(symbol=x) for x in (args.symbols or ["NVDA"])[:2]]:
                try:
                    print(f"=== {url}\n{fn._fetch(url)[: args.raw_chars].decode(errors='replace')}\n")
                except Exception as exc:
                    print(f"=== {url}\nERROR {exc}\n")
            return
        now = clock.now_et()
        try:
            events = fn.economic_events()
            soon = [e for e in events if e.time and now - timedelta(hours=1) <= e.time <= now + timedelta(days=args.days)]
            print(f"Economic calendar: {len(events)} events this week, {len(soon)} in the next {args.days} days")
            for e in sorted(soon, key=lambda e: e.time):
                flag = "HIGH" if e.high_impact and e.us else "    "
                print(f"  {flag} {e.time:%a %m-%d %H:%M} ET  {e.country:<4} {e.name}  {e.impact}")
            ev = blackout(events, now, s.macro_blackout_before_min, s.macro_blackout_after_min)
            print(f"Blackout now: {ev.name + ' at ' + format(ev.time, '%H:%M') if ev else 'no'}")
        except Exception as exc:
            print(f"Economic calendar unavailable: {exc}")
        for sym in args.symbols or []:
            try:
                heads = fn.symbol_headlines(sym.upper())
                print(f"\n{sym.upper()}: {len(heads)} headline(s)")
                for h in heads[: args.limit]:
                    print(f"  {h.time:%m-%d %H:%M}  " if h.time else "  ", end="")
                    print(h.title[:120])
            except Exception as exc:
                print(f"{sym.upper()}: headlines unavailable: {exc}")
        return
    wm = WorldMonitor(s.worldmonitor_api_key, variant=args.variant)
    if args.raw:
        for name in PATHS:
            try:
                data = wm.get(name, {"variant": args.variant} if name == "feed_digest" else None)
                print(f"=== {name} {PATHS[name]}\n{_json.dumps(data, indent=1, default=str)[: args.raw_chars]}\n")
            except Exception as exc:
                print(f"=== {name} {PATHS[name]}\nERROR {exc}\n")
        return
    now = clock.now_et()
    try:
        events = wm.economic_events()
        soon = [e for e in events if e.time and now - timedelta(hours=1) <= e.time <= now + timedelta(days=args.days)]
        print(f"Economic calendar: {len(events)} events, {len(soon)} in the next {args.days} days")
        for e in sorted(soon, key=lambda e: e.time):
            flag = "HIGH" if e.high_impact and e.us else "    "
            print(f"  {flag} {e.time:%a %m-%d %H:%M} ET  {e.country:<4} {e.name}  {e.impact}")
        ev = blackout(events, now, s.macro_blackout_before_min, s.macro_blackout_after_min)
        print(f"Blackout now: {ev.name + ' at ' + format(ev.time, '%H:%M') if ev else 'no'}")
    except Exception as exc:
        print(f"Economic calendar unavailable: {exc}")
    try:
        heads = wm.headlines()
        print(f"\nHeadlines ({args.variant}): {len(heads)}")
        for h in heads[: args.limit]:
            print(f"  {h.time:%m-%d %H:%M} " if h.time else "  ", end="")
            print(f"{h.title[:120]}  [{h.source}]")
        for sym in args.symbols or []:
            hits = mentions(sym.upper(), heads)
            print(f"\n{sym.upper()}: {len(hits)} headline(s)")
            for h in hits[:5]:
                print(f"  {h.title[:120]}  [{h.source}]")
    except Exception as exc:
        print(f"Headlines unavailable: {exc}")
    if args.symbols:
        try:
            earn = wm.earnings()
            for sym in args.symbols:
                print(f"earnings {sym.upper()}: {earn.get(sym.upper(), 'none listed')}")
        except Exception as exc:
            print(f"Earnings calendar unavailable: {exc}")


def cmd_research(args) -> None:
    """Systematic research: in/out-of-sample backtests, benchmark, sensitivity, ranked report."""
    s = _settings(args)
    _logging(s)
    import glob
    import json as _json
    import logging as _logging_mod
    from datetime import timedelta
    from .data import load_dir, save_csv
    from .research import Options, render, run_strategy, to_json
    files: list[str] = []
    for pattern in args.strategies:
        files += sorted(glob.glob(pattern)) or [pattern]
    loaded = {f: load_strategy(f) for f in files}
    data = Path(args.data)
    data.mkdir(parents=True, exist_ok=True)
    by_tf: dict[int, list[str]] = {}
    for f, ld in loaded.items():
        by_tf.setdefault(int(getattr(ld.strategy, "bar_minutes", 5)), []).append(f)

    if args.fetch_days:
        from .alpaca_broker import AlpacaCryptoData, alpaca_timeframe, fname
        d = AlpacaCryptoData(s.alpaca_api_key, s.alpaca_api_secret)
        for minutes, fs in sorted(by_tf.items()):
            if not all(loaded[f].continuous for f in fs):
                print(f"skipping fetch for {minutes}-min equities strategies; supply their CSVs in {data}")
                continue
            days = args.fetch_days if minutes >= 60 else min(args.fetch_days, args.max_intraday_days)
            symbols = sorted({sym for f in fs for sym in (loaded[f].universe or [])})
            for sym in symbols:
                out = data / f"{fname(sym)}_{minutes}min.csv"
                if out.exists() and not args.refetch:
                    continue
                bars = d.bars(sym, alpaca_timeframe(minutes), clock.now_et() - timedelta(days=days))
                save_csv(bars, out)
                print(f"fetched {sym} {minutes}-min: {len(bars)} bars", flush=True)

    opts = Options(equity=args.equity, oos_frac=args.oos_frac, fee_bps=args.fee_bps,
                   stop_fill_lambda=args.stop_fill_lambda, stop_slippage_bps=args.stop_slippage_bps,
                   sensitivity=not args.no_sensitivity, walk_forward=args.walk_forward, min_trades=args.min_trades)
    _logging_mod.getLogger("tradebot").setLevel(_logging_mod.WARNING)  # per-fill sim logs would drown progress
    reports = []
    for minutes, fs in sorted(by_tf.items()):
        bars = load_dir(data, suffix=f"_{minutes}min.csv")  # one timeframe in memory at a time
        bars = {k.replace("-", "/"): v for k, v in bars.items()}
        for f in fs:
            print(f"== {loaded[f].name} ({minutes}-min, {len(bars)} symbols on disk)", flush=True)
            rep = run_strategy(s, f, {minutes: bars}, opts, progress=lambda m: print("   " + m, flush=True))
            print(f"   -> {rep.verdict}  OOS return {rep.oos.total_return:+.1%}  Sharpe {rep.oos.sharpe:.2f}  "
                  f"maxDD {rep.oos.max_dd:.1%}  trades {rep.full.trades}  {rep.error}", flush=True)
            reports.append(rep)
        del bars
    out = Path(args.out) if args.out else s.data_dir / "research_report.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(reports, opts))
    out.with_suffix(".json").write_text(_json.dumps(to_json(reports), indent=1, default=str))
    print(f"\nreport -> {out}\njson   -> {out.with_suffix('.json')}")


def cmd_report(args) -> None:
    """Why are trades losing? Hold time, stop distance and exit reason for the live journal."""
    s = _settings(args)
    from collections import Counter
    from .journal import Journal
    from .models import px
    trades = [t for t in Journal(args.journal or s.journal_file).load() if t.status == "CLOSED"]
    if args.last:
        trades = trades[-args.last:]
    if not trades:
        print(f"no closed trades in {args.journal or s.journal_file}")
        return
    wins = [t for t in trades if t.realized_pnl > 0]
    total_r = sum(t.r_multiple for t in trades)
    pnl = sum(t.realized_pnl for t in trades)
    print(f"{len(trades)} closed · {len(wins)} profitable · total {total_r:+.2f}R · ${pnl:+,.2f}")
    holds = []
    print(f"{'symbol':<10}{'entry (ET)':<13}{'hold':>7}{'entry':>12}{'stop':>12}{'stop %':>8}{'best R':>8}"
          f"{'exit':>12}{'R':>7}  exits")
    for t in trades:
        end = t.last_exit_time or t.entry_time
        mins = (end - t.entry_time).total_seconds() / 60.0
        holds.append(mins)
        stop_pct = (t.entry_price - t.stop_initial) / t.entry_price * 100.0 if t.entry_price else 0.0
        rps = t.risk_per_share or 1e-12
        best = (t.highest - t.entry_price) / rps if t.highest else 0.0
        reasons = ",".join(f.reason for f in t.exits)
        print(f"{t.symbol:<10}{t.entry_time:%m-%d %H:%M}  {mins:>6.0f}m{px(t.entry_price):>12}{px(t.stop_initial):>12}"
              f"{stop_pct:>7.2f}%{best:>+8.2f}{px(t.exit_price_avg):>12}{t.r_multiple:>+7.2f}  {reasons}")
    holds.sort()
    print(f"\nhold minutes: median {holds[len(holds)//2]:.0f}, shortest {holds[0]:.0f}, longest {holds[-1]:.0f}")
    print("exit reasons:", dict(Counter(t.exits[-1].reason for t in trades if t.exits)))
    never_green = sum(1 for t in trades if t.highest and t.highest <= t.entry_price)
    print(f"trades that never traded above entry: {never_green} of {len(trades)}")
    fast = sum(1 for h in holds if h <= 10)
    print(f"stopped within 10 minutes of entry: {fast} of {len(trades)}")
    import re as _re

    def kind(reason: str) -> str:  # which rule set opened the trade, from its signal text
        m = _re.search(r"\((\d+) bars\)", reason or "")
        if m:
            return f"{'fade' if (reason or '').startswith('fade') else 'breakout'} {m.group(1)} bars"
        return (reason or "?").split(" ")[0]
    print("entry rule sets seen:", dict(Counter(kind(t.reason) for t in trades)))


def cmd_backtest(args) -> None:
    s = _settings(args)
    _logging(s)
    from .backtest import Backtester
    from .dashboard import write_dashboard
    from .data import load_daily_dir, load_dir, synthetic_bars, synthetic_daily
    from .journal import Journal
    strategy_file = Path(args.strategy) if args.strategy else s.strategy_file
    loaded = load_strategy(strategy_file, s.allow_shorts)
    loaded.apply(s, validate=False)  # a simulation isn't bound by the broker's rules
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
            if loaded.universe and not args.symbols:
                bars = {k: v for k, v in bars.items() if k in loaded.universe}
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
    fee_bps = args.fee_bps if args.fee_bps is not None else (25.0 if loaded.continuous else 0.0)
    lam = args.stop_fill_lambda if args.stop_fill_lambda is not None else (0.5 if loaded.continuous else 0.0)
    sslip = args.stop_slippage_bps if args.stop_slippage_bps is not None else (20.0 if loaded.continuous else 0.0)
    bt = Backtester(s, loaded, bars, daily=daily, equity=args.equity, fee_bps=fee_bps, stop_fill_lambda=lam,
                    stop_slippage_bps=sslip)
    from datetime import date as _date
    start = _date.fromisoformat(args.start) if args.start else None
    end = _date.fromisoformat(args.end) if args.end else None
    res = bt.run(start, end)
    st = res.stats
    params = loaded
    print(f"\n{loaded.name} · {res.days} days · {len(bars)} symbols · fees {fee_bps:.0f} bps/side · "
          f"stop fill lambda {lam:.2f} +{sslip:.0f} bps · {s.describe()}")
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
    from .analyze import default_grid, format_sweep, sweep
    from .data import load_daily_dir, load_dir
    import json as _json
    import logging as _logging
    strategy_file = Path(args.strategy) if args.strategy else s.strategy_file
    raw = _json.loads(strategy_file.read_text()) if strategy_file.exists() else {}
    crypto = raw.get("market") == "crypto"
    if crypto:
        from .crypto import CryptoRules
        params = CryptoRules.load(strategy_file)
        suffix = f"_{params.bar_minutes}min.csv"
    elif "strategy_name" in raw or "daily_filters" in raw:
        from .tjl import TJLRules
        params = TJLRules.load(strategy_file)
        suffix = "_5min.csv"
    else:
        params = StrategyParams.load(strategy_file)
        suffix = "_5min.csv"
    bars = load_dir(args.data, suffix=suffix)
    daily = load_daily_dir(args.data) or None
    if crypto:
        bars = {k.replace("-", "/"): v for k, v in bars.items()}
        if params.universe and not args.symbols:
            bars = {k: v for k, v in bars.items() if k in params.universe}
        daily = {k.replace("-", "/"): v for k, v in daily.items()} if daily else None
    if args.symbols:
        bars = {k: v for k, v in bars.items() if k in args.symbols}
    if not bars:
        print(f"No *{suffix} files in {args.data}. Run `fetch-data`/`fetch-crypto` first.")
        sys.exit(1)
    grid = _json.loads(args.grid) if args.grid else default_grid(params)
    fee_bps = args.fee_bps if args.fee_bps is not None else (25.0 if crypto else 0.0)
    n = 1
    for v in grid.values():
        n *= len(v)
    print(f"Sweeping {n} combinations over {len(bars)} symbols (base: {strategy_file}, fees {fee_bps:.0f} bps/side)...")
    _logging.getLogger("tradebot").setLevel(_logging.WARNING)  # the sim's per-fill INFO lines would drown the table
    lam = args.stop_fill_lambda if args.stop_fill_lambda is not None else (0.5 if crypto else 0.0)
    sslip = args.stop_slippage_bps if args.stop_slippage_bps is not None else (20.0 if crypto else 0.0)
    rows = sweep(s, params, bars, grid, equity=args.equity, daily=daily, fee_bps=fee_bps,
                 stop_fill_lambda=lam, stop_slippage_bps=sslip,
                 progress=lambda i, n, combo: print(f"  [{i}/{n}] {combo}", flush=True))
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
    p.add_argument("--strategy", help="rules file whose bar size/universe to fetch (default STRATEGY_FILE)")
    p = sub.add_parser("crypto-explain", help="why isn't the crypto bot trading? count the gate that rejected each bar")
    p.add_argument("--days", type=int, default=3)
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--strategy", help="rules file to replay instead of STRATEGY_FILE (e.g. crypto_15m.json)")
    p = sub.add_parser("news", help="World Monitor: macro calendar, headlines, earnings (or --raw JSON)")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--variant", default="finance")
    p.add_argument("--days", type=int, default=3)
    p.add_argument("--limit", type=int, default=15)
    p.add_argument("--raw", action="store_true", help="print raw API responses (to check the data format)")
    p.add_argument("--raw-chars", type=int, default=2500)
    p.add_argument("--worldmonitor", action="store_true", help="query World Monitor even without a key")
    p = sub.add_parser("research", help="rank strategies: in/out-of-sample, benchmark, sensitivity, report")
    p.add_argument("--strategies", nargs="+", default=["strategies/*.json", "crypto_swing.json"],
                   help="rules files or globs to evaluate")
    p.add_argument("--data", default="data/research", help="bar CSVs, one file per symbol per timeframe")
    p.add_argument("--fetch-days", type=int, default=0, help="download this many days of crypto bars first")
    p.add_argument("--refetch", action="store_true", help="re-download even if the CSV exists")
    p.add_argument("--max-intraday-days", type=int, default=180,
                   help="cap history for sub-hourly bars (memory on small servers)")
    p.add_argument("--equity", type=float, default=3560)
    p.add_argument("--oos-frac", type=float, default=0.33)
    p.add_argument("--walk-forward", type=int, default=0, help="number of walk-forward folds (0 = off)")
    p.add_argument("--no-sensitivity", action="store_true")
    p.add_argument("--min-trades", type=int, default=30)
    p.add_argument("--fee-bps", type=float, default=None)
    p.add_argument("--stop-fill-lambda", type=float, default=None)
    p.add_argument("--stop-slippage-bps", type=float, default=None)
    p.add_argument("--out", help="report path (default DATA_DIR/research_report.md)")
    p = sub.add_parser("report", help="break down live trades: hold time, stop distance, exit reasons")
    p.add_argument("--journal", help="journal file (default: DATA_DIR/trades.jsonl)")
    p.add_argument("--last", type=int, default=0, help="only the most recent N trades")
    p = sub.add_parser("arb-monitor", help="measure cross-venue crypto spreads net of fees (Coinbase/Kraken/Alpaca)")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--minutes", type=float, default=0, help="stop after N minutes (default: run until ctrl-c)")
    p.add_argument("--report-every", type=int, default=60)
    p.add_argument("--dislocation-pct", type=float, default=0.5)
    p.add_argument("--fees", nargs="*", help="override taker fees, e.g. alpaca=25 coinbase=60 kraken=40")
    p = sub.add_parser("backtest", help="run the strategy over CSV history (or --demo synthetic data)")
    p.add_argument("--data", default="data/bars")
    p.add_argument("--symbols", nargs="*")
    p.add_argument("--days", type=int, default=60, help="(demo) days of synthetic data")
    p.add_argument("--equity", type=float, default=100_000)
    p.add_argument("--fee-bps", type=float, default=None,
                   help="per-side commission in bps (default 25 for crypto, 0 for equities)")
    p.add_argument("--stop-fill-lambda", type=float, default=None,
                   help="0 = stops fill at the stop price, 1 = at the bar low (default 0.5 crypto, 0 equities)")
    p.add_argument("--start", help="first trading date to include, YYYY-MM-DD (earlier bars still warm up indicators)")
    p.add_argument("--end", help="last trading date to include, YYYY-MM-DD")
    p.add_argument("--stop-slippage-bps", type=float, default=None,
                   help="extra adverse slip on stop fills (default 20 crypto, 0 equities)")
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
    p.add_argument("--fee-bps", type=float, default=None, help="per-side commission in bps (default 25 for crypto)")
    p.add_argument("--stop-fill-lambda", type=float, default=None)
    p.add_argument("--stop-slippage-bps", type=float, default=None)
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
     "fetch-gappers": cmd_fetch_gappers, "fetch-crypto": cmd_fetch_crypto,
     "crypto-explain": cmd_crypto_explain, "arb-monitor": cmd_arb_monitor, "report": cmd_report,
     "research": cmd_research, "news": cmd_news}[args.cmd](args)


if __name__ == "__main__":
    main()
