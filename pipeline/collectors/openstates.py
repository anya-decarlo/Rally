"""Collector #1 — California AB/SB via OpenStates.

Fetch:   OPENSTATES_API_KEY (env) — openstates.org → profile → API key
Source:  https://v3.openstates.org — the 50-state legislature aggregator
Output:  data/legislation/ca.json   (bill cards — normalized Bill records)
         data/activity/ca.json    (event stream — status changes appended)

Collector contract (see COLLECTION.md):
    new + updated records · dedupe by id · preserve source_url ·
    structured fields · responsible body · jurisdiction tags ·
    retrieved_at on every record · status is append-only history

    OPENSTATES_API_KEY=... python3 pipeline/collectors/openstates.py
"""
import json, os, sys, time
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urlencode
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parent.parent.parent
LEGISLATION = ROOT / "data" / "legislation" / "ca.json"
ACTIVITY = ROOT / "data" / "activity" / "ca.json"
API = "https://v3.openstates.org"
JURISDICTION = "CA"
API_SESSION = "20252026"       # OpenStates session id format
STATE_SESSION = "2025-2026"    # our display format
PER_PAGE = 20  # API caps at 20
MAX_PAGES = 260  # full session (~5,041 bills); incremental syncs come later
DELAY = 2.0      # polite seconds between requests — OpenStates rate-limits
CHECKPOINT = Path("/tmp/ca_bills_checkpoint.json")


def api(path, **params):
    params["apikey"] = os.environ["OPENSTATES_API_KEY"]
    url = f"{API}{path}?{urlencode(params, doseq=True)}"
    for attempt in range(8):
        try:
            with urlopen(Request(url, headers={"User-Agent": "Rally/1.0"})) as r:
                return json.loads(r.read())
        except HTTPError as e:
            if e.code == 429:
                wait = 60 * (attempt + 1)
                print(f"  429 — cooling off {wait}s")
                time.sleep(wait)
                continue
            if e.code >= 500:
                print(f"  {e.code} — retrying in 15s")
                time.sleep(15)
                continue
            raise
    raise RuntimeError(f"rate limited repeatedly: {url}")


def chamber_of(bill):
    org = (bill.get("from_organization") or {}).get("name", "")
    return "senate" if "Senate" in org else "assembly"


def normalize(b):
    """OpenStates bill → our Bill record."""
    code = b["identifier"]
    people = []
    for sp in b.get("sponsorships", []):
        if sp.get("entity_type") != "person":
            continue
        p = sp.get("person") or {}
        name = p.get("name") or sp.get("name", "")
        if not name:
            continue
        role = "author" if sp.get("primary") or sp.get("classification") == "author" else "coauthor"
        seat = ""
        role_info = p.get("current_role") or {}
        if role_info:
            chamber = "State Senate" if role_info.get("org_classification") == "upper" else "Assembly"
            dist = role_info.get("district", "")
            party = (p.get("party") or "")[:1].upper()
            seat = f"{chamber} · {party}-{dist}"
        people.append({"name": name, "role": role, "seat": seat})
    actions = [
        {"date": (a.get("date") or "")[:10], "action": a.get("description", "")}
        for a in b.get("actions", [])
    ]
    actions.sort(key=lambda a: a["date"])
    return {
        "id": "ca-" + code.lower().replace(" ", "-"),
        "code": code,
        "chamber": chamber_of(b),
        "title": b.get("title") or code,
        "summary": (b.get("abstracts") or [{}])[0].get("abstract", "")[:500]
                   or b.get("title", ""),
        "status": status_of(b),
        "introduced": (b.get("first_action_date") or "")[:10] or None,
        "lastAction": actions[-1] if actions else None,
        "people": people,
        "subjects": [s.lower() for s in b.get("subject", [])][:6],
        "source": source_url(b),
        "retrievedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


def status_of(b):
    la = (b.get("latest_action_description") or "").lower()
    if "veto" in la: return "vetoed"  # "Vetoed by the Governor." / "Veto sustained."
    if "chaptered" in la or "approved by the governor" in la: return "law"
    if "governor" in la: return "governor's desk"
    if "failed" in la or "dead" in la or "inactive" in la: return "dead"
    if "committee" in la: return "in committee"
    if "passed" in la or "read third time" in la: return "passed a chamber"
    return "introduced"


def source_url(b):
    for s in b.get("sources", []):
        if "leginfo" in s.get("url", ""):
            return s["url"]
    return (b.get("sources") or [{}])[0].get("url",
        f"https://openstates.org/ca/bills/{STATE_SESSION}/{b['identifier']}/")


def stage_of(status):
    return {"introduced": 0, "in committee": 1, "passed a chamber": 2,
            "passed second chamber": 3, "governor's desk": 4,
            "law": 5, "vetoed": 4, "dead": 1, "enjoined": 5}.get(status, 0)


def fetch_all_bills():
    bills, page = [], 1
    if CHECKPOINT.exists():
        cp = json.loads(CHECKPOINT.read_text())
        bills, page = cp["bills"], cp["page"]
        print(f"resuming at page {page} ({len(bills)} bills already fetched)")
    while page <= MAX_PAGES:
        res = api("/bills", jurisdiction=JURISDICTION, session=API_SESSION,
                  sort="updated_desc", per_page=PER_PAGE, page=page,
                  include=["sponsorships", "actions", "abstracts", "sources"])
        results = res.get("results", [])
        bills += results
        print(f"  page {page}: {len(results)} bills ({len(bills)} total)")
        page += 1
        CHECKPOINT.write_text(json.dumps({"page": page, "bills": bills}))
        if len(results) < PER_PAGE:
            break
        time.sleep(DELAY)
    return bills


def merge_legislation(new_bills):
    """Merge into data/legislation/ca.json — merge by id, never delete."""
    doc = json.loads(LEGISLATION.read_text()) if LEGISLATION.exists() else {
        "_generated": "pipeline/collectors — do not edit",
        "state": "CA", "session": STATE_SESSION,
        "stages": ["introduced", "committee", "first chamber",
                   "second chamber", "governor", "law"],
        "bills": [],
    }
    by_id = {b["id"]: b for b in doc["bills"]}
    added = updated = 0
    for b in new_bills:
        b["stage"] = stage_of(b["status"])
        if b["id"] not in by_id:
            by_id[b["id"]] = b; added += 1
        elif by_id[b["id"]] != b:
            by_id[b["id"]] = b; updated += 1
    doc["bills"] = sorted(by_id.values(),
                          key=lambda b: (b.get("lastAction") or {}).get("date", ""),
                          reverse=True)
    LEGISLATION.write_text(json.dumps(doc, indent=2) + "\n")
    return added, updated


def emit_activity(new_bills, previous):
    """Status changes → ActivityItems appended to the stream."""
    doc = json.loads(ACTIVITY.read_text())
    items = {i["id"]: i for i in doc["items"]}
    new_events = 0
    for b in new_bills:
        prev = previous.get(b["id"])
        if prev is None:
            items[f"{b['id']}-seen"] = {
                "id": f"{b['id']}-seen", "kind": "billIntroduced",
                "jurisdiction": "ca", "date": b.get("introduced") or "",
                "title": f"{b['code']} — {b['title']}",
                "detail": b.get("summary"),
                "actors": [p["name"] for p in b.get("people", []) if p["role"] == "author"],
                "bill": b["code"], "source": b["source"],
            }
            new_events += 1
        elif prev.get("status") != b["status"]:
            eid = f"{b['id']}-{b['lastAction']['date'] if b.get('lastAction') else 'now'}"
            items[eid] = {
                "id": eid, "kind": "vote" if "pass" in (b["lastAction"] or {}).get("action", "").lower() else "billIntroduced",
                "jurisdiction": "ca",
                "date": (b.get("lastAction") or {}).get("date", ""),
                "title": f"{b['code']}: {prev['status']} → {b['status']}",
                "detail": (b.get("lastAction") or {}).get("action"),
                "bill": b["code"], "source": b["source"],
            }
            new_events += 1
    doc["items"] = sorted(items.values(), key=lambda i: i["date"], reverse=True)
    ACTIVITY.write_text(json.dumps(doc, indent=2) + "\n")
    return new_events


if __name__ == "__main__":
    if not os.environ.get("OPENSTATES_API_KEY"):
        sys.exit("OPENSTATES_API_KEY not set — openstates.org → profile → API key")
    previous = {}
    if LEGISLATION.exists():
        previous = {b["id"]: b for b in json.loads(LEGISLATION.read_text())["bills"]}
    print(f"collecting CA {STATE_SESSION} bills…")
    raw = fetch_all_bills()
    bills = [normalize(b) for b in raw]
    added, updated = merge_legislation(bills)
    events = emit_activity(bills, previous)
    print(f"done: {len(bills)} bills · {added} new · {updated} updated · {events} events")
