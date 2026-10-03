#!/usr/bin/env python3
"""X → posts.json. Curated only: a human supplies post URLs; nothing is crawled or searched.

    python3 pipeline/x.py https://x.com/RobertWhite_DC/status/1234567890 [more urls]

Uses X's public syndication JSON (what embedded tweets load). No key, but unofficial —
if it breaks, this file is the only thing that changes. The handle must be on the ballot (data/ballot.json).
"""
import json, re, sys, urllib.parse, urllib.request
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from candidates import accounts as ballot_accounts

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "posts.json"
SYND = "https://cdn.syndication.twimg.com/tweet-result"
UA = {"User-Agent": "Mozilla/5.0 (Rally/0.1; github.com/anya-decarlo/Rally)"}


def token(tweet_id):
    """The syndication endpoint's lightweight anti-abuse token: (id / 1e15 * pi) in base 36, zeros stripped."""
    n = (int(tweet_id) / 1e15) * 3.141592653589793
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    i, frac, s = int(n), n - int(n), ""
    while i:
        s, i = digits[i % 36] + s, i // 36
    for _ in range(10):
        frac *= 36
        d = int(frac)
        frac -= d
        s += digits[d]
    return s.replace("0", "")


def fetch(tweet_id):
    q = urllib.parse.urlencode({"id": tweet_id, "token": token(tweet_id), "lang": "en"})
    with urllib.request.urlopen(urllib.request.Request(f"{SYND}?{q}", headers=UA), timeout=30) as r:
        return json.load(r)


def alt(s):
    s = (s or "").strip()
    return s or None


def normalize(t, account):
    user = t["user"]
    media = []
    for m in t.get("mediaDetails", []) or []:
        if m.get("type") == "photo":
            media.append({"type": "image", "url": m.get("media_url_https"), "thumb": m.get("media_url_https"),
                          "alt": alt(m.get("ext_alt_text"))})
        elif m.get("type") in ("video", "animated_gif"):
            vs = sorted((v for v in m.get("video_info", {}).get("variants", []) if v.get("content_type") == "video/mp4"),
                        key=lambda v: v.get("bitrate", 0), reverse=True)
            media.append({"type": "video", "url": vs[0]["url"] if vs else None, "thumb": m.get("media_url_https"),
                          "alt": alt(m.get("ext_alt_text"))})
    for u in t.get("entities", {}).get("urls", []):
        media.append({"type": "link", "url": u.get("expanded_url"), "title": None, "thumb": None})
    created = t["created_at"]
    try:
        created = datetime.fromisoformat(created.replace("Z", "+00:00")).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        created = parsedate_to_datetime(created).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    out = {
        "id": f"x:{t['id_str']}",
        "platform": "x",
        "candidate": account["candidate"],
        "account": {"handle": user["screen_name"], "displayName": user.get("name") or user["screen_name"],
                    "avatar": user.get("profile_image_url_https"), "kind": account["kind"]},
        "text": t.get("text", ""),
        "createdAt": created,
        "url": f"https://x.com/{user['screen_name']}/status/{t['id_str']}",
        "media": media,
        "metrics": {"likes": t.get("favorite_count", 0), "reposts": t.get("retweet_count", 0),
                    "replies": t.get("reply_count", 0) or t.get("conversation_count", 0)},
    }
    if q := t.get("quoted_tweet"):
        out["quoted"] = {"handle": q["user"]["screen_name"], "text": q.get("text", ""),
                         "url": f"https://x.com/{q['user']['screen_name']}/status/{q['id_str']}"}
    return out


def main():
    urls = sys.argv[1:]
    if not urls:
        sys.exit(__doc__)
    accounts = {a["handle"].lower(): a for a in ballot_accounts("x")}
    existing = json.loads(OUT.read_text())["posts"] if OUT.exists() else []
    merged = {p["id"]: p for p in existing}
    for u in urls:
        m = re.search(r"(?:x|twitter)\.com/([^/]+)/status/(\d+)", u)
        if not m:
            print(f"skip (not a post url): {u}", file=sys.stderr); continue
        handle, tid = m.group(1), m.group(2)
        if handle.lower() not in accounts:
            print(f"skip (@{handle} not in accounts.json): {u}", file=sys.stderr); continue
        t = fetch(tid)
        if t.get("user", {}).get("screen_name", "").lower() != handle.lower():
            print(f"skip (author mismatch): {u}", file=sys.stderr); continue
        n = normalize(t, accounts[handle.lower()])
        merged[n["id"]] = n
        print(f"✓ @{handle}: {n['text'][:70]!r}", file=sys.stderr)
    out = sorted(merged.values(), key=lambda p: p["createdAt"], reverse=True)
    OUT.write_text(json.dumps({"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                               "posts": out}, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(out)} posts → {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
