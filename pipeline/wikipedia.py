#!/usr/bin/env python3
"""Wikipedia → facts.json + portrait. Bite-size, sourced facts for the feed. Stdlib only.

    python3 pipeline/wikipedia.py
"""
import html, json, re, sys, urllib.parse, urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "facts.json"
PORTRAITS = ROOT / "data" / "portraits"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from candidates import candidates, slug

# every candidate on the ballot with a "wikipedia" field
PAGES = {c["name"]: c["wikipedia"] for c in candidates() if c.get("wikipedia")}

UA = {"User-Agent": "Rally/0.1 (github.com/anya-decarlo/Rally)"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return r.read()


def api(**q):
    q.update(format="json", formatversion=2)
    return json.loads(get(f"https://en.wikipedia.org/w/api.php?{urllib.parse.urlencode(q)}"))


def article_text(title):
    h = api(action="parse", page=title, prop="text", redirects=1)["parse"]["text"]
    h = re.sub(r"<(table|sup|style|script)[^>]*>.*?</\1>", " ", h, flags=re.S)   # infobox, citations
    h = re.sub(r"<h[1-6][^>]*>.*?</h[1-6]>", "\n", h, flags=re.S)
    paras = re.findall(r"<p[^>]*>(.*?)</p>", h, flags=re.S)
    text = " ".join(html.unescape(re.sub(r"<[^>]+>", "", p)) for p in paras)
    return re.sub(r"\[\d+\]|\s+", lambda m: " " if m.group(0)[0] != "[" else "", text)


def facts_from(text):
    sents = re.split(r"(?<=[.!?])\s+(?=[A-Z])", text)
    keep = []
    for s in (s.strip() for s in sents):
        if not (50 <= len(s) <= 220): continue
        if s.count("(") != s.count(")"): continue
        if re.search(r"\b(is an? American|citation needed)\b", s): continue
        keep.append(s)
    return keep


def portrait(title, slug):
    s = json.loads(get(f"https://en.wikipedia.org/api/rest_v1/page/summary/{title}"))
    src = s.get("originalimage", {}).get("source")
    if not src:
        return None
    src = src.split("?")[0]
    fname = urllib.parse.unquote(src.rsplit("/", 1)[-1])
    info = api(action="query", prop="imageinfo", iiprop="extmetadata|url", titles=f"File:{fname}")
    md = info["query"]["pages"][0].get("imageinfo", [{}])[0].get("extmetadata", {})
    clean = lambda k: html.unescape(re.sub(r"<[^>]+>", "", md.get(k, {}).get("value", ""))).strip()
    PORTRAITS.mkdir(parents=True, exist_ok=True)
    ext = Path(fname).suffix.lower() or ".jpg"
    (PORTRAITS / f"{slug}{ext}").write_bytes(get(src))
    return {"file": f"{slug}{ext}", "source": src, "license": clean("LicenseShortName"),
            "credit": clean("Artist") or clean("Credit"), "page": f"https://commons.wikimedia.org/wiki/File:{fname}"}


def main():
    out = {}
    for cand, title in PAGES.items():
        facts = facts_from(article_text(title))
        url = f"https://en.wikipedia.org/wiki/{title}"
        out[cand] = {"facts": [{"text": f, "source": "Wikipedia", "url": url, "category": "bio"} for f in facts],
                     "portrait": portrait(title, slug(cand))}
        print(f"{cand}: {len(facts)} facts, portrait={bool(out[cand]['portrait'])}", file=sys.stderr)
    OUT.write_text(json.dumps({"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                               "candidates": out}, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote → {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
