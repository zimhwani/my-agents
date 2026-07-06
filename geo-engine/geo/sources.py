"""Prospect-list source connectors — auto-pull target businesses for a
vertical + city so the prospecting engine has a steady top of funnel.

Sources:
* ``overpass`` — OpenStreetMap via the Overpass API (free, no key). Geocodes the
  location with Nominatim, then pulls named businesses matching the vertical.
* ``mock``     — synthetic businesses, offline, for testing the pipeline.

Output rows match the `geo prospect` CSV schema, so:
    python -m geo find --vertical dental --location "San Diego, CA" --out leads.csv
    python -m geo prospect --prospects leads.csv
"""

from __future__ import annotations

import csv
import hashlib
import json
import urllib.parse
import urllib.request
from typing import List

# Map our vertical slugs to OpenStreetMap tag filters (key, value).
VERTICAL_OSM = {
    "med_spa": [("leisure", "spa"), ("shop", "beauty")],
    "cosmetic_clinic": [("shop", "beauty"), ("amenity", "clinic")],
    "dermatology": [("healthcare", "dermatology"), ("amenity", "clinic")],
    "dental": [("amenity", "dentist"), ("healthcare", "dentist")],
    "optometry": [("shop", "optician"), ("healthcare", "optometrist")],
    "veterinary": [("amenity", "veterinary")],
    "physical_therapy": [("healthcare", "physiotherapist")],
    "chiropractic": [("healthcare", "chiropractor")],
    "law_firm": [("office", "lawyer")],
    "hvac": [("craft", "hvac"), ("shop", "trade")],
    "roofing": [("craft", "roofer")],
    "landscaping": [("craft", "gardener"), ("shop", "garden_centre")],
}

_UA = "geo-engine-prospector/0.1 (contact: set your email)"
_NOMINATIM = "https://nominatim.openstreetmap.org/search"
_OVERPASS = "https://overpass-api.de/api/interpreter"


def _get_json(url: str, data: bytes | None = None) -> object:
    req = urllib.request.Request(url, data=data, headers={"User-Agent": _UA})
    with urllib.request.urlopen(req, timeout=45) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _geocode(location: str):
    q = urllib.parse.urlencode({"q": location, "format": "json", "limit": 1})
    results = _get_json(f"{_NOMINATIM}?{q}")
    if not results:
        raise ValueError(f"Could not geocode location: {location!r}")
    bb = results[0]["boundingbox"]  # [south, north, west, east] as strings
    south, north, west, east = (float(x) for x in bb)
    return south, west, north, east


def _overpass_search(vertical: str, bbox, limit: int) -> List[dict]:
    tags = VERTICAL_OSM.get(vertical)
    if not tags:
        raise ValueError(
            f"No OSM mapping for vertical '{vertical}'. Known: {', '.join(VERTICAL_OSM)}")
    s, w, n, e = bbox
    clauses = []
    for k, v in tags:
        for kind in ("node", "way"):
            clauses.append(f'{kind}["{k}"="{v}"]["name"]({s},{w},{n},{e});')
    query = f"[out:json][timeout:40];({''.join(clauses)});out center tags {limit * 3};"
    payload = urllib.parse.urlencode({"data": query}).encode("utf-8")
    data = _get_json(_OVERPASS, data=payload)

    seen, rows = set(), []
    for el in data.get("elements", []):
        t = el.get("tags", {})
        name = t.get("name")
        if not name or name.lower() in seen:
            continue
        seen.add(name.lower())
        rows.append({"business_name": name, "website": t.get("website", "")})
        if len(rows) >= limit:
            break
    return rows


def _mock_search(vertical: str, location: str, limit: int) -> List[dict]:
    seed = int(hashlib.md5(f"{vertical}|{location}".encode()).hexdigest(), 16)
    adjectives = ["Summit", "Bright", "Cedar", "Harbor", "Vista", "Radiant",
                  "Pioneer", "Maple", "Copper", "Lakeside", "Union", "Crest"]
    nouns = {"dental": "Dental", "med_spa": "Med Spa", "optometry": "Eye Care",
             "veterinary": "Veterinary", "law_firm": "Law", "hvac": "Heating & Air"}
    noun = nouns.get(vertical, vertical.replace("_", " ").title())
    rows = []
    for i in range(limit):
        adj = adjectives[(seed + i * 7) % len(adjectives)]
        rows.append({"business_name": f"{adj} {noun}", "website": ""})
    return rows


def find_prospects(vertical: str, location: str, source: str = "overpass",
                   limit: int = 20) -> List[dict]:
    if source == "mock":
        found = _mock_search(vertical, location, limit)
    elif source == "overpass":
        found = _overpass_search(vertical, _geocode(location), limit)
    else:
        raise ValueError(f"Unknown source '{source}' (use 'overpass' or 'mock')")
    for r in found:
        r["vertical"] = vertical
        r["location"] = location
        r.setdefault("services", "")
        r.setdefault("competitors", "")
    return found


def write_csv(rows: List[dict], path: str) -> None:
    cols = ["business_name", "vertical", "location", "services", "competitors", "website"]
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in cols})
