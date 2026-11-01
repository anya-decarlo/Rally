# Coverage Plan — every politician, loaded and kept current

*Drafted 2026-10-28, after the `prototypes/graph/` identity prototype (F1 0.96) and the
source landscape research (`ELECTION_DATA_RESEARCH.md`).*

## Scope decision

"Every politician" has two readings:

- **Literal:** ~500k elected officials across 19k municipalities, 3k counties, 13k
  school districts. *Nobody has this* — not Ballotpedia, not DDHQ, not the Census
  Bureau in usable form. Multi-year, multi-hundred-thousand-dollar data operation.
- **Ours:** every politician a Rally user can plausibly encounter — all federal, all
  state, and the top few hundred cities/counties. **~100k officials + candidates.**

We build the second. Local expands with users, not ahead of them.

## Foundation (the five pieces)

1. **Canonical people registry** — `rally_person_id` mapped to every source ID
   (FEC, OCF, FEP, Ballotpedia, Wikidata, OpenStates, ...). Postgres. This is the
   moat; the prototype proved the hard part (namesake rejection, FEC ID sprawl
   resolution, misspelling clustering).
2. **Source adapters** — one per source, 50–200 lines each: fetch → normalize →
   cache. Stdlib, receipts preserved (every record links back to its source row —
   house rule). The work is count, not difficulty.
3. **Identity engine as a standing service** — blocking → feature similarity →
   Jev judges gray-zone pairs → agglomerative clustering → **curator queue with a
   human review UI**. The human loop is not optional: ~10% of pairs need 30 seconds
   of judgment each, and those decisions become the eval truth.
4. **Ground-truth ballot layer** — *who is officially on the ballot* is the anchor
   every other record joins to. **Buy this, don't build it** (Ballotpedia or
   Democracy Works API — both contact-sales; get rate cards).
5. **Cycle-aware updater** — filing deadlines and election calendars drive
   incremental re-pulls; re-cluster only changed neighborhoods, never the whole graph.

## Coverage tiers

| Tier | Scope | Data cost | Eng time | Elapsed |
|---|---|---|---|---|
| **Federal** | ~540 officials + ~3k candidates/cycle | $0 — FEC, Congress.gov, MEDSL, OpenElections | 2–4 wks (≈80% done) | **~1 month** |
| **+ State** | ~7,700 legislators + statewide + candidates | $0–$$ — OpenStates free; money via OpenSecrets licensing *or* free Accountability Project | +4–8 wks | **~3 months** |
| **+ Local top 100–300** | ~30–50k officials + candidates | **The real spend** — Ballotpedia / Democracy Works licensing, likely five figures/yr (get quotes) | 6–8 wks DIY per-city, ~2 wks integrating a licensed feed | **~4–6 months** |
| ~~Every local~~ | ~500k officials | doesn't exist anywhere | years | don't |

## Cost model

| Item | Year one | Notes |
|---|---|---|
| Data licensing (ballot layer, maybe state money) | $10–50k | contact-sales; the quotes drive the decision |
| Engineering | 4–6 engineer-months | foundation + tiers 1–3 |
| Jev adjudication | ~$0 | 10–50k calls per full national build = dollars; donors go to Splink, not Jev |
| Infra (Postgres + scheduler on existing Workers/D1 stack) | tens of $/mo | |
| **Human review** | **40–80 hrs/cycle** | the hidden ongoing cost — budget as labor |

**Bottom line: launchable national identity graph in ~4–6 months, ~$30–60k year one,
dominated by data licensing and review labor — not engineering.**

## Sequencing

1. **Now → +1 mo:** Federal end-to-end (mostly done in DC prototype; generalize the
   fetcher over `state=`). Fix the FEP fetch (all ~67 registrations) as the adapter
   pattern's second case.
2. **+1 → +3 mo:** State — OpenStates key (free), per-state money via Accountability
   Project where fresh, portal adapters for priority states. Canonical registry
   becomes Postgres.
3. **+3 → +6 mo:** Local top-100 — integrate licensed ballot feed; NYC CFB, SF
   Ethics, LA Ethics as the first three hand-built money adapters (replicate the DC
   OCF playbook). Curator review UI.
4. **Ongoing:** cycle-aware updates; new cities on user demand (~1 week each).

## Open decisions (this week)

- [ ] Get **Ballotpedia** rate card (data@ballotpedia.org) and **Democracy Works**
      Elections API quote — pick the ballot layer
- [ ] Ask **OpenSecrets** for state-data licensing terms; if slow/hostile, start on
      Accountability Project + per-state portals and revisit
- [ ] Register a free **OpenStates** API key
- [ ] Decide review-UI owner (who spends the 40–80 hrs/cycle)

## Risks

- **Licensing price/ terms kill the buy option** → fallback: per-SoS certified lists
  (free, 50 schemas, slower); the architecture doesn't change.
- **Recall from thin sources** (FEP-style name formats, dormant committees) →
  curator queue absorbs it; never auto-merge on name alone. Precision over recall,
  always — a wrong merge is a libel risk, a missing link is a Tuesday.
- **500k creep** → resist. Local grows with users.
