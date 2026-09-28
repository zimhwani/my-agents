"""World Monitor client: tolerant parsing, key header, blackout window, headline matching."""

import json
from datetime import datetime, timedelta

import pytest

from tradebot import clock
from tradebot.risk import DayStats, RiskGate
from tradebot.worldmonitor import (Headline, MacroEvent, WorldMonitor, blackout, mentions, parse_earnings,
                                   parse_economic, parse_headlines, watchlist_notes)


def test_parse_economic_handles_several_shapes():
    a = parse_economic({"events": [{"event": "CPI YoY", "country": "US", "impact": "high",
                                    "datetime": "2026-10-14T08:30:00-04:00"}]})
    b = parse_economic({"data": {"items": [{"name": "FOMC Rate Decision", "date": "2026-10-28", "time": "14:00"}]}})
    c = parse_economic([{"title": "German ZEW", "country": "DE", "importance": 2, "timestamp": 1791000000}])
    assert a[0].name == "CPI YoY" and a[0].time.hour == 8 and a[0].time.minute == 30 and a[0].high_impact and a[0].us
    assert b[0].time == datetime(2026, 10, 28, 14, 0, tzinfo=clock.ET) and b[0].high_impact  # by name
    assert c[0].time is not None and not c[0].us and not c[0].high_impact


def test_blackout_window_and_gate(settings):
    t = datetime(2026, 10, 14, 8, 30, tzinfo=clock.ET)
    ev = [MacroEvent(t, "CPI YoY", "US", "high"), MacroEvent(t, "UK CPI", "GB", "high"),
          MacroEvent(t + timedelta(hours=3), "Wholesale Inventories", "US", "low")]
    assert blackout(ev, t - timedelta(minutes=16), 15, 30) is None
    assert blackout(ev, t - timedelta(minutes=10), 15, 30).name == "CPI YoY"
    assert blackout(ev, t + timedelta(minutes=29), 15, 30) is not None
    assert blackout(ev, t + timedelta(minutes=31), 15, 30) is None
    assert blackout(ev, t + timedelta(hours=3), 15, 30) is None  # low impact
    gate = RiskGate(settings, honour_kill_switch=False)
    gate.macro_events = ev
    assert any("macro blackout: CPI YoY" in b for b in gate.blockers([], DayStats(start_equity=1000), 1000, t))
    gate.macro_events = []
    assert not any("macro" in b for b in gate.blockers([], DayStats(start_equity=1000), 1000, t))


def test_headlines_mentions_and_notes():
    heads = parse_headlines({"categories": {"finance": {"items": [
        {"title": "Kodiak (KOD) soars after trial data", "source": "Reuters", "publishedAt": "2026-09-28T12:00:00Z"},
        {"title": "Nvidia's NVDA hits record", "source": "CNBC"},
        {"title": "Markets wobble as KODAK files", "source": "AP"}]}}})
    assert len(heads) == 3 and heads[0].time is not None
    assert [h.source for h in mentions("KOD", heads)] == ["Reuters"]  # not KODAK
    assert mentions("P", [Headline("P rises"), Headline("$P jumps")])[0].title == "$P jumps"
    earn = parse_earnings({"earnings": [{"symbol": "nvda", "date": "2026-11-19"}]})
    notes = watchlist_notes(["KOD", "NVDA", "AMPX"], heads, earn)
    assert "KOD: Kodiak (KOD) soars" in notes and "NVDA: earnings 2026-11-19" in notes and "AMPX" not in notes


def test_client_sends_key_caches_and_explains_auth_errors():
    calls = []

    def transport(url, headers):
        calls.append((url, headers))
        if "economic" in url:
            return 200, json.dumps({"events": [{"event": "NFP", "datetime": "2026-10-02T08:30:00-04:00"}]}).encode()
        return 401, b"unauthorized"

    wm = WorldMonitor("k123", transport=transport)
    assert wm.economic_events()[0].name == "NFP" and wm.economic_events()[0].high_impact
    assert len(calls) == 1 and calls[0][1]["X-WorldMonitor-Key"] == "k123"
    assert calls[0][0].startswith("https://api.worldmonitor.app/api/economic/v1/get-economic-calendar")
    with pytest.raises(RuntimeError, match="API key"):
        wm.headlines()
    seen = []
    WorldMonitor("", transport=lambda u, h: (seen.append(h), (200, b"[]"))[1]).get("earnings_calendar")
    assert "X-WorldMonitor-Key" not in seen[0]  # no key configured -> no header


def test_free_sources_forex_factory_and_yahoo_rss(settings):
    from tradebot.worldmonitor import FreeNews, WorldMonitor, make_news, parse_rss
    ff = json.dumps([
        {"title": "CPI m/m", "country": "USD", "date": "2026-10-14T08:30:00-04:00", "impact": "High",
         "forecast": "0.3%", "previous": "0.4%"},
        {"title": "Bank Holiday", "country": "JPY", "date": "2026-10-12T00:00:00-04:00", "impact": "Holiday"},
        {"title": "Crude Oil Inventories", "country": "USD", "date": "2026-10-14T10:30:00-04:00", "impact": "Medium"}]).encode()
    rss = (b'<?xml version="1.0"?><rss><channel><title>x</title>'
           b'<item><title>Kodiak shares surge on trial win</title><link>http://y/1</link>'
           b'<pubDate>Mon, 28 Sep 2026 12:00:00 +0000</pubDate></item>'
           b'<item><title>Old story</title><pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate></item>'
           b'</channel></rss>')
    urls = []

    def transport(url, headers):
        urls.append(url)
        return (200, ff) if "faireconomy" in url else (200, rss)

    fn = FreeNews(transport=transport)
    ev = fn.economic_events()
    assert [e.name for e in ev if e.high_impact and e.us] == ["CPI m/m"]
    t = datetime(2026, 10, 14, 8, 30, tzinfo=clock.ET)
    assert blackout(ev, t - timedelta(minutes=5), 15, 30).name == "CPI m/m"
    heads = parse_rss(rss)
    assert heads[0].title.startswith("Kodiak") and heads[0].time.tzinfo is not None
    fn.economic_events()
    assert sum("faireconomy" in u for u in urls) == 1  # cached
    notes = fn.notes(["KOD", "BTC/USD"], max_age_hours=24 * 365 * 5)
    assert notes.startswith("KOD: Kodiak shares surge") and "BTC" not in notes
    assert parse_rss(b"not xml") == []
    assert isinstance(make_news(settings), FreeNews)
    settings.worldmonitor_api_key = "k"
    assert isinstance(make_news(settings), WorldMonitor)
