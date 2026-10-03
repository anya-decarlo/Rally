-- v3: app-contract compliance (pipeline/schema.md).
-- New capture columns; purge pre-contract Bluesky rows (full-at-uri ids,
-- replies kept) for a clean re-crawl under the contract rules.
-- Plus human-curated facts + clips tables (clips NEVER populated by crawlers).

ALTER TABLE feed_items ADD COLUMN display_name TEXT;
ALTER TABLE feed_items ADD COLUMN avatar TEXT;
ALTER TABLE feed_items ADD COLUMN kind TEXT;
ALTER TABLE feed_items ADD COLUMN media_json TEXT;
ALTER TABLE feed_items ADD COLUMN quoted_json TEXT;
ALTER TABLE candidates ADD COLUMN bsky_kind TEXT;

DELETE FROM feed_items WHERE source = 'bluesky';

CREATE TABLE IF NOT EXISTS facts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  candidate TEXT NOT NULL,
  text TEXT NOT NULL,
  source TEXT NOT NULL,
  url TEXT NOT NULL,
  sort INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_facts_candidate ON facts(candidate, sort);

CREATE TABLE IF NOT EXISTS clips (
  id TEXT PRIMARY KEY,
  candidate TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'youtube',
  title TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT '',
  channel_url TEXT,
  published_at TEXT,
  duration INTEGER,
  thumb TEXT,
  url TEXT NOT NULL,
  embed_url TEXT NOT NULL,
  verified_by TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_clips_candidate ON clips(candidate);

-- Seed facts: every row verified this session, each with its source link.
INSERT OR IGNORE INTO facts (id, candidate, text, source, url, sort) VALUES
(1, 'Robert White', 'Raised $826,537 and spent $791,773 for the 2026 Delegate race through June 30, 2026 ($601,561 itemized, $114,475 small-dollar).', 'FEC', 'https://www.fec.gov/data/candidate/H6DC01079/?cycle=2026', 1),
(2, 'Robert White', 'Won the June 16, 2026 Democratic primary for Delegate with 63.6% (86,871 votes) over Brooke Pinto''s 20.9% — the first new delegate in 36 years.', 'AP via Wikipedia', 'https://en.wikipedia.org/wiki/2026_United_States_House_of_Representatives_election_in_the_District_of_Columbia', 2),
(3, 'Robert White', 'At-Large member of the DC Council since September 2016 (third term); chairs the Committee on Housing since 2023.', 'DC Council', 'https://dccouncil.gov/council/councilmember-robert-c-white-jr/', 3),
(4, 'Robert White', 'From 2008 to 2013, he was legislative counsel to Delegate Eleanor Holmes Norton — whose seat he is now taking.', 'Wikipedia', 'https://en.wikipedia.org/wiki/Robert_White_(Washington,_D.C.,_politician)', 4),
(5, 'Robert White', 'Ran At-Large as an Independent in 2014 (6%, 22,198 votes), ran for Mayor in 2022 and lost, then won the 2026 Delegate primary.', 'Wikipedia', 'https://en.wikipedia.org/wiki/Robert_White_(Washington,_D.C.,_politician)', 5),
(6, 'Robert White', 'Unveiled the “Defend DC” plan (Aug 2026): send DC residents to canvass in battleground House districts against anti-Home-Rule members, plus a PAC for pro-statehood candidates.', 'AP', 'https://www.pressdemocrat.com/2026/08/25/dc-delegate-politics', 6),
(7, 'Robert White', 'Scores 86% (12 of 14) on the JUFJ Campaign Fund Council scorecard; broke with it twice: the 2021 COVID hero-pay vote and the 2022 DCHA board vote.', 'JUFJ Campaign Fund', 'https://www.dccouncil.org/mems/robert-white', 7),
(8, 'Robert White', 'As Housing chair: DCHA Stabilization & Reform, +$24.5M for affordable housing, +$6.7M in emergency rental assistance.', '2025 Annual Report', 'https://www.robertwhiteatlarge.com/wp-content/uploads/2026/03/Annual-Report-2025.pdf', 8);

-- Seed clips: the two human-verified WUSA9 entries from data/videos.json.
INSERT OR IGNORE INTO clips
  (id, candidate, platform, title, channel, channel_url, published_at, duration, thumb, url, embed_url, verified_by)
VALUES
('youtube:DPLYY53XbuE', 'Robert White', 'youtube', 'DC Delegate Candidate Robert White on The DC Beat', 'WUSA9', 'https://www.youtube.com/channel/UCcT6w3xUyVshyR2_2vrMp1w', '2026-02-12', 42, 'https://i.ytimg.com/vi/DPLYY53XbuE/hqdefault.jpg', 'https://www.youtube.com/watch?v=DPLYY53XbuE', 'https://www.youtube-nocookie.com/embed/DPLYY53XbuE?playsinline=1&rel=0', 'human'),
('youtube:8JVFI_RgLLk', 'Robert White', 'youtube', 'Councilmember Robert White criticizes DC mayor''s response to federal surge', 'WUSA9', 'https://www.youtube.com/channel/UCcT6w3xUyVshyR2_2vrMp1w', '2025-08-28', 135, 'https://i.ytimg.com/vi/8JVFI_RgLLk/hqdefault.jpg', 'https://www.youtube.com/watch?v=8JVFI_RgLLk', 'https://www.youtube-nocookie.com/embed/8JVFI_RgLLk?playsinline=1&rel=0', 'human');
