"""Systematic strategy research: in-sample / out-of-sample backtests, benchmark comparison,
parameter sensitivity, optional walk-forward, quality criteria and a ranked markdown report.

Everything runs on the same Backtester the live bot is judged by (fees, pessimistic stop fills,
real sizing), so a strategy that ranks well here is ranked on the costs it will actually pay.

Nothing in here tunes a strategy to look good: each rules file is evaluated with the parameters
it ships with. Sensitivity and walk-forward exist to catch settings that only work by luck.
"""

from __future__ import annotations

import copy
import itertools
import json
import math
from dataclasses import dataclass, field, replace
from datetime import date, timedelta
from pathlib import Path

from .backtest import Backtester, BacktestResult
from .models import Bar

# ---------------------------------------------------------------------------------------------
# metrics


@dataclass
class Metrics:
    start: date | None = None
    end: date | None = None
    days: int = 0
    trades: int = 0
    total_return: float = 0.0     # fraction, e.g. 0.12 = +12%
    cagr: float = 0.0
    sharpe: float = 0.0
    sortino: float = 0.0
    max_dd: float = 0.0           # fraction, negative
    vol: float = 0.0              # annualised volatility of daily returns
    win_rate: float = 0.0
    profit_factor: float = 0.0
    expectancy_r: float = 0.0
    total_r: float = 0.0
    trades_per_week: float = 0.0


def curve_metrics(curve: list[tuple[date, float]], start_equity: float, periods_per_year: int = 365) -> Metrics:
    """Return/risk metrics from a daily marked-to-market equity curve."""
    m = Metrics()
    if not curve or start_equity <= 0:
        return m
    eq = [start_equity] + [e for _, e in curve]
    rets = [eq[i] / eq[i - 1] - 1.0 for i in range(1, len(eq)) if eq[i - 1] > 0]
    m.start, m.end = curve[0][0], curve[-1][0]
    m.days = (m.end - m.start).days + 1
    m.total_return = eq[-1] / eq[0] - 1.0
    years = m.days / 365.25
    if years > 0 and eq[-1] > 0:
        m.cagr = (eq[-1] / eq[0]) ** (1.0 / years) - 1.0
    if len(rets) > 1:
        mean = sum(rets) / len(rets)
        var = sum((r - mean) ** 2 for r in rets) / (len(rets) - 1)
        sd = math.sqrt(var)
        m.vol = sd * math.sqrt(periods_per_year)
        if sd > 0:
            m.sharpe = mean / sd * math.sqrt(periods_per_year)
        down = math.sqrt(sum(min(r, 0.0) ** 2 for r in rets) / len(rets))
        if down > 0:
            m.sortino = mean / down * math.sqrt(periods_per_year)
    peak = eq[0]
    for e in eq:
        peak = max(peak, e)
        if peak > 0:
            m.max_dd = min(m.max_dd, e / peak - 1.0)
    return m


def result_metrics(res: BacktestResult, periods_per_year: int = 365) -> Metrics:
    m = curve_metrics(res.equity_curve, res.start_equity, periods_per_year)
    st = res.stats
    m.trades = st.trades
    m.win_rate = st.win_rate
    m.profit_factor = st.profit_factor
    m.expectancy_r = st.expectancy_r
    m.total_r = st.total_r
    if m.days:
        m.trades_per_week = st.trades / (m.days / 7.0)
    return m


def daily_closes(bars: list[Bar]) -> dict[date, float]:
    """Last close per calendar date (ET), from bars of any timeframe."""
    out: dict[date, float] = {}
    for b in bars:
        out[b.time.date()] = b.close
    return out


def benchmark_curve(bars: dict[str, list[Bar]], start: date, end: date,
                    start_equity: float) -> list[tuple[date, float]]:
    """Equal-weight buy-and-hold of every symbol, bought at the first close on/after ``start``."""
    series = {s: daily_closes(b) for s, b in bars.items()}
    days = sorted({d for s in series.values() for d in s if start <= d <= end})
    if not days:
        return []
    base, last, curve = {}, {}, []
    for d in days:
        vals = []
        for sym, closes in series.items():
            if d in closes:
                last[sym] = closes[d]
                base.setdefault(sym, closes[d])
            if sym in base:
                vals.append(last[sym] / base[sym])
        if vals:
            curve.append((d, start_equity * sum(vals) / len(vals)))
    return curve


def regime(bars: dict[str, list[Bar]], start: date, end: date, lead: str = "BTC/USD") -> str:
    """One-line market description of a window, computed from the data (not an opinion)."""
    bm = curve_metrics(benchmark_curve(bars, start, end, 1.0), 1.0)
    trend = ""
    if lead in bars:
        closes = daily_closes(bars[lead])
        hist = [c for d, c in sorted(closes.items()) if d <= end]
        if len(hist) >= 50:
            sma50 = sum(hist[-50:]) / 50
            trend = f"; {lead} ended {'above' if hist[-1] > sma50 else 'below'} its 50-day average"
    kind = "rising" if bm.total_return > 0.05 else ("falling" if bm.total_return < -0.05 else "sideways")
    return (f"{kind} ({bm.total_return:+.0%} equal-weight, {bm.vol:.0%} annualised volatility, "
            f"max drawdown {bm.max_dd:.0%}){trend}")


# ---------------------------------------------------------------------------------------------
# running


@dataclass
class Options:
    equity: float = 3560.0
    oos_frac: float = 0.33
    fee_bps: float | None = None
    stop_fill_lambda: float | None = None
    stop_slippage_bps: float | None = None
    sensitivity: bool = True
    walk_forward: int = 0
    min_trades: int = 30
    periods_per_year: int = 365


@dataclass
class StrategyReport:
    path: str
    name: str
    timeframe: str
    thesis: str = ""
    risks: str = ""
    tuned: str = ""
    params: dict = field(default_factory=dict)
    window: tuple = ()
    split: date | None = None
    full: Metrics = field(default_factory=Metrics)
    ins: Metrics = field(default_factory=Metrics)
    oos: Metrics = field(default_factory=Metrics)
    bench_ins: Metrics = field(default_factory=Metrics)
    bench_oos: Metrics = field(default_factory=Metrics)
    regime_ins: str = ""
    regime_oos: str = ""
    sensitivity: list = field(default_factory=list)  # [(param, value, total_return, pf, trades)]
    walk_forward: dict = field(default_factory=dict)
    criteria: dict = field(default_factory=dict)       # name -> (passed: bool, detail)
    score: int = 0
    verdict: str = ""
    error: str = ""


def _timeframe(minutes: int) -> str:
    if minutes % 1440 == 0:
        return f"{minutes // 1440}d"
    if minutes % 60 == 0:
        return f"{minutes // 60}h"
    return f"{minutes}m"


def _costs(loaded, opts: Options) -> tuple[float, float, float]:
    from .backtest import default_costs
    fee, lam, slip = default_costs(loaded)
    return (opts.fee_bps if opts.fee_bps is not None else fee,
            opts.stop_fill_lambda if opts.stop_fill_lambda is not None else lam,
            opts.stop_slippage_bps if opts.stop_slippage_bps is not None else slip)


def _backtest(settings, loaded, bars, opts: Options, start: date, end: date) -> BacktestResult:
    s = copy.deepcopy(settings)
    ld = copy.deepcopy(loaded)
    ld.apply(s, validate=False)
    fee, lam, slip = _costs(ld, opts)
    bt = Backtester(s, ld, bars, equity=opts.equity, fee_bps=fee, stop_fill_lambda=lam, stop_slippage_bps=slip)
    return bt.run(start, end)


SENSITIVE = {  # parameters worth perturbing, by entry mode
    "breakout": ["breakout_bars", "trend_ema_bars", "stop_atr_mult", "min_initial_risk_pct", "min_rel_volume"],
    "pullback": ["rsi_buy", "trend_ema_bars", "stop_atr_mult", "final_target_r"],
    "squeeze": ["squeeze_pct", "box_bars", "trend_ema_bars", "stop_atr_mult"],
    "fade": ["breakout_bars", "stop_atr_mult", "min_initial_risk_pct"],
}


def _perturbations(rules) -> list[tuple[str, object]]:
    out = []
    for name in SENSITIVE.get(getattr(rules, "mode", "breakout"), []):
        v = getattr(rules, name, None)
        if not isinstance(v, (int, float)) or v == 0:
            continue
        for f in (0.75, 1.25):
            nv = max(1, round(v * f)) if isinstance(v, int) else round(v * f, 4)
            if nv != v:
                out.append((name, nv))
    trail = getattr(rules, "trail", "")
    if isinstance(trail, str) and trail.startswith("atr_"):
        mult = float(trail[4:])
        out += [("trail", f"atr_{mult * 0.75:.2f}"), ("trail", f"atr_{mult * 1.25:.2f}")]
    return out


def _crypto_rules(loaded):
    return getattr(getattr(loaded, "strategy", None), "r", None) if loaded.continuous else None


def run_strategy(settings, path: str | Path, bars_by_tf: dict[int, dict[str, list[Bar]]],
                 opts: Options, progress=None) -> StrategyReport:
    from .strategy import load_strategy
    from .crypto import loaded_from_rules

    loaded = load_strategy(path)
    strat = loaded.strategy
    minutes = getattr(strat, "bar_minutes", 5)
    rules = _crypto_rules(loaded)
    rep = StrategyReport(path=str(path), name=loaded.name, timeframe=_timeframe(minutes))
    raw = json.loads(Path(path).read_text())
    rep.thesis = raw.get("thesis", "") or getattr(rules, "thesis", "")
    rep.risks = raw.get("risks", "") or getattr(rules, "risks", "")
    rep.tuned = raw.get("tuned", "")
    if rules is not None:
        rep.params = {k: getattr(rules, k) for k in (
            "mode", "bar_minutes", "breakout_bars", "trend_ema_bars", "min_rel_volume", "stop_atr_mult",
            "min_initial_risk_pct", "max_initial_risk_pct", "rsi_bars", "rsi_buy", "squeeze_pct", "box_bars",
            "partial_r", "breakeven_r", "trail", "trail_from_entry", "final_target_r", "time_stop_minutes",
            "max_risk_per_trade_pct", "max_positions")}
    bars = bars_by_tf.get(minutes) or {}
    universe = loaded.universe or list(bars)
    bars = {k: v for k, v in bars.items() if k in universe}
    if not bars:
        rep.error = f"no {minutes}-minute data for {rep.name}"
        rep.verdict = "NO DATA"
        return rep
    first = min(b[0].time.date() for b in bars.values() if b)
    last = max(b[-1].time.date() for b in bars.values() if b)
    start = first + timedelta(days=int(loaded.intraday_days) + 1)  # indicator warm-up
    if start >= last:
        rep.error = f"not enough history: need {loaded.intraday_days} warm-up days, have {(last - first).days}"
        rep.verdict = "NO DATA"
        return rep
    split = start + timedelta(days=int((last - start).days * (1.0 - opts.oos_frac)))
    rep.window, rep.split = (start, last), split
    say = progress or (lambda msg: None)

    say(f"{rep.name}: full period {start}..{last}")
    rep.full = result_metrics(_backtest(settings, loaded, bars, opts, start, last), opts.periods_per_year)
    say(f"{rep.name}: in-sample {start}..{split - timedelta(days=1)}")
    rep.ins = result_metrics(_backtest(settings, loaded, bars, opts, start, split - timedelta(days=1)),
                             opts.periods_per_year)
    say(f"{rep.name}: out-of-sample {split}..{last}")
    rep.oos = result_metrics(_backtest(settings, loaded, bars, opts, split, last), opts.periods_per_year)
    rep.bench_ins = curve_metrics(benchmark_curve(bars, start, split - timedelta(days=1), opts.equity), opts.equity,
                                  opts.periods_per_year)
    rep.bench_oos = curve_metrics(benchmark_curve(bars, split, last, opts.equity), opts.equity, opts.periods_per_year)
    rep.regime_ins = regime(bars, start, split - timedelta(days=1))
    rep.regime_oos = regime(bars, split, last)

    if opts.sensitivity and rules is not None:
        for name, value in _perturbations(rules):
            say(f"{rep.name}: sensitivity {name}={value}")
            variant = loaded_from_rules(replace(rules, **{name: value}))
            m = result_metrics(_backtest(settings, variant, bars, opts, start, last), opts.periods_per_year)
            rep.sensitivity.append((name, value, m.total_return, m.profit_factor, m.trades))

    if opts.walk_forward and rules is not None:
        rep.walk_forward = _walk_forward(settings, rules, bars, opts, start, last, say)

    judge(rep, opts)
    return rep


def _walk_forward(settings, rules, bars, opts: Options, start: date, end: date, say) -> dict:
    """Split the period into k+1 blocks; for each block i>0 pick the best nearby setting on block i-1
    and trade it, untouched, on block i. The stitched test blocks are what re-tuning would really earn."""
    from .crypto import loaded_from_rules

    k = opts.walk_forward
    span = (end - start).days
    edges = [start + timedelta(days=int(span * i / (k + 1))) for i in range(k + 2)]
    names = [n for n in SENSITIVE.get(rules.mode, []) if isinstance(getattr(rules, n, None), (int, float))
             and getattr(rules, n)][:2]
    grid = []
    for combo in itertools.product(*[(0.75, 1.0, 1.25)] * len(names)):
        ch = {}
        for n, f in zip(names, combo):
            v = getattr(rules, n)
            ch[n] = max(1, round(v * f)) if isinstance(v, int) else round(v * f, 4)
        grid.append(ch)
    folds, equity, curve, trades = [], opts.equity, [], 0
    for i in range(1, k + 1):
        tr_s, tr_e = edges[i - 1], edges[i] - timedelta(days=1)
        te_s, te_e = edges[i], (edges[i + 1] - timedelta(days=1)) if i < k else end
        best, best_key = None, None
        for ch in grid:
            m = result_metrics(_backtest(settings, loaded_from_rules(replace(rules, **ch)), bars, opts, tr_s, tr_e))
            key = (m.trades >= 5, m.profit_factor if m.profit_factor != float("inf") else 99.0, m.total_return)
            if best_key is None or key > best_key:
                best, best_key = ch, key
        say(f"walk-forward fold {i}/{k}: trained {tr_s}..{tr_e} -> {best}; testing {te_s}..{te_e}")
        fold_opts = replace(opts, equity=equity)
        res = _backtest(settings, loaded_from_rules(replace(rules, **best)), bars, fold_opts, te_s, te_e)
        m = result_metrics(res, opts.periods_per_year)
        folds.append({"train": f"{tr_s}..{tr_e}", "test": f"{te_s}..{te_e}", "chosen": best,
                      "return": m.total_return, "pf": m.profit_factor, "trades": m.trades})
        curve += res.equity_curve
        equity = res.end_equity
        trades += m.trades
    stitched = curve_metrics(curve, opts.equity, opts.periods_per_year)
    stitched.trades = trades
    return {"folds": folds, "metrics": stitched}


# ---------------------------------------------------------------------------------------------
# judging


def judge(rep: StrategyReport, opts: Options) -> None:
    """The prompt's quality bar, applied mechanically."""
    c = {}
    c["beats benchmark (risk-adjusted, out of sample)"] = (
        rep.oos.sharpe > rep.bench_oos.sharpe,
        f"Sharpe {rep.oos.sharpe:.2f} vs buy-and-hold {rep.bench_oos.sharpe:.2f}; "
        f"return {rep.oos.total_return:+.1%} vs {rep.bench_oos.total_return:+.1%}")
    c["Sharpe above 1.0 (out of sample)"] = (rep.oos.sharpe > 1.0, f"{rep.oos.sharpe:.2f}")
    worst = min(rep.ins.max_dd, rep.oos.max_dd, rep.full.max_dd)
    c["max drawdown under 30%"] = (worst > -0.30, f"worst {worst:.1%}")
    c["profitable in and out of sample"] = (
        rep.ins.total_return > 0 and rep.oos.total_return > 0,
        f"in {rep.ins.total_return:+.1%}, out {rep.oos.total_return:+.1%}")
    if rep.sensitivity:
        ok = sum(1 for _, _, r, _, _ in rep.sensitivity if r > 0)
        c["robust to parameter changes (70%+ of variants profitable)"] = (
            ok / len(rep.sensitivity) >= 0.7, f"{ok} of {len(rep.sensitivity)} variants profitable")
    if rep.walk_forward:
        wf = rep.walk_forward["metrics"]
        c["walk-forward profitable"] = (wf.total_return > 0, f"{wf.total_return:+.1%}, Sharpe {wf.sharpe:.2f}")
    c[f"enough trades ({opts.min_trades}+)"] = (rep.full.trades >= opts.min_trades, f"{rep.full.trades} trades")
    c["stated economic rationale"] = (bool(rep.thesis), "yes" if rep.thesis else "missing")
    rep.criteria = c
    rep.score = sum(1 for ok, _ in c.values() if ok)
    hard = ("profitable in and out of sample", "max drawdown under 30%", f"enough trades ({opts.min_trades}+)")
    if all(c[h][0] for h in hard) and rep.score == len(c):
        rep.verdict = "DEPLOY CANDIDATE"
    elif all(c[h][0] for h in hard):
        rep.verdict = "PAPER-TRADE / WATCH"
    else:
        rep.verdict = "REJECT"


# ---------------------------------------------------------------------------------------------
# report


def _pct(x: float) -> str:
    return f"{x:+.1%}"


def _pf(x: float) -> str:
    return "inf" if x == float("inf") else f"{x:.2f}"


def _mrow(label: str, m: Metrics) -> str:
    return (f"| {label} | {m.start}..{m.end} | {m.trades} | {_pct(m.total_return)} | {_pct(m.cagr)} | "
            f"{m.sharpe:.2f} | {m.sortino:.2f} | {m.max_dd:.1%} | {m.win_rate:.0%} | {_pf(m.profit_factor)} |")


def render(reports: list[StrategyReport], opts: Options, notes: str = "") -> str:
    ranked = sorted(reports, key=lambda r: ({"DEPLOY CANDIDATE": 0, "PAPER-TRADE / WATCH": 1, "REJECT": 2}
                                            .get(r.verdict, 3), -r.score, -r.oos.sharpe))
    L = ["# Strategy research report", ""]
    fee = "25 bps/side" if opts.fee_bps is None else f"{opts.fee_bps:.0f} bps/side"
    L += [f"Costs: fees {fee} (crypto default; a rules file's own \"costs\" block overrides it, e.g. gold/forex), "
          "stops filled halfway to the bar's extreme plus slippage, "
          f"entries at the signal bar close plus fees. Starting equity ${opts.equity:,.0f}. "
          f"Equity is marked to market daily. Out-of-sample = last {opts.oos_frac:.0%} of each window. "
          "Parameters are the ones in each rules file; nothing was tuned on the out-of-sample data "
          "unless the strategy notes say otherwise.", ""]
    if notes:
        L += [notes, ""]

    L += ["## 1. Executive summary", "",
          "| Rank | Strategy | TF | Verdict | Criteria | OOS return | OOS Sharpe | OOS max DD | OOS PF | Trades/wk |",
          "|---|---|---|---|---|---|---|---|---|---|"]
    for i, r in enumerate(ranked, 1):
        L.append(f"| {i} | {r.name} | {r.timeframe} | {r.verdict} | {r.score}/{len(r.criteria) or '-'} | "
                 f"{_pct(r.oos.total_return)} | {r.oos.sharpe:.2f} | {r.oos.max_dd:.1%} | "
                 f"{_pf(r.oos.profit_factor)} | {r.full.trades_per_week:.1f} |")
    good = [r for r in ranked if r.verdict == "DEPLOY CANDIDATE"]
    watch = [r for r in ranked if r.verdict == "PAPER-TRADE / WATCH"]
    L += ["", (f"{len(good)} strategy(ies) met every criterion." if good else
               "No strategy met every criterion.") +
          (f" {len(watch)} passed the hard criteria and are worth paper-trading." if watch else ""), ""]

    L += ["## 2. Market analysis", "", "Computed from the same bars the strategies traded.", ""]
    seen = set()
    for r in ranked:
        key = (r.timeframe, r.window)
        if r.window and key not in seen:
            seen.add(key)
            L.append(f"- **{r.timeframe} window {r.window[0]}..{r.window[1]}.** In-sample: {r.regime_ins}. "
                     f"Out-of-sample: {r.regime_oos}.")
    L.append("")

    L += ["## 3. Strategy details", ""]
    for r in ranked:
        L += [f"### {r.name} ({r.timeframe})", "", f"File: `{r.path}`", ""]
        if r.error:
            L += [f"Not evaluated: {r.error}", ""]
            continue
        L += [f"**Thesis.** {r.thesis or 'not stated'}", ""]
        if r.tuned:
            L += [f"**Tuning note.** {r.tuned}", ""]
        if r.params:
            L.append("**Rules.** " + ", ".join(f"{k}={v}" for k, v in r.params.items()
                                              if v not in (None, "", 0, 0.0) or k in ("partial_r", "breakeven_r")))
            L.append("")

    L += ["## 4. Backtest results", ""]
    for r in ranked:
        if r.error:
            continue
        L += [f"### {r.name} ({r.timeframe})", "",
              "| Period | Dates | Trades | Return | CAGR | Sharpe | Sortino | Max DD | Win | PF |",
              "|---|---|---|---|---|---|---|---|---|---|",
              _mrow("Full", r.full), _mrow("In-sample", r.ins), _mrow("Out-of-sample", r.oos),
              _mrow("Buy & hold (in)", r.bench_ins), _mrow("Buy & hold (out)", r.bench_oos), ""]
        if r.sensitivity:
            L += ["Sensitivity (full period, one setting changed at a time):", "",
                  "| Setting | Value | Return | PF | Trades |", "|---|---|---|---|---|"]
            for name, value, ret, pf, n in r.sensitivity:
                L.append(f"| {name} | {value} | {_pct(ret)} | {_pf(pf)} | {n} |")
            L.append("")
        if r.walk_forward:
            wf = r.walk_forward["metrics"]
            L += [f"Walk-forward (re-picked each block from nearby settings, traded on the next block): "
                  f"return {_pct(wf.total_return)}, Sharpe {wf.sharpe:.2f}, max DD {wf.max_dd:.1%}, "
                  f"{wf.trades} trades.", "", "| Train | Test | Chosen | Return | PF | Trades |",
                  "|---|---|---|---|---|---|"]
            for f in r.walk_forward["folds"]:
                L.append(f"| {f['train']} | {f['test']} | {f['chosen']} | {_pct(f['return'])} | "
                         f"{_pf(f['pf'])} | {f['trades']} |")
            L.append("")
        L += ["Criteria:", ""] + [f"- {'PASS' if ok else 'FAIL'}: {name} ({detail})"
                                  for name, (ok, detail) in r.criteria.items()] + [""]

    L += ["## 5. Comparison and ranking", "",
          "Ranked by verdict, then criteria passed, then out-of-sample Sharpe. Hard criteria: profitable "
          "both in and out of sample, max drawdown under 30%, and enough trades to mean something.", ""]
    for i, r in enumerate(ranked, 1):
        fails = [n for n, (ok, _) in r.criteria.items() if not ok]
        L.append(f"{i}. **{r.name} ({r.timeframe})**: {r.verdict}. "
                 + (f"Fails: {'; '.join(fails)}." if fails else "Passes every criterion."))
    L.append("")

    L += ["## 6. Final recommendations", ""]
    top = (good + watch)[:5]
    if top:
        for r in top:
            L.append(f"- **{r.name} ({r.timeframe})**: {r.verdict.lower()}. Out of sample it returned "
                     f"{_pct(r.oos.total_return)} with Sharpe {r.oos.sharpe:.2f} and a {r.oos.max_dd:.1%} "
                     f"worst drawdown, about {r.full.trades_per_week:.1f} trades a week.")
    else:
        L.append("- Nothing here is ready for live money. Keep capital out, or in buy-and-hold if you want the "
                 "market's return, until a strategy clears the hard criteria on data it was not built on.")
    L.append("")

    L += ["## 7. Deployment considerations", "",
          "- Paper-trade any candidate for at least 30 live trades before real money, and compare the live "
          "fee-inclusive R per trade with the out-of-sample figure above.",
          "- Size from the rules file's risk per trade; drawdowns above scale linearly with it.",
          "- Candidates on the same coins are correlated: running several at once does not diversify "
          "much, so cap total open risk across strategies.",
          "- Re-run this report monthly. Retire a strategy whose live results fall outside its "
          "backtested range for two months running.", ""]

    L += ["## 8. What could go wrong", ""]
    for r in ranked:
        if r.risks:
            L.append(f"- **{r.name}**: {r.risks}")
    L += ["- **All strategies**: a regime unlike the test window (a long bear market, a volatility collapse), "
          "exchange outages, spreads wider than modelled on thin pairs, and the backtest's daily-bar "
          "assumptions about the order in which a bar's high and low were reached.",
          "- **Sample size**: two years of crypto is one or two market cycles. A strategy that only worked "
          "in one of them is fragile even if its numbers look good.", ""]
    return "\n".join(L)


def to_json(reports: list[StrategyReport]) -> list[dict]:
    def m(x: Metrics) -> dict:
        d = {k: getattr(x, k) for k in x.__dataclass_fields__}
        d["start"], d["end"] = str(x.start), str(x.end)
        if d["profit_factor"] == float("inf"):
            d["profit_factor"] = None
        return d
    out = []
    for r in reports:
        out.append({"name": r.name, "path": r.path, "timeframe": r.timeframe, "verdict": r.verdict,
                    "score": r.score, "error": r.error, "full": m(r.full), "in_sample": m(r.ins),
                    "out_of_sample": m(r.oos), "benchmark_in": m(r.bench_ins), "benchmark_out": m(r.bench_oos),
                    "criteria": {k: {"pass": ok, "detail": d} for k, (ok, d) in r.criteria.items()},
                    "sensitivity": [{"param": n, "value": v, "return": ret,
                                     "pf": None if pf == float("inf") else pf, "trades": t}
                                    for n, v, ret, pf, t in r.sensitivity]})
    return out
