"""Legislation — every bill is a card, every card has its people.

Generates data/legislation/<state>.json. Bills are instruments with a
lifecycle; ActivityItems are the stream of events that fall out of them.
Seeded by hand from leginfo/official releases until collector #1 lands.

    python3 pipeline/legislation.py   # regenerate all

Stages (a bill moves left→right, or dies):
    0 introduced · 1 committee · 2 first chamber · 3 second chamber ·
    4 governor · 5 law — or status "vetoed"/"dead"/"enjoined" ends the line
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "legislation"

def leginfo(code):
    return ("https://leginfo.legislature.ca.gov/faces/billNavClient.xhtml"
            f"?bill_id=202520260{code.replace(' ', '')}")

BILLS = [
    {
        "id": "ca-sb-79", "code": "SB 79", "chamber": "senate",
        "title": "Abundant & Affordable Homes Near Transit Act",
        "summary": "Legalizes mid-rise multifamily housing within a half-mile of "
                   "major transit stops, overriding local zoning in eight counties.",
        "status": "law", "stage": 5,
        "introduced": "2025-01-15",
        "lastAction": {"date": "2025-10-10",
                       "action": "Approved by the Governor. Chapter 512, Statutes of 2025."},
        "people": [
            {"name": "Scott Wiener", "role": "author", "seat": "State Senate · D-11 · SF"},
            {"name": "Buffy Wicks", "role": "principal coauthor", "seat": "Assembly · D-14 · Oakland"},
            {"name": "Matt Haney", "role": "coauthor", "seat": "Assembly · D-17 · SF"},
            {"name": "Alex Lee", "role": "coauthor", "seat": "Assembly · D-24 · San Jose"},
        ],
        "subjects": ["housing", "transit", "zoning"],
        "source": leginfo("SB 79"),
    },
    {
        "id": "ca-sb-53", "code": "SB 53", "chamber": "senate",
        "title": "Transparency in Frontier Artificial Intelligence Act",
        "summary": "First-in-nation law: big AI labs must publish safety protocols, "
                   "report critical incidents, and protect whistleblowers.",
        "status": "law", "stage": 5,
        "introduced": "2025-01-14",
        "lastAction": {"date": "2025-09-29", "action": "Approved by the Governor."},
        "people": [
            {"name": "Scott Wiener", "role": "author", "seat": "State Senate · D-11 · SF"},
        ],
        "subjects": ["ai", "tech"],
        "source": leginfo("SB 53"),
    },
    {
        "id": "ca-sb-627", "code": "SB 627", "chamber": "senate",
        "title": "No Secret Police Act",
        "summary": "Bans federal and local law enforcement — including ICE — from "
                   "concealing their faces with ski masks during operations.",
        "status": "enjoined", "stage": 5, "crossLevel": True,
        "introduced": "2025-02-25",
        "lastAction": {"date": "2026-02-09",
                       "action": "Federal court partly blocked enforcement against federal "
                                 "officers — DOJ sued California under the Supremacy Clause."},
        "people": [
            {"name": "Scott Wiener", "role": "author", "seat": "State Senate · D-11 · SF"},
            {"name": "Jesse Arreguín", "role": "coauthor", "seat": "State Senate · D-7 · Oakland"},
            {"name": "Sasha Pérez", "role": "coauthor", "seat": "State Senate · D-25 · Pasadena"},
            {"name": "Aisha Wahab", "role": "coauthor", "seat": "State Senate · D-10 · Fremont"},
            {"name": "Isaac Bryan", "role": "coauthor", "seat": "Assembly · D-55 · Los Angeles"},
        ],
        "subjects": ["immigration", "police", "federal"],
        "source": leginfo("SB 627"),
    },
    {
        "id": "ca-ab-1064", "code": "AB 1064", "chamber": "assembly",
        "title": "Leading Ethical AI Development for Kids Act",
        "summary": "Would ban companies from offering companion AI chatbots to minors "
                   "unless they can ensure no sexual content or self-harm encouragement.",
        "status": "vetoed", "stage": 4,
        "introduced": "2025-02-20",
        "lastAction": {"date": "2025-10-13", "action": "Vetoed by the Governor."},
        "people": [
            {"name": "Rebecca Bauer-Kahan", "role": "author", "seat": "Assembly · D-16 · Orinda"},
        ],
        "subjects": ["ai", "kids", "tech"],
        "source": leginfo("AB 1064"),
    },
    {
        "id": "ca-sb-7", "code": "SB 7", "chamber": "senate",
        "title": "No Robo Bosses Act",
        "summary": "Would require employers to notify workers before using automated "
                   "systems in hiring, discipline, or firing decisions.",
        "status": "vetoed", "stage": 4,
        "introduced": "2024-12-02",
        "lastAction": {"date": "2025-10-13", "action": "Vetoed by the Governor."},
        "people": [
            {"name": "Jerry McNerney", "role": "author", "seat": "State Senate · D-5 · Stockton"},
        ],
        "subjects": ["ai", "labor", "work"],
        "source": leginfo("SB 7"),
    },
]


def build_ca():
    return {
        "_generated": "pipeline/legislation.py — do not edit",
        "state": "CA",
        "session": "2025-2026",
        "stages": ["introduced", "committee", "first chamber",
                   "second chamber", "governor", "law"],
        "bills": BILLS,
    }


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    (OUT / "ca.json").write_text(json.dumps(build_ca(), indent=2) + "\n")
    print(f"ca.json: {len(BILLS)} bills")
