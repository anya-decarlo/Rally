"""California special districts — State Controller registry → jurisdictions.

Source: bythenumbers.sco.ca.gov (Socrata) — Special Districts Revenues,
grouped to one row per reporting district. ~4,600 independent districts:
fire, water, cemetery, parks, JPAs, county service areas, …

    python3 pipeline/districts.py

Merges kind=district records into data/jurisdictions/ca.json — parented to
their county — and rebuilds districtCatalog counts from real numbers.
School-district seeds are preserved; CDE enumerates those separately.
"""
import json, re, unicodedata
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parent.parent
CA = ROOT / "data" / "jurisdictions" / "ca.json"
SOCRATA = "https://bythenumbers.sco.ca.gov/resource/nkv3-m73r.json"
FISCAL_YEAR = "2025"

# Socrata activity → our districtKind (broad lanes for the catalog)
KIND_RULES = [
    ("school", "school"), ("fire", "fire"), ("water", "water"),
    ("reclamation", "water"), ("flood", "water"), ("irrigation", "water"),
    ("transit", "transit"), ("transportation", "transit"),
    ("hospital", "healthcare"), ("health", "healthcare"),
    ("joint powers", "joint powers"), ("jpa", "joint powers"),
    ("county service", "county service"), ("cemetery", "cemetery"),
    ("park", "parks"), ("recreation", "parks"),
    ("librar", "library"), ("police", "police"), ("sanit", "sanitation"),
    ("sewer", "sanitation"), ("storm", "stormwater"),
    ("lighting", "lighting"), ("mosquito", "pest control"), ("pest", "pest control"),
    ("resource conservation", "resource conservation"),
    ("community services", "community services"),
    ("maintenance", "maintenance"), ("memorial", "memorial"),
]


def kind_of(activity):
    a = activity.lower()
    for needle, kind in KIND_RULES:
        if needle in a:
            return kind
    return "other"


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.lower())).strip("-")


def fetch():
    q = {"$select": "entity_name,activity,district_type,county,city_state",
         "$where": f"fiscal_year='{FISCAL_YEAR}'",
         "$group": "entity_name,activity,district_type,county,city_state",
         "$limit": "50000", "$order": "county,entity_name"}
    url = f"{SOCRATA}?{urlencode(q)}"
    with urlopen(Request(url, headers={"User-Agent": "Rally/1.0"})) as r:
        return json.loads(r.read())


def main():
    doc = json.loads(CA.read_text())
    county_ids = {j["name"].replace(" County", "").lower(): j["id"]
                  for j in doc["jurisdictions"] if j["kind"] == "county"}

    rows = fetch()
    districts, seen_ids = [], {}
    for r in rows:
        name = r["entity_name"].strip()
        county = r["county"].strip().lower()
        parent = county_ids.get(county, "ca")
        base = f"ca-{slug(name)}"
        jid = base if base not in seen_ids else f"{base}-{slug(county)}"
        seen_ids[jid] = True
        districts.append({
            "id": jid, "name": name, "kind": "district",
            "districtKind": kind_of(r.get("activity", "")),
            "covers": r.get("city_state", ""),
            "parent": parent,
            "note": r.get("activity", ""),
            "seats": [{"office": "Governing Board", "seats": 0,
                       "elected": "districts"}],
        })

    # Keep school-district seeds (CDE enumerates those); replace the rest.
    doc["jurisdictions"] = [j for j in doc["jurisdictions"]
                            if j["kind"] != "district"
                            or j.get("districtKind") == "school"] + districts

    # Rebuild the catalog from real counts.
    by_kind = {}
    for d in districts:
        by_kind.setdefault(d["districtKind"], 0)
        by_kind[d["districtKind"]] += 1
    school_n = sum(1 for j in doc["jurisdictions"]
                   if j.get("districtKind") == "school")
    doc["districtCatalog"] = (
        [{"kind": "school", "count": "~940",
          "note": "unified, elementary & high school districts — CDE directory pending"}]
        + [{"kind": k, "count": str(n)} for k, n in
           sorted(by_kind.items(), key=lambda kv: -kv[1])]
    )
    doc["districtTotal"] = len(districts) + school_n

    CA.write_text(json.dumps(doc, indent=2) + "\n")
    n_kinds = len(by_kind)
    print(f"done: {len(districts)} special districts across {n_kinds} kinds → {CA.name}")


if __name__ == "__main__":
    main()
