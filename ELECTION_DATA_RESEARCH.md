# Election Data Research — federal, state, local

*Researched 2026-10-28. Question: what are our options for pulling (a) election data — who's on the ballot, results — and (b) election spending data, across all three levels of US elections?*

Rally's pipeline runs **offline and ships bundled data**, so bulk/CSV-first sources fit better than live APIs. We don't need election-night race calls — we can wait for certification. That rules out the expensive half of this market (AP, DDHQ, Edison) and puts free bulk sources first.

---

## ⚠️ Landscape shifts since 2024 — read this first

Several sources listed in older civic-tech guides (and in `DATA_SOURCES.md`) are dead or changed:

| What | Status |
|---|---|
| **Google Civic Information API** | **Shut down April 30, 2025.** The "who represents this address" market is now fragmented: Democracy Works, Ballotpedia, Cicero (paid), Plural Open, USgeocoder. |
| **ProPublica Congress API** | **Dead.** Docs are "historical reference only"; repo archived Feb 2025. Use Congress.gov API + GovTrack bulk instead. (DATA_SOURCES.md row #8 in the queued table needs updating.) |
| **OpenSecrets public API** | **Discontinued April 2025.** OpenSecrets now sells custom data licensing (federal + state, summary or itemized). Free bulk downloads still exist for educational use. |
| **FollowTheMoney** | Merged into OpenSecrets. Site is **frozen at the 2024 cycle** ("isn't maintained as we integrate"). Its all-50-state data is migrating to OpenSecrets' new unified dashboard (launched Oct 2026). |
| **OpenStates** | Now **Plural Open** (moved 2023). v3 REST API still free with a key; bulk downloads; covers all 50 states + DC + PR (+ limited municipal). Commercial tier being explored for heavy users. |
| **GovTrack REST API** | Wound down. **Bulk data downloads still maintained** (govtrack.us/data) and the `unitedstates/congress` scrapers remain the standard pipeline for bill/vote XML→JSON. |
| **Vote Smart** | Alive. API now has paid plans ("Civic Knowledge API"): bios, votes, positions, ratings, statements for 220k+ candidates/officials since 1992. |

---

## Federal

### Federal spending

| Source | What it gives | Access | Verdict |
|---|---|---|---|
| **OpenFEC API + FEC bulk files** (already verified) | Candidates, committees, Schedules A/B/E, itemized receipts/disbursements, independent expenditures, electioneering comms, e-filed reports near-real-time | Free key via api.data.gov (~1,000 req/hr default); bulk files updated daily–weekly | ✅ **Primary engine.** Keep as-is. |
| **The Accountability Project** (IRE) | Normalized FEC Schedule A export, 2007→2026, **1.1B+ rows**, plus legacy paper filings transcribed; processing code is open source | Free search + CSV download, no account needed | ✅ Best shortcut for a normalized federal contribution archive without running FEC bulk parsing yourself. |
| **OpenSecrets custom data** | Their cleaned layer: employer→industry coding, PAC→sponsor orgs, federal + state + lobbying, 30+ years | 💰 Contact-sales licensing (public API dead) | Consider later for the sector-classification roadmap item — this is literally their industry codes. |
| **Congress.gov API** | Bills, amendments, members, committees, hearings; **beta House roll-call vote endpoint** (member-level) | Free key | ✅ For the "what they did" layer. Already in DATA_SOURCES. |
| **clerk.house.gov / senate.gov vote XML** | Official roll calls (House 1990–, Senate 1989–) | Free XML | The canonical vote feeds GovTrack itself consumes. |
| **GovTrack bulk + `unitedstates/congress` scrapers** | Full bill/vote pipeline output as JSON | Free | Good bootstrap for historical votes. |
| **USAspending API** (already listed) | Federal contracts/awards to recipients | Free key | ✅ Keep for the company-alignment layer. |

### Federal election data (ballot + results)

| Source | What it gives | Access | Verdict |
|---|---|---|---|
| **MIT Election Lab (MEDSL)** | Free result datasets: President by county 2000–2024, Senate statewide 1976–2024, House by district 1976–2024, precinct-level 2020 & 2024, cast-vote-record database | Free download | ✅ **Best free federal results.** Perfect for historical cards and margins. |
| **OpenElections** | Certified precinct-level results, ~30+ states complete, federal + statewide + state leg, CSVs on GitHub. Volunteer-run but actively committed (2026) | Free | ✅ Complements MEDSL at precinct level. No live results — fine for us. |
| **FEC candidate/committee master + official "Federal Elections" PDFs** | Who filed to run (≠ ballot-qualified); certified biennial results | Free API/bulk/PDF | Filing ≠ ballot access. Pair with state-certified lists when that matters. |

---

## State

### State spending

| Source | What it gives | Access | Verdict |
|---|---|---|---|
| **OpenSecrets (ex-FollowTheMoney)** | The **only** normalized all-50-state dataset: candidate contributions/expenditures, ballot-measure money, lobbying. New unified federal+state dashboard (Oct 2026); current-cycle state data promised in future releases | 💰 Custom data licensing; old FTM site still has free bulk CSVs frozen at 2024 cycle (CC BY-NC-SA, noncommercial) | Watch closely. If we want one integration for 50 statehouses, this is it — but access is now a negotiation, and the free frozen copy has a noncommercial license. |
| **The Accountability Project** (IRE) | Normalized state contributions + expenditures + lobbying for dozens of states, per-state datasets with source links | Free CSV downloads | ✅ Best free option today. Caveat: update cadence varies by state (some lag to 2021–2023). Check per state before relying. |
| **Direct state disclosure portals** | Every state has its own agency (ethics commission / SoS). Some are excellent bulk CSV/API (often Socrata/ArcGIS), some are PDF hell | Free; 50 different schemas | The DC OCF playbook, 50 times. Only worth it per-state when OpenSecrets/TAP coverage lags the current cycle. |

### State election data (ballot + results)

| Source | What it gives | Access | Verdict |
|---|---|---|---|
| **Plural Open (OpenStates) API v3 + bulk** | Current legislators, bills, roll-call votes, all 50 states + DC + PR | Free key; commercial tier coming for heavy use | ✅ "LIMS-for-America" — exactly the vote-cards-everywhere layer we queued. |
| **LegiScan GAITS API** | Bills, votes, roll calls, all 50 states + Congress, near-real-time | 💰 Paid (low-cost tiers) | Alternative to Plural if we need bill text/monitoring at scale. |
| **Ballotpedia API** | Candidates, officeholders, ballot measures, election dates; geographic API (`elections_by_point`) and bulk, refreshed every 24h; tiers: federal/statewide → state leg + top-100 cities → "ultralocal" | 💰 Rate card on request (data@ballotpedia.org) | The realistic way to get "who's on your ballot" nationally without 50 SoS integrations. Ballot measures + money-for/against is a high-fun card format. |
| **Democracy Works Elections API** | Ballot info (contests, candidates, measures), voting guidance, polling locations; powers TikTok, Anthropic election centers | 💰 Contact for pricing; test key available | Overlaps Ballotpedia; stronger on voting logistics, weaker on candidate depth. |
| **Vote Smart API** | Bios, issue positions (Political Courage Test), votes, interest-group ratings, statements — 220k+ people | 💰 Paid plans | Stance-card fuel at national scale, candidate-authored positions. |
| **State SoS certified lists + results** | Official ballot qualification and certified results | Free; 50 formats | Authoritative receipts. Use to validate any aggregator. |
| **MEDSL state-leg returns + OpenElections** | Historical state legislative results, precinct where available | Free | ✅ Historical context layer. |

---

## Local

The hard truth: **no source covers all ~19,000 municipalities.** Local is a city-by-city replication of the DC playbook.

| Source | What it gives | Access | Verdict |
|---|---|---|---|
| **City/county open-data portals** (the DC OCF pattern) | Contributions + expenditures, often live APIs with no key: DC (ArcGIS ✅ verified), NYC CFB ("Follow the Money" search + downloads), SF Ethics (data.sfgov Socrata), LA Ethics, Chicago, Seattle, etc. | Free; per-city schema | ✅ **Our proven pattern.** Discovery step: search `data.{city}.gov` / Socrata / ArcGIS for "campaign finance". Most big cities publish; formats vary. |
| **OpenSecrets local** | FTM historically had "limited local contributions for 30+ cities/counties" — now under OpenSecrets custom licensing | 💰 | Only if we expand faster than per-city builds allow. |
| **The Accountability Project** | Some county/city finance datasets mixed in with the states | Free | Check coverage per city. |
| **DDHQ / AP (commercial)** | Local *results* down to school board; DDHQ claims 100k+ races/cycle | 💰💰 | Not worth it — we don't need live calls, and local certified results are free from county offices after the fact. |
| **Ballotpedia top-100-cities / ultralocal** | Local candidates + measures | 💰 | The cheapest systematic local ballot coverage available. |
| **County election offices** | Certified local results (PDF/CSV/web) | Free; no standard | The receipts layer for local results. |
| **MEDSL local precinct returns (2018) + OpenElections** | Historical local results where they exist | Free | Spotty but free. |

---

## The joins nobody solves

Every aggregator has its own IDs (FEC candidate ID, OpenSecrets/FTM Entity ID, OCD-IDs, Vote Smart ID, state IDs). There is no universal politician ID. Rally will need its own identity-resolution layer (name + office + cycle + geography), with Wikidata/Wikipedia (already in the pipeline) as connective tissue. This is real work, but it's also a moat — it's the same join Rally is already doing for DC.

---

## Recommendations, phased

> **2026-10-28:** the costed version of this plan — scope decision, foundation, tiers,
> budget, sequencing — lives in `COVERAGE_PLAN.md`.

1. **Stay DC-first (now).** DCBOE results + RCV rounds (already queued), OCF + Fair Elections (verified). Nothing here blocks patient zero.
2. **Federal expansion (next, all free):** OpenFEC (done) + MEDSL/OpenElections for results + Congress.gov API for votes + TAP if we want a pre-normalized Schedule A archive. No paid dependencies.
3. **State expansion (the real decision):**
   - Legislators/votes: **Plural Open**, free.
   - Money: evaluate **OpenSecrets custom licensing** vs. **Accountability Project (free, check freshness per state)** vs. per-state portals only where we care. Decide when OpenSecrets publishes state-licensing terms — their Oct 2026 dashboard launch suggests they're actively courting this.
   - Ballot/candidates: get **Ballotpedia's rate card** (and a Democracy Works quote for comparison) before attempting any 50-SoS crawl.
4. **Local expansion:** replicate the DC playbook city by city. NYC + SF + LA are the obvious next three (all have real portals). No shortcut exists — but every city we add is a schema, not a research project.
5. **Cross-cutting:** start the identity-resolution layer early (internal politician ID mapped to FEC/state/Wikidata IDs). Every new source plugs into it. → **Prototyped in `prototypes/graph/`** (fetch.py + resolve.py): 6 free sources, Jev adjudicates gray-zone pairs, agglomerative clustering at F1 0.96.

### Cost snapshot

| Free, today | Contact-pricing |
|---|---|
| OpenFEC, FEC bulk, Congress.gov, clerk/senate vote XML, GovTrack bulk, MEDSL, OpenElections, Plural Open, Accountability Project, USAspending, DC OCF, city portals | OpenSecrets (state+federal custom data), Ballotpedia, Democracy Works, Vote Smart, LegiScan, Cicero, DDHQ/AP (not needed) |
