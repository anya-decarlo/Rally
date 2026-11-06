# The Record Engine

An autonomous government-record collection system that continuously retrieves,
classifies, and connects government activity across California's 58 counties,
cities, legislative districts, and federal congressional districts.

## The one rule that shapes everything

**You cannot retrieve government activity by district. You retrieve it by
source, then attribute it to the districts and jurisdictions it affects.**

- An Assembly Bill affects the whole state, though one member introduced it.
- A U.S. House bill is introduced by one representative but affects the country.
- A federal court case might affect California, several states, or the nation.
- A city council hearing affects one municipality.

Preserve the distinction. Never collapse *who introduced it* into *who it affects*.

```
origin district   ≠   jurisdiction   ≠   affected districts
(the author's seat)  (the machine it runs in)  (where it lands)
```

## The eight streams

| # | Stream | Source | What we pull |
|---|---|---|---|
| 1 | CA AB / SB bills | [California Legislative Information](https://leginfo.legislature.ca.gov) + [Digital Democracy](https://www.digitaldemocracy.org) (API key + approval) | Bill text, author, coauthors, amendments, status, votes, committees, analyses |
| 2 | Federal H.R. / S. bills | [Congress.gov API](https://api.congress.gov) (free key) | Bill text, sponsor, cosponsors, actions, committees, votes, summaries |
| 3 | Executive orders | Governor's EO archive; Federal Register | Order number, issuing official, date, subject, authority, agencies |
| 4 | Agency regulations | [Federal Register API](https://www.federalregister.gov/developers/documentation/api/v1); CA agency publications | Proposed/final rules, comments, effective dates, agencies |
| 5 | Court cases | CA Judicial Branch; PACER (auth + fees); CourtListener | Case number, parties, court, filing date, opinions, status |
| 6 | Appointments | Governor's announcements; CA Senate confirmations; Congress.gov nominations | Nominee, position, authority, confirmation status, term |
| 7 | Budgets | CA Dept. of Finance; LAO; federal budget pubs | Proposed/enacted budgets, appropriations, amendments |
| 8 | Public hearings | CA Leg. committee calendars; city/county agendas; federal committee calendars | Date, location, agenda, linked legislation, testimony, outcome |

Source notes:

- **Digital Democracy** — structured legislative data incl. hearing transcripts
  and testimony linked to speakers. API key + access approval required.
- **Congress.gov** — bills, sponsors, cosponsors, committees, hearings, votes,
  nominations, actions. Free API key.
- **PACER** — nationwide case-locator API; detailed filings need auth and cost
  money. CA appellate opinions have a separate official publication system.

## The geographic layer

Already built — `data/jurisdictions/ca.json` is the attribution backbone.
Records map onto these jurisdiction types:

| District type | Coverage |
|---|---|
| CA Assembly | 80 districts |
| CA State Senate | 40 districts |
| U.S. Congressional | CA's House districts |
| County | 58 |
| City | 482 incorporated municipalities |
| School district | individual boundaries |
| Special district | water, fire, transit, library, … |

Every record gets one or more geographic associations — **where the evidence
supports it.** An AB's card reads: origin AD-12, sponsor = the AD-12 member,
jurisdiction statewide, affected districts statewide (or specific ones if the
bill expressly targets them). The author's district and the bill's reach are
different fields and stay different fields.

## Architecture

```
SOURCE COLLECTION          eight independent collectors, one per stream
        │
NORMALIZE & DEDUPE         one record shape, original document preserved
        │
GEOGRAPHIC MAPPING         record → legislators, districts, counties,
        │                  cities, agencies, bodies
        ▼
CENTRAL DATABASE           records, source URLs, status histories,
        │                  relationships, geographic coverage
        ▼
PUBLIC APPLICATION         search by district · follow legislation ·
                           view hearings · track representatives
```

Each collector's contract — all eight, same ten jobs:

1. Retrieve new records.
2. Retrieve updated records.
3. Identify previously collected records.
4. Preserve the original government source.
5. Extract structured fields.
6. Identify the responsible government body.
7. Associate the record with geographic jurisdictions.
8. Store the retrieval timestamp.
9. Flag missing or uncertain information.
10. Make updates available to the app.

**Status is a history, not a field.** A bill moving committee → floor generates
a new event. We never overwrite the previous state — we append. (This is what
`ActivityItem` in `data/activity/<state>.json` is for: the flattened event
stream that falls out of record updates.)

## Record schema

| Field | Meaning |
|---|---|
| `record_id` | unique id |
| `record_type` | bill, regulation, hearing, court case, … |
| `record_number` | AB 100, SB 20, H.R. 100, case number |
| `title` | official title |
| `description` | official summary |
| `originating_body` | legislature, agency, court |
| `originating_official` | sponsor, judge, governor, agency |
| `originating_district` | district of the originating official, if any |
| `jurisdiction` | state, federal, county, city |
| `affected_districts` | geographic areas the evidence supports |
| `date_introduced` | initial publication/introduction |
| `last_updated` | latest source update |
| `current_status` | current procedural status |
| `status_history` | chronological actions — append only |
| `associated_records` | related bills, lawsuits, regulations |
| `source_url` | the receipt — original government record |
| `source_updated_at` | source's own update timestamp |
| `retrieved_at` | our collector's timestamp |
| `verification_status` | verified · inferred · needs review |

`originating_district`, `jurisdiction`, and `affected_districts` are three
separate fields forever.

## Build order — not all eight at once

| Priority | Stream | Why first |
|---|---|---|
| 1 | CA AB / SB | The legislative record — connects to reps + proceedings |
| 2 | Federal H.R. / S. | Federal bills + which CA members sponsored them |
| 3 | Public hearings | State leg hearings + the bills they're about |
| 4 | Executive orders | CA gubernatorial + presidential |
| 5 | Agency regulations | Proposed + finalized rules |
| 6 | Appointments | Nominations + confirmations |
| 7 | Budgets | Proposed → amended → enacted |
| 8 | Court cases | CA + federal, opinions, procedural events |

1–3 establish the legislative spine. 4–8 extend into executive, administrative,
financial, and judicial activity.

## What exists today

- `pipeline/jurisdictions.py` → `data/jurisdictions/ca.json` — the geographic
  layer: all 58 counties, 482 cities, seat structures, seeded districts
- `pipeline/activity.py` → `data/activity/ca.json` — the 12-kind activity
  taxonomy and the official-source registry; `items` is the stream collectors fill
- `Rally/Government.swift` — `ActivityItem` model with `source` required
- `pipeline/candidates.py` — the pattern collectors follow: data files shared
  between pipeline and app, names are join keys, sources are receipts
