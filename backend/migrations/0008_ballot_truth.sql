-- v8: ballot as source of truth. wikipedia_title comes free with the ballot
-- entry (used by the bio refresh). allowed_accounts stays parked: upstream
-- accounts.json is now read live from the repo on every crawl/intake, so no
-- redeploy is ever needed for a new candidate. Do not add rows here.

ALTER TABLE candidates ADD COLUMN wikipedia_title TEXT;

UPDATE candidates
SET wikipedia_title = 'Robert_White_(Washington,_D.C._politician)'
WHERE name = 'Robert White' AND wikipedia_title IS NULL;
