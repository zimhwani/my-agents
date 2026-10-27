"""Gold Swarm: show the MT5 gold EAs on the hosted dashboard's Gold tab.

The EAs (GS_USOpen, GS_Trend) run in MetaTrader 5 on a Deriv demo account and
log every decision and fill to CSV. The Gold Swarm lab turns those logs into
one JSON feed. This module converts that feed into the two documents the
hosted dashboard already reads for every tab - ``live.json`` (right now) and
``trades.json`` (closed trades) - and uploads them under the gold prefix.

Display only: nothing here places, changes or closes an order.

    python -m tradebot --env .env.gold goldswarm-publish --feed data-goldswarm/feed.json
"""
from __future__ import annotations

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

ET = ZoneInfo("America/New_York")
CONTRACT_OZ = 100.0                     # MT5 XAUUSD: 1 lot = 100 oz
LABELS = {"GS_USOpen": "XAUUSD·USOpen", "GS_Trend": "XAUUSD·Trend"}
ERRORS = {"HALT", "OPEN_FAIL", "EXIT_FAIL", "TRAIL_FAIL"}
WARNINGS = {"SKIP"}


def _srv(ts: str) -> datetime:
    """MT5 server time (Deriv = UTC) 'YYYY-MM-DD HH:MM:SS' -> aware UTC datetime."""
    return datetime.strptime(ts, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)


def _label(name: str) -> str:
    return LABELS.get(name, f"XAUUSD·{name.removeprefix('GS_')}")


def _f(x, default: float = 0.0) -> float:
    try:
        return float(x) if x is not None else default
    except (TypeError, ValueError):
        return default


def closed_rows(feed: dict) -> list[dict]:
    """Every closed EA trade as a dashboard trade row, oldest first, numbered."""
    rows = []
    for name, ea in (feed.get("eas") or {}).items():
        for t in ea.get("trades") or []:
            if not t.get("close_srv") or t.get("fill") is None or t.get("exit") is None:
                continue
            d = 1 if int(t.get("dir", 1)) > 0 else -1
            fill, exit_, dist, lots = _f(t["fill"]), _f(t["exit"]), _f(t.get("dist")), _f(t.get("lots"))
            pnl = t.get("profit")
            pnl = _f(pnl) + _f(t.get("swap")) if pnl is not None else (exit_ - fill) * d * lots * CONTRACT_OZ
            r = t.get("R")
            r = _f(r) if r is not None else ((exit_ - fill) * d / dist if dist else 0.0)
            e, x = _srv(t["open_srv"]).astimezone(ET), _srv(t["close_srv"]).astimezone(ET)
            rows.append({
                "id": f"{name}-{t['open_srv']}", "symbol": _label(name), "side": "LONG" if d > 0 else "SHORT",
                "qty": lots, "date": e.strftime("%Y-%m-%d"), "entry_time": e.strftime("%H:%M"),
                "exit_time": x.strftime("%H:%M"), "entry": round(fill, 2),
                "stop": round(fill - d * dist, 2), "exit": round(exit_, 2), "r": round(r, 2),
                "pnl": round(pnl, 2), "risk": round(_f(t.get("risk_usd"), dist * lots * CONTRACT_OZ), 2),
                "exits": f"{t.get('reason') or 'close'} {lots:g}@{exit_:.2f}", "reason": name,
                "_close_et": x,
            })
    rows.sort(key=lambda r: (r["date"], r["entry_time"], r["id"]))
    for i, r in enumerate(rows, start=1):
        r["n"] = i
    return rows


def _stats(rows: list[dict]) -> dict:
    rs = [r["r"] for r in rows]
    wins, losses = [x for x in rs if x > 0], [x for x in rs if x < 0]
    gl = -sum(losses)
    cum = peak = dd = 0.0
    for x in rs:
        cum += x
        peak = max(peak, cum)
        dd = min(dd, cum - peak)
    return {"trades": len(rs), "win_rate": round(len(wins) / len(rs), 3) if rs else 0.0,
            "total_r": round(sum(rs), 2), "expectancy_r": round(sum(rs) / len(rs), 3) if rs else 0.0,
            "profit_factor": round(sum(wins) / gl, 2) if gl > 0 else None, "max_drawdown_r": round(dd, 2)}


def trades_doc(feed: dict) -> dict:
    rows = closed_rows(feed)
    return {"rows": [{k: v for k, v in r.items() if not k.startswith("_")} for r in rows], "stats": _stats(rows)}


def live_doc(feed: dict, start_equity: float = 10_000.0, now: datetime | None = None) -> dict:
    """The Gold tab's 'right now' snapshot, in the shape loop.write_live() produces."""
    now = (now or datetime.now(timezone.utc)).astimezone(ET)
    eas = feed.get("eas") or {}
    rows = closed_rows(feed)
    today = [r for r in rows if r["_close_et"].date() == now.date()]
    realized = sum(r["pnl"] for r in rows)
    realized_today = sum(r["pnl"] for r in today)
    bid = _f(feed.get("last_bid"))

    open_rows, blockers, log = [], [], []
    for name, ea in eas.items():
        o = ea.get("open")
        if o and o.get("fill") is not None:
            d = 1 if int(o.get("dir", 1)) > 0 else -1
            lots, fill, mark = _f(o.get("lots")), _f(o["fill"]), _f(o.get("mark"), bid)
            open_rows.append({
                "symbol": _label(name), "side": "LONG" if d > 0 else "SHORT", "qty": lots, "qty_initial": lots,
                "entry": round(fill, 2), "stop": round(_f(o.get("sl")), 2), "price": round(mark, 2),
                "r": round(_f(o.get("floatR")), 2), "pnl": round((mark - fill) * d * lots * CONTRACT_OZ, 2),
                "partial": False, "entry_time": _srv(o["open_srv"]).astimezone(ET).strftime("%H:%M"),
                "reason": name})
        short = name.removeprefix("GS_")
        if ea.get("halted"):
            blockers.append(f"{short}: HALTED (loss limit)")
        for k, v in (ea.get("alerts") or {}).items():
            blockers.append(f"{short}: {v}x {k}")
        chk = ea.get("lab_check") or {}
        if chk.get("checked") and chk.get("matched") != chk.get("checked"):
            blockers.append(f"{short}: {chk['checked'] - chk['matched']} decision(s) differ from the lab")
        for dec in ea.get("decisions") or []:
            if not dec.get("srv"):
                continue
            t = _srv(dec["srv"]).astimezone(ET)
            lvl = "E" if dec.get("event") in ERRORS else "W" if dec.get("event") in WARNINGS else "I"
            log.append((t, f"{t.strftime('%H:%M:%S')} {lvl} [{short}] {dec.get('event')} {dec.get('detail', '')}"))
    log.sort(key=lambda x: x[0])
    lines = [line for _, line in log][-60:]
    for name, ea in eas.items():
        chk = ea.get("lab_check") or {}
        if chk.get("summary"):
            lines.append(f"{now.strftime('%H:%M:%S')} {'W' if chk.get('issues') else 'I'} lab check: {chk['summary']}")

    data_through = feed.get("data_through_utc")
    if data_through:
        age_min = (now - _srv(data_through).astimezone(ET)).total_seconds() / 60
        if age_min > 30 and now.weekday() < 5:
            blockers.append(f"MT5 price data {age_min / 60:.1f} h old - is the terminal running?")

    float_pnl = sum(o["pnl"] for o in open_rows)
    return {
        "updated": now.isoformat(), "strategy": "Gold Swarm · MT5 EAs",
        "mode": f"{(feed.get('account') or {}).get('mode', 'demo')} · Deriv MT5 · " + " + ".join(eas),
        "currency": "USD", "chart": feed.get("chart"), "log": lines, "events": [],
        "equity": round(start_equity + realized + float_pnl, 2),
        "day_start_equity": round(start_equity + realized - realized_today, 2),
        "realized_r": round(sum(r["r"] for r in today), 2), "realized_pnl": round(realized_today, 2),
        "closed_today": len(today), "open": open_rows,
        "watchlist": [{"symbol": _label(n), "price": round(bid, 2), "gap_pct": 0.0, "atr_pct": 0.0} for n in eas],
        "blockers": blockers, "scanned": True, "day_done": False,
    }


def publish(feed: dict, publisher, start_equity: float = 10_000.0, now: datetime | None = None) -> tuple[bool, bool]:
    """Upload live.json and trades.json; returns (live_ok, trades_ok). Never raises."""
    live_ok = publisher.publish("live.json", live_doc(feed, start_equity, now), force=True)
    trades_ok = publisher.publish("trades.json", trades_doc(feed), force=True)
    return live_ok, trades_ok
