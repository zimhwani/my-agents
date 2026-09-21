import json

import pytest

from conftest import DAY
from tradebot import clock
from tradebot.dashboard import export_static, render, trades_payload
from tradebot.models import LONG, TradeRecord
from tradebot.publish import BlobPublisher, PublishError


def mk(i, r):
    t = TradeRecord(id=f"t{i}", symbol="T", side=LONG, qty_initial=10, entry_price=100.0,
                    entry_time=clock.at(DAY, clock.parse_hhmm("10:05")), stop_initial=99.0, stop=99.0,
                    target=102, atr=0.5, reason="TJL gap +4.0%")
    t.record_exit(t.entry_time, 10, 100.0 + r, "eod")
    return t


class FakeBlob:
    def __init__(self):
        self.store = {}
        self.calls = []
        self.conflict_once = False

    def __call__(self, method, url, headers, body):
        self.calls.append((method, url))
        assert headers["authorization"] == "Bearer TOK"
        if url.endswith("/delete"):
            return 200, b"{}"
        if self.conflict_once:
            self.conflict_once = False
            return 409, b'{"error":"blob already exists"}'
        name = url.split("blob.vercel-storage.com/")[1]
        self.store[name] = body
        return 200, json.dumps({"url": f"https://store1.public.blob.vercel-storage.com/{name}"}).encode()


def test_blob_publisher_put_publish_and_base_url():
    fake = FakeBlob()
    pub = BlobPublisher("TOK", "tradebot", transport=fake, min_interval=0)
    url = pub.put("trades.json", b"{}")
    assert url.endswith("/tradebot/trades.json")
    assert pub.base_url == "https://store1.public.blob.vercel-storage.com/tradebot"
    assert fake.store["tradebot/trades.json"] == b"{}"
    assert pub.publish("live.json", {"a": 1}) is True
    assert json.loads(fake.store["tradebot/live.json"]) == {"a": 1}
    fake.conflict_once = True
    assert pub.put("live.json", b"[]").endswith("/live.json")  # delete + retry path
    assert any(u.endswith("/delete") for _, u in fake.calls)


def test_publish_rate_limit_and_failure_is_soft():
    fake = FakeBlob()
    pub = BlobPublisher("TOK", "", transport=fake, min_interval=1000)
    assert pub.publish("live.json", {"n": 1}) is True
    assert pub.publish("live.json", {"n": 2}) is False  # throttled
    assert pub.publish("live.json", {"n": 3}, force=True) is True

    def down(method, url, headers, body):
        return 500, b"boom"
    bad = BlobPublisher("TOK", "x", transport=down, min_interval=0)
    assert bad.publish("live.json", {}) is False
    with pytest.raises(PublishError):
        bad.put("live.json", b"")
    with pytest.raises(PublishError):
        BlobPublisher("")


def test_trades_payload_and_static_export(tmp_path):
    trades = [mk(1, 1.0), mk(2, -1.0)]
    payload = trades_payload(trades)
    assert len(payload["rows"]) == 2 and payload["stats"]["trades"] == 2
    html = render(trades, "X")
    assert "__DATA__" not in html and '"rows"' in html
    idx = export_static(tmp_path / "site", "https://store1.public.blob.vercel-storage.com/tradebot", "X")
    out = idx.read_text()
    assert "const EMBEDDED = null" in out and '<script src="config.js">' in out and "__DATA__" not in out
    cfg = (tmp_path / "site" / "config.js").read_text()
    assert "store1.public.blob.vercel-storage.com/tradebot" in cfg
    idx2 = export_static(tmp_path / "multi", [("Equities", "https://s/tradebot"), ("Crypto", "https://s/crypto")], "X")
    cfg2 = (tmp_path / "multi" / "config.js").read_text()
    assert "DATA_SOURCES" in cfg2 and '"name": "Crypto"' in cfg2 and "https://s/crypto" in cfg2
    assert '<script src="config.js">' in idx2.read_text()
    assert json.loads((tmp_path / "site" / "vercel.json").read_text())["outputDirectory"] == "."
