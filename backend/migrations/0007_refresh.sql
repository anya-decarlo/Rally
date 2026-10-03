-- v7: scheduled money refresh.
-- races: office -> election date drives cadence (weekly far out, daily inside
-- 30 days). facts gain fetched_at so the app can show staleness.
-- candidates gain fec_candidate_id for the FEC totals pull.

CREATE TABLE IF NOT EXISTS races (
  office TEXT PRIMARY KEY,
  election_date TEXT NOT NULL,
  scope TEXT NOT NULL DEFAULT 'general'
);

INSERT OR IGNORE INTO races (office, election_date, scope) VALUES
('U.S. House Delegate', '2026-11-03', 'general'),
('Mayor', '2026-11-03', 'general');

ALTER TABLE candidates ADD COLUMN fec_candidate_id TEXT;
ALTER TABLE facts ADD COLUMN fetched_at TEXT;
