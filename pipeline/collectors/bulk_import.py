"""Bulk importer — OpenStates session CSV archive → data/legislation/ca.json.

One zip replaces ~253 rate-limited API pages. Updated monthly by OpenStates;
the API collector (openstates.py) handles incremental updates between drops.

    python3 pipeline/collectors/bulk_import.py /tmp/ca_bulk/CA/20252026

Archive layout (per-session zip): bills, bill_abstracts, bill_actions,
bill_sponsorships, bill_sources, votes, vote_people, vote_counts,
organizations. Download URL comes from the jurisdictions API:
    /jurisdictions/CA?include=legislative_sessions → session.downloads[].url
"""
import ast, csv, json, sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from openstates import (merge_legislation, emit_activity, status_of,
                        LEGISLATION, STATE_SESSION)

PEOPLE_CSV = Path("/tmp/ca_people.csv")  # data.openstates.org/people/current/ca.csv
VOTES_OUT = LEGISLATION.parent / "ca_votes.json"


def rows(path):
    with open(path, newline="") as f:
        yield from csv.DictReader(f)


def lit(s):
    try:
        return ast.literal_eval(s)
    except (ValueError, SyntaxError):
        return []


def load_people():
    """person_id → 'Chamber · P-district' seat label."""
    seats = {}
    if not PEOPLE_CSV.exists():
        return seats
    for p in rows(PEOPLE_CSV):
        chamber = "State Senate" if p["current_chamber"] == "upper" else "Assembly"
        seats[p["id"]] = f"{chamber} · {p['current_party'][:1]}-{p['current_district']}"
    return seats


def normalize_bulk(bill, abstracts, actions, sponsors, sources, seats):
    code = bill["identifier"]
    acts = sorted(actions, key=lambda a: (a["date"], int(a["order"] or 0)))
    latest = acts[-1] if acts else {}
    people = [
        {"name": sp["name"],
         "role": "author" if sp["primary"] == "True" or sp["classification"] == "author" else "coauthor",
         "seat": seats.get(sp["person_id"], "")}
        for sp in sponsors if sp["entity_type"] == "person" and sp["name"]
    ]
    leginfo = next((s["url"] for s in sources if "leginfo" in s["url"]), None)
    return {
        "id": "ca-" + code.lower().replace(" ", "-"),
        "code": code,
        "chamber": "senate" if bill["organization_classification"] == "upper" else "assembly",
        "title": bill["title"] or code,
        "summary": (abstracts[0] if abstracts else "")[:500] or bill["title"],
        "status": status_of({"latest_action_description": latest.get("description", "")}),
        "introduced": acts[0]["date"] if acts else None,
        "lastAction": {"date": latest.get("date", ""), "action": latest.get("description", "")} if acts else None,
        "people": people,
        "subjects": [s.lower() for s in lit(bill.get("subject", "[]"))][:6],
        "source": leginfo or (sources[0]["url"] if sources else
                  f"https://openstates.org/ca/bills/{STATE_SESSION}/{code}/"),
        "retrievedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


def main(bulk_dir):
    d = Path(bulk_dir)
    pref = "CA_20252026_"
    seats = load_people()
    orgs = {r["id"]: r["name"] for r in rows(d / f"{pref}organizations.csv")}

    abstracts, actions, sponsors, sources = {}, {}, {}, {}
    for r in rows(d / f"{pref}bill_abstracts.csv"):
        abstracts.setdefault(r["bill_id"], []).append(r["abstract"])
    for r in rows(d / f"{pref}bill_actions.csv"):
        actions.setdefault(r["bill_id"], []).append(r)
    for r in rows(d / f"{pref}bill_sponsorships.csv"):
        sponsors.setdefault(r["bill_id"], []).append(r)
    for r in rows(d / f"{pref}bill_sources.csv"):
        sources.setdefault(r["bill_id"], []).append(r)

    votes, counts, members = {}, {}, {}
    for r in rows(d / f"{pref}votes.csv"):
        votes.setdefault(r["bill_id"], []).append(r)
    for r in rows(d / f"{pref}vote_counts.csv"):
        counts.setdefault(r["vote_event_id"], {})[r["option"]] = int(r["value"])
    for r in rows(d / f"{pref}vote_people.csv"):
        members.setdefault(r["vote_event_id"], []).append(
            {"name": r["voter_name"], "option": r["option"]})

    bills, votes_out = [], {}
    for bill in rows(d / f"{pref}bills.csv"):
        nb = normalize_bulk(bill, abstracts.get(bill["id"], []),
                            actions.get(bill["id"], []),
                            sponsors.get(bill["id"], []),
                            sources.get(bill["id"], []), seats)
        bills.append(nb)
        if bill["id"] in votes:
            votes_out[nb["id"]] = [
                {"date": v["start_date"][:10], "motion": v["motion_text"],
                 "result": v["result"], "body": orgs.get(v["organization_id"], ""),
                 "counts": counts.get(v["id"], {}),
                 "members": members.get(v["id"], [])}
                for v in sorted(votes[bill["id"]], key=lambda v: v["start_date"])
            ]

    previous = {}
    if LEGISLATION.exists():
        previous = {b["id"]: b for b in json.loads(LEGISLATION.read_text())["bills"]}
    added, updated = merge_legislation(bills)
    events = emit_activity(bills, previous)
    VOTES_OUT.write_text(json.dumps({"_generated": "bulk_import — do not edit",
                                     "state": "CA", "session": STATE_SESSION,
                                     "votes": votes_out}))
    n_votes = sum(len(v) for v in votes_out.values())
    print(f"done: {len(bills)} bills · {added} new · {updated} updated · "
          f"{events} events · {n_votes} vote events on {len(votes_out)} bills")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/ca_bulk/CA/20252026")
