# posts.json — the contract

Every social fetcher (Bluesky, X, whatever comes next) emits this exact shape. The app reads only this. Adding a platform = one new fetcher, zero app changes.

```jsonc
{
  "generatedAt": "2026-10-03T18:00:00Z",
  "posts": [
    {
      "id": "bluesky:3m6fjgzpzyk2x",          // "<platform>:<platform-native id>", globally unique
      "platform": "bluesky",                   // "bluesky" | "x"
      "candidate": "Robert White",             // matches Candidate.name in Ballot.swift
      "account": {
        "handle": "robertwhitedc.bsky.social",
        "displayName": "At-Large Councilmember Robert White",
        "avatar": "https://...",               // may be null
        "kind": "official"                     // "official" (gov office) | "personal" (campaign/self)
      },
      "text": "…",
      "createdAt": "2025-11-24T19:05:50Z",     // ISO 8601, UTC
      "url": "https://bsky.app/profile/robertwhitedc.bsky.social/post/3m6fjgzpzyk2x",
      "media": [
        { "type": "image", "url": "https://...", "thumb": "https://...", "alt": "…" },
        { "type": "video", "url": "https://.../playlist.m3u8", "thumb": "https://...", "alt": "…" },
        { "type": "link",  "url": "https://...", "title": "…", "thumb": "https://..." }
      ],
      "metrics": { "likes": 7, "reposts": 1, "replies": 0 },
      "quoted": {                               // present only if this post quotes another
        "handle": "dcattorneygeneral.bsky.social",
        "text": "…",
        "url": "https://bsky.app/profile/.../post/..."
      }
    }
  ]
}
```

## Rules

- **Only the account's own posts.** No replies, no reposts of others. (Quote-posts are kept — the candidate wrote words.)
- **`url` always resolves to the original post** on the platform. Every card in the app links out to it.
- **`kind` is required.** Official-office vs. personal-campaign is a distinction voters care about; the app shows it.
- **Nothing is rewritten.** `text` is verbatim. Fetchers normalize *structure*, never *content*.
- Posts are sorted newest-first. Re-running a fetcher merges by `id`; it never duplicates and never deletes.
