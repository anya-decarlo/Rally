# Deploying the Rally backend

Target: Cloudflare Worker `rally-backend` + D1 `rally-db`, live at
`https://rally-backend.geraniumlabs.workers.dev`. No secrets required at any step.

## First time (new machine)

```sh
cd backend
npm install
npx wrangler login          # OAuth in browser; verify with: npx wrangler whoami
```

The repo pins the database: `database_id b136a854-…` in `wrangler.jsonc`. If you
ever recreate it, update that field with the new id.

## Every deploy

```sh
cd backend
npm run check                                    # tsc --noEmit, must be clean
npx wrangler d1 migrations apply rally-db --remote   # pending migrations only
npm run deploy                                   # deploys worker + both crons
```

Secrets (one time; values never touch chat, config, or git):

```sh
npx wrangler secret put FEC_API_KEY   # interactive prompt — paste, hit enter
```

Without it, the FEC leg reports `skipped` and everything else still works.

Verify:

```sh
curl -s https://rally-backend.geraniumlabs.workers.dev/api/health \
  -H "User-Agent: Mozilla/5.0"                  # {"ok":true}
npx wrangler tail                               # live logs, incl. cron runs
```

Deploy output shows a Version ID per release; the cron line confirms the
schedule armed.

## Seeding / operating

```sh
# add a candidate (handles validated live; Bluesky must be in accounts.json)
curl -X POST https://rally-backend.geraniumlabs.workers.dev/api/candidates \
  -H 'content-type: application/json' -H "User-Agent: Mozilla/5.0" \
  -d '{"name":"Janeese Lewis George","party":"Democrat","office":"Mayor"}'

# attach a channel, then crawl
curl -X POST .../api/channels -d '{"candidate_id":2,"platform":"youtube","input":"@handle","role":"official"}'
curl -X POST .../api/crawl -H 'content-type: application/json' -d '{}'
```

Direct DB reads (no deploy needed):

```sh
npx wrangler d1 execute rally-db --remote --json \
  --command "SELECT source, COUNT(*) FROM feed_items GROUP BY source"
```

## Rollback

```sh
npx wrangler versions list        # find the previous Version ID
npx wrangler rollback <VERSION_ID>
```

Migrations are forward-only (never edit an applied file); a bad data migration
gets a new fixing migration, same as 0006 did.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `403 Forbidden` from curl/wget/Python | Bot management blocks non-browser UAs — add `-H "User-Agent: Mozilla/5.0"`. `URLSession` in the app is unaffected. |
| `429` from Bluesky/FEC pulls | Rate-limited, not broken. Back off; cron spacing (:15) avoids self-inflicted limits. |
| `wrangler: command not found` | It's local: `backend/node_modules/.bin/`. Use `npx wrangler` from `backend/`. |
| `database_id` mismatch / D1 404 | Config id doesn't match the account's DB — `npx wrangler d1 list` and update `wrangler.jsonc`. |
| Cron not firing | Check `npx wrangler tail` at :15; confirm `triggers.crons` in `wrangler.jsonc` and the `schedule:` line in deploy output. |
| Remote vs local drift | `npm run dev` uses a **local** D1 (empty until seeded). Remote state is separate — always pass `--remote` for prod reads/writes. |
