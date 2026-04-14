"""
Australian Term Deposit Rate Benchmarker
Compares Bank First rates against the broader Australian market.
Scrapes data from Canstar, Finder, Savings.com.au, and other comparison sites.
"""

import json
import os
import re
import logging
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, render_template, jsonify, send_from_directory
from flask_cors import CORS

import requests
from bs4 import BeautifulSoup
from apscheduler.schedulers.background import BackgroundScheduler

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).parent / "data"
RATES_FILE = DATA_DIR / "rates.json"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-AU,en;q=0.9",
}

# Known comparison site endpoints to try scraping
SCRAPE_TARGETS = [
    {
        "name": "Canstar",
        "url": "https://www.canstar.com.au/term-deposits/compare/best-term-deposit-rates/",
        "parser": "parse_canstar",
    },
    {
        "name": "Finder",
        "url": "https://www.finder.com.au/term-deposits",
        "parser": "parse_finder",
    },
    {
        "name": "Savings.com.au",
        "url": "https://www.savings.com.au/term-deposits/",
        "parser": "parse_savings_com",
    },
    {
        "name": "InfoChoice",
        "url": "https://www.infochoice.com.au/term-deposits/",
        "parser": "parse_infochoice",
    },
]


def load_rates():
    """Load cached rates from JSON file."""
    if RATES_FILE.exists():
        with open(RATES_FILE) as f:
            return json.load(f)
    return None


def save_rates(data):
    """Save rates data to JSON file."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(RATES_FILE, "w") as f:
        json.dump(data, f, indent=2)


def parse_rate(text):
    """Extract a numeric rate from text like '4.85% p.a.'"""
    match = re.search(r"(\d+\.\d+)\s*%", str(text))
    if match:
        return float(match.group(1))
    return None


def classify_term(term_text):
    """Map term text to our standard term keys."""
    text = term_text.lower().strip()
    mapping = {
        "1 month": "1m", "2 month": "2m", "3 month": "3m",
        "4 month": "4m", "5 month": "5m", "6 month": "6m",
        "7 month": "7m", "8 month": "8m", "9 month": "9m",
        "10 month": "10m", "11 month": "11m", "12 month": "12m",
        "1 year": "12m", "18 month": "18m", "24 month": "24m",
        "2 year": "24m", "36 month": "36m", "3 year": "36m",
        "48 month": "48m", "4 year": "48m", "60 month": "60m",
        "5 year": "60m",
    }
    for key, val in mapping.items():
        if key in text:
            return val
    # Try numeric extraction
    months_match = re.search(r"(\d+)\s*month", text)
    if months_match:
        return f"{months_match.group(1)}m"
    years_match = re.search(r"(\d+)\s*year", text)
    if years_match:
        return f"{int(years_match.group(1)) * 12}m"
    days_match = re.search(r"(\d+)\s*day", text)
    if days_match:
        days = int(days_match.group(1))
        if days <= 31:
            return "1m"
        elif days <= 92:
            return "3m"
        elif days <= 183:
            return "6m"
        elif days <= 365:
            return "12m"
    return None


def scrape_page(url):
    """Fetch a page with error handling."""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    except Exception as e:
        logger.warning(f"Failed to scrape {url}: {e}")
        return None


def parse_canstar(soup):
    """Parse term deposit rates from Canstar comparison page."""
    banks = []
    if not soup:
        return banks

    # Canstar uses structured tables and card components
    # Look for rate tables
    tables = soup.find_all("table")
    for table in tables:
        rows = table.find_all("tr")
        for row in rows[1:]:  # skip header
            cells = row.find_all(["td", "th"])
            if len(cells) >= 3:
                name = cells[0].get_text(strip=True)
                rate = parse_rate(cells[1].get_text())
                term_text = cells[2].get_text(strip=True) if len(cells) > 2 else ""
                term = classify_term(term_text)
                if name and rate and term:
                    banks.append({
                        "name": name,
                        "rate": rate,
                        "term": term,
                        "source": "Canstar",
                    })

    # Also look for card-based layouts
    cards = soup.find_all(class_=re.compile(r"product|card|result", re.I))
    for card in cards:
        name_el = card.find(class_=re.compile(r"name|title|provider", re.I))
        rate_el = card.find(class_=re.compile(r"rate|interest|percent", re.I))
        if name_el and rate_el:
            name = name_el.get_text(strip=True)
            rate = parse_rate(rate_el.get_text())
            if name and rate:
                banks.append({
                    "name": name,
                    "rate": rate,
                    "term": "12m",
                    "source": "Canstar",
                })

    return banks


def parse_finder(soup):
    """Parse term deposit rates from Finder comparison page."""
    banks = []
    if not soup:
        return banks

    tables = soup.find_all("table")
    for table in tables:
        rows = table.find_all("tr")
        for row in rows[1:]:
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                name = cells[0].get_text(strip=True)
                rate = parse_rate(cells[1].get_text())
                term = classify_term(cells[2].get_text()) if len(cells) > 2 else "12m"
                if name and rate:
                    banks.append({
                        "name": name,
                        "rate": rate,
                        "term": term or "12m",
                        "source": "Finder",
                    })

    return banks


def parse_savings_com(soup):
    """Parse term deposit rates from Savings.com.au."""
    banks = []
    if not soup:
        return banks

    tables = soup.find_all("table")
    for table in tables:
        rows = table.find_all("tr")
        for row in rows[1:]:
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                name = cells[0].get_text(strip=True)
                rate = parse_rate(cells[1].get_text())
                if name and rate:
                    banks.append({
                        "name": name,
                        "rate": rate,
                        "term": "12m",
                        "source": "Savings.com.au",
                    })

    return banks


def parse_infochoice(soup):
    """Parse term deposit rates from InfoChoice."""
    banks = []
    if not soup:
        return banks

    tables = soup.find_all("table")
    for table in tables:
        rows = table.find_all("tr")
        for row in rows[1:]:
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                name = cells[0].get_text(strip=True)
                rate = parse_rate(cells[1].get_text())
                if name and rate:
                    banks.append({
                        "name": name,
                        "rate": rate,
                        "term": "12m",
                        "source": "InfoChoice",
                    })

    return banks


PARSER_MAP = {
    "parse_canstar": parse_canstar,
    "parse_finder": parse_finder,
    "parse_savings_com": parse_savings_com,
    "parse_infochoice": parse_infochoice,
}


def scrape_all_sources():
    """Attempt to scrape all comparison sites and merge data."""
    all_scraped = []
    sources_succeeded = []

    for target in SCRAPE_TARGETS:
        logger.info(f"Scraping {target['name']}...")
        soup = scrape_page(target["url"])
        if soup:
            parser_fn = PARSER_MAP.get(target["parser"])
            if parser_fn:
                results = parser_fn(soup)
                if results:
                    all_scraped.extend(results)
                    sources_succeeded.append(target["name"])
                    logger.info(f"  Got {len(results)} rates from {target['name']}")
                else:
                    logger.info(f"  No rates parsed from {target['name']} (page structure may have changed)")
        else:
            logger.info(f"  Could not access {target['name']}")

    return all_scraped, sources_succeeded


def merge_scraped_into_data(scraped_rates, existing_data):
    """Merge scraped rates into existing data structure."""
    if not scraped_rates:
        return existing_data

    # Build a lookup of existing banks
    bank_lookup = {}
    for bank in existing_data.get("banks", []):
        bank_lookup[bank["name"].lower()] = bank

    # Process scraped rates
    for entry in scraped_rates:
        name_lower = entry["name"].lower()
        # Try to match to existing bank
        matched = None
        for key in bank_lookup:
            if key in name_lower or name_lower in key:
                matched = key
                break

        if matched and entry.get("term") and entry.get("rate"):
            bank_lookup[matched]["rates"][entry["term"]] = entry["rate"]
            bank_lookup[matched]["lastUpdated"] = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    existing_data["lastUpdated"] = datetime.now(timezone.utc).isoformat()
    return existing_data


def refresh_rates():
    """Main refresh function - scrapes and updates cached data."""
    logger.info("Starting rate refresh...")
    existing = load_rates()
    if not existing:
        logger.error("No base data file found")
        return

    scraped, sources = scrape_all_sources()
    if scraped:
        updated = merge_scraped_into_data(scraped, existing)
        updated["lastScrapeSources"] = sources
        save_rates(updated)
        logger.info(f"Rates updated from: {', '.join(sources)}")
    else:
        logger.info("No new data scraped - using cached data")
        existing["lastScrapeAttempt"] = datetime.now(timezone.utc).isoformat()
        save_rates(existing)


# ----- Flask Routes -----

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/static/<path:filename>")
def serve_static(filename):
    return send_from_directory("static", filename)


@app.route("/api/rates")
def api_rates():
    """Return all rate data as JSON."""
    data = load_rates()
    if not data:
        return jsonify({"error": "No data available"}), 500

    # Compute market statistics
    banks = data.get("banks", [])
    terms = data.get("terms", ["3m", "6m", "12m", "24m", "36m", "60m"])

    stats = {}
    for term in terms:
        rates = [b["rates"].get(term) for b in banks if b["rates"].get(term)]
        if rates:
            stats[term] = {
                "min": round(min(rates), 2),
                "max": round(max(rates), 2),
                "avg": round(sum(rates) / len(rates), 2),
                "median": round(sorted(rates)[len(rates) // 2], 2),
                "count": len(rates),
            }

    # Big 4 averages
    big4 = [b for b in banks if b.get("type") == "Big 4"]
    big4_avg = {}
    for term in terms:
        rates = [b["rates"].get(term) for b in big4 if b["rates"].get(term)]
        if rates:
            big4_avg[term] = round(sum(rates) / len(rates), 2)

    # Challenger averages
    challengers = [b for b in banks if b.get("type") in ("Challenger", "Mutual Bank", "Credit Union")]
    challenger_avg = {}
    for term in terms:
        rates = [b["rates"].get(term) for b in challengers if b["rates"].get(term)]
        if rates:
            challenger_avg[term] = round(sum(rates) / len(rates), 2)

    # Bank First data
    bank_first = next((b for b in banks if b.get("highlight")), None)

    data["marketStats"] = stats
    data["big4Average"] = big4_avg
    data["challengerAverage"] = challenger_avg
    data["bankFirst"] = bank_first

    return jsonify(data)


@app.route("/api/refresh", methods=["POST"])
def api_refresh():
    """Trigger a manual data refresh."""
    refresh_rates()
    data = load_rates()
    return jsonify({
        "status": "ok",
        "lastUpdated": data.get("lastUpdated"),
        "sources": data.get("lastScrapeSources", []),
    })


@app.route("/api/comparison/<term>")
def api_comparison(term):
    """Get comparison data for a specific term."""
    data = load_rates()
    if not data:
        return jsonify({"error": "No data available"}), 500

    banks = data.get("banks", [])
    results = []
    for bank in banks:
        rate = bank["rates"].get(term)
        if rate:
            results.append({
                "name": bank["name"],
                "rate": rate,
                "type": bank.get("type", "Unknown"),
                "highlight": bank.get("highlight", False),
                "minDeposit": bank.get("minDeposit"),
            })

    results.sort(key=lambda x: x["rate"], reverse=True)

    # Compute rank for Bank First
    bank_first_rank = None
    for i, r in enumerate(results):
        if r["highlight"]:
            bank_first_rank = i + 1
            break

    return jsonify({
        "term": term,
        "banks": results,
        "bankFirstRank": bank_first_rank,
        "totalBanks": len(results),
    })


# ----- Scheduler -----

scheduler = BackgroundScheduler()
# Refresh every 6 hours
scheduler.add_job(refresh_rates, "interval", hours=6, id="rate_refresh")


if __name__ == "__main__":
    scheduler.start()
    logger.info("Starting Term Deposit Rate Benchmarker...")
    logger.info("Dashboard available at http://localhost:5000")
    app.run(debug=True, host="0.0.0.0", port=5000, use_reloader=False)
