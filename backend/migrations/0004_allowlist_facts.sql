-- v4: UI-agent decisions.
-- 1. allowed_accounts mirrors pipeline/accounts.json — the single authority
--    for account.kind. Handles not listed here are never crawled or served.
-- 2. facts gain category (bio|money|record|vote). My two bio-overlapping rows
--    go away; bio comes from pipeline/wikipedia.py (seeded in 0005).
-- 3. portraits table mirrors data/portraits + data/facts.json portrait objects.
--    Binaries stay bundled in the app; we serve metadata only.

CREATE TABLE IF NOT EXISTS allowed_accounts (
  platform TEXT NOT NULL CHECK (platform IN ('bluesky', 'x')),
  handle TEXT NOT NULL,
  candidate TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('official', 'personal')),
  note TEXT,
  PRIMARY KEY (platform, handle)
);

INSERT OR IGNORE INTO allowed_accounts (platform, handle, candidate, kind, note) VALUES
('bluesky', 'robertwhitedc.bsky.social', 'Robert White', 'official', 'Council office account. Taxpayer-funded government comms, not campaign.'),
('x', 'RobertWhite_DC', 'Robert White', 'personal', 'Personal / campaign account.'),
('x', 'CMRobertWhiteDC', 'Robert White', 'official', 'Council office account.');

ALTER TABLE facts ADD COLUMN category TEXT;
UPDATE facts SET category = 'money' WHERE id = 1;
UPDATE facts SET category = 'vote' WHERE id = 2;
UPDATE facts SET category = 'record' WHERE id IN (3, 6, 8);
UPDATE facts SET category = 'vote' WHERE id = 7;
DELETE FROM facts WHERE id IN (4, 5);

CREATE TABLE IF NOT EXISTS portraits (
  candidate TEXT PRIMARY KEY,
  file TEXT NOT NULL,
  source TEXT NOT NULL,
  license TEXT NOT NULL,
  credit TEXT NOT NULL,
  page TEXT NOT NULL
);

INSERT OR IGNORE INTO portraits (candidate, file, source, license, credit, page) VALUES
('Robert White',
 'robert-white.jpg',
 'https://upload.wikimedia.org/wikipedia/commons/0/0c/Member_of_the_Council_of_the_District_of_Columbia_Robert_C._White_Jr_%28cropped%29.jpg',
 'Public domain',
 'Council of the District of Columbia',
 'https://commons.wikimedia.org/wiki/File:Member_of_the_Council_of_the_District_of_Columbia_Robert_C._White_Jr_(cropped).jpg');
