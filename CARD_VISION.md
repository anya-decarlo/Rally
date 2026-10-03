# The Card — a brief for whoever builds it next

You're getting creative freedom on the most important object in Rally: **the candidate card.** This doc tells you what we know, what we believe, and where the walls are. Everything inside the walls is yours.

Read `README.md` first for the ethos. Read `DATA_SOURCES.md` for where the facts come from. Then come back here.

---

## What Rally is, in one breath

A social network for politicians where they don't get to post. Every candidate on the DC 2026 ballot gets a profile; the content is generated from their campaign-finance filings, video of them speaking, and their own X posts. Scroll it like TikTok. Trust it like a receipt.

The app shell exists (a "where do you vote?" home page → the ballot as swipeable stories → tap a candidate). Right now, tapping a candidate shows a name, a party, and an honest "nothing loaded yet." **Your job is what appears when the data arrives.**

## The worked example: Robert White

Robert White (D) is running for **U.S. House Delegate** — DC's non-voting seat in Congress. He's the first candidate in the app (first story, first card). Use him as the test subject because he's an interesting case:

- He's a **federal** candidate, so his money is in **FEC** filings, not DC OCF. Different schema, different quirks than the rest of the ballot.
- He's a sitting **At-Large DC Councilmember**, so he has years of **DC Council hearing footage** on YouTube and a **legislative voting record** in the Council's database.
- He ran for **Mayor in 2022** — so there's a prior-cycle paper trail and debate footage.
- He's active on **X**.

In other words: he has every kind of data we care about. If a card design works for him, it works for everyone.

## What a card might hold

Not a spec. A menu. Pick, combine, invent.

**Identity** — name, party, office sought, current office, ward, photo (public/official), the one-line "who is this."

**Money** — total raised, total spent, donor count, average donation, top employers/sectors, PAC vs. individual, in-DC vs. out-of-DC donors, biggest single check, Fair Elections status (for local races), spending by category (ads, staff, consultants). How much is left.

**Nobody** — the ledger of transactions with blank, vague, or incomplete payee/donor fields (`MISC`, `VARIOUS`, `INFORMATION REQUESTED`, empty). Total it. Show it. Don't explain it away and don't accuse — just: *this much money has no name attached in the filing.*

**Voice** — clips from hearings, forums, debates; transcribed, timestamped, cut into shorts. Their X posts. Quotes that are *checkable*: a promise, a number, a position.

**Receipts** — the join. A quote next to the money that's relevant to it. *"I've never taken a dollar from X"* next to what the filings say about X. The user draws the conclusion; the card just puts the two facts side by side.

**Record** — for sitting officials: votes, bills sponsored, committee seats, attendance. What they actually did.

**Time** — when the money came in vs. when they said things vs. when they voted. Timelines are underrated.

**Contrast** — how they compare to their opponents in the same contest, on anything above.

**Fun** — stickers, scores, streaks, badges, superlatives ("Most small-donor funded on the ballot"), anything that makes a 19-year-old want to tap the next one. Earn it with real data; never fake it.

## The walls

These are not negotiable. Everything else is.

1. **Every number links to its filing. Every quote links to its clip or post.** A fact the user can't tap through to verify doesn't ship.
2. **No accusations.** Rally never says "bought," "corrupt," "owned by." It shows the promise, the money, the vote. The user draws the line. Tone: receipts, not takes.
3. **Same treatment for everyone.** Whatever you build for Robert White renders identically for every other candidate, every party. If a feature only makes one person look bad, it's a bug.
4. **Blank ≠ hiding.** A missing field in a filing means the data is incomplete. Say that. Don't imply intent.
5. **X is the only outside social platform.** One source, applied to everyone equally.
6. **No fake data in the app.** Prototype with mock data all you want — but label it `MOCK` loudly, and the app ships with nothing invented.
7. **It has to be fun.** Hyperpop, serotonin, awe. If it feels like a government website or a research PDF, it's wrong. Look at `StoriesView.swift` and `HomeView.swift` for the energy: lava-lamp gradients, glass, glow, cards that breathe.

## What we don't know yet

Honestly: a lot. We haven't pulled a single filing into the app. The Mayor race (OCF data) is being worked on in parallel. Nobody has touched FEC for Robert White. There are no clips yet. The card is a blank canvas with a very strong vibe.

So: **don't wait for the data to be perfect to design the card.** Design the card that makes us want to go get the data.

## Deliverable

Open. Could be any of:

- A design doc or mockups for the card (and the profile it expands into)
- A JSON schema for what a fully-loaded candidate looks like
- A SwiftUI prototype against clearly-labeled mock data
- A data-pull script for Robert White's FEC filings that outputs that JSON
- Something we haven't thought of

Pick the thing you're best at. Surprise us.

---

*Democracy runs on promises. Rally keeps track of them.*
