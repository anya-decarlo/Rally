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


def card(category, text, source, url):
    return {"text": text, "source": source, "url": url, "category": category}


def cards(d):
    out = []

    # identity — the non-bio structured bits
    idn = d.get("identity") or {}
    src = idn.get("sources", {})
    if idn.get("office_sought_note"):
        out.append(card("identity", idn["office_sought_note"], "DC Council", src.get("council_bio")))
    if idn.get("council_tenure"):
        out.append(card("identity", f"Council tenure: {idn['council_tenure']}", "DC Council", src.get("council_bio")))
    if idn.get("current_office"):
        out.append(card("identity", idn["current_office"], "DC Council", src.get("council_bio")))

    # money — every federal number is its own card
    m = d.get("money") or {}
    fed = m.get("federal") or {}
    labels = [("receipts", "Raised"), ("disbursements", "Spent"), ("individual_contributions", "From individuals"),
              ("individual_itemized", "Itemized (over $200)"), ("individual_unitemized", "Small-dollar (under $200)"),
              ("other_pac_contributions", "From PACs"), ("operating_expenditures", "Operating expenditures"),
              ("cash_on_hand", "Cash on hand")]
    for key, label in labels:
        if fed.get(key) is not None:
            out.append(card("money", f"{label}: {usd(fed[key])} — {fed['committee']}, {fed['coverage']}", "FEC", fed["source"]))

    snap = m.get("federal_opponent_snapshot") or {}
    for key, label in [("pinto_raised", "Brooke Pinto raised"), ("pinto_spent", "Brooke Pinto spent"), ("pinto_cash", "Brooke Pinto cash on hand"),
                       ("white_raised", "Robert White raised"), ("white_spent", "Robert White spent"), ("white_cash", "Robert White cash on hand")]:
        if snap.get(key) is not None:
            out.append(card("money", f"{label}: {usd(snap[key])} as of {snap['as_of']}", "FEC via Wikipedia", snap["source"]))

    for y in m.get("local_ocf_by_year") or []:
        out.append(card("money", f"{y['year']} Council campaign: {usd(y['total'])} across {y['count']:,} contributions", "DC OCF", OCF_URL))
    if m.get("local_ocf_note"):
        out.append(card("money", m["local_ocf_note"], "DC OCF", OCF_URL))

    for x in m.get("local_2020_max_donors_1000") or []:
        out.append(card("money", f"$1,000-max donor, 2020 Council run: {x['donor']} ({x['sector_hint']})", "DC OCF", OCF_URL))

    oc = m.get("oppo_claim")
    if oc:
        out.append(card("money", f"Claim: {oc['claim']} — {oc['framing']}", "NY Post", oc["source"]))

    # primary — a results table is one fact; every row kept, verbatim, together
    p = d.get("primary_2026") or {}
    if p.get("results"):
        rows = "\n".join(f"{r['candidate']} — {r['pct']}% ({r['votes']:,} votes)" for r in p["results"])
        out.append(card("vote", f"Democratic primary for Delegate, {p['date']}\n{rows}", "AP via Wikipedia", p["sources"]["results_table"]))
    if p.get("note"):
        out.append(card("vote", f"{p['date']}: {p['note']}", "AP via Wikipedia", p["sources"]["results_table"]))

    # record — every highlight, every vote, scorecard latest + each history year
    rec = d.get("record") or {}
    for c in rec.get("committees") or []:
        out.append(card("record", c, "2025 Annual Report", rec.get("record_source")))
    for h in rec.get("highlights") or []:
        out.append(card("record", h, "2025 Annual Report", rec.get("record_source")))
    sc = rec.get("scorecard") or {}
    for v in sc.get("votes") or []:
        side = "FOR" if v["white"] == "for" else "AGAINST"
        out.append(card("vote", f"Voted {side}: {v['title']} ({v['bill']}, {v['date']}) — {v['outcome']}", f"DC Council · JUFJ scorecard", v["link"]))
    if sc.get("latest"):
        hist = "\n".join(f"{yr}: {pct}" for yr, pct in sorted((sc.get("history") or {}).items()))
        out.append(card("vote", f"JUFJ Campaign Fund scorecard\nCurrent term: {sc['latest']}\n{hist}", "JUFJ Campaign Fund (advocacy)", sc["source"]))

    # voice — verbatim
    v = d.get("voice") or {}
    if v.get("victory_quote"):
        out.append(card("record", f"“{v['victory_quote']}”", "NBC4", v["victory_quote_source"]))
    if v.get("defend_dc"):
        out.append(card("record", f"“Defend DC” plan: {v['defend_dc']}", "AP", v["defend_dc_source"]))
    for e in v.get("electoral_history") or []:
        out.append(card("record", e, "Wikipedia", src.get("bio_timeline")))

    # endorsements — one each
    for e in d.get("endorsements_2026") or []:
        out.append(card("endorsement", f"Endorsed by {e}", "Campaign", src.get("campaign_site")))

    # pairs — vote ⟷ money, verbatim both sides
    for pr in d.get("vote_vs_money_pairs") or []:
        out.append(card("pair", f"{pr['vote']}{SEP}{pr['money']}", "DC Council + DC OCF", pr["vote_link"]))

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
