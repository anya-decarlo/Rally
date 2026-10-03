# Rally

**The TikTok for politics. The politicians don't get to post.**

Every candidate on the ballot gets a profile, a feed, and shorts — but the content is written by their campaign filings, their hearing footage, and their own tweets. Scroll it like TikTok. Trust it like a receipt.

---

## What it is

Politicians make promises on camera. Rally finds the clip, finds the check, and puts them on the same card.

The posts are generated from four public sources that nobody has ever put on one timeline:

| Source | What it gives us |
|---|---|
| **YouTube** — hearings, debates, forums | What they said — transcribed, timestamped, clipped into shorts |
| **Campaign finance filings** (FEC / DC OCF) | Who paid them — every itemized dollar, in and out |
| **Votes & records** | What they actually did |
| **X** | What they say when they think it's just their followers listening |

X is the *only* outside social platform Rally pulls from. One source, consistently applied to everyone.

Rally is the join.

## The app

It's a social app. It has to feel like one.

**📱 Shorts** — vertical, swipeable clips from hearings and forums. Candidate says the thing; the money appears under it. The For You page of local democracy.

**🪪 Profiles** — every candidate's page: photo, bio, office they're running for, their X feed, their money breakdown, their stances, and their **Nobody score**. They don't get to edit it.

**🗣️ Stance cards** — a quote (clip or tweet) next to the money relevant to it.
> *"I will never take developer money."* — Candidate X, Ward 1 forum, 42:17
> Received **$38,500** from real estate this cycle.

**⚔️ Head-to-head** — opponents in one contest, side by side. The default feed.

**👻 Nobody cards** — money that went somewhere with no name on it. The mystery feed.

Everything links out. Tap the number → the filing. Tap the quote → the clip. Tap the tweet → the tweet.

## The Nobody ledger

FEC data has holes, and the holes are the interesting part:

- Disbursements to payees like `MISC`, `VARIOUS`, `REIMBURSEMENT`, or blank
- Contributions from `INFORMATION REQUESTED` or with no employer/occupation
- Earmarked money routed through conduits where the real endpoint is obscured
- Payments to LLCs with no public footprint

Rally collects all of it into a per-candidate **Nobody ledger** — *"$2.3M of Sen. X's money went to Nobody"* — and tries to trace it: same LLC address across campaigns, treasurers who keep showing up, vendors mentioned in hearing transcripts. Every trace is a card. Unsolved ones are open puzzles.

## Rules of the house

1. **Receipts, not accusations.** Rally never says "bought." It says: here's the promise, here's the money, here's the vote. You draw the line.
2. **Every number links to its filing. Every quote links to its clip.** If you can't check it, it doesn't ship.
3. **Everyone gets the same treatment.** Same rules, same math, every party, every seat.
4. **It should be fun.** If scrolling Rally feels like homework, we built it wrong.

## How it's built

- **App:** native SwiftUI, iOS + macOS, one target (`Rally.xcodeproj`)
- **Pipeline:** Python — video ingest → transcription → stance extraction → finance join → X pull → card generation. Runs offline on a Mac; the app ships with the output bundled. No API calls from the app (v1).
- **Data:** [DC OCF](https://ocf.dc.gov/) for local races, [OpenFEC API](https://api.open.fec.gov/developers/) for federal, YouTube for video, X for social

## Focus: DC 2026

Rally starts at home. One city, one ballot, every contest — small enough to get right, real enough to matter.

| Election group | Office / contest | Candidates |
|---|---|---|
| **Federal** | U.S. House Delegate | Robert White (D) · Denise Rosado (R) · Kymone Freeman (Green) · Rebekkah Green (I, write-in) · David Solana (I, write-in) |
| **Federal** | U.S. Shadow Senator | Paul Strauss (D, incumbent) · Rob Simmons (R) |
| **Federal** | U.S. Shadow Representative | Franklin Garcia (D) · Ciprian Ivanof (R) |
| **District-wide executive** | Mayor | Janeese Lewis George (D) · Robert L. Gross (DC Statehood Green) · Rhonda Hamilton (I) |
| **District-wide executive** | Attorney General | Brian Schwalb (D, incumbent) · Manuel Rivera (R) |
| **District-wide legislative** | Council Chairman | Phil Mendelson (D, incumbent) · Abi-Ananiah Prudent (R) · John C. Cheeks (I, write-in) |
| **District-wide legislative** | Council At-Large | Elissa Silverman (I, incumbent) · Oye Owolewa (D) · Darrell Green (R) · Darryl Moch (Green) · Joe Jackson (I, write-in) |
| **Ward 1** | Councilmember | Aparna Raj (D) · Jett Jasper (R) · Jude Crannitch (Green) · Ryan Prince (I) |
| **Ward 3** | Councilmember | Matthew Frumin (D, incumbent) |
| **Ward 5** | Councilmember | Zachary Parker (D, incumbent) · Jeffrey Kihien-Palza (R) · Joyce Robinson-Paul (Green) |
| **Ward 6** | Councilmember | Charles Allen (D, incumbent) · Jorge Rice (R) |
| **Ward 1** | State Board of Education | Ben Williams (nonpartisan, incumbent) |
| **Ward 3** | State Board of Education | Eric Goulet (nonpartisan, incumbent) · Aaron Wesolowski (nonpartisan) |
| **Ward 5** | State Board of Education | Jon Alfuth (nonpartisan) |
| **Ward 6** | State Board of Education | Lynn Jennings · David Parker · Joshua Wiley · Amber Williams (all nonpartisan) |

### Where the money data lives

| Race type | Filings | Source |
|---|---|---|
| Delegate | Federal | [OpenFEC API](https://api.open.fec.gov/developers/) |
| Everything else (Mayor, AG, Council, SBOE, Shadow seats) | Local | [DC Office of Campaign Finance](https://ocf.dc.gov/) — contributions, expenditures, and the **Fair Elections Program** (who took public financing and swore off big donors) |

### How we group cards

Three options we're choosing between:

1. **Head-to-head** — opponents in one contest, side by side. *"Mayor: here's where each candidate's money comes from."* Sharpest contrast, most fun to scroll.
2. **By party** — every D, every R, every Green across the ballot. Shows patterns, loses the drama.
3. **By ward** — your ballot, your neighbors. Most personal.

Leaning **head-to-head** as the default feed, with party and ward as filters.

### Patient zero: Mayor

Open seat, crowded field, and the sharpest money contrast on the ballot — Fair Elections candidates vs. traditional fundraising, side by side. DC Council hearings, mayoral forums, and debates are already on YouTube. It's the most fun contest to scroll, so it's the one we build first.

Candidates: **Janeese Lewis George (D)** · **Robert L. Gross (DC Statehood Green)** · **Rhonda Hamilton (I)**

## Roadmap

- [ ] **Patient zero: Mayor** — every candidate, end to end. OCF filings + YouTube clips + X in, profiles and shorts out.
- [ ] Nobody ledger v1 — rule-based flagging + per-candidate totals
- [ ] The feed — scrollable cards with embedded clips
- [ ] Sector classification of donors (employer → industry)
- [ ] Timing view — donor flow vs. hearing and vote dates
- [ ] Every mic in the building

## Status

Day one. The app launches, says hello, and knows nothing yet.

---

*Democracy runs on promises. Rally keeps track of them.*
