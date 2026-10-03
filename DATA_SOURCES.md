# Data Sources

Everything Rally knows comes from somewhere public. This is the list, what we pull from each, and how it lands in the app.

**Rule:** every number and quote in the app traces back to a row in one of these. If it can't, it doesn't ship.

---

## Verified so far

What we've actually hit and confirmed works (updated as we go):

| Source | Endpoint | Status |
|---|---|---|
| **DC OCF Contributions** | `https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Public_Service_WebMercator/MapServer/34` | ✅ Live ArcGIS REST API, no key. Fields: `COMMITTEENAME, CANDIDATENAME, ELECTIONYEAR, CONTRIBUTORNAME, CONTRIBUTORTYPE, CONTRIBUTIONTYPE, ADDRESS, FULLADDRESS, WARD, EMPLOYER, EMPLOYERADDRESS, AMOUNT, ...` |
| **DC OCF Expenditures** | `.../MapServer/35` | ✅ Live. Fields: `CANDIDATENAME, PAYEE, FULLADDRESS, ADDRESS, PURPOSE, AMOUNT, TRANSACTIONDATE, WARD, LATITUDE, LONGITUDE, ...` |
| **DC OCF bulk CSV** | `https://opendata.dc.gov/api/download/v1/items/5638336c30ea4c69805ebb838f22794a/csv?layers=35` | ✅ Full expenditures since 2003 as one CSV (swap `layers=34` for contributions) |

These two layers are the Mayor race's primary finance source. Every mayoral candidate's donors and payees are in here, geocoded, with employer fields — which is exactly what the Nobody ledger and the donor map need.

---

## Full source list

| # | Data source | What you pull | API / manual | How it fits the app |
|---|---|---|---|---|
| 1 | **FEC.gov / OpenFEC API** | Federal candidates, committees, PACs, receipts, disbursements, donors, filings | API | Core federal campaign-finance engine; test API output against the public FEC website |
| 2 | **FEC Schedule A** | Individual/organization contributions and other receipts | API + bulk | Build donor / company / PAC relationships |
| 3 | **FEC Schedule B** | Campaign expenditures/disbursements and payees | API + bulk | The "transactions with no recipient" investigation belongs here; flag null/blank/incomplete payee fields rather than assuming they represent an unidentified recipient |
| 4 | **FEC Independent Expenditures / Schedule E** | Outside spending supporting/opposing federal candidates | API | Separate candidate-controlled money from outside spending |
| 5 | **FEC committee data** | PAC identity, committee type, sponsor, affiliated committees | API | Build Company → PAC → Candidate relationships |
| 6 | **D.C. Office of Campaign Finance (OCF)** | D.C. candidate contributions and expenditures | **API (verified — see above)**, plus public database | Primary finance source for the Mayor race; OCF's database contains contribution/expenditure records back to 2003, updated daily. ([OCF](https://ocf.dc.gov/external-link/contributions-and-expenditures-search)) |
| 7 | **D.C. OCF Candidate Campaign Contributions Search** | Candidate, office, party, committee, geography, contribution records | Manual + investigate underlying data access | Mayor-specific donor map; OCF provides candidate/office/party/committee searches and geographic lookup. ([OCF](https://ocf.dc.gov/service/candidate-campaign-contributions-search)) |
| 8 | **Human Rights Campaign Congressional Scorecard** | Congressional voting record / issue scorecard | Manual / download | Legislative score field for federal candidates; don't apply it to the mayor unless HRC actually provides a D.C. local rating |
| 9 | **Human Rights Campaign PAC / political spending** | PAC-related political activity | Manual / research | Link HRC political activity to candidate/committee records rather than treating the scorecard and PAC as the same dataset |
| 10 | **OpenSecrets** | PACs, donors, industries, outside spending, candidate finance | Manual / API depending on dataset | Cross-check / normalization layer against FEC records — especially their employer → industry coding |
| 11 | **Congress.gov API** | Bills, votes, hearings, committees, members | API | Candidate/member legislative record for the federal feature. Exposes bill, hearing, committee-meeting and Congressional Record endpoints. ([api.congress.gov](https://api.congress.gov/)) |
| 12 | **GovInfo API** | Congressional Record, hearings, legislative documents | API | The "FEC topic greps during hearings" feature. Machine-readable government documents and metadata. ([GovInfo](https://www.govinfo.gov/features/api)) |
| 13 | **Congressional Record** | Actual speeches / statements / hearing-related material | API + document search | Extract topics/terms and associate them with members |
| 14 | **D.C. Council legislative database** | Bills, resolutions, votes, committee actions | Manual / API if available | The federal legislative layer's equivalent for Mayor / D.C. Council research |
| 15 | **D.C. Council Legislative Information Hub / DCAT data** | Structured D.C. government datasets | API / data download | The DCAT / Legislative Branch Information Hub layer |
| 16 | **U.S. GPO / GovInfo developer resources** | Government documents, metadata, bulk data | API | Infrastructure for the government-document ingestion system; GovInfo publishes developer repos and APIs. ([GovInfo developers](https://www.govinfo.gov/developers)) |
| 17 | **Acquire.info** | Corporate / company and ownership / business information | Research / API if available | Company alignment / company identity resolution layer |
| 18 | **USAspending.gov** | Federal contracts, awards, recipients | API | Connect companies/organizations to federal spending rather than relying solely on campaign-finance relationships |
| 19 | **D.C. government open-data / DCAT datasets** | Government entities, expenditures, contracts, administrative datasets | API / download | Expand beyond campaign finance into actual government activity |
| 20 | **Candidate campaign websites / official statements** | Platforms, issue positions, biographies, endorsements, statements | Manual / web crawl | The Candidate Align layer; keep candidate-authored statements distinct from third-party ratings |

## Media sources

| Source | What you pull | How it fits the app |
|---|---|---|
| **YouTube** | DC Council hearings, mayoral forums, debates, local news clips | Shorts + Stance cards. Transcribed, timestamped, clipped. The DC Council streams every hearing. |
| **X** | Candidates' own posts | Profile feed + Stance cards. The *only* outside social platform Rally pulls from — one source, applied equally to everyone. |

---

## Priority for the Mayor race

1. **OCF Contributions + Expenditures** (#6, verified API) — the whole money story
2. **YouTube** — forums, debates, Council hearings for sitting members
3. **X** — candidate feeds
4. **Candidate websites** (#20) — stated positions to check against
5. **DC Council legislative database** (#14) — voting records for candidates who are current councilmembers

Everything federal (#1–5, 8–13, 16, 18) waits for the Delegate race.
