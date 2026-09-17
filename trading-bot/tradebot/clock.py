"""Market-hours helpers. Every datetime the bot handles is timezone-aware and
expressed in US/Eastern (the exchange's clock), regardless of where the
computer running the bot lives.
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

ET = ZoneInfo("America/New_York")

MARKET_OPEN = time(9, 30)
MARKET_CLOSE = time(16, 0)

# NYSE full-day closures. Update yearly (https://www.nyse.com/markets/hours-calendars).
HOLIDAYS = {
    # 2026
    date(2026, 1, 1), date(2026, 1, 19), date(2026, 2, 16), date(2026, 4, 3),
    date(2026, 5, 25), date(2026, 6, 19), date(2026, 7, 3), date(2026, 9, 7),
    date(2026, 11, 26), date(2026, 12, 25),
    # 2027
    date(2027, 1, 1), date(2027, 1, 18), date(2027, 2, 15), date(2027, 3, 26),
    date(2027, 5, 31), date(2027, 6, 18), date(2027, 7, 5), date(2027, 9, 6),
    date(2027, 11, 25), date(2027, 12, 24),
}


def now_et() -> datetime:
    return datetime.now(tz=ET)


def to_et(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=ET)
    return dt.astimezone(ET)


def parse_hhmm(value: str) -> time:
    hh, mm = value.strip().split(":")
    return time(int(hh), int(mm))


def at(day: date, t: time) -> datetime:
    return datetime.combine(day, t, tzinfo=ET)


def is_trading_day(day: date) -> bool:
    return day.weekday() < 5 and day not in HOLIDAYS


def session_open(day: date) -> datetime:
    return at(day, MARKET_OPEN)


def session_close(day: date) -> datetime:
    return at(day, MARKET_CLOSE)


def is_market_open(dt: datetime | None = None) -> bool:
    dt = to_et(dt or now_et())
    if not is_trading_day(dt.date()):
        return False
    return session_open(dt.date()) <= dt < session_close(dt.date())


def minutes_since_open(dt: datetime) -> float:
    dt = to_et(dt)
    return (dt - session_open(dt.date())).total_seconds() / 60.0


def minutes_to_close(dt: datetime) -> float:
    dt = to_et(dt)
    return (session_close(dt.date()) - dt).total_seconds() / 60.0


def next_trading_day(day: date) -> date:
    day = day + timedelta(days=1)
    while not is_trading_day(day):
        day += timedelta(days=1)
    return day


def in_window(dt: datetime, start: time, end: time) -> bool:
    t = to_et(dt).time()
    return start <= t < end
