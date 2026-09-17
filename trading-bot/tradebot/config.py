"""Settings, loaded from the environment (and a local ``.env`` file if present).

Safety rules enforced here, not in the trading code, so they cannot be
bypassed by a strategy change:

* Paper ports (7497 TWS, 4002 Gateway) are the default.
* A live port (7496 / 4001) is refused unless ``LIVE_TRADING_ACK`` equals
  ``I_UNDERSTAND_LIVE_TRADING`` exactly.
* Every risk limit has a sane default and a hard ceiling.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from datetime import time
from pathlib import Path

from .clock import parse_hhmm

PAPER_PORTS = {7497, 4002}
LIVE_PORTS = {7496, 4001}
LIVE_ACK = "I_UNDERSTAND_LIVE_TRADING"

DEFAULT_UNIVERSE = (
    "AAPL,MSFT,NVDA,AMZN,META,GOOGL,TSLA,AMD,NFLX,AVGO,CRM,ORCL,JPM,BAC,GS,"
    "XOM,CVX,UNH,LLY,COST,WMT,HD,NKE,DIS,BA,CAT,UBER,SHOP,PLTR,COIN,MU,QCOM,"
    "INTC,PYPL,SQ,ABNB,SMCI,ARM,MRVL,DELL"
)


def load_dotenv(path: str | os.PathLike = ".env") -> None:
    """Minimal .env loader (KEY=VALUE, '#' comments). Never overrides real env."""
    p = Path(path)
    if not p.exists():
        return
    for raw in p.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.split(" #")[0].strip().strip('"').strip("'")
        os.environ.setdefault(key.strip(), value)


def _env(key: str, default: str = "") -> str:
    return os.environ.get(key, default).strip()


def _bool(key: str, default: bool = False) -> bool:
    return _env(key, str(default)).lower() in {"1", "true", "yes", "on"}


def _float(key: str, default: float) -> float:
    v = _env(key)
    return float(v) if v else default


def _int(key: str, default: int) -> int:
    v = _env(key)
    return int(v) if v else default


class UnsafeConfig(RuntimeError):
    pass


@dataclass
class Settings:
    # broker
    ib_host: str = "127.0.0.1"
    ib_port: int = 7497
    ib_client_id: int = 7
    ib_account: str = ""
    market_data_type: int = 1
    live_ack: str = ""
    # risk
    risk_per_trade_pct: float = 0.5
    max_risk_per_trade_usd: float = 250.0
    max_position_pct: float = 25.0
    max_positions: int = 3
    max_daily_loss_r: float = -3.0
    max_daily_loss_pct: float = 2.0
    allow_shorts: bool = False
    # universe
    universe: list[str] = field(default_factory=lambda: DEFAULT_UNIVERSE.split(","))
    min_price: float = 10.0
    max_price: float = 600.0
    min_avg_dollar_volume: float = 50e6
    min_atr_pct: float = 1.0
    max_watchlist: int = 8
    # loop
    poll_seconds: int = 30
    force_close_time: time = time(15, 50)
    dry_run: bool = False
    # telegram
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""
    telegram_status_minutes: int = 30
    # paths
    data_dir: Path = Path("data")
    strategy_file: Path = Path("strategy.json")

    # ---- derived ---------------------------------------------------------
    @property
    def is_paper(self) -> bool:
        return self.ib_port in PAPER_PORTS

    @property
    def kill_switch_file(self) -> Path:
        return self.data_dir / "KILL"

    @property
    def journal_file(self) -> Path:
        return self.data_dir / "trades.jsonl"

    @property
    def state_file(self) -> Path:
        return self.data_dir / "state.json"

    @property
    def dashboard_file(self) -> Path:
        return self.data_dir / "dashboard.html"

    @property
    def log_file(self) -> Path:
        return self.data_dir / "bot.log"

    def validate(self) -> None:
        if self.ib_port not in PAPER_PORTS:
            if self.live_ack != LIVE_ACK:
                raise UnsafeConfig(
                    f"IB_PORT={self.ib_port} is not a paper port ({sorted(PAPER_PORTS)}). "
                    f"Refusing to start. To trade live, set LIVE_TRADING_ACK={LIVE_ACK} "
                    "only after the bot has run clean on paper for weeks."
                )
        if not 0 < self.risk_per_trade_pct <= 2.0:
            raise UnsafeConfig("RISK_PER_TRADE_PCT must be in (0, 2].")
        if self.max_positions < 1 or self.max_positions > 10:
            raise UnsafeConfig("MAX_POSITIONS must be 1..10.")
        if self.max_daily_loss_r >= 0:
            raise UnsafeConfig("MAX_DAILY_LOSS_R must be negative (e.g. -3).")
        if self.force_close_time >= time(16, 0):
            raise UnsafeConfig("FORCE_CLOSE_TIME must be before 16:00.")

    @classmethod
    def load(cls, dotenv: str | os.PathLike = ".env") -> "Settings":
        load_dotenv(dotenv)
        universe = [s.strip().upper() for s in _env("UNIVERSE", DEFAULT_UNIVERSE).split(",") if s.strip()]
        s = cls(
            ib_host=_env("IB_HOST", "127.0.0.1"),
            ib_port=_int("IB_PORT", 7497),
            ib_client_id=_int("IB_CLIENT_ID", 7),
            ib_account=_env("IB_ACCOUNT"),
            market_data_type=_int("IB_MARKET_DATA_TYPE", 1),
            live_ack=_env("LIVE_TRADING_ACK"),
            risk_per_trade_pct=_float("RISK_PER_TRADE_PCT", 0.5),
            max_risk_per_trade_usd=_float("MAX_RISK_PER_TRADE_USD", 250.0),
            max_position_pct=_float("MAX_POSITION_PCT", 25.0),
            max_positions=_int("MAX_POSITIONS", 3),
            max_daily_loss_r=_float("MAX_DAILY_LOSS_R", -3.0),
            max_daily_loss_pct=_float("MAX_DAILY_LOSS_PCT", 2.0),
            allow_shorts=_bool("ALLOW_SHORTS", False),
            universe=universe,
            min_price=_float("MIN_PRICE", 10.0),
            max_price=_float("MAX_PRICE", 600.0),
            min_avg_dollar_volume=_float("MIN_AVG_DOLLAR_VOLUME", 50e6),
            min_atr_pct=_float("MIN_ATR_PCT", 1.0),
            max_watchlist=_int("MAX_WATCHLIST", 8),
            poll_seconds=_int("POLL_SECONDS", 30),
            force_close_time=parse_hhmm(_env("FORCE_CLOSE_TIME", "15:50")),
            dry_run=_bool("DRY_RUN", False),
            telegram_bot_token=_env("TELEGRAM_BOT_TOKEN"),
            telegram_chat_id=_env("TELEGRAM_CHAT_ID"),
            telegram_status_minutes=_int("TELEGRAM_STATUS_MINUTES", 30),
            data_dir=Path(_env("DATA_DIR", "data")),
            strategy_file=Path(_env("STRATEGY_FILE", "strategy.json")),
        )
        s.validate()
        s.data_dir.mkdir(parents=True, exist_ok=True)
        return s

    def describe(self) -> str:
        mode = "PAPER" if self.is_paper else "*** LIVE ***"
        return (
            f"{mode} {self.ib_host}:{self.ib_port} client={self.ib_client_id} "
            f"dry_run={self.dry_run} risk={self.risk_per_trade_pct}%/trade "
            f"(cap ${self.max_risk_per_trade_usd:.0f}) max_pos={self.max_positions} "
            f"daily_stop={self.max_daily_loss_r}R/{self.max_daily_loss_pct}% "
            f"force_close={self.force_close_time.strftime('%H:%M')} ET"
        )
