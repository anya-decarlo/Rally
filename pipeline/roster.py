"""California Roster (SoS, PDF) → officials + contact info on jurisdictions.

Source: admin.cdn.sos.ca.gov/ca-roster/<year>/{counties,cities-towns}.pdf
The official roster of who holds every county and city seat — supervisors,
mayors, councils, sheriffs, clerks — plus websites and legislative districts.

    python3 pipeline/roster.py /tmp/roster_counties.pdf /tmp/roster_cities-towns.pdf
"""
import csv, io, json, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CA = ROOT / "data" / "jurisdictions" / "ca.json"

# Lines that end a wrapped name list (meeting schedules, next fields, etc.)
LIST_END = re.compile(
    r"^(every|meets?|first|second|third|fourth|fifth|1st|2nd|3rd|4th|\d|"
    r"monday|tuesday|wednesday|thursday|friday|saturday|sunday|"
    r"city manager|city clerk|city attorney|police chief|fire chief|"
    r"school superintendent|treasurer|incorporated|legislative|"
    r"chartered|general law|address|telephone|website|email|office hours|"
    r"population|county seat|assessor|auditor|behavioral|chief|child|clerk|"
    r"community|county|district attorney|emergency|fire|general|health|"
    r"human|information|library|planning|probation|public|purchasing|"
    r"recorder|registrar|resource|sheriff|social|superintendent|surveyor|"
    r"treasurer|superior|business hours|mailing|fax)", re.I)


def pdf_columns(pdf_path):
    """Reconstruct two-column reading order from word coordinates.
    Words left of x=300 form the left column; the rest the right. Each
    page emits left column top→bottom then right column top→bottom."""
    tsv = subprocess.run(["pdftotext", "-tsv", str(pdf_path), "-"],
                         capture_output=True, text=True).stdout
    lines, cur_page, words = [], None, []

    def emit(ws):
        for col in (0, 1):
            rows = {}
            for top, left, text in ws:
                if (left < 300) != (col == 0):
                    continue
                rows.setdefault(round(top / 3), []).append((left, text))
            for top in sorted(rows):
                row = sorted(rows[top])
                lines.append(" ".join(t for _, t in row))

    for r in csv.reader(io.StringIO(tsv), delimiter="\t"):
        if len(r) < 12 or r[0] != "5":
            continue
        pg, left, top = int(r[1]), float(r[6]), float(r[7])
        if cur_page is None:
            cur_page = pg
        if pg != cur_page:
            emit(words)
            words, cur_page = [], pg
        words.append((top, left, r[11]))
    if words:
        emit(words)
    return lines


def parse_blocks(lines, is_start):
    """Yield (header, [body lines]) for each jurisdiction block."""
    cur, body = None, []
    for line in lines:
        line = line.strip()
        if is_start(line):
            if cur:
                yield cur, body
            cur, body = line, []
        elif cur:
            body.append(line)
    if cur:
        yield cur, body


def kv(line):
    m = re.match(r"^([A-Za-z][A-Za-z \-/']+?):\s*(.*)$", line)
    return (m.group(1).strip(), m.group(2).strip()) if m else (None, None)


def parse_county(name, body):
    rec = {"officials": []}
    in_board = False
    for line in body:
        k, v = kv(line)
        if line == "Board of Supervisors":
            in_board = True
            continue
        if line.startswith("Superior Court"):
            in_board = False
            continue
        if in_board and k and k.startswith("District"):
            rec["officials"].append({"office": f"Supervisor, {k}", "name": v})
            continue
        if not k:
            in_board = False
            continue
        if k == "Website":
            rec["website"] = v
        elif k == "Legislative Districts":
            rec["legislativeDistricts"] = v
        elif k in META or k.startswith(("District",)) \
                or "Judge" in k or "Court" in k:
            pass
        else:
            rec["officials"].append({"office": k, "name": v})
    return rec


META = {"Address", "Mailing Address", "Telephone", "Fax", "Business Hours",
        "Office Hours", "Incorporated", "Population", "County Seat",
        "Email", "Please Note", "Elected and Appointed Officials",
        "Board of Supervisors"}


def parse_city(header, body):
    rec = {"officials": []}
    council, in_council, pending = [], False, None
    for line in body:
        k, v = kv(line)
        if pending and (not k or re.search(r"[.@/]", line)):
            rec[pending] = line      # wrapped Website:/Email: value
            pending = None
            continue
        pending = None
        if in_council:
            if not k and not LIST_END.match(line):
                council.append(line)          # wrapped name lines
                continue
            in_council = False
        if k == "City Council":
            council.append(v)
            in_council = True
            continue
        if not k:
            # schedule lines have no key: "Every 2nd and 4th Wednesday…"
            if line and not line.startswith("(") and len(line) > 15 \
                    and re.search(r"day|a\.m\.|p\.m\.|time|recess", line, re.I):
                rec.setdefault("meeting", line)
            continue
        if k in ("Website", "Email") and not v:
            pending = k.lower()
        elif k == "Website":
            rec["website"] = v
        elif k == "Email":
            rec["email"] = v
        elif k == "Legislative Districts":
            rec["legislativeDistricts"] = v
        elif k in ("Mayor", "Vice Mayor/Mayor Pro Tempore", "City Manager",
                   "City Clerk", "City Attorney", "Police Chief", "Fire Chief",
                   "School Superintendent", "Treasurer"):
            rec["officials"].append({"office": k, "name": v})
    for name in re.split(r",| and ", " ".join(council)):
        name = name.strip().rstrip(".")
        if name:
            rec["officials"].append({"office": "Councilmember", "name": name})
    return rec


def main(counties_pdf, cities_pdf):
    doc = json.loads(CA.read_text())
    counties = {j["name"].replace(" County", ""): j
                for j in doc["jurisdictions"] if j["kind"] == "county"}
    # "City and County of San Francisco" → key "City and of San Francisco"
    counties["San Francisco"] = counties["City and of San Francisco"]
    cities = {j["name"].lower(): j
              for j in doc["jurisdictions"] if j["kind"] == "city"}
    city_aliases = {j["name"].lower().replace("city", "").strip(): j
                    for j in doc["jurisdictions"] if j["kind"] == "city"}
    for roster_name, app_name in {
            "angels camp (angels)": "Angels Camp",
            "industry": "City of Industry",
            "san buenaventura (ventura)": "Ventura",
            }.items():
        for j in doc["jurisdictions"]:
            if j["kind"] == "city" and j["name"] == app_name:
                city_aliases[roster_name] = j

    lines = pdf_columns(counties_pdf)
    county_names = dict.fromkeys(counties)
    county_names["City and County of San Francisco"] = "San Francisco"
    seen = set()
    n_county = 0
    for header, body in parse_blocks(
            lines, lambda l: l in county_names):
        target = county_names[header] or header
        rec = parse_county(header, body)
        counties[target].update(rec)
        seen.add(target)
        n_county += 1
    seen_ids = {id(counties[t]) for t in seen if t in counties}
    missing = [k for k, v in counties.items() if id(v) not in seen_ids]
    if missing:
        print(f"  counties not in roster: {sorted(missing)}")

    lines = pdf_columns(cities_pdf)
    blocks = []
    for s in lines:
        s = s.strip()
        if not s or s == "Incorporated Cities and Town Officials" \
                or s.startswith("Please Note"):
            continue
        m = re.match(r"^(?:City|Town|City and County) of (.+)$", s)
        if m:
            blocks.append([m.group(1).strip(), []])
        elif s.lower() in cities or s.lower() in city_aliases:
            blocks.append([s, []])    # roster drops "City of" on some entries
        elif blocks:
            blocks[-1][1].append(s)

    n_city = 0
    for name, body in blocks:
        j = cities.get(name.lower()) or city_aliases.get(name.lower()) \
            or counties.get(name)
        if not j:
            print(f"  no jurisdiction for {name!r}")
            continue
        j.update(parse_city(name, body))
        n_city += 1

    CA.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"done: {n_county} counties · {n_city} cities enriched")


if __name__ == "__main__":
    main(*sys.argv[1:3])
