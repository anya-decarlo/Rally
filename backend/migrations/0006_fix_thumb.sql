-- v6: align clip thumb byte-for-byte with data/videos.json in the Rally repo.
UPDATE clips
SET thumb = 'https://i.ytimg.com/vi/DPLYY53XbuE/hq720_2.jpg?sqp=-oaymwEoCIAKENAF8quKqQMcGADwAQH4AbYIgAKAD4oCDAgAEAEYWSBNKGUwDw==&rs=AOn4CLCpA_4TmWBBhMgrlo80tMbLF5yvxQ'
WHERE id = 'youtube:DPLYY53XbuE';
