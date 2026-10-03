#!/usr/bin/env python3
"""Bluesky → posts.json. Public AT Protocol API, no auth. Stdlib only.

    python3 pipeline/bluesky.py                 # all bluesky accounts in accounts.json
    python3 pipeline/bluesky.py --limit 50      # cap posts per account
"""
import argparse, json, sys, urllib.parse, urllib.request
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from candidates import accounts as ballot_accounts

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "posts.json"
API = "https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed"


def fetch_feed(handle, limit):
    posts, cursor = [], None
    while len(posts) < limit:
        q = {"actor": handle, "limit": min(100, limit - len(posts)), "filter": "posts_no_replies"}
        if cursor:
            q["cursor"] = cursor
        with urllib.request.urlopen(f"{API}?{urllib.parse.urlencode(q)}", timeout=30) as r:
            page = json.load(r)
        for item in page.get("feed", []):
            if item.get("reason"):                       # a repost of someone else — skip
                continue
            if item["post"]["author"]["handle"] != handle:
                continue
            posts.append(item["post"])
        cursor = page.get("cursor")
        if not cursor or not page.get("feed"):
            break
    return posts


def rkey(uri):
    return uri.rsplit("/", 1)[-1]


def post_url(handle, uri):
    return f"https://bsky.app/profile/{handle}/post/{rkey(uri)}"


def alt(s):
    """Verbatim, but trimmed; whitespace-only becomes null."""
    s = (s or "").strip()
    return s or None


def media_from(embed):
    if not embed:
        return [], None
    t = embed.get("$type", "")
    media, quoted = [], None
    if t.startswith("app.bsky.embed.images"):
        media += [{"type": "image", "url": i.get("fullsize"), "thumb": i.get("thumb"), "alt": alt(i.get("alt"))}
                  for i in embed.get("images", [])]
    elif t.startswith("app.bsky.embed.video"):
        media.append({"type": "video", "url": embed.get("playlist"), "thumb": embed.get("thumbnail"),
                      "alt": alt(embed.get("alt"))})
    elif t.startswith("app.bsky.embed.external"):
        ext = embed.get("external", {})
        media.append({"type": "link", "url": ext.get("uri"), "title": ext.get("title") or None,
                      "thumb": ext.get("thumb")})
    elif t.startswith("app.bsky.embed.record"):
        rec = embed.get("record", {})
        if "media" in embed:                              # recordWithMedia: quote + attachment
            m, _ = media_from(embed["media"])
            media += m
            rec = rec.get("record", rec)
        if rec.get("$type", "").endswith("viewRecord"):
            quoted = {"handle": rec["author"]["handle"],
                      "text": rec.get("value", {}).get("text", ""),
                      "url": post_url(rec["author"]["handle"], rec["uri"])}
    return media, quoted


def normalize(post, account):
    rec = post["record"]
    media, quoted = media_from(post.get("embed"))
    out = {
        "id": f"bluesky:{rkey(post['uri'])}",
        "platform": "bluesky",
        "candidate": account["candidate"],
        "account": {
            "handle": post["author"]["handle"],
            "displayName": post["author"].get("displayName") or post["author"]["handle"],
            "avatar": post["author"].get("avatar"),
            "kind": account["kind"],
        },
        "text": rec.get("text", ""),
        "createdAt": rec.get("createdAt"),
        "url": post_url(post["author"]["handle"], post["uri"]),
        "media": media,
        "metrics": {"likes": post.get("likeCount", 0), "reposts": post.get("repostCount", 0),
                    "replies": post.get("replyCount", 0)},
    }
    if quoted:
        out["quoted"] = quoted
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=100)
    args = ap.parse_args()

    accounts = ballot_accounts("bluesky")
    existing = json.loads(OUT.read_text())["posts"] if OUT.exists() else []
    merged = {p["id"]: p for p in existing}

    for a in accounts:
        posts = fetch_feed(a["handle"], args.limit)
        for p in posts:
            n = normalize(p, a)
            merged[n["id"]] = n
        print(f"{a['handle']}: {len(posts)} posts", file=sys.stderr)

    out = sorted(merged.values(), key=lambda p: p["createdAt"], reverse=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                               "posts": out}, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(out)} posts → {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
