"""Self-contained HTML dashboard: R multiple per trade, cumulative R curve,
headline stats and a trade table. No external assets; open the file directly.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from .clock import now_et
from .journal import compute_stats
from .models import TradeRecord


def trade_rows(trades: list[TradeRecord]) -> list[dict]:
    rows = []
    for i, t in enumerate(sorted(trades, key=lambda t: t.entry_time), start=1):
        rows.append({
            "n": i, "id": t.id, "symbol": t.symbol, "side": t.side, "qty": t.qty_initial,
            "date": t.entry_time.strftime("%Y-%m-%d"), "entry_time": t.entry_time.strftime("%H:%M"),
            "exit_time": t.last_exit_time.strftime("%H:%M") if t.last_exit_time else "",
            "entry": round(t.entry_price, 2), "stop": round(t.stop_initial, 2),
            "exit": round(t.exit_price_avg, 2) if t.exit_price_avg else None,
            "r": round(t.r_multiple, 2), "pnl": round(t.realized_pnl, 2),
            "risk": round(t.initial_risk_usd, 2),
            "exits": ", ".join(f"{f.reason} {f.qty}@{f.price:.2f}" for f in t.exits),
            "reason": t.reason,
        })
    return rows


def render(trades: list[TradeRecord], title: str = "Trading Bot", generated: datetime | None = None) -> str:
    closed = [t for t in trades if t.status == "CLOSED"]
    rows = trade_rows(closed)
    stats = compute_stats(closed).as_dict()
    if stats["profit_factor"] == float("inf"):
        stats["profit_factor"] = None
    generated = generated or now_et()
    data = json.dumps({"rows": rows, "stats": stats}).replace("</", "<\\/")
    return _template().replace("__TITLE__", title).replace("__DATA__", data) \
        .replace("__GENERATED__", generated.strftime("%Y-%m-%d %H:%M ET"))


def write_dashboard(trades: list[TradeRecord], out: str | Path, title: str = "Trading Bot") -> Path:
    p = Path(out)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(render(trades, title), encoding="utf-8")
    return p


def trades_payload(trades: list[TradeRecord]) -> dict:
    """The same rows/stats the page embeds, as a standalone JSON document."""
    closed = [t for t in trades if t.status == "CLOSED"]
    stats = compute_stats(closed).as_dict()
    if stats["profit_factor"] == float("inf"):
        stats["profit_factor"] = None
    return {"rows": trade_rows(closed), "stats": stats}


def export_static(out_dir: str | Path, data_url: str | list[tuple[str, str]], title: str = "Trading Bot") -> Path:
    """Write a hostable copy (e.g. for Vercel) that loads trades.json and
    live.json from remote URLs instead of embedding them. ``data_url`` is one
    base URL, or a list of (name, base_url) for a multi-bot page with tabs."""
    d = Path(out_dir)
    d.mkdir(parents=True, exist_ok=True)
    html = _template().replace("__TITLE__", title).replace("__DATA__", "null") \
        .replace("__GENERATED__", "live")
    html = html.replace("<script>\nconst EMBEDDED", '<script src="config.js"></script>\n<script>\nconst EMBEDDED', 1)
    (d / "index.html").write_text(html, encoding="utf-8")
    if isinstance(data_url, str):
        cfg = f'window.DATA_BASE = {json.dumps(data_url)};\n'
    else:
        cfg = "window.DATA_SOURCES = " + json.dumps([{"name": n, "base": u} for n, u in data_url], indent=2) + ";\n"
    (d / "config.js").write_text(cfg, encoding="utf-8")
    (d / "vercel.json").write_text(json.dumps({
        "$schema": "https://openapi.vercel.sh/vercel.json", "framework": None, "buildCommand": None,
        "installCommand": None, "outputDirectory": ".",
        "headers": [{"source": "/(.*)", "headers": [{"key": "Cache-Control", "value": "no-cache"}]}],
    }, indent=2) + "\n", encoding="utf-8")
    return d / "index.html"


def _template() -> str:
    return (Path(__file__).with_name("dashboard.html")).read_text(encoding="utf-8")
