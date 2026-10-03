-- v9: votes, money, donors as first-class app data.
-- votes: one row per recorded vote (scorecard-sourced, bill-linked).
-- money: one row per candidate per source cycle snapshot (refresher-owned).
-- donors: itemized rows, feed-shaped (newest-first, dedupe on id).

CREATE TABLE IF NOT EXISTS votes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  candidate TEXT NOT NULL,
  bill TEXT NOT NULL,
  title TEXT NOT NULL,
  date TEXT,
  outcome TEXT,
  position TEXT NOT NULL,
  link TEXT,
  sort INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_votes_candidate ON votes(candidate, sort);

CREATE TABLE IF NOT EXISTS money (
  candidate TEXT NOT NULL,
  source TEXT NOT NULL,
  raised REAL,
  spent REAL,
  cash REAL,
  small_dollar REAL,
  public_funds REAL,
  donor_count INTEGER,
  as_of TEXT,
  fetched_at TEXT,
  url TEXT,
  PRIMARY KEY (candidate, source)
);

CREATE TABLE IF NOT EXISTS donors (
  id TEXT PRIMARY KEY,
  candidate TEXT NOT NULL,
  donor TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT,
  employer TEXT,
  occupation TEXT,
  committee TEXT,
  source TEXT NOT NULL,
  url TEXT,
  fetched_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_donors_candidate
  ON donors(candidate, amount DESC);
