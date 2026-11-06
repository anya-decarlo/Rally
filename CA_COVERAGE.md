# CA Coverage — the state-level dig, answered for California

*2026-11-05 — follow-up to `Election_Data_Research.md`'s state section.
California is the pilot; the same checklist applies to every state.*

Verdict up front: **CA is about as good as it gets.** Bills ✓ live, votes ✓
member-level, money = free daily raw data, ballot = certified SoS lists.

## The four layers, CA edition

| Layer | Source | Status |
|---|---|---|
| **Bills** | OpenStates (Plural Open) v3 | ✅ **Running** — collector #1, 502 cards live |
| **Votes** | OpenStates `include=votes` | ✅ **Verified** — member-level roll calls |
| **Money** | CAL-ACCESS raw data (SoS) → cleaned by CA Civic Data Coalition / Big Local News | ✅ **Free, daily-updated** |
| **Ballot** | CA SoS certified candidate lists | ✅ Free PDFs per election |
| **Hearings/transcripts** | Digital Democracy API | ⏳ Needs key + approval |

## Votes — verified live

OpenStates returns vote records per CA bill with per-member breakdowns.
SB 79 pulled **10 vote records**: floor votes (80 Assembly members, 40 Senate)
plus committee votes ("Do pass as amended", 8–6–1). This powers the
"legislative vote" lane AND the "how did YOUR rep vote" card — add
`include=votes` to the collector when we wire the vote lane.

## Money — the Cal-Access path

- **CAL-ACCESS raw data**: SoS publishes the full database as a daily-updated
  ZIP of ~80 tab-delimited files (RCPT_CD contributions, EXPN_CD expenditures,
  FILERNAME_CD, S497 late contributions, S496 independent expenditures…).
  Free, no key, documented layouts.
- **CA Civic Data Coalition** (now Big Local News, Stanford) already wrote the
  cleaning pipeline and publishes processed daily files —
  `calaccess.californiacivicdata.org`. Use their cleaned layer first;
  drop to raw for anything they don't normalize.
- **The Accountability Project's CA set is stale** (contributions end 2019,
  8.1M records) — skip it for CA; Cal-Access/CCDC is fresher and freer.
- OpenSecrets licensing is a maybe-later for sector classification
  (employer→industry), not a blocker.

## Ballot — SoS certified lists

sos.ca.gov publishes certified candidate lists per election (June 2026
primary + Nov 2026 general). Free, authoritative — the ground-truth layer
for "who's on the ballot" that the research doc recommends buying
statewide but which CA gives away.

## What this means for the sequence

Streams 1–2 of the record engine are done/proven for CA. Next collectors:
3. **votes** (same API, one include flag away) → powers per-member cards
4. **money** (CCDC cleaned Cal-Access files — TSVs, no scraping) →
   contributions + IEs per candidate
5. **ballot** (SoS certified list — small, hand-parseable) → who qualified

Digital Democracy application is still worth filing — it's the only
structured source for hearing transcripts (the shorts pipeline).
