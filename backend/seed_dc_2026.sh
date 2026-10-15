#!/usr/bin/env bash
# Registers every verified DC-2026 candidate on the live backend and crawls them.
#
#   npx wrangler login          # once — Jonathan's Cloudflare account
#   ./seed_dc_2026.sh
#
# What it does:
#   1. applies migrations/0008_dc_ballot_accounts.sql to remote D1
#      (allowed_accounts mirrors pipeline/accounts.json — the crawl allowlist)
#   2. POST /api/candidates for each candidate with a verified handle
#   3. POST /api/crawl — pulls Bluesky + X (logged-out profile → syndication)
#   4. prints /api/candidates so you can see post_count per candidate
set -euo pipefail
cd "$(dirname "$0")"

BASE="https://rally-backend.geraniumlabs.workers.dev"
UA="Mozilla/5.0 (Rally seed)"

echo "== 1. allowed_accounts migration =="
npx wrangler d1 execute rally-db --remote --file=migrations/0008_dc_ballot_accounts.sql

echo "== 2. register candidates =="
post() { echo "--- $1"; curl -sS -X POST "$BASE/api/candidates" \
  -H 'content-type: application/json' -A "$UA" -d "$2"; echo; }

post "Paul Strauss"        '{"name":"Paul Strauss","party":"democrat","office":"U.S. Shadow Senator","bsky_handle":"paulstrauss.bsky.social","x_handle":"SenPaulStrauss"}'
post "Franklin Garcia"     '{"name":"Franklin Garcia","party":"democrat","office":"U.S. Shadow Representative","x_handle":"FGarciaDC"}'
post "Robert L. Gross"     '{"name":"Robert L. Gross","party":"green","office":"Mayor","bsky_handle":"grossformayor.bsky.social","x_handle":"RLGforMayor"}'
post "Rhonda Hamilton"     '{"name":"Rhonda Hamilton","party":"independent","office":"Mayor","bsky_handle":"rhondahamilton4dc.bsky.social","x_handle":"Rhonda4DC"}'
post "Brian Schwalb"       '{"name":"Brian Schwalb","party":"democrat","office":"Attorney General","bsky_handle":"dcattorneygeneral.bsky.social","x_handle":"DCAttorneyGen"}'
post "Phil Mendelson"      '{"name":"Phil Mendelson","party":"democrat","office":"Council Chairman","bsky_handle":"chairmanmendelson.com","x_handle":"ChmnMendelson"}'
post "Elissa Silverman"    '{"name":"Elissa Silverman","party":"independent","office":"Council At-Large","bsky_handle":"elissasilverman.bsky.social","x_handle":"tweetelissa"}'
post "Oye Owolewa"         '{"name":"Oye Owolewa","party":"democrat","office":"Council At-Large","bsky_handle":"repoyedc.bsky.social","x_handle":"repoyedc","youtube":"@vote4oye"}'
post "Aparna Raj"          '{"name":"Aparna Raj","party":"democrat","office":"Councilmember — Ward 1","bsky_handle":"aparnafordc.bsky.social","x_handle":"AparnaForDC"}'
post "Matthew Frumin"      '{"name":"Matthew Frumin","party":"democrat","office":"Councilmember — Ward 3","bsky_handle":"mattfrumin.bsky.social","x_handle":"CMFrumin"}'
post "Zachary Parker"      '{"name":"Zachary Parker","party":"democrat","office":"Councilmember — Ward 5","bsky_handle":"cmzparker5.bsky.social","x_handle":"ZacharyforWard5"}'
post "Charles Allen"       '{"name":"Charles Allen","party":"democrat","office":"Councilmember — Ward 6","bsky_handle":"cmcharlesallen.bsky.social","x_handle":"charlesallen"}'
post "Eric Goulet"         '{"name":"Eric Goulet","party":"nonpartisan","office":"State Board of Education — Ward 3","bsky_handle":"ejgoulet.bsky.social"}'
post "Aaron Wesolowski"    '{"name":"Aaron Wesolowski","party":"nonpartisan","office":"State Board of Education — Ward 3","bsky_handle":"aaron4ward3sboe.bsky.social","x_handle":"Aaron4Ward3SBOE"}'
post "Denise Rosado"       '{"name":"Denise Rosado","party":"republican","office":"U.S. House Delegate","x_handle":"Rosado4Congress"}'
post "Kymone Freeman"      '{"name":"Kymone Freeman","party":"green","office":"U.S. House Delegate","x_handle":"guerillartist"}'
post "Ryan Prince"         '{"name":"Ryan Prince","party":"independent","office":"Councilmember — Ward 1","x_handle":"Prince4Ward1"}'
post "Ben Williams"        '{"name":"Ben Williams","party":"nonpartisan","office":"State Board of Education — Ward 1","x_handle":"BenWilliamsDC"}'
post "Joshua Wiley"        '{"name":"Joshua Wiley","party":"nonpartisan","office":"State Board of Education — Ward 6","x_handle":"whywiley"}'

echo "== 3. crawl =="
curl -sS -X POST "$BASE/api/crawl" -H 'content-type: application/json' -A "$UA" -d '{}'
echo

echo "== 4. resulting roster =="
curl -sS "$BASE/api/candidates" -A "$UA"
