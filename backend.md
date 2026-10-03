# Rally backend — what's in place and how it works

Live at `https://rally-backend.geraniumlabs.workers.dev` (hourly cron `:15`).
Source: `backend/` (Worker + D1 + migrations). No secrets anywhere in the stack.

## What it does

Turns candidates' public social posts into clean JSON for the iPhone app, and
holds the verified money/record/vote material the cards render. Three jobs:

1. **Crawl** — Bluesky + YouTube, hourly + on demand. X stored, crawl pending.
2. **Serve the app contract** — `/rally/posts.json`, `/rally/facts.json`,
   `/rally/videos.json` in the exact shapes `pipeline/schema.md` + the Swift
   decoders expect. Remote is authoritative; the app replaces bundled wholesale.
3. **Serve the working API** — `/api/*` for debugging, seeding, and future use.

## Data model (D1 `rally-db`)

- `candidates` — one row per person. Social identity lives here (Bluesky handle
  + DID, X handle). YouTube lives in `channels`, not here.
- `channels` — one channel, exactly one owner (DB-enforced CHECK): a candidate
  or a committee. White has 3 (committee hearings, campaign ads, personal).
- `committees` — PACs, super PACs, IECs, parties. Linked to a candidate with a
  `support`/`oppose` stance plus FEC/OCF ids. Their items carry both ids, so
  outside voice stays queryable with the candidate.
- `feed_items` — every crawled post/video, deduped on `source:source_id`.
  Carries account display data (name, avatar, kind), media/quoted JSON, counts.
- `allowed_accounts` — mirrors `pipeline/accounts.json`. The single authority
  for `account.kind`. Unlisted handles are never crawled or served, by code.
- `facts` — curated `{text, source, url, category}` rows: 85 bio (from a
  `pipeline/wikipedia.py` run) + money/record/vote from verified pulls.
- `clips` — human-verified videos ONLY. No crawler path writes here, by
  construction. Currently byte-matches `data/videos.json`.
- `portraits` — portrait metadata mirror (binaries stay bundled in the app).

Migrations `0001`–`0006` are the audit trail (schema, channels/committees,
contract columns + purge, allowlist/facts, bio seed, one thumb fix).

## Sources and their rules

| Source | How | Key? | Rule |
|---|---|---|---|
| Bluesky | Public AppView, `posts_no_replies` + author-match, 3 pages | No | Own posts only; rkey ids; embeds → media/quoted; profile per crawl |
| YouTube | `@handle` → channel scrape → channel RSS (15 latest) | No | Titles pass through; transcription is still offline work |
| X | None built — no keyless path exists | — | Handle stored; status honestly `pending`/`skipped` |

Edge note: our Cloudflare bot management 403s non-browser user-agents.
`URLSession` is fine; `curl`/`wget`/stdlib need a browser UA string.

## Routes

App contract: `GET /rally/posts.json`, `/rally/facts.json`, `/rally/videos.json`
(`application/json`, `generatedAt` included, newest-first).

Working API: `GET /api/health`, `GET /api/candidates`,
`POST /api/candidates` (validates handles live, allowlist-enforced, 422/409),
`GET /api/candidates/:id/feed` (`limit`, `before`, `source`,
`committees=support|oppose|all`), `GET/POST /api/committees`,
`POST /api/channels`, `GET /api/committees/:id/feed`, `POST /api/crawl`
(one / some / all). Full field contract: `backend/schema/feed.schema.json`.

## Verified live (2026-10-03)

- Candidate #1 (Robert White): **295 items** — 268→144 Bluesky own-posts after
  the reply purge + 27 YouTube across 3 channels. Diffed against the reference
  pipeline output: all 60 reference posts present, 84 deeper, zero missing.
- Facts: 91 (85 bio / 3 record / 2 vote / 1 money). Videos: 2/2 human.
- `tsc` clean, migrations validated in SQLite, `wrangler deploy --dry-run` green.

## Deliberately not built yet

- X crawling (blocked on access; schema-ready on both sides).
- Receipts (`/rally/receipts.json`) — design agreed (see conversation); needs
  donor industry-coding for type 1, transcripts for type 2.
- Jev-as-reviewer for claim-vs-filing receipts — proposal parked at
  `backend/proposals/jev-receipt-review.md`.
- Fun facts (`category: "fun"` + human gate) — discussed, unscoped.
- Transcription/timestamp pipeline for hearing footage (titles like "Live with
  Restream" carry no information until transcribed).

## Run it

```sh
cd backend && npm install
npm run dev      # local worker + local D1
npm run check    # typecheck
wrangler login && wrangler d1 migrations apply rally-db --remote && npm run deploy
```

Seed: `POST /api/candidates` → `POST /api/crawl` with `{}`. White is candidate 1;
Janeese (and linking Safe & Affordable DC to her) is the obvious seed 2.
