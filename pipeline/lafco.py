"""LAFCO special-district directories → district websites.

Each county LAFCO publishes a list of its special districts — often with
direct links to district homepages. This crawler fetches each LAFCO
homepage, follows links that look like district/agency listings, and
matches outbound anchors against our jurisdiction nodes.

    python3 pipeline/lafco.py                # all counties
    python3 pipeline/lafco.py santa-clara    # one county
"""
import json, re, sys, time, urllib.request, urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CA = ROOT / "data" / "jurisdictions" / "ca.json"
SOURCES = ROOT / "SOURCES.csv"
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"}

# county-id suffix → LAFCO homepage. 50 from CALAFCO Member_Roster
# (calafco.org/Member_Roster) + 8 non-member counties found directly.
LAFCO = {
    "alameda": "https://alamedalafco.org/",
    "alpine": "https://www.alpinecountyca.gov/185/Local-Agency-Formation-Commission-LAFCO",
    "amador": "https://www.amadorcounty.gov/government/lafco",
    "butte": "https://www.buttelafco.org/",
    "calaveras": "https://www.calaveraslafco.org/",
    "colusa": "https://www.colusalafco.org/",
    "contra-costa": "https://www.contracostalafco.org/",
    "del-norte": "https://www.delnortelafco.org/",
    "el-dorado": "https://www.edcgov.us/Government/lafco",
    "fresno": "https://www.fresnolafco.org/",
    "glenn": "https://www.countyofglenn.net/government/committees-commissions/local-agency-formation-commiss",
    "humboldt": "https://humboldtlafco.org/",
    "imperial": "https://www.iclafco.com/",
    "inyo": "https://www.inyocounty.us/services/planning-department/lafco",
    "kern": "https://kernco.com/lafco/",
    "kings": "https://www.countyofkingsca.gov/departments/outside-agencies/kings-lafco",
    "lake": "https://www.lakelafco.org/",
    "lassen": "https://www.lassenlafco.org/",
    "los-angeles": "https://lalafco.org/en/",
    "madera": "https://www.maderacounty.com/government/madera-lafco",
    "marin": "https://www.marinlafco.org/",
    "mariposa": "https://www.mariposacounty.org/543/Local-Agency-Formation-Commission-LA",
    "mendocino": "https://www.mendolafco.org/",
    "merced": "https://www.lafcomerced.org/",
    "modoc": "https://www.modoclafco.org/",
    "mono": "https://www.monocounty.ca.gov/1527/Local-Agency-Formation-Commission",
    "monterey": "https://www.countyofmonterey.gov/government/government-links/lafco",
    "napa": "https://www.napa.lafco.ca.gov/",
    "nevada": "https://www.nevadacountyca.gov/907/Local-Agency-Formation-Commission-LAFCo",
    "orange": "https://oclafco.org/",
    "placer": "https://www.placerlafcoca.gov/",
    "plumas": "https://www.plumaslafco.org/",
    "riverside": "https://lafco.org/",
    "sacramento": "https://saclafco.saccounty.gov/us/en.html",
    "san-benito": "https://www.sanbenitocountyca.gov/departments/lafco/",
    "san-bernardino": "https://lafco.sbcounty.gov/",
    "san-diego": "https://sdlafco.org/",
    "san-francisco": "https://www.sf.gov/department-local-agency-formation-commission",
    "san-joaquin": "https://www.sjlafco.org/",
    "san-luis-obispo": "https://slo.lafco.ca.gov/",
    "san-mateo": "https://www.smcgov.org/lafco",
    "santa-barbara": "https://www.sblafco.org/",
    "santa-clara": "https://santaclaralafco.org/",
    "santa-cruz": "https://santacruzlafco.org/",
    "shasta": "https://www.shastalafco.org/",
    "sierra": "https://www.sierracounty.ca.gov/341/Local-Agency-Formation-Commission",
    "siskiyou": "https://www.siskiyoucounty.gov/lafco",
    "solano": "https://solanolafco.gov/",
    "sonoma": "https://sonomalafco.org/",
    "stanislaus": "https://www.stanislauslafco.org/",
    "sutter": "https://www.sutterlafco.org/",
    "tehama": "https://www.tehama.gov/government/departments/planning-department/lafco/",
    "trinity": "https://www.trinitylafco.org/",
    "tulare": "https://lafco.tularecounty.ca.gov/",
    "tuolumne": "https://sonoraca.com/tuolumne-county-lafco/",
    "ventura": "https://www.ventura.lafco.ca.gov/",
    "yolo": "https://www.yololafco.org/",
    "yuba": "https://www.yubalafco.org/",
}

LIST_HINT = re.compile(r"district|agenc", re.I)
ANCHOR = re.compile(
    r'<a\s+[^>]*href="([^"#]+)"[^>]*>(.*?)</a>', re.I | re.S)
TAG = re.compile(r"<[^>]+>")


def fetch(url, timeout=15):
    try:
        req = urllib.request.Request(url, headers=UA)
        return urllib.request.urlopen(req, timeout=timeout).read().decode(
            "utf-8", "replace")
    except Exception:
        return None


def links(html, base):
    out = []
    for href, text in ANCHOR.findall(html or ""):
        url = urllib.parse.urljoin(base, href)
        text = TAG.sub("", text).strip()
        if url.startswith("http") and text:
            out.append((url, text))
    return out


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def crawl(county, base_url, district_names, max_pages=6):
    """Return [(district_node_name, site_url)] discovered on the LAFCO site."""
    found, seen_pages, queue = {}, set(), [base_url]
    for _ in range(max_pages):
        if not queue:
            break
        url = queue.pop(0)
        if url in seen_pages:
            continue
        seen_pages.add(url)
        html = fetch(url)
        if not html:
            continue
        host = urllib.parse.urlparse(url).netloc
        for link, text in links(html, url):
            if norm(text) in district_names:
                found[district_names[norm(text)]] = link
                continue
            # internal links that might lead to a district list page
            if urllib.parse.urlparse(link).netloc == host \
                    and LIST_HINT.search(link + " " + text) \
                    and link not in seen_pages and len(queue) < 20:
                queue.append(link)
        # row-level pairing: a chunk (tr/li/p/div) containing the district
        # name + an outbound link ("Website"/"Map" style anchors)
        for chunk in re.split(r"</(?:tr|li|p|div|dd|dt)>", html):
            ctext = TAG.sub(" ", chunk)
            cnorm = norm(ctext)
            for nkey, node_name in district_names.items():
                if node_name in found or nkey not in cnorm:
                    continue
                for href, _ in ANCHOR.findall(chunk):
                    cand = urllib.parse.urljoin(url, href)
                    if urllib.parse.urlparse(cand).netloc != host:
                        found[node_name] = cand
                        break
        time.sleep(0.3)
    return found


def main(only=None):
    doc = json.loads(CA.read_text())
    # index this county's districts by normalized name
    by_parent = {}
    for j in doc["jurisdictions"]:
        if j["kind"] != "district" or j.get("website"):
            continue
        p = (j.get("parent") or "").replace("ca-", "")
        by_parent.setdefault(p, {})[norm(j["name"])] = j["name"]

    existing = SOURCES.read_text()
    have = set(l.split(",", 1)[0] for l in existing.splitlines())
    new_rows = []
    total = 0
    counties = [only] if only else sorted(LAFCO)
    for county in counties:
        base = LAFCO.get(county)
        names = by_parent.get(county, {})
        if not base or not names:
            if only:
                print(f"{county}: no LAFCO url or no un-sited districts")
            continue
        found = crawl(county, base, names)
        for node_name, url in found.items():
            j = next(j for j in doc["jurisdictions"]
                     if j["kind"] == "district" and j["name"] == node_name
                     and not j.get("website"))
            j["website"] = url
            sid = f"lafco-site-{j['id'].replace('ca-', '')}"
            if sid not in have:
                new_rows.append(
                    f'{sid},CA,district,{node_name},{node_name} website,'
                    f'district-site,{url},html,public,weekly,,enumerated,'
                    f'"platform:custom · from {county} LAFCO directory"')
        total += len(found)
        print(f"{county}: {len(found)}/{len(names)} districts sited")
    if new_rows:
        with SOURCES.open("a") as f:
            f.write("\n".join(new_rows) + "\n")
    CA.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"done: {total} district sites via LAFCO · "
          f"{len(new_rows)} source rows")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
