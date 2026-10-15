-- "Who wore it best" + future games. Anonymous votes — one row per vote,
-- no user/device identity. The client enforces one-vote-per-device.
CREATE TABLE IF NOT EXISTS faceoff_votes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  faceoff_id TEXT NOT NULL,
  look_id TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_faceoff_votes
  ON faceoff_votes(faceoff_id, look_id);
