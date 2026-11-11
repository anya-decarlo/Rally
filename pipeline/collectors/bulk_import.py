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
PEOPLE_OUT = LEGISLATION.parent.parent / "people" / "ca.json"


def rows(path):
    with open(path, newline="") as f:
        yield from csv.DictReader(f)


def lit(s):
    try:
        return ast.literal_eval(s)
    except (ValueError, SyntaxError):
        return []


def load_people():
    """person_id → full legislator record (seat label + contact/photo/site)."""
    people = {}
    if not PEOPLE_CSV.exists():
        return people
    for p in rows(PEOPLE_CSV):
        chamber = "senate" if p["current_chamber"] == "upper" else "assembly"
        label = "State Senate" if chamber == "senate" else "Assembly"
        people[p["id"]] = {
            "name": p["name"],
            "seat": f"{label} · {p['current_party'][:1]}-{p['current_district']}",
            "chamber": chamber,
            "district": p["current_district"],
            "party": p["current_party"][:1],
            "photo": p.get("image") or "",
            "email": p.get("email") or "",
            "site": (p.get("links") or "").split(";")[0],
        }
    return people


def normalize_bulk(bill, abstracts, actions, sponsors, sources, seats):
    code = bill["identifier"]
    acts = sorted(actions, key=lambda a: (a["date"], int(a["order"] or 0)))
    latest = acts[-1] if acts else {}
    people = [
        {"name": sp["name"], "pid": sp["person_id"],
         "role": "author" if sp["primary"] == "True" or sp["classification"] == "author" else "coauthor",
         "seat": seats.get(sp["person_id"], {}).get("seat", "")}
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
    our_id = {}          # ocd-bill → ca-xx-nn
    people = {}          # person_id → legislator record w/ authored/votes
    for bill in rows(d / f"{pref}bills.csv"):
        nb = normalize_bulk(bill, abstracts.get(bill["id"], []),
                            actions.get(bill["id"], []),
                            sponsors.get(bill["id"], []),
                            sources.get(bill["id"], []), seats)
        bills.append(nb)
        our_id[bill["id"]] = nb["id"]
        for sp in sponsors.get(bill["id"], []):
            if sp["entity_type"] != "person" or not sp["person_id"]:
                continue
            rec = people.setdefault(sp["person_id"],
                dict(seats.get(sp["person_id"], {"name": sp["name"], "seat": "",
                     "chamber": "", "district": "", "party": "",
                     "photo": "", "email": "", "site": ""}),
                     authored=[], coauthored=[], votes=[]))
            key = "authored" if sp["primary"] == "True" or sp["classification"] == "author" else "coauthored"
            rec[key].append(nb["id"])
        if bill["id"] in votes:
            votes_out[nb["id"]] = [
                {"date": v["start_date"][:10], "motion": v["motion_text"],
                 "result": v["result"], "body": orgs.get(v["organization_id"], ""),
                 "counts": counts.get(v["id"], {}),
                 "members": members.get(v["id"], [])}
                for v in sorted(votes[bill["id"]], key=lambda v: v["start_date"])
            ]

    # Member votes → per-person record {"bill": ca-id, "option", "date"}
    vote_date = {v["id"]: (v["start_date"][:10], v["bill_id"])
                 for vs in votes.values() for v in vs}
    for r in rows(d / f"{pref}vote_people.csv"):
        pid = r["voter_id"]
        if not pid or r["vote_event_id"] not in vote_date:
            continue
        date, bill_id = vote_date[r["vote_event_id"]]
        people.setdefault(pid, dict(seats.get(pid, {"name": r["voter_name"],
                "seat": "", "chamber": "", "district": "", "party": "",
                "photo": "", "email": "", "site": ""}),
                authored=[], coauthored=[], votes=[]))
        if bill_id in our_id:
            people[pid]["votes"].append(
                {"bill": our_id[bill_id], "option": r["option"], "date": date})

    # Roster = light file the app loads at once; each member's vote history is
    # a separate lazily-loaded file — 600k vote rows can't decode at launch.
    PEOPLE_OUT.parent.mkdir(exist_ok=True)
    (PEOPLE_OUT.parent / "ca").mkdir(exist_ok=True)
    roster = []
    for pid, rec in people.items():
        detail = {"id": pid,
                  "votes": sorted(rec["votes"], key=lambda v: v["date"], reverse=True)}
        (PEOPLE_OUT.parent / "ca" / f"{pid.split('/')[-1]}.json").write_text(
            json.dumps(detail))
        roster.append({"id": pid,
            **{k: v for k, v in rec.items()
               if k in ("name", "seat", "chamber", "district", "party",
                        "photo", "email", "site")},
            "authored": rec["authored"], "coauthored": rec["coauthored"],
            "voteCount": len(rec["votes"])})
    roster.sort(key=lambda p: (p["chamber"] != "senate", p["district"], p["name"]))
    PEOPLE_OUT.write_text(json.dumps(
        {"_generated": "bulk_import — do not edit", "state": "CA",
         "session": STATE_SESSION, "people": roster}))

    previous = {}
    if LEGISLATION.exists():
        previous = {b["id"]: b for b in json.loads(LEGISLATION.read_text())["bills"]}
    added, updated = merge_legislation(bills)
    events = emit_activity(bills, previous)
    VOTES_OUT.write_text(json.dumps({"_generated": "bulk_import — do not edit",
                                     "state": "CA", "session": STATE_SESSION,
                                     "votes": votes_out}))
    n_votes = sum(len(v) for v in votes_out.values())
    n_cast = sum(p["voteCount"] for p in roster)
    print(f"done: {len(bills)} bills · {added} new · {updated} updated · "
          f"{events} events · {n_votes} vote events on {len(votes_out)} bills · "
          f"{len(roster)} legislators · {n_cast} member votes")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/ca_bulk/CA/20252026")
