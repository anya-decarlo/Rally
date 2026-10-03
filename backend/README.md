# Rally backend (Cloudflare Worker)

Social feed API for the iPhone app. Contract: `schema/feed.schema.json`.

## Sources

| Source | How | Key? |
|---|---|---|
| Bluesky | Public AppView (`public.api.bsky.app`), 3 pages × 100, reposts skipped | No |
| YouTube | `@handle` → channel ID scrape → channel RSS (15 latest) | No |
| X | Handle stored at request time; crawl **pending** until X access is decided | — |

## Routes

- `GET /api/health`
- `GET /api/candidates` — all tracked candidates + counts
- `POST /api/candidates` — `{name, party?, office?, bsky_handle?, youtube? (@handle or channel id), x_handle?}`. Handles validated live (422 if unknown).
- `GET /api/candidates/:id/feed?limit=&before=&source=&committees=` — newest-first feed items. `committees=support|oppose|all` folds linked PAC/IEC voice into the candidate's feed.
- `POST /api/crawl` — `{candidate_id?, committee_id?, sources?}`. Empty body = everyone, everything.
- `GET /rally/posts.json` — app contract shape (`pipeline/schema.md`): own posts only, rkey ids, media/quoted/avatar/kind captured.
- `GET /rally/facts.json` — curated `{text, source, url}` facts per candidate.
- `GET /rally/videos.json` — human-verified clips ONLY. Crawlers never write here.
- `GET /api/committees` · `POST /api/committees` — `{name, kind: pac|super_pac|iec|…, candidate_id?, stance: support|oppose, fec_id?, ocf_name?}`. Committees attach to a candidate; their items carry both ids.
- `POST /api/channels` — `{candidate_id|XOR committee_id, platform: 'youtube', input (@handle or channel id), label?, role?}`. One channel, exactly one owner.
- Cron `15 * * * *` — crawls all candidates, all available sources.

## Local dev

```sh
npm install
npm run dev      # wrangler dev, local D1
npm run check    # tsc --noEmit
```

First deploy needs login + DB (DB auto-provisions from `database_name`):

```sh
wrangler login
wrangler d1 migrations apply rally-db --remote
wrangler deploy
```

Seed example:

```sh
curl -X POST localhost:8787/api/candidates \
  -H 'content-type: application/json' \
  -d '{"name":"Robert White","party":"Democrat","office":"U.S. House Delegate","bsky_handle":"RobertWhiteDC.bsky.social"}'
curl -X POST localhost:8787/api/crawl -H 'content-type: application/json' -d '{}'
```
