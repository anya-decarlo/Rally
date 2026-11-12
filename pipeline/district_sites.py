"""District homepages → ca.json + SOURCES.csv.

School districts come from the NCES CCD LEA directory (one file, every CA
district's website). Special-district homepages join later via LAFCO lists.

    curl -O https://nces.ed.gov/ccd/Data/zip/ccd_lea_029_2425_w_0a_051425.zip
    python3 pipeline/district_sites.py /tmp/lea/ccd_lea_029_2425_w_0a_051425.csv
"""
import csv, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CA = ROOT / "data" / "jurisdictions" / "ca.json"
SOURCES = ROOT / "SOURCES.csv"

norm = lambda s: re.sub(r"[^a-z0-9]", "",
                      s.lower().replace("school district", "")
                       .replace("usd", ""))


def platform(url):
    d = url.lower()
    if "boarddocs" in d:
        return "boarddocs"
    if "granicus" in d or "swagit" in d:
        return "granicus"
    if "legistar" in d:
        return "legistar"
    if "civicplus" in d or "civicengage" in d or "civicweb" in d:
        return "civicplus"
    if "edlio" in d:
        return "edlio"
    if "finalsite" in d or "fs.ffinal.net" in d:
        return "finalsite"
    if "schoolwires" in d or "blackboard" in d:
        return "blackboard"
    return "custom"


def add_sources(doc, pairs, prefix, provenance):
    """pairs: [(url, district_name)]. Returns count of websites applied."""
    dists = [j for j in doc["jurisdictions"] if j["kind"] == "district"]
    ours = {}
    for j in dists:
        ours.setdefault(norm(j["name"]), []).append(j)
    hit, new_srcs = 0, []
    for url, name in pairs:
        for j in ours.get(norm(name), []):
            if j.get("website"):
                continue
            j["website"] = url
            hit += 1
            slug = j["id"].replace("ca-", "")
            new_srcs.append(
                f"{prefix}-{slug},CA,district,{j['name']},"
                f"{j['name']} website,district-site,{url},html,public,"
                f"weekly,,enumerated,\"platform:{platform(url)} · {provenance}\"")
    existing = SOURCES.read_text()
    have = set(l.split(",", 1)[0] for l in existing.splitlines())
    add = [s for s in new_srcs if s.split(",", 1)[0] not in have]
    if add:
        with SOURCES.open("a") as f:
            f.write("\n".join(add) + "\n")
    return hit, len(add)


def school_districts(doc, lea_csv):
    rows = [r for r in csv.DictReader(open(lea_csv)) if r["ST"] == "CA"]
    by_name = {norm(r["LEA_NAME"]): r for r in rows}
    by_cds = {r["ST_LEAID"].replace("CA-", "").zfill(7): r
              for r in rows if r["ST_LEAID"].startswith("CA-")}
    pairs, nosite = [], 0
    for j in doc["jurisdictions"]:
        if j["kind"] != "district" or j.get("districtKind") != "school":
            continue
        r = by_name.get(norm(j["name"]))
        if not r:
            m = re.search(r"CDS (\d{7})", j.get("note", ""))
            r = by_cds.get(m.group(1)) if m else None
        if r and r["WEBSITE"].strip():
            pairs.append((r["WEBSITE"].strip(), j["name"]))
        else:
            nosite += 1
            print(f"  no NCES site: {j['name']}")
    return pairs, nosite


def acwa_members(doc, acwa_html):
    pairs = re.findall(
        r'<a href="(https?://[^"]+)"\s+target="_blank">\s*([^<]+?)\s*</a>',
        Path(acwa_html).read_text())
    return [(u.strip(), n.strip())
            for u, n in pairs if "acwa.com" not in u], 0


def main(lea_csv=None, acwa_html=None):
    doc = json.loads(CA.read_text())
    if lea_csv:
        pairs, nosite = school_districts(doc, lea_csv)
        hit, added = add_sources(doc, pairs, "sch-site",
                                 "from NCES CCD LEA directory")
        print(f"school: {hit} websites applied · {added} rows "
              f"({nosite} have no site on file)")
    if acwa_html:
        pairs, _ = acwa_members(doc, acwa_html)
        hit, added = add_sources(doc, pairs, "acwa-site",
                                 "from ACWA member directory")
        print(f"acwa: {hit} websites applied · {added} rows "
              f"({len(pairs)} member links)")
    CA.write_text(json.dumps(doc, indent=2) + "\n")
    cov = sum(1 for j in doc["jurisdictions"]
              if j["kind"] == "district" and j.get("website"))
    tot = sum(1 for j in doc["jurisdictions"] if j["kind"] == "district")
    print(f"district website coverage: {cov}/{tot}")


if __name__ == "__main__":
    args = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in sys.argv[1:]}
    main(lea_csv=args.get("lea"), acwa_html=args.get("acwa"))
