-- Rally backend schema: candidates + unified social feed items.
-- One row per item per source; dedupe on id ('<source>:<source_id>').

CREATE TABLE IF NOT EXISTS candidates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  party TEXT,
  office TEXT,
  bsky_handle TEXT UNIQUE,
  bsky_did TEXT,
  youtube_channel_id TEXT UNIQUE,
  youtube_label TEXT,
  x_handle TEXT UNIQUE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE IF NOT EXISTS feed_items (
  id TEXT PRIMARY KEY,
  candidate_id INTEGER NOT NULL REFERENCES candidates(id),
  source TEXT NOT NULL CHECK (source IN ('bluesky', 'youtube', 'x')),
  source_id TEXT NOT NULL,
  url TEXT NOT NULL,
  author_handle TEXT NOT NULL DEFAULT '',
  title TEXT,
  text TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  like_count INTEGER NOT NULL DEFAULT 0,
  repost_count INTEGER NOT NULL DEFAULT 0,
  reply_count INTEGER NOT NULL DEFAULT 0,
  view_count INTEGER,
  thumb_url TEXT,
  fetched_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_feed_candidate_time
  ON feed_items(candidate_id, created_at DESC);
