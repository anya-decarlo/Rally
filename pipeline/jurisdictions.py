"""Jurisdiction skeleton — the map of who governs what.

Generates data/jurisdictions/*.json, shared with the app. A jurisdiction is a
container that can hold seats (elected offices), contests (elections), and
child jurisdictions. Districts are overlapping, not strictly nested.

    python3 pipeline/jurisdictions.py   # regenerate all
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "jurisdictions"
HTML = Path("/tmp/ca_cities.html")  # fetched List_of_municipalities_in_California


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def fetch_ca_cities():
    """Parse Wikipedia's municipality table → [(name, type, county)]."""
    if not HTML.exists():
        import urllib.request
        req = urllib.request.Request(
            "https://en.wikipedia.org/wiki/List_of_municipalities_in_California",
            headers={"User-Agent": "Rally/1.0 (civic data; contact: local)"})
        HTML.write_text(urllib.request.urlopen(req).read().decode("utf-8"))
    html = HTML.read_text()
    table = re.findall(r"<table[^>]*wikitable[^>]*>.*?</table>", html, re.S)[1]
    cities = []
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", table, re.S):
        cells = [re.sub(r"\[\d+\]", "", re.sub(r"<[^>]+>", "", c)).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, re.S)]
        if len(cells) >= 3 and cells[0] != "Name" and cells[1] in ("City", "Town"):
            cities.append((cells[0].rstrip("†‡").strip(), cells[1], cells[2]))
    return cities


# Counties the municipality table can't give us: Alpine, Mariposa and Trinity
# have no incorporated cities; San Francisco is a consolidated city-county.
EXTRA_COUNTIES = {
    "Alpine": {"consolidated": False},
    "Mariposa": {"consolidated": False},
    "Trinity": {"consolidated": False},
    "San Francisco": {"consolidated": True},
}


# ---------------------------------------------------------------------------
# Seat templates. `seats` = offices that exist at that level.
# elected: "districts" (by sub-district), "at-large", or "wide" (jurisdiction-wide)

STATE_SEATS = [
    {"office": "Governor", "seats": 1, "elected": "wide"},
    {"office": "Lieutenant Governor", "seats": 1, "elected": "wide"},
    {"office": "Attorney General", "seats": 1, "elected": "wide"},
    {"office": "Secretary of State", "seats": 1, "elected": "wide"},
    {"office": "State Treasurer", "seats": 1, "elected": "wide"},
    {"office": "State Controller", "seats": 1, "elected": "wide"},
    {"office": "Insurance Commissioner", "seats": 1, "elected": "wide"},
    {"office": "Superintendent of Public Instruction", "seats": 1, "elected": "wide",
     "note": "nonpartisan"},
    {"office": "Board of Equalization", "seats": 4, "elected": "districts"},
    {"office": "State Senate", "seats": 40, "elected": "districts"},
    {"office": "State Assembly", "seats": 80, "elected": "districts"},
    {"office": "Supreme Court", "seats": 7, "elected": "retention",
     "note": "appointed by Governor, retained by voters"},
    {"office": "Courts of Appeal", "seats": 0, "elected": "retention",
     "note": "6 appellate districts"},
    {"office": "U.S. Senate", "seats": 2, "elected": "wide", "federal": True},
    {"office": "U.S. House", "seats": 52, "elected": "districts", "federal": True},
    {"office": "Ballot measures", "seats": 0, "elected": "wide",
     "note": "propositions — varies per election"},
]

# Standard elected row officers in most CA counties (charter varies)
COUNTY_WIDE_OFFICERS = [
    "Sheriff", "District Attorney", "Assessor",
    "Auditor-Controller", "Treasurer-Tax Collector", "County Clerk-Recorder",
]

def county_seats(supervisors=5):
    return [{"office": "Board of Supervisors", "seats": supervisors, "elected": "districts"}] \
        + [{"office": o, "seats": 1, "elected": "wide"} for o in COUNTY_WIDE_OFFICERS] \
        + [{"office": "Superior Court", "seats": 0, "elected": "wide",
            "note": "judges — mostly unopposed retention"},
           {"office": "County Board of Education", "seats": 0, "elected": "districts"}]

CITY_SEATS = [
    {"office": "Mayor", "seats": 1, "elected": "wide"},
    {"office": "City Council", "seats": 0, "elected": "districts",
     "note": "size varies — most CA councils are 5"},
]

# Per-jurisdiction seat overrides where the generic template is wrong
COUNTY_OVERRIDES = {
    "San Francisco": county_seats(11) + [  # consolidated city-county
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Attorney", "seats": 1, "elected": "wide"},
        {"office": "Public Defender", "seats": 1, "elected": "wide"},
    ],
}
CITY_OVERRIDES = {
    "Los Angeles": [
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Council", "seats": 15, "elected": "districts"},
        {"office": "City Attorney", "seats": 1, "elected": "wide"},
        {"office": "City Controller", "seats": 1, "elected": "wide"},
    ],
    "San Diego": [
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Council", "seats": 9, "elected": "districts"},
        {"office": "City Attorney", "seats": 1, "elected": "wide"},
    ],
    "San Jose": [
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Council", "seats": 10, "elected": "districts"},
    ],
    "Oakland": [
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Council", "seats": 8, "elected": "districts"},
        {"office": "City Attorney", "seats": 1, "elected": "wide"},
    ],
    "Long Beach": [
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Council", "seats": 9, "elected": "districts"},
        {"office": "City Attorney", "seats": 1, "elected": "wide"},
        {"office": "City Auditor", "seats": 1, "elected": "wide"},
        {"office": "City Prosecutor", "seats": 1, "elected": "wide"},
    ],
    "Sacramento": [
        {"office": "Mayor", "seats": 1, "elected": "wide"},
        {"office": "City Council", "seats": 8, "elected": "districts"},
    ],
}

# Famous independent districts — the catalog is huge, seed the ones people know
SEEDED_DISTRICTS = [
    ("lausd", "Los Angeles Unified School District", "school", "Los Angeles"),
    ("sfusd", "San Francisco Unified School District", "school", "San Francisco"),
    ("sdusd", "San Diego Unified School District", "school", "San Diego"),
    ("fresno-usd", "Fresno Unified School District", "school", "Fresno"),
    ("lb-usd", "Long Beach Unified School District", "school", "Los Angeles"),
    ("bart", "Bay Area Rapid Transit District", "transit",
     "Alameda, Contra Costa, San Francisco, San Mateo"),
    ("la-metro", "Los Angeles County Metropolitan Transportation Authority", "transit", "Los Angeles"),
    ("mwd", "Metropolitan Water District of Southern California", "water",
     "Los Angeles, Orange, Riverside, San Bernardino, San Diego, Ventura"),
    ("ebmud", "East Bay Municipal Utility District", "water", "Alameda, Contra Costa"),
    ("smud", "Sacramento Municipal Utility District", "utility", "Sacramento"),
    ("lacd", "Los Angeles Community College District", "community college", "Los Angeles"),
]

DISTRICT_CATALOG = [
    {"kind": "school", "count": "~940", "note": "unified, elementary & high school districts"},
    {"kind": "community college", "count": "72"},
    {"kind": "water", "count": "~200", "note": "includes irrigation & municipal water"},
    {"kind": "fire", "count": "~350", "note": "fire protection districts"},
    {"kind": "transit", "count": "~100"},
    {"kind": "healthcare", "count": "~75", "note": "hospital & healthcare districts"},
    {"kind": "parks & recreation", "count": "~130"},
    {"kind": "other special", "count": "~1,000",
     "note": "cemetery, mosquito, library, utility, harbor…"},
]


def build_ca():
    cities = fetch_ca_cities()
    counties = {name: [] for name in EXTRA_COUNTIES}  # name -> [city names]
    for name, typ, county in cities:
        counties.setdefault(county, []).append((name, typ))

    jurisdictions = [{
        "id": "ca", "name": "California", "kind": "state", "seats": STATE_SEATS,
    }]

    for county in sorted(counties):
        cid = "ca-" + slug(county)
        consolidated = EXTRA_COUNTIES.get(county, {}).get("consolidated", False)
        jurisdictions.append({
            "id": cid, "name": "City and County of San Francisco" if consolidated
                else f"{county} County",
            "kind": "county", "parent": "ca",
            "consolidated": consolidated,
            "seats": COUNTY_OVERRIDES.get(county, county_seats()),
            "unincorporated": True,  # county governs residents outside cities directly
        })
        for name, typ in sorted(counties[county]):
            jurisdictions.append({
                "id": f"{cid}-{slug(name)}", "name": name, "kind": "city",
                "type": typ, "parent": cid,
                "seats": CITY_OVERRIDES.get(name, CITY_SEATS),
            })

    for did, name, kind, covers in SEEDED_DISTRICTS:
        jurisdictions.append({
            "id": f"ca-{did}", "name": name, "kind": "district", "districtKind": kind,
            "covers": covers, "parent": "ca",
            "seats": [{"office": "Governing Board", "seats": 0, "elected": "districts"}],
        })

    return {
        "_generated": "pipeline/jurisdictions.py — do not edit",
        "state": "CA",
        "levels": ["state", "county", "city", "district"],
        "districtCatalog": DISTRICT_CATALOG,
        "jurisdictions": jurisdictions,
    }


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    doc = build_ca()
    (OUT / "ca.json").write_text(json.dumps(doc, indent=2) + "\n")
    kinds = {}
    for j in doc["jurisdictions"]:
        kinds[j["kind"]] = kinds.get(j["kind"], 0) + 1
    print(f"ca.json: {kinds}")
