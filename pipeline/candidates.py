"""The ballot is the only list of candidates. Every fetcher imports from here.

    from candidates import candidates, accounts, slug

data/ballot.json is shared with the app (bundled as ballot.json). A name that isn't
on a card doesn't get crawled; a name on a card is spelled exactly one way.
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BALLOT = ROOT / "data" / "ballot.json"


def ballot():
    return json.loads(BALLOT.read_text())


def candidates():
    """Flat list of candidate records, each with its contest attached."""
    out = []
    for contest in ballot()["contests"]:
        for c in contest["candidates"]:
            out.append({**c, "contest": contest["office"], "group": contest["group"]})
    return out


def accounts(platform=None):
    """Flat list of {candidate, platform, handle, kind} — the crawl allowlist."""
    out = []
    for c in candidates():
        for a in c.get("accounts", []):
            if platform is None or a["platform"] == platform:
                out.append({"candidate": c["name"], **a})
    return out


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def write_accounts_json():
    """Derived file for the backend's allowlist. Never edit by hand; regenerate from the ballot."""
    (ROOT / "pipeline" / "accounts.json").write_text(json.dumps(
        {"_generated": "from data/ballot.json — do not edit", "accounts": accounts()}, indent=2) + "\n")


if __name__ == "__main__":
    write_accounts_json()
    for a in accounts():
        print(f"{a['candidate']:24} {a['platform']:8} @{a['handle']:30} {a['kind']}")
