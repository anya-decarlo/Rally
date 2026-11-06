"""Government activity — the stream of decisions between elections.

Generates data/activity/<state>.json. Jurisdictions and seats are the
structure (who can act); activities are what they actually did. Every item
carries a source URL — receipts, not accusations.

    python3 pipeline/activity.py   # regenerate all

Item shape:

    {
      "id": "ca-bill-ab-100-introduced",
      "kind": "billIntroduced",          // see KINDS below
      "jurisdiction": "ca",              // jurisdiction id, or "us" for federal
      "date": "2026-01-12",
      "title": "AB 100 introduced",
      "detail": "…",
      "actors": ["Asm. Jane Doe"],       // people/seats involved
      "bill": "AB 100",                  // optional link to an instrument
      "crossLevel": false,               // state↔federal interaction
      "source": "https://leginfo.legislature.ca.gov/…"
    }
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "activity"

# The tracker taxonomy — every kind of decision that happens between elections
ACTIVITY_KINDS = [
    {"kind": "billIntroduced",    "label": "Proposed legislation",     "example": "California AB 100"},
    {"kind": "committeeHearing",  "label": "Committee hearing",        "example": "Education committee hearing"},
    {"kind": "vote",              "label": "Legislative vote",         "example": "Senate floor vote"},
    {"kind": "executiveOrder",    "label": "Executive action",         "example": "Governor executive order"},
    {"kind": "initiative",        "label": "Ballot initiative",        "example": "Proposed proposition gathering signatures"},
    {"kind": "qualifiedMeasure",  "label": "Qualified ballot measure", "example": "November ballot proposition"},
    {"kind": "publicHearing",     "label": "Public hearing",           "example": "Housing development hearing"},
    {"kind": "courtRuling",       "label": "Judicial decision",        "example": "Federal court ruling involving the state"},
    {"kind": "lawsuit",           "label": "Lawsuit",                  "example": "State AG challenges federal policy"},
    {"kind": "regulation",        "label": "Agency regulation",        "example": "Environmental rule, proposed or final"},
    {"kind": "appointment",       "label": "Appointment",              "example": "Governor nominates a judge"},
    {"kind": "budget",            "label": "Budget decision",          "example": "State budget proposal"},
]

# Where each state's stream comes from — the feeds to wire next
SOURCES = [
    {"name": "California Legislative Information", "provides": "bills, votes, committees, calendars",
     "url": "https://leginfo.legislature.ca.gov"},
    {"name": "California Secretary of State", "provides": "elections, initiatives, qualified measures",
     "url": "https://www.sos.ca.gov/elections"},
    {"name": "Governor of California", "provides": "executive orders, signed bills, vetoes",
     "url": "https://www.gov.ca.gov"},
    {"name": "California DOJ", "provides": "lawsuits, legal actions",
     "url": "https://oag.ca.gov"},
    {"name": "Congress.gov API", "provides": "federal bills, members, votes",
     "url": "https://api.congress.gov"},
    {"name": "Federal Register API", "provides": "proposed and final federal rules",
     "url": "https://www.federalregister.gov/developers/documentation/api/v1"},
]

# How a law is made — the two paths, rendered as an explainer inside the app.
# Teaching content, not data: marked `explainer` so it never poses as a filing.
EXPLAINER = {
    "topic": "Stronger protections for clean drinking water",
    "paths": [
        {
            "id": "state",
            "label": "A CALIFORNIA LAW",
            "jurisdiction": "ca",
            "steps": [
                "A resident raises the issue with their Assembly member",
                "The member sponsors an Assembly Bill (AB)",
                "Committees review it, hold hearings, vote",
                "Assembly and Senate both pass it",
                "Governor signs or vetoes",
                "State agencies implement and enforce it",
            ],
        },
        {
            "id": "federal",
            "label": "FEDERAL ACTION",
            "jurisdiction": "us",
            "steps": [
                "The state wants stronger national standards",
                "Governor, AG, or officials press federal authorities",
                "A CA member of Congress introduces a bill",
                "Federal committees review, amend, vote",
                "Both chambers pass it → the President signs or vetoes",
                "Federal agencies implement it",
            ],
        },
    ],
    "note": "Two separate machines. A state law doesn't become federal law — "
            "and your drinking water might need both.",
}


def build_ca():
    return {
        "_generated": "pipeline/activity.py — do not edit",
        "state": "CA",
        "activityKinds": ACTIVITY_KINDS,
        "sources": SOURCES,
        "explainer": EXPLAINER,
        "items": [],  # the stream — parsed in from SOURCES as feeds land
    }


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    (OUT / "ca.json").write_text(json.dumps(build_ca(), indent=2) + "\n")
    print("ca.json: 12 activity kinds, 6 sources, 2-path explainer, 0 items")
