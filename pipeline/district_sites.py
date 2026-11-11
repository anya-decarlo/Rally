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


def main(lea_csv):
    rows = [r for r in csv.DictReader(open(lea_csv)) if r["ST"] == "CA"]
    doc = json.loads(CA.read_text())
    sds = [j for j in doc["jurisdictions"]
           if j["kind"] == "district" and j.get("districtKind") == "school"]

    by_name = {norm(r["LEA_NAME"]): r for r in rows}
    by_cds = {r["ST_LEAID"].replace("CA-", "").zfill(7): r
              for r in rows if r["ST_LEAID"].startswith("CA-")}

    hit = nosite = 0
    new_srcs = []
    for j in sds:
        r = by_name.get(norm(j["name"]))
        if not r:
            m = re.search(r"CDS (\d{7})", j.get("note", ""))
            r = by_cds.get(m.group(1)) if m else None
        if not r:
            print(f"  no NCES match: {j['name']}")
            continue
        site = r["WEBSITE"].strip()
        if not site:
            nosite += 1
            print(f"  no site in file: {j['name']}")
            continue
        j["website"] = site
        hit += 1
        slug = j["id"].replace("ca-", "")
        new_srcs.append(
            f'sch-site-{slug},CA,district,{j["name"]},'
            f'{j["name"]} website,district-site,{site},html,public,'
            f'weekly,,enumerated,"platform:{platform(site)} · from NCES CCD '
            'LEA directory"')

    CA.write_text(json.dumps(doc, indent=2) + "\n")

    existing = SOURCES.read_text()
    have = set(l.split(",", 1)[0] for l in existing.splitlines())
    add = [s for s in new_srcs if s.split(",", 1)[0] not in have]
    if add:
        with SOURCES.open("a") as f:
            f.write("\n".join(add) + "\n")

    print(f"done: {hit}/{len(sds)} school districts got websites "
          f"({nosite} missing in NCES file) · {len(add)} source rows added")


if __name__ == "__main__":
    main(sys.argv[1])
