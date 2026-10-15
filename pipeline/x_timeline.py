#!/usr/bin/env python3
"""X timeline crawler → posts.json. Enumerates each allowlisted X account's
logged-out profile page (server-rendered, no auth) for its newest status IDs,
then resolves each through the same syndication endpoint x.py uses.

    python3 pipeline/x_timeline.py                 # one pass over every X account
    python3 pipeline/x_timeline.py --one           # one random account (cron/rotate)
    python3 pipeline/x_timeline.py @Rosado4Congress ...
    python3 pipeline/x_timeline.py --loop 20 60    # rotate forever, sleep 20-60 min
                                                   # between accounts (stochastic)

The profile page only embeds the ~5 newest posts — bulk history is not available
without X's paid API. But run on a rotation it catches every new post and the
archive grows monotonically: merges by id, never duplicates, never deletes.
"""
import json, random, re, sys, time, urllib.request
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from candidates import accounts as ballot_accounts
from x import fetch, normalize

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "posts.json"
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"}


def status_ids(handle):
    """Tweet IDs from the logged-out profile page (Posts tab, newest ~5)."""
    req = urllib.request.Request(f"https://x.com/{handle}", headers=UA)
    raw = urllib.request.urlopen(req, timeout=30).read().decode()
    return sorted(set(re.findall(rf"/{re.escape(handle)}/status/(\d{{10,}})", raw,
                                 flags=re.I)))


def crawl(account):
    handle = account["handle"]
    ids = status_ids(handle)
    posts = []
    for tid in ids:
        try:
            t = fetch(tid)
        except Exception as e:
            print(f"  ! tweet-result failed for {tid}: {e}", file=sys.stderr)
            continue
        if t.get("user", {}).get("screen_name", "").lower() != handle.lower():
            continue
        posts.append(normalize(t, account))
    return posts


def write(posts):
    existing = json.loads(OUT.read_text())["posts"] if OUT.exists() else []
    merged = {p["id"]: p for p in existing}
    new = 0
    for p in posts:
        if p["id"] not in merged:
            new += 1
        merged[p["id"]] = p
    out = sorted(merged.values(), key=lambda p: p["createdAt"], reverse=True)
    OUT.write_text(json.dumps({"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                               "posts": out}, indent=2, ensure_ascii=False) + "\n")
    return len(out), new


def run(accounts):
    """Crawl the given accounts; returns total+new post counts."""
    found = []
    for a in accounts:
        try:
            got = crawl(a)
        except Exception as e:
            print(f"✗ @{a['handle']} ({a['candidate']}): {e}", file=sys.stderr)
            continue
        found += got
        print(f"✓ @{a['handle']} ({a['candidate']}): {len(got)} statuses", file=sys.stderr)
        time.sleep(random.uniform(2, 5))  # politeness between handles
    if not found:
        return None, 0
    return write(found)


def main():
    args = sys.argv[1:]
    accounts = ballot_accounts("x")
    by_handle = {a["handle"].lower().lstrip("@"): a for a in accounts}

    if args and args[0] == "--loop":
        lo, hi = (int(args[1]), int(args[2])) if len(args) >= 3 else (20, 60)
        print(f"rotating: one account every {lo}-{hi} min", file=sys.stderr)
        while True:
            a = random.choice(accounts)
            total, new = run([a]) or (None, 0)
            print(f"[{datetime.now(timezone.utc):%H:%MZ}] @{a['handle']} → {new} new "
                  f"({total} total)", file=sys.stderr)
            time.sleep(random.uniform(lo, hi) * 60)

    if args and args[0] == "--one":
        total, new = run([random.choice(accounts)])
    elif args:
        picked = [by_handle[a.lower().lstrip("@")] for a in args if a.lower().lstrip("@") in by_handle]
        total, new = run(picked)
    else:
        total, new = run(accounts)
    if total:
        print(f"wrote {total} posts ({new} new) → {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
