# Rally backend API — for iOS devs

Base: `https://rally-backend.geraniumlabs.workers.dev`
Auth: none. Format: JSON, UTF-8. One rule: send a browser `User-Agent`
(`URLSession` is fine as-is); bare `curl`/stdlib UAs get a 403 from edge bot
management.

## App files (fetch on launch, cache locally, remote is authoritative)

These are the only routes the app needs. All carry `generatedAt` (ISO-8601).

| Route | Shape | Keying |
|---|---|---|
| `GET /rally/posts.json` | `{generatedAt, posts[]}` — `id` (`<platform>:<native>`), `platform`, `candidate`, `account{handle,displayName,avatar,kind}`, `text` verbatim, `createdAt`, `url`, `media[]`, `metrics{likes,reposts,replies}`, optional `quoted` | Filter client-side by `candidate` (ballot-exact name) |
| `GET /rally/facts.json` | `{generatedAt, candidates: {name: {facts[{text,source,url,category?}], portrait?}}}` | Dictionary key = ballot-exact name. `category`: `bio`/`money`/`record`/`vote`. `fetchedAt` on refreshed rows = staleness label. Portrait is metadata only; image stays bundled |
| `GET /rally/videos.json` | `{generatedAt, videos: {name: [clips]}}` | Human-verified only (`verifiedBy: "human"`). Byte-mirrors the repo file |
| `GET /rally/votes.json` | `{generatedAt, votes: {name: [{bill,title,date,outcome,position,link}]}}` | `position` = their vote; `outcome` = what the bill did |
| `GET /rally/money.json` | `{generatedAt, money: {name: [{source,raised,spent,cash,smallDollar,publicFunds,donorCount,asOf,fetchedAt,url}]}}` | One entry per source (FEC / Fair Elections). Nulls where the source gives nothing — never zero-filled |
| `GET /rally/donors.json?candidate=&limit=&before=` | `{generatedAt, donors[]}` — `id`, `candidate`, `donor`, `amount`, `date`, `employer`, `occupation`, `committee`, `source`, `url` | Feed-shaped: newest-first, `limit` (1–100, default 20), `before=<ISO date>` pages back. Shown as-filed |

## Working API (seeding, debugging, future use)

- `GET /api/health` → `{"ok":true}`
- `GET /api/candidates` — tracked candidates + `post_count`, `channel_count`, `committee_count`, `latest_item`
- `POST /api/candidates` — start tracking. `{name (ballot-exact, required), bsky_handle?, youtube? (@handle or channel id), x_handle?}`. Office/party/wikipedia auto-fill from the ballot; handles must be listed in `accounts.json` for that candidate. `201` / `422` (bad name/handle) / `409` (dup).
- `GET /api/candidates/:id/feed?limit=&before=&source=&committees=` — raw feed incl. YouTube; `committees=support|oppose|all` folds linked PAC/IEC voice in
- `GET /api/committees` · `POST /api/committees` — `{name, kind: pac|super_pac|iec|…, candidate_id?, stance: support|oppose, fec_id?, ocf_name?}`
- `POST /api/channels` — attach a channel to exactly one candidate or committee
- `GET /api/committees/:id/feed`
- `POST /api/crawl` — `{candidate_id?, committee_id?, sources?}`; empty body = everything
- `POST /api/refresh/money` — `{candidate_id?}`; refresh money facts now (bypasses cadence)

## Freshness

- Social: hourly cron. Money: daily cron, weekly far out / daily inside 30 days to the race. Votes/bio/clips: manual. Every refreshed fact carries `fetchedAt`.

## Errors

`{error: "<message>"}` with HTTP `400` (bad input), `404` (unknown route/id), `409` (already tracked), `422` (unknown handle / off-ballot name), `502` (upstream ballot unreachable), `500` (bug — tell backend).
