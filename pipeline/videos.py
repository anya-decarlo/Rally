#!/usr/bin/env python3
"""Curated YouTube clips → videos.json. No search, ever — only URLs a human verified.

    python3 pipeline/videos.py "Robert White" https://www.youtube.com/watch?v=...  [more urls]

Uses yt-dlp for metadata only (nothing is downloaded). Re-running merges by id.
"""
import json, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from candidates import candidates

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "videos.json"
YTDLP = next((p for p in ["/Users/ad/yt-dlp", "yt-dlp"] if Path(p).exists() or p == "yt-dlp"), "yt-dlp")


def meta(url):
    raw = subprocess.run([YTDLP, "--dump-json", "--skip-download", url], capture_output=True, text=True, check=True).stdout
    v = json.loads(raw)
    d = v.get("upload_date") or ""
    return {
        "id": f"youtube:{v['id']}",
        "platform": "youtube",
        "title": v.get("title"),
        "channel": v.get("channel"),
        "channelUrl": v.get("channel_url"),
        "publishedAt": f"{d[:4]}-{d[4:6]}-{d[6:]}" if len(d) == 8 else None,
        "duration": v.get("duration"),
        "thumb": v.get("thumbnail"),
        "url": f"https://www.youtube.com/watch?v={v['id']}",
        "embedUrl": f"https://www.youtube-nocookie.com/embed/{v['id']}?playsinline=1&rel=0",
        "verifiedBy": "human",
    }


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    candidate, urls = sys.argv[1], sys.argv[2:]
    if candidate not in {c["name"] for c in candidates()}:
        sys.exit(f"{candidate!r} is not on the ballot (data/ballot.json). Names must match the card exactly.")
    data = json.loads(OUT.read_text()) if OUT.exists() else {"videos": {}}
    vids = {v["id"]: v for v in data["videos"].get(candidate, [])}
    for u in urls:
        m = meta(u)
        vids[m["id"]] = m
        print(f"✓ {m['channel']} — {m['title']} ({m['duration']}s)", file=sys.stderr)
    data["videos"][candidate] = sorted(vids.values(), key=lambda v: v["publishedAt"] or "", reverse=True)
    data["generatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"{candidate}: {len(vids)} clips → {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
