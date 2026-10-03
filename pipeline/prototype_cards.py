#!/usr/bin/env python3
"""prototypes/<slug>.json → feed cards, merged into data/facts.json.

    python3 pipeline/prototype_cards.py

ONE CARD = ONE DATUM. Nothing is summarized, grouped, or dropped. Text fields are
verbatim; numbers get a label and nothing else. Every card carries the source URL
from the JSON it came from. Nulls are skipped, never invented.

Categories: money · vote · record · pair · endorsement · identity
"""
import json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from candidates import candidates, slug

ROOT = Path(__file__).resolve().parent.parent
FACTS = ROOT / "data" / "facts.json"
PROTO = ROOT / "prototypes"
SEP = " ⟷ "
OCF_URL = "https://efiling.ocf.dc.gov/ContributionExpenditure"


def load_lenient(p):
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", p.read_text()))


def usd(n):
    return f"${n:,.2f}" if n != int(n) else f"${int(n):,}"


# Plain-English "what am I looking at" notes. Definitions and context for THIS card — never new claims.
EXPLAIN = {
    "receipts": "Receipts = every dollar that came into the campaign committee in the period: individual donations, PAC money, transfers. This is the top-line 'raised' number the FEC reports.",
    "disbursements": "Disbursements = every dollar the committee paid out: ads, staff, consultants, rent, fees. The top-line 'spent' number.",
    "individual_contributions": "Money from people (not PACs, parties, or committees). Federal law caps an individual at $3,500 per election for the 2026 cycle.",
    "individual_itemized": "'Itemized' = donations from anyone who gave more than $200 total. The FEC requires the donor's name, address, employer and occupation on these — this is the part of the money you can actually see.",
    "individual_unitemized": "'Unitemized' = donations of $200 or less. Reported only as a lump sum — no names. A high share here usually means a small-donor base.",
    "other_pac_contributions": "Money from political action committees — unions, trade groups, corporate PACs, leadership PACs. Capped at $5,000 per election per PAC.",
    "operating_expenditures": "The everyday cost of running the campaign: payroll, rent, ads, travel, consultants. Most of 'spent' is this.",
    "cash_on_hand": "What was left in the account on the last day of the reporting period. Low cash late in a race means the money is being spent, not hoarded.",
    "money-race": "A snapshot of both campaigns' FEC totals on the same date, so the numbers are comparable. Brooke Pinto was his main primary opponent. Pinto raised about 3x more and still lost the primary 63.6% to 20.9%.",
    "ocf-years": "His earlier Council campaigns filed with DC's Office of Campaign Finance (OCF), not the FEC — local races, local regulator. 'Contributions' here = number of individual donation rows in the filing.",
    "ocf-gap": "The DC OCF open-data layer tags rows by candidate name. His 2022 mayoral run and later filings appear under different committee names or years, so they don't show up under 'Robert White' — a data quirk, not missing money.",
    "donors-2020": "In 2020, $1,000 was the legal maximum one person or company could give to an At-Large Council candidate in DC. This donor gave the cap. The sector tag is a hint derived from the filing's employer/occupation field. Real-estate developers are a frequent topic in DC politics because the Council votes on zoning, housing and land deals.",
    "oppo": "An 'oppo file' is opposition research a rival campaign assembles about a candidate. This is their claim, reported by a newspaper. Rally shows it next to the filings so you can check it yourself — it is not a finding.",
    "primary": "DC is overwhelmingly Democratic, so the Democratic primary effectively decides the Delegate seat. 2026 was DC's first ranked-choice primary: voters ranked candidates, and if nobody cleared 50% the last-place candidate's votes were redistributed. He cleared 50% outright.",
    "primary-note": "Eleanor Holmes Norton held the Delegate seat from 1991 to 2026. The Mayor's office was also open in 2026, so DC chose a new mayor and a new delegate on the same ballot.",
    "committees": "DC Councilmembers chair committees that write and gatekeep legislation in one policy area. The Housing chair controls the housing budget and oversight of the DC Housing Authority (DCHA).",
    "highlights": "From his office's own 2025 annual report — his account of what he did. Treat it as the candidate speaking, not a neutral audit.",
    "votes": "A recorded vote on a DC Council bill. Bill numbers like B24-0192 mean Council Period 24 (2021-22), bill 192. 'Passed' or 'failed' is the outcome of the vote itself. These votes were selected by the JUFJ Campaign Fund, an advocacy group — the list reflects what they cared about.",
    "scorecard": "The JUFJ Campaign Fund is a progressive advocacy group (Jews United for Justice). Their scorecard grades councilmembers on how often they voted the group's way on bills the group picked. It's a legitimate record of votes, scored from one point of view — always labeled advocacy in Rally.",
    "victory": "His election-night speech after winning the 2026 Democratic primary for Delegate, as reported by NBC4.",
    "defend-dc": "His stated plan for the Delegate seat, as reported by AP. The Delegate can't vote on the House floor, so this is a strategy for influence without a vote. Walter Fauntroy was DC's first delegate (1971-91).",
    "races": "Every election he has appeared in. 'At-Large' = a Council seat elected by the whole city, not one ward. '(I)' = he ran as an independent that year.",
    "endorsements": "Endorsements the campaign lists on its own site. An endorsement is a public statement of support — it is not money. Some endorsers (unions, PACs) may separately spend money; that shows up in filings, not here.",
    "pair": "Two separate facts placed side by side: how he voted on a bill, and who gave to his campaign in an earlier cycle. Rally does not claim one caused the other. The point is that you can see both at once.",
    "identity": "Basic facts about the office, from the DC Council's official site.",
}


def card(category, title, text, source, url, explain=None):
    """title = plain-English headline; text = the datum, verbatim; explain = what-am-I-looking-at note."""
    c = {"title": title, "text": text, "source": source, "url": url, "category": category}
    if explain and explain in EXPLAIN: c["explain"] = EXPLAIN[explain]
    return c


def cards(d):
    out = []

    # identity — the non-bio structured bits
    idn = d.get("identity") or {}
    src = idn.get("sources", {})
    if idn.get("office_sought_note"):
        out.append(card("identity", "The seat he's running for", idn["office_sought_note"], "DC Council", src.get("council_bio"), explain="identity"))
    if idn.get("council_tenure"):
        out.append(card("identity", "Time on the Council", idn["council_tenure"], "DC Council", src.get("council_bio"), explain="identity"))
    if idn.get("current_office"):
        out.append(card("identity", "His current job", idn["current_office"], "DC Council", src.get("council_bio"), explain="identity"))

    # money — every federal number is its own card
    m = d.get("money") or {}
    fed = m.get("federal") or {}
    labels = [("receipts", "Raised"), ("disbursements", "Spent"), ("individual_contributions", "From individuals"),
              ("individual_itemized", "Itemized (over $200)"), ("individual_unitemized", "Small-dollar (under $200)"),
              ("other_pac_contributions", "From PACs"), ("operating_expenditures", "Operating expenditures"),
              ("cash_on_hand", "Cash on hand")]
    for key, label in labels:
        if fed.get(key) is not None:
            out.append(card("money", f"{label} — Delegate campaign", f"{usd(fed[key])}\n{fed['committee']}\n{fed['coverage']}", "FEC", fed["source"], explain=key))

    snap = m.get("federal_opponent_snapshot") or {}
    for key, label in [("pinto_raised", "Brooke Pinto raised"), ("pinto_spent", "Brooke Pinto spent"), ("pinto_cash", "Brooke Pinto cash on hand"),
                       ("white_raised", "Robert White raised"), ("white_spent", "Robert White spent"), ("white_cash", "Robert White cash on hand")]:
        if snap.get(key) is not None:
            out.append(card("money", "The money race vs. Brooke Pinto", f"{label}: {usd(snap[key])}\nas of {snap['as_of']}", "FEC via Wikipedia", snap["source"], explain="money-race"))

    for y in m.get("local_ocf_by_year") or []:
        out.append(card("money", f"His {y['year']} Council campaign", f"{usd(y['total'])} raised\n{y['count']:,} contributions", "DC OCF", OCF_URL, explain="ocf-years"))
    if m.get("local_ocf_note"):
        out.append(card("money", "A gap in the local filings", m["local_ocf_note"], "DC OCF", OCF_URL, explain="ocf-gap"))

    for x in m.get("local_2020_max_donors_1000") or []:
        out.append(card("money", f"Gave the $1,000 max in 2020 · {x['sector_hint']}", x["donor"], "DC OCF", OCF_URL, explain="donors-2020"))

    oc = m.get("oppo_claim")
    if oc:
        out.append(card("money", "What his opponent's oppo file claimed", f"{oc['claim']}\n{oc['framing']}", "NY Post", oc["source"], explain="oppo"))

    # primary — a results table is one fact; every row kept, verbatim, together
    p = d.get("primary_2026") or {}
    if p.get("results"):
        rows = "\n".join(f"{r['candidate']} — {r['pct']}% ({r['votes']:,} votes)" for r in p["results"])
        out.append(card("vote", "He won the primary", f"Democratic primary for Delegate, {p['date']}\n{rows}", "AP via Wikipedia", p["sources"]["results_table"], explain="primary"))
    if p.get("note"):
        out.append(card("vote", "Why this primary was different", f"{p['date']}: {p['note']}", "AP via Wikipedia", p["sources"]["results_table"], explain="primary-note"))

    # record — every highlight, every vote, scorecard latest + each history year
    rec = d.get("record") or {}
    for c in rec.get("committees") or []:
        out.append(card("record", "Committees", c, "2025 Annual Report", rec.get("record_source"), explain="committees"))
    for h in rec.get("highlights") or []:
        out.append(card("record", "What he did as Housing chair", h, "2025 Annual Report", rec.get("record_source"), explain="highlights"))
    sc = rec.get("scorecard") or {}
    for v in sc.get("votes") or []:
        side = "FOR" if v["white"] == "for" else "AGAINST"
        out.append(card("vote", f"Voted {side}", f"{v['title']}\n{v['bill']} · {v['date']} · {v['outcome']}", "DC Council · JUFJ scorecard", v["link"], explain="votes"))
    if sc.get("latest"):
        hist = "\n".join(f"{yr}: {pct}" for yr, pct in sorted((sc.get("history") or {}).items()))
        out.append(card("vote", "How a progressive group grades him", f"JUFJ Campaign Fund scorecard\nCurrent term: {sc['latest']}\n{hist}", "JUFJ Campaign Fund (advocacy)", sc["source"], explain="scorecard"))

    # voice — verbatim
    v = d.get("voice") or {}
    if v.get("victory_quote"):
        out.append(card("record", "What he said on election night", f"“{v['victory_quote']}”", "NBC4", v["victory_quote_source"], explain="victory"))
    if v.get("defend_dc"):
        out.append(card("record", "His plan: “Defend DC”", v["defend_dc"], "AP", v["defend_dc_source"], explain="defend-dc"))
    for e in v.get("electoral_history") or []:
        out.append(card("record", "Every race he's run", e, "Wikipedia", src.get("bio_timeline"), explain="races"))

    # endorsements — one each
    for e in d.get("endorsements_2026") or []:
        out.append(card("endorsement", "Endorsed by", e, "Campaign", src.get("campaign_site"), explain="endorsements"))

    # pairs — vote ⟷ money, verbatim both sides
    for pr in d.get("vote_vs_money_pairs") or []:
        out.append(card("pair", "A vote, and the money", f"{pr['vote']}{SEP}{pr['money']}", "DC Council + DC OCF", pr["vote_link"], explain="pair"))

    return [c for c in out if c["text"] and c["url"]]


def main():
    facts = json.loads(FACTS.read_text())
    for c in candidates():
        p = PROTO / f"{slug(c['name'])}.json"
        if not p.exists():
            continue
        new = cards(load_lenient(p))
        entry = facts["candidates"].setdefault(c["name"], {"facts": [], "portrait": None})
        bio = [f for f in entry["facts"] if (f.get("category") or "bio") == "bio"]
        entry["facts"] = bio + new
        print(f"{c['name']}: {len(new)} cards from prototype + {len(bio)} bio", file=sys.stderr)
    FACTS.write_text(json.dumps(facts, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
