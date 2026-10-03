-- v2: channels + committees. A channel (e.g. a YouTube channel) belongs to
-- exactly one owner: a candidate or a committee (PAC / super PAC / IEC / party).
-- Committee feed items attach to the linked candidate so support/oppose money
-- and voice stay queryable together.

CREATE TABLE IF NOT EXISTS committees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind IN ('candidate_committee', 'pac', 'super_pac', 'iec', 'party', 'other')),
  candidate_id INTEGER REFERENCES candidates(id),
  stance TEXT CHECK (stance IN ('support', 'oppose')),
  fec_id TEXT,
  ocf_name TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS channels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_key TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('youtube')),
  platform_id TEXT NOT NULL,
  label TEXT,
  role TEXT NOT NULL CHECK (role IN ('official', 'campaign', 'committee', 'personal', 'pac', 'iec', 'other')),
  candidate_id INTEGER REFERENCES candidates(id),
  committee_id INTEGER REFERENCES committees(id),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  CHECK (
    (candidate_id IS NOT NULL AND committee_id IS NULL) OR
    (candidate_id IS NULL AND committee_id IS NOT NULL)
  )
);

ALTER TABLE feed_items ADD COLUMN committee_id INTEGER REFERENCES committees(id);
ALTER TABLE feed_items ADD COLUMN channel_key TEXT;

-- Backfill: existing youtube rows came from White's committee channel.
UPDATE feed_items
SET channel_key = 'youtube:UCPJZbHhKFbnyGeQclJxQk0g'
WHERE source = 'youtube' AND channel_key IS NULL;

-- Move White's single channel into the channels table, then drop the column.
INSERT OR IGNORE INTO channels
  (channel_key, platform, platform_id, label, role, candidate_id)
SELECT
  'youtube:' || youtube_channel_id, 'youtube', youtube_channel_id,
  youtube_label, 'committee', id
FROM candidates WHERE youtube_channel_id IS NOT NULL;

-- Legacy single-channel columns stay parked (SQLite can't drop UNIQUE
-- columns); code reads channels table instead. Do not use them for new rows.

CREATE INDEX IF NOT EXISTS idx_channels_owner
  ON channels(candidate_id, committee_id);
CREATE INDEX IF NOT EXISTS idx_committees_candidate
  ON committees(candidate_id);
CREATE INDEX IF NOT EXISTS idx_feed_committee
  ON feed_items(committee_id);
