# Rally data sources and data dictionary

Nov 4, 2026 · @Jonathan

## How to read this

Rally can pull seats, votes, results and money for DC and Maryland today from 12 free sources; only two need a free API key (LegiScan, Open States API). Every source maps onto one shared set of entities below, joined on two keys:

- **Place**: an [OCD division ID](https://open-civic-data-docs.readthedocs.io/en/latest/proposals/0002.html), e.g. `ocd-division/country:us/state:md/sldl:12a` or `ocd-division/country:us/district:dc/ward:8`.
- **Person**: a rally person id (`rp_…`), with every outside id (Open States, LegiScan, FEC, state filer ids) kept in a crosswalk.

Scope is DC first, then Maryland, as you picked. Federal sources rally already uses are listed so the dictionary covers them too. Status: **In use** (rally pulls it now), **Planned** (next ingest), **Check** (access or terms not yet confirmed), **Later**.

## Coverage at a glance

Votes are covered in every state. Elections (contests, candidates and results, from official results files) are machine-readable in 21 states, and money can be bulk-downloaded in 23 (Nevada needs a free account). Only 11 states have both: AL, CA, CO, GA, ID, IL, NE, NM, PA, VA and WA. Candidate lists published before an election have not been checked yet.

- **Yes**: free official files or exports we can load as-is.
- **Scrape**: only web pages, PDFs or search exports.
- **On request**: the state sends bulk data only if asked.
- **Unconfirmed**: I found the agency but not a confirmed download.

The money column falls back to the Accountability Project, and the elections column to MIT and VEST precinct files for 2016–2024. Details for each cell are in the sections below.

| State | Elections (contests, candidates, results) | Votes (roll calls) | Money |
| --- | --- | --- | --- |
| Alabama | Yes | Yes | Yes |
| Alaska | Scrape | Yes | Unconfirmed |
| Arizona | Unconfirmed | Yes | On request |
| Arkansas | Scrape | Yes | Unconfirmed |
| California | Yes | Yes | Yes |
| Colorado | Yes | Yes | Yes |
| Connecticut | Scrape | Yes | Yes |
| Delaware | Yes | Yes | Unconfirmed |
| Florida | Unconfirmed | Yes | On request |
| Georgia | Yes | Yes | Yes |
| Hawaii | Unconfirmed | Yes | Unconfirmed |
| Idaho | Yes | Yes | Yes |
| Illinois | Yes | Yes | Yes |
| Indiana | Unconfirmed | Yes | Yes |
| Iowa | Scrape | Yes | Yes |
| Kansas | Scrape | Yes | Unconfirmed |
| Kentucky | Unconfirmed | Yes | Unconfirmed |
| Louisiana | Unconfirmed | Yes | Unconfirmed |
| Maine | Yes | Yes | Unconfirmed |
| Maryland | Scrape | Yes | On request |
| Massachusetts | Yes | Yes | Unconfirmed |
| Michigan | Scrape | Yes | Yes |
| Minnesota | Unconfirmed | Yes | Yes |
| Mississippi | Scrape | Yes | Unconfirmed |
| Missouri | Scrape | Yes | Yes |
| Montana | Yes | Yes | Unconfirmed |
| Nebraska | Yes | Yes | Yes |
| Nevada | Unconfirmed | Yes | Yes (account) |
| New Hampshire | Unconfirmed | Yes | Yes |
| New Jersey | Unconfirmed | Yes | Unconfirmed |
| New Mexico | Yes | Yes | Yes |
| New York | Unconfirmed | Yes | Yes |
| North Carolina | Yes | Yes | Scrape |
| North Dakota | Yes | Yes | Unconfirmed |
| Ohio | Unconfirmed | Yes | Yes |
| Oklahoma | Scrape | Yes | Yes |
| Oregon | Scrape | Yes | Unconfirmed |
| Pennsylvania | Yes | Yes | Yes |
| Rhode Island | Unconfirmed | Yes | Unconfirmed |
| South Carolina | Unconfirmed | Yes | On request |
| South Dakota | Yes | Yes | Unconfirmed |
| Tennessee | Unconfirmed | Yes | Unconfirmed |
| Texas | Unconfirmed | Yes | Yes |
| Utah | Yes | Yes | Unconfirmed |
| Vermont | Yes | Yes | Unconfirmed |
| Virginia | Yes | Yes | Yes |
| Washington | Yes | Yes | Yes |
| West Virginia | Yes | Yes | Unconfirmed |
| Wisconsin | Unconfirmed | Yes | Scrape |
| Wyoming | Unconfirmed | Yes | Scrape |
| DC | Scrape (2026 races already in rally) | Yes | Yes |

## Source register

The Planned rows are enough for DC and Maryland seats, votes and results; Maryland money is the gap, because MD CRIS documents no bulk export.

| Source | Track | Covers | Access | Format, cadence | IDs it gives | License | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [OCD division IDs](https://open-civic-data-docs.readthedocs.io/en/latest/proposals/0002.html) (`country-us.csv`) | Places | Every US state, district, ward | GitHub CSV, no key | CSV, as districts change | ocd\_id | Public | Planned |
| [Open States people](https://open.pluralpolicy.com/data/) | Seats | All 50 states + DC Council | Bulk YAML/CSV, no key | YAML/CSV, as needed in session | openstates person id, district | Public domain | Planned |
| [Open States bills and votes](https://open.pluralpolicy.com/data/) | Votes | Same | Bulk per session | CSV/JSON, monthly | openstates bill, vote, person ids | Public domain | Later |
| [Open States API v3](https://open.pluralpolicy.com/data/) | Seats, votes | Same | Free key | JSON, live | Same | Public domain | Later |
| [LegiScan API, Public tier](https://legiscan.com/legiscan) | Votes | 50 states + Congress + DC | Free key, 30,000 queries/month | JSON, live | bill\_id, roll\_call\_id, people\_id | CC BY 4.0 | Planned |
| [LegiScan weekly datasets](https://legiscan.com/legiscan) | Votes | Same | Same key | ZIP of JSON per session, weekly | Same | CC BY 4.0 | Planned |
| [MD State Board of Elections results](https://elections.maryland.gov/elections/2026/Primary_Results/index.html) | Results | MD statewide, Senate 1–47, House 1A–47B, by county | Public web pages | HTML per office and district; no CSV found | None (names only) | Public record | Planned |
| [MD CRIS](https://elections.maryland.gov/campaign_finance/campaign_finance_database.html) (campaignfinancemd.us) | Money | MD candidates and committees, 2007–now | Web search; bulk via request to SBE | Search results; no bulk export documented | Committee (CCF) id | Public record | Check |
| [DC OCF contributions](https://catalog.data.gov/dataset/campaign-financial-contributions-023f6) and expenditures | Money | DC committees, 2003–now | DC Open Data (ArcGIS), no key | Daily | Committee name | CC BY 4.0 | In use |
| DC Board of Elections results | Results | DC offices, wards | Public web pages | Not yet located | None | Public record | Check |
| [VEST precinct results](https://election.lab.ufl.edu/dataset/dc-2024-precinct-level-election-results/) (UF Election Lab) | Results | DC 2022, 2024 by precinct | Login for TXT; shapefile is paid | TXT/SHP, after certification | Precinct | Not stated | Later |
| [OpenSecrets / FollowTheMoney](https://bellingcat.gitbook.io/toolkit/more/all-tools/opensecrets) state data | Money | 50 states | API registration closed April 2025; bulk is paid | Custom datasets | Their own ids | Paid terms | Check |
| OpenFEC API | Money (federal) | Federal candidates, PACs | Free api.data.gov key | JSON, nightly | FEC candidate and committee ids | Public record | In use |

[source](https://legiscan.com/legiscan) for LegiScan tiers; [source](https://open.pluralpolicy.com/data/) for Open States formats and cadence.

## Data dictionary

Sixteen entities cover all four tracks; each row below is one field, and the D1 tables in the draft migration (0100\_state\_data.sql) use these names exactly. Fields marked \* are required.

| Entity | Field | Type | Meaning | Example |
| --- | --- | --- | --- | --- |
| division | ocd\_id\* | text, key | OCD division ID | ocd-division/country:us/state:md/sldl:12a |
| division | name\* | text | Display name | House of Delegates District 12A |
| division | kind\* | text | state, sldu, sldl, cd, county, place, ward | sldl |
| division | state\* | text | Two-letter code, dc included | md |
| division | parent\_ocd\_id | text | Containing division | ocd-division/country:us/state:md |
| division | valid\_from, valid\_to | date | Redistricting window | 2022-01-01 |
| person | id\* | text, key | Rally person id | rp\_01J… |
| person | name\*, given\_name, family\_name | text | As the person uses it | Wes Moore |
| person | candidate\_id | int | Link to rally's existing DC candidates table | 12 |
| person\_id | scheme\*, value\* | text, key | An outside id for a person | legiscan / 21345 |
| person\_id | person\_id\* | text | Rally person it belongs to | rp\_01J… |
| person\_id | matched\_by\* | text | source-provided, name+district, curator | source-provided |
| office\_term | person\_id\*, ocd\_id\*, office\* | text | Who sat in which seat | upper |
| office\_term | party | text | Party code (see rules) | D |
| office\_term | start\_date, end\_date | date | end\_date empty = serving now | 2023-01-11 |
| election | id\* | text, key | state-date-kind | md-2026-11-03-general |
| election | kind\* | text | primary, general, special, runoff | general |
| contest | id\*, election\_id\*, ocd\_id\*, office\* | text | One race | md-2026-11-03-general/sldu:21/upper |
| contest | seats\*, party | int, text | Seats to fill; party for partisan primaries | 3 (MD House multi-member) |
| candidacy | contest\_id\*, person\_id\* | text, key | A person on that ballot |  |
| candidacy | party, incumbent | text, bool | As listed on ballot | D, 1 |
| result\_snapshot | votes, pct, won | int, real, bool | Count at fetch time | 18,240 / 61.3 / 1 |
| result\_snapshot | status\*, fetched\_at\* | text, timestamp | unofficial or certified; when we read it | unofficial |
| bill | id\* | text, key | source:id | legiscan:1987654 |
| bill | state\*, session\*, number\*, title\* | text | Bill identity | md / 2026 / HB 1 |
| bill | status, subjects, change\_hash | text | Latest status, topics, LegiScan change marker | Passed |
| roll\_call | id\*, bill\_id\* | text, key | One recorded vote | legiscan:1456789 |
| roll\_call | date, chamber, description | text | When, where, what motion | 2026-03-20 / lower / Third Reading |
| roll\_call | yea, nay, nv, absent, passed | int, bool | Totals | 98 / 38 / 2 / 3 / 1 |
| vote\_position | roll\_call\_id\*, person\_id\*, position\* | text, key | yea, nay, nv, absent | yea |
| filer | id\*, name\*, kind\*, state\* | text | A committee that reports money | md\_cris:01001234 |
| filer | person\_id | text | Candidate it serves; empty for PACs | rp\_01J… |
| finance\_snapshot | filer\_id\*, report\_period\_end\* | text, date | One filed report | 2026-10-20 |
| finance\_snapshot | raised, spent, cash, debts | USD | Report totals | 412,000.00 |
| contribution | id\*, filer\_id\*, amount\*, date | text, USD, date | Money in |  |
| contribution | contributor\*, contributor\_kind | text | Name; individual, business, pac, party, candidate | individual |
| contribution | employer, occupation, city, state, zip | text | Contributor details as filed |  |
| expenditure | id\*, filer\_id\*, payee\*, amount\*, date, purpose | text, USD | Money out |  |
| expenditure | supports\_person\_id, opposes\_person\_id | text | Independent spending target |  |
| ingest\_run | id\*, source\*, scope\*, status\* | text | One fetch of one source | legiscan / md:2026 / ok |
| ingest\_run | rows\_in, rows\_new, raw\_key, error | int, text | What it read; R2 key of the raw file |  |

Every fact row also carries `source`, `fetched_at` and, where there is one, `url`.

## Source field mappings

Each source fills only part of the dictionary; the table shows which source field lands in which dictionary field. Source field names are approximate, from the sources' published formats, and get confirmed against the first real download.

| Dictionary field | Open States people | LegiScan | MD SBE results | MD CRIS | DC OCF | OpenFEC |
| --- | --- | --- | --- | --- | --- | --- |
| person\_id (scheme value) | id (ocd-person/…) | people\_id | none, match by name + district | none, via filer | none, via filer | candidate\_id |
| person.name | name, given\_name, family\_name | name, first\_name, last\_name | Candidate name | Candidate name | Candidate name | name |
| office\_term.ocd\_id | roles\[\].district + jurisdiction | district (e.g. HD-12A), built into ocd\_id | Page per district | Office sought | Office sought | state + district |
| office\_term.office | roles\[\].type (upper, lower) | role (Sen, Rep) | Office heading | Office | Office | office (H, S, P) |
| office\_term.party | party\[\].name | party (D, R, I) | Party column | Party | Party | party |
| office\_term.start/end | roles\[\].start\_date, end\_date | none | none | none | none | none |
| bill.\* | n/a | bill\_id, session, bill\_number, title, status, change\_hash | n/a | n/a | n/a | n/a |
| roll\_call.\* | n/a | roll\_call\_id, date, chamber, desc, yea, nay, nv, absent, passed | n/a | n/a | n/a | n/a |
| vote\_position.position | n/a | votes\[\].vote\_text (Yea, Nay, NV, Absent) | n/a | n/a | n/a | n/a |
| result\_snapshot.votes, pct | n/a | n/a | Votes, percent per candidate | n/a | n/a | n/a |
| filer.id | n/a | n/a | n/a | CCF id | Committee name | committee\_id |
| contribution.\* | n/a | n/a | n/a | Contributor name, address, type, amount, date | Contributor, address, amount, date | Schedule A |
| expenditure.\* | n/a | n/a | n/a | Payee, purpose, amount, date | Payee, purpose, amount, date | Schedule B, Schedule E (independent) |

Open States bills and votes map the same way as LegiScan and serve as a cross-check for DC Council votes.

## More states

Seats and votes come from Open States and LegiScan for every state, so a new state only needs its own results and money sources. Of the six next-largest or nearest states, Virginia, California, Texas, New York and Pennsylvania publish free bulk finance files; Florida only mails bulk data on DVD.

| State | Money source | Money access | Results source | Results access | Ready |
| --- | --- | --- | --- | --- | --- |
| Virginia | [ELECT campaign finance CSV](https://www.elections.virginia.gov/candidatepac-info/reporting/) (apps.elections.virginia.gov/SBE\_CSV/CF/) | CSV, 1999–now, updated twice daily | [ELECT results CSV + historical database](https://www.elections.virginia.gov/resultsreports/) | CSV 2005–2023, historical site 1924–now, current results JSON | Both free bulk |
| California | [CAL-ACCESS raw data](https://www.sos.ca.gov/campaign-lobbying/helpful-resources/raw-data-campaign-finance-and-lobbying-activity) | ZIP of tab-delimited tables, daily; a replacement system is in progress | [Statement of Vote](https://www.sos.ca.gov/elections/prior-elections/statewide-election-results/general-election-november-3-2020/statement-vote) | PDF and XLSX, by county and district | Both free bulk |
| Texas | [Texas Ethics Commission CSV database](https://www.transparencyusa.org/data-explanation-for-texas) | One ZIP of CSVs with all data | Secretary of State results | Not yet located | Money only |
| New York | [NYS Board of Elections downloads](https://publicreporting.elections.ny.gov/DownloadCampaignFinanceData/DownloadCampaignFinanceData) | Zipped CSVs by state and county filers, with layout PDFs | State Board of Elections results | Not yet located | Money only |
| Pennsylvania | [Department of State full export](https://www.transparencyusa.org/data-explanation-for-pennsylvania) | CSVs for filers, contributions, receipts, expenses, debts | [DOS election data](https://www.pa.gov/agencies/dos/resources/voting-and-elections-resources/voting-and-election-statistics/election-data) | Text files with readmes, 1992 through the 2026 primary, precinct level | Both free bulk |
| Florida | [Division of Elections database](https://www.transparencyusa.org/data-explanation-for-florida) | Web search; bulk only as a mailed DVD, up to six weeks | [VEST precinct results](https://election.lab.ufl.edu/data-archive/florida/) | 2012–2024, after certification | Hard: money needs scraping or a DVD |

Recommended order after DC and Maryland: Virginia (next door, everything is free CSV), then Pennsylvania and California, then Texas and New York once their results sources are found. Florida waits until the rest are running.

## All 50 states

22 states publish free bulk campaign finance files; 4 give bulk data only on request, 4 only let you export search results, and 20 are not yet checked. Every state, checked or not, has a fallback: the [Accountability Project](https://github.com/irworkshop/accountability_datacleaning/blob/master/state/mo/contribs/docs/mo_contribs_diary.md) (Investigative Reporting Workshop) publishes cleaned contribution CSVs for all 50 states and DC, per [Concourse's source list](https://campaign-finance.onconcourse.com/methodology). Seats and votes need nothing per state (Open States, LegiScan).

For results, the national fallback is MIT Election Data and Science Lab [precinct returns for 2016, 2018, 2020 and 2024](https://electionlab.mit.edu/data), plus VEST files. State results feeds are checked so far only for DC, MD, VA, CA and PA (see sections above). Agencies are from the [FEC state records list](https://www.fec.gov/resources/cms-content/documents/StateRecordsOffices.pdf) and [Ballotpedia](https://ballotpedia.org/State_campaign_finance_agencies).

| State | Money agency | Money access | How the state publishes it | Results agency |
| --- | --- | --- | --- | --- |
| Alabama | Secretary of State | Free bulk | [CSV files from the Electronic FCPA Reporting System](https://www.transparencyusa.org/data-explanation-for-alabama) | Secretary of State |
| Alaska | Public Offices Commission | Not yet checked |  | Division of Elections |
| Arizona | Secretary of State | Request only | [Database sent on request after each filing deadline](https://www.transparencyusa.org/data-explanation-for-arizona) | Secretary of State |
| Arkansas | Secretary of State; Ethics Commission | Not yet checked |  | Secretary of State |
| California | Secretary of State (CAL-ACCESS) | Free bulk | [Daily ZIP of tab-delimited tables](https://www.sos.ca.gov/campaign-lobbying/helpful-resources/raw-data-campaign-finance-and-lobbying-activity) | Secretary of State (XLSX Statement of Vote) |
| Colorado | Secretary of State (TRACER) | Free bulk | [CSV contributions, expenditures, loans, committees](https://www.transparencyusa.org/data-explanation-for-colorado) | Secretary of State |
| Connecticut | State Elections Enforcement Commission (eCRIS) | Free bulk | [Yearly receipts and disbursements, CSV/XLSX, 1999–2026](https://seec.ct.gov/Portal/eCRIS/CurPreYears) | Secretary of the State |
| Delaware | Department of Elections | Not yet checked |  | Department of Elections |
| Florida | Division of Elections | Request only | [Mailed DVD, up to six weeks](https://www.transparencyusa.org/data-explanation-for-florida) | Division of Elections |
| Georgia | Government Transparency and Campaign Finance Commission | Free bulk | [CSV contributions and expenditures, 2021–now](https://www.transparencyusa.org/data-explanation-for-georgia) | Secretary of State |
| Hawaii | Campaign Spending Commission | Not yet checked |  | Office of Elections |
| Idaho | Secretary of State | Free bulk | [Bulk downloads in the 2020–now systems; Excel for 2000–2019](https://www.transparencyusa.org/data-explanation-for-idaho) | Secretary of State |
| Illinois | State Board of Elections | Free bulk | [TSV files](https://www.transparencyusa.org/data-explanation-for-illinois) | State Board of Elections |
| Indiana | Secretary of State, Election Division | Free bulk | [CSV contributions and expenditures](https://www.transparencyusa.org/data-explanation-for-indiana) | Secretary of State |
| Iowa | Ethics and Campaign Disclosure Board | Free bulk | [CSV contributions, expenditures, committees](https://www.transparencyusa.org/data-explanation-for-iowa) | Secretary of State |
| Kansas | Governmental Ethics Commission | Not yet checked |  | Secretary of State |
| Kentucky | Registry of Election Finance | Not yet checked |  | State Board of Elections |
| Louisiana | Ethics Administration Program | Not yet checked |  | Secretary of State |
| Maine | Commission on Governmental Ethics and Election Practices | Not yet checked |  | Secretary of State |
| Maryland | State Board of Elections (MD CRIS) | Request only | [Web search; bulk by request](https://elections.maryland.gov/campaign_finance/campaign_finance_database.html) | State Board of Elections (HTML) |
| Massachusetts | Office of Campaign and Political Finance | Not yet checked |  | Secretary of the Commonwealth |
| Michigan | Secretary of State | Free bulk | [TSV committees, contributions, expenditures, receipts](https://www.transparencyusa.org/data-explanation-for-michigan) | Secretary of State |
| Minnesota | Campaign Finance and Public Disclosure Board | Free bulk | [Current-year activity database and lists](https://www.transparencyusa.org/data-explanation-for-minnesota) | Secretary of State |
| Mississippi | Secretary of State | Not yet checked |  | Secretary of State |
| Missouri | Missouri Ethics Commission | Free bulk | [CSV by report form, 2011–now](https://github.com/irworkshop/accountability_datacleaning/blob/master/state/mo/contribs/docs/mo_contribs_diary.md) | Secretary of State |
| Montana | Commissioner of Political Practices | Not yet checked |  | Secretary of State |
| Nebraska | Accountability and Disclosure Commission | Free bulk | [Zipped CSV per year, 2022–2026, with layouts](https://nadc-e.nebraska.gov/PublicSite/DataDownload.aspx) | Secretary of State |
| Nevada | Secretary of State (AURORA) | Bulk with account | [CSV after creating an account](https://www.transparencyusa.org/data-explanation-for-nevada) | Secretary of State |
| New Hampshire | Secretary of State | Free bulk | [Bulk downloads plus search export](https://www.transparencyusa.org/data-explanation-for-new-hampshire) | Secretary of State |
| New Jersey | Election Law Enforcement Commission | Not yet checked | [Search and custom listings](https://www.elec.nj.gov/publicinformation.htm); bulk format not confirmed | Division of Elections |
| New Mexico | Secretary of State (CFIS) | Free bulk | [CSV contributions, loans, expenditures, 2020–now](https://www.transparencyusa.org/data-explanation-for-new-mexico) | Secretary of State |
| New York | State Board of Elections | Free bulk | [Zipped CSV, state and county filers](https://publicreporting.elections.ny.gov/DownloadCampaignFinanceData/DownloadCampaignFinanceData) | State Board of Elections |
| North Carolina | State Board of Elections | Search export only | [Search only, no full export](https://transparencyusa.org/data-explanation-for-north-carolina) | State Board of Elections |
| North Dakota | Secretary of State | Not yet checked |  | Secretary of State |
| Ohio | Secretary of State | Free bulk | [CSV on the campaign finance FTP site](https://www.transparencyusa.org/data-explanation-for-ohio) | Secretary of State |
| Oklahoma | Ethics Commission (Guardian) | Free bulk | [State-direct bulk download](https://campaign-finance.onconcourse.com/methodology) | State Election Board |
| Oregon | Secretary of State (ORESTAR) | Not yet checked |  | Secretary of State |
| Pennsylvania | Department of State | Free bulk | [Full export: CSV filers, contributions, receipts, expenses, debts](https://www.transparencyusa.org/data-explanation-for-pennsylvania) | Department of State (text files, precinct level) |
| Rhode Island | Board of Elections | Not yet checked |  | Secretary of State |
| South Carolina | State Ethics Commission | Request only | [SQL Server backup on request](https://www.transparencyusa.org/data-explanation-for-south-carolina) | State Election Commission |
| South Dakota | Secretary of State | Not yet checked |  | Secretary of State |
| Tennessee | Registry of Election Finance | Not yet checked |  | Secretary of State |
| Texas | Texas Ethics Commission | Free bulk | [One ZIP of CSVs with all data](https://www.transparencyusa.org/data-explanation-for-texas) | Secretary of State |
| Utah | Lieutenant Governor, Elections | Not yet checked |  | Lieutenant Governor |
| Vermont | Secretary of State | Not yet checked |  | Secretary of State |
| Virginia | Department of Elections | Free bulk | [CSV 1999–now, updated twice daily](https://www.elections.virginia.gov/candidatepac-info/reporting/) | Department of Elections (CSV) |
| Washington | Public Disclosure Commission | Free bulk | [CSV contributions, expenditures, loans, independent expenditures](https://www.transparencyusa.org/data-explanation-for-washington) | Secretary of State |
| West Virginia | Secretary of State | Not yet checked |  | Secretary of State |
| Wisconsin | Ethics Commission | Search export only | [Search export, up to 65,000 rows a file](https://www.transparencyusa.org/data-explanation-for-wisconsin) | Elections Commission |
| Wyoming | Secretary of State (WYCFIS) | Search export only | [Search results by two-year cycle; reports as PDFs](https://www.transparencyusa.org/data-explanation-for-wyoming) | Secretary of State |

The same table is saved as state\_sources.csv for the pipeline to read.

## Election results by state

I've confirmed machine-readable official results for 21 states: 10 publish bulk files, 8 offer a CSV, XML or Excel export for each election, and 3 have a historical database with per-contest downloads. Another 11 publish only web pages or PDFs, so those need scraping. For the remaining 18 I found the results site but couldn't confirm its format.

Every state also has two fallbacks. MIT Election Lab precinct returns cover 2016, 2018, 2020 and 2024 ([source](https://electionlab.mit.edu/data)). VEST precinct files cover 2016–2024 (for example [Hawaii](https://election.lab.ufl.edu/data-archive/hawaii) and [South Carolina](https://election.lab.ufl.edu/data-archive/south-carolina)). Both are published months after certification, so neither has the 2026-11-03 results yet. OpenElections has volunteer-cleaned precinct CSVs for some states, including AL, CA, GA, MS, NY, PA, TX and WV ([repo list](https://github.com/openelections)).

Four vendor patterns repeat across states, so one adapter each covers several of them:

- **ResultsExport.aspx sites** (ND, NE, SD, MT, NM): per-election exports by statewide, legislative and county.
- **ElectionStats databases** (CO, VT, MA, CT, ID): one page per contest; CO and VT confirmed CSV download.
- **Clarity/Scytl ENR**: XML detail and JSON summary, but URLs change every election and old results are taken down ([notes](https://cgorski.github.io/election-aggregation/sources/clarity.html)).
- **State bulk ZIPs** (NC, GA, AL, PA): the easiest to load.

| State | Results access | What the state publishes |
| --- | --- | --- |
| Alabama | Bulk files | [ZIP/XLS precinct results 2010–2026; county and statewide back to 1892](https://www.sos.alabama.gov/alabama-votes/voter/election-data) |
| Alaska | Web or PDF only | [HTML/PDF summary and detail 2022–now; search tool 1958–2021](https://www.elections.alaska.gov/research/statistics/) |
| Arizona | Format not confirmed | Current results site not located; old query pages on apps.azsos.gov |
| Arkansas | Web or PDF only | [Results site since 1976 plus PDFs](https://sos.arkansas.gov/elections/research) |
| California | Bulk files | [Statement of Vote in XLSX, by county and district](https://www.sos.ca.gov/elections/prior-elections/statewide-election-results/general-election-november-3-2020/statement-vote) |
| Colorado | Per-contest database | [Historical database, precinct and county, CSV per contest](https://historicalelectiondata.coloradosos.gov/contests/view/4998) |
| Connecticut | Web or PDF only | [Town-level history database](https://electionhistory.ct.gov/contests/view/34720), no download visible; PDF Statement of Vote |
| Delaware | Bulk files | [HTML by election district plus raw TXT files, 1940–2025](https://elections.delaware.gov/elections/election_archive.shtml) |
| Florida | Format not confirmed | [Archive 1978–now](https://dos.fl.gov/elections/data-statistics/elections-data/election-results-archive/); format not stated |
| Georgia | Bulk files | [ZIP per election, precinct and summary, 2015–2024](https://sos.ga.gov/page/historical-elections-results) |
| Hawaii | Format not confirmed | Official files not located; VEST only |
| Idaho | Bulk files | [Excel to precinct level, 1990–2018](https://sos.idaho.gov/ELECT/results/); canvass database for later years |
| Illinois | Export per election | [Vote totals search 1998–2025 with download, precinct filter](https://www.elections.il.gov/electionoperations/ElectionVoteTotals.aspx) |
| Indiana | Format not confirmed | [Results archive 2019–now](https://enr.indianavoters.in.gov/archive/2022General/index.html); downloads not confirmed |
| Iowa | Web or PDF only | Canvass summary PDFs |
| Kansas | Web or PDF only | Official vote totals PDFs |
| Kentucky | Format not confirmed | [Results 1973–now, recap sheets](https://www.elect.ky.gov/results); format not stated |
| Louisiana | Format not confirmed | Secretary of State results site; format not confirmed |
| Maine | Bulk files | [XLSX by office and district](https://www.maine.gov/sos/elections-voting/election-results-data/2022-election-results) |
| Maryland | Web or PDF only | [HTML page per office and district](https://elections.maryland.gov/elections/2026/Primary_Results/index.html) |
| Massachusetts | Per-contest database | [Database 1970–2026, town filter](https://electionstats.state.ma.us/); CSV not confirmed |
| Michigan | Web or PDF only | [Precinct lookup 1998–now, PDFs](https://michigan.gov/sos/elections/Election-Results-and-Data) |
| Minnesota | Format not confirmed | Precinct results spreadsheet page exists; the link redirected |
| Mississippi | Web or PDF only | Certified results PDF per office |
| Missouri | Web or PDF only | Results PDFs per election |
| Montana | Export per election | [Statewide and county exports](https://electionresults.mt.gov/MyTrackedContests.aspx?eid=19); canvass PDFs |
| Nebraska | Export per election | [Statewide, legislative and county exports; 2026 general live](https://electionresults.nebraska.gov/ResultsExport.aspx?cat=SWALL) |
| Nevada | Format not confirmed | Results site not reached |
| New Hampshire | Format not confirmed | Election database run by NH Public Radio; official files not located |
| New Jersey | Format not confirmed | [County reports and an archive](https://www.nj.gov/state/elections/election-results.shtml); format not stated |
| New Mexico | Export per election | [CSV exports by office group, county level](https://electionresults.sos.nm.gov/ResultsMedia.aspx?eid=2882) |
| New York | Format not confirmed | Certified results not located as files |
| North Carolina | Bulk files | [Precinct results ZIP 2000–2026, including 2026-11-03](https://ncsbe.gov/results-data/election-results/historical-election-results-data) |
| North Dakota | Export per election | [CSV, Excel, XML exports: statewide, legislative, county](https://results.sos.nd.gov/ResultsExport.aspx?eid=326) |
| Ohio | Format not confirmed | Official files not located |
| Oklahoma | Web or PDF only | [Fixed-width precinct files for 2010 only](https://oklahoma.gov/elections/elections-results/precinct-level-results-data.html); web pages otherwise |
| Oregon | Web or PDF only | Abstract of votes PDFs |
| Pennsylvania | Bulk files | [Text files with readmes, 1992 to the 2026 primary, precinct level](https://www.pa.gov/agencies/dos/resources/voting-and-elections-resources/voting-and-election-statistics/election-data) |
| Rhode Island | Format not confirmed | [Results pages 2008–2024](https://www.ri.gov/election/results/); PDF count books |
| South Carolina | Format not confirmed | Official exports not located; VEST only |
| South Dakota | Export per election | [Statewide, legislative and county exports; 2026 general live](https://electionresults.sd.gov/ResultsExport.aspx) |
| Tennessee | Format not confirmed | [County-level unofficial results site](https://elections.tn.gov/results-by-county); no downloads seen |
| Texas | Format not confirmed | [Archive 1992–now across three sites](https://www.sos.texas.gov/elections/historical/elections-results-archive.shtml); format not stated |
| Utah | Bulk files | [XLSX primary and general results](https://vote.utah.gov/2014-election-records) |
| Vermont | Per-contest database | [Archive database with CSV per contest](https://electionarchive.vermont.gov/contest/158046) |
| Virginia | Bulk files | [CSV 2005–2023, database 1924–now, current-results JSON](https://www.elections.virginia.gov/resultsreports/) |
| Washington | Export per election | [CSV and XML per election incl. precinct CSV](https://results.vote.wa.gov/results/20200428/export.html); [XLSX archive](https://www.sos.wa.gov/node/30367) |
| West Virginia | Export per election | [County results with a download per election, 2008–2017](https://apps.sos.wv.gov/elections/results/); newer page separate |
| Wisconsin | Format not confirmed | Ward-by-ward PDFs found; data files not confirmed |
| Wyoming | Format not confirmed | Canvass releases only |
| DC | Web or PDF only | [Certified results PDF by ward and ANC district](https://electionresults.dcboe.org/Downloads/Reports/November_8_2022_General_Election_Certified_Results.pdf) |

## Identity and normalization rules

The rules below decide how rows from different sources become one record.

1. **Matching people.** Use ids a source already crosswalks first. Then match on exact name plus the same division and office within one state. Anything else goes to a curator list and is never merged automatically.
2. **Places.** Build ocd\_ids from source district codes with one function per source (LegiScan `HD-12A` becomes `state:md/sldl:12a`). DC uses `district:dc`, not `state:dc`.
3. **Party.** Store one-letter codes: D, R, L, G, I (independent or unaffiliated), O (other). Keep the source's original text in a raw column.
4. **Vote positions.** Map to yea, nay, nv (present or not voting) and absent. Excused counts as absent.
5. **Money.** Store dollars as numbers with two decimals, never cents as integers. Refunds and returned contributions are negative rows, not deletions. Totals come from filed reports, never from summing transactions.
6. **Dates.** ISO 8601 dates; timestamps in UTC with a Z.
7. **History.** Nothing is overwritten. Results and finance totals are new rows per fetch; a seat change closes end\_date.
8. **Provenance.** Each row keeps source, fetched\_at, url and the ingest\_run that wrote it; the raw file stays in R2.

## Open questions

- [ ] Get a free LegiScan API key (Jonathan)
- [ ] Ask the Maryland State Board of Elections for a bulk MD CRIS export, or confirm the new portal's download option
- [ ] Find the DC Board of Elections official results download
- [ ] Decide whether paid OpenSecrets state data is worth it once DC and Maryland are in
- [ ] Confirm the source field names above against the first real download of each source

## Sources

- [LegiScan API](https://legiscan.com/legiscan)
- [Open States bulk data](https://open.pluralpolicy.com/data/)
- [OCD division identifiers (OCDEP 2)](https://open-civic-data-docs.readthedocs.io/en/latest/proposals/0002.html)
- [Maryland campaign finance database](https://elections.maryland.gov/campaign_finance/campaign_finance_database.html)
- [Maryland 2026 primary results](https://elections.maryland.gov/elections/2026/Primary_Results/index.html)
- [DC campaign financial contributions](https://catalog.data.gov/dataset/campaign-financial-contributions-023f6)
- [VEST DC 2024 precinct results](https://election.lab.ufl.edu/dataset/dc-2024-precinct-level-election-results/)
- [OpenSecrets entry, Bellingcat toolkit](https://bellingcat.gitbook.io/toolkit/more/all-tools/opensecrets)
