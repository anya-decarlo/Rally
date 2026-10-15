// Source fetchers: Bluesky (public AppView, keyless) + YouTube (channel RSS,
// keyless) + X (logged-out profile page → syndication embed, keyless).
// Each fetcher returns normalized items matching schema/feed.schema.json.

export type Source = "bluesky" | "youtube" | "x";

export interface NormalizedItem {
  source: Source;
  source_id: string;
  url: string;
  author_handle: string;
  title: string | null;
  text: string;
  created_at: string;
  like_count: number;
  repost_count: number;
  reply_count: number;
  view_count: number | null;
  thumb_url: string | null;
  extra?: { media: BskyMedia[]; quoted: BskyQuoted | null };
}

export interface CandidateInput {
  id: number;
  name: string;
  bsky_handle: string | null;
  bsky_did: string | null;
  bsky_kind: string | null;
  youtube_channel_id: string | null;
  x_handle: string | null;
}

export interface BskyMedia {
  type: string;
  url?: string | null;
  thumb?: string | null;
  alt?: string | null;
  title?: string | null;
}

export interface BskyQuoted {
  handle: string;
  text: string;
  url: string;
}

export interface BskyProfile {
  did: string;
  handle: string;
  displayName?: string;
  avatar?: string;
}

const BSKY_PUBLIC = "https://public.api.bsky.app/xrpc";
const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36";

async function getJson<T>(url: string, headers?: Record<string, string>): Promise<T> {
  const res = await fetch(url, { headers: { accept: "application/json", ...headers } });
  if (!res.ok) throw new Error(`GET ${url} -> ${res.status}`);
  return (await res.json()) as T;
}

export async function resolveBlueskyProfile(handle: string): Promise<BskyProfile> {
  const p = await getJson<BskyProfile>(
    `${BSKY_PUBLIC}/app.bsky.actor.getProfile?actor=${encodeURIComponent(handle)}`,
  );
  if (!p.did) throw new Error("profile not found");
  return p;
}

function rkey(uri: string): string {
  return uri.split("/").pop() ?? uri;
}

function mediaFrom(embed: any): { media: BskyMedia[]; quoted: BskyQuoted | null } {
  if (!embed || typeof embed.$type !== "string") return { media: [], quoted: null };
  const t: string = embed.$type;
  if (t.startsWith("app.bsky.embed.images")) {
    return {
      media: (embed.images ?? []).map((i: any) => ({
        type: "image",
        url: i.fullsize ?? null,
        thumb: i.thumb ?? null,
        alt: i.alt ?? null,
      })),
      quoted: null,
    };
  }
  if (t.startsWith("app.bsky.embed.video")) {
    return {
      media: [{ type: "video", url: embed.playlist ?? null, thumb: embed.thumbnail ?? null, alt: embed.alt ?? null }],
      quoted: null,
    };
  }
  if (t.startsWith("app.bsky.embed.external")) {
    const ext = embed.external ?? {};
    return {
      media: [{ type: "link", url: ext.uri ?? null, title: ext.title ?? null, thumb: ext.thumb ?? null }],
      quoted: null,
    };
  }
  if (t.startsWith("app.bsky.embed.record")) {
    let rec = embed.record ?? {};
    let media: BskyMedia[] = [];
    if (embed.media) {
      const inner = mediaFrom(embed.media);
      media = inner.media;
      rec = rec.record ?? rec;
    }
    if (typeof rec.$type === "string" && rec.$type.endsWith("viewRecord") && rec.author) {
      return {
        media,
        quoted: {
          handle: rec.author.handle,
          text: rec.value?.text ?? "",
          url: `https://bsky.app/profile/${rec.author.handle}/post/${rkey(rec.uri)}`,
        },
      };
    }
    return { media, quoted: null };
  }
  return { media: [], quoted: null };
}

export interface BlueskyResult {
  items: NormalizedItem[];
  profile: BskyProfile;
}

export async function fetchBluesky(
  handle: string,
  did: string | null,
  pages = 3,
): Promise<BlueskyResult> {
  const profile = await resolveBlueskyProfile(handle);
  const out: NormalizedItem[] = [];
  let cursor: string | undefined;
  for (let i = 0; i < pages; i++) {
    const params = new URLSearchParams({ actor: handle, limit: "100", filter: "posts_no_replies" });
    if (cursor) params.set("cursor", cursor);
    const feed = await getJson<{
      feed: Array<{
        post: {
          uri: string;
          cid: string;
          author: { did: string; handle: string };
          record: { text?: string; createdAt?: string };
          embed?: unknown;
          indexedAt?: string;
          likeCount?: number;
          repostCount?: number;
          replyCount?: number;
        };
        reason?: { $type?: string };
      }>;
      cursor?: string;
    }>(`${BSKY_PUBLIC}/app.bsky.feed.getAuthorFeed?${params}`);
    if (feed.feed.length === 0) break;
    for (const item of feed.feed) {
      // Contract: only the account's own posts. No replies, no reposts of others.
      if (item.reason) continue;
      if (item.post.author.handle !== profile.handle) continue;
      if (did && item.post.author.did !== did) continue;
      const { media, quoted } = mediaFrom(item.post.embed);
      const key = rkey(item.post.uri);
      out.push({
        source: "bluesky",
        source_id: key,
        url: `https://bsky.app/profile/${profile.handle}/post/${key}`,
        author_handle: profile.handle,
        title: null,
        text: item.post.record.text ?? "",
        created_at: item.post.record.createdAt ?? item.post.indexedAt ?? "",
        like_count: item.post.likeCount ?? 0,
        repost_count: item.post.repostCount ?? 0,
        reply_count: item.post.replyCount ?? 0,
        view_count: null,
        thumb_url: null,
        extra: { media, quoted },
      });
    }
    cursor = feed.cursor;
    if (!cursor) break;
  }
  return { items: out, profile };
}

function unescapeXml(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&");
}

function pick(block: string, re: RegExp): string | null {
  const m = block.match(re);
  return m?.[1] ? unescapeXml(m[1]) : null;
}

// --- X -------------------------------------------------------------

const SYND = "https://cdn.syndication.twimg.com/tweet-result";

function syndicationToken(tweetId: string): string {
  // The embed widget's anti-abuse token: (id / 1e15 * π) rendered in base 36,
  // zeros stripped. Same math as pipeline/x.py.
  const n = (Number(tweetId) / 1e15) * Math.PI;
  const digits = "0123456789abcdefghijklmnopqrstuvwxyz";
  let i = Math.floor(n);
  let frac = n - i;
  let s = "";
  while (i) {
    s = digits[i % 36] + s;
    i = Math.floor(i / 36);
  }
  for (let k = 0; k < 10; k++) {
    frac *= 36;
    const d = Math.floor(frac);
    frac -= d;
    s += digits[d];
  }
  return s.replace(/0/g, "");
}

function xMedia(t: any): BskyMedia[] {
  const media: BskyMedia[] = [];
  for (const m of t.mediaDetails ?? []) {
    if (m.type === "photo") {
      media.push({ type: "image", url: m.media_url_https ?? null, thumb: m.media_url_https ?? null, alt: m.ext_alt_text || null });
    } else if (m.type === "video" || m.type === "animated_gif") {
      const vs = ((m.video_info?.variants ?? []) as any[])
        .filter((v) => v.content_type === "video/mp4")
        .sort((a, b) => (b.bitrate ?? 0) - (a.bitrate ?? 0));
      media.push({ type: "video", url: vs[0]?.url ?? null, thumb: m.media_url_https ?? null, alt: m.ext_alt_text || null });
    }
  }
  for (const u of t.entities?.urls ?? []) {
    media.push({ type: "link", url: u.expanded_url ?? null, title: null });
  }
  return media;
}

export interface XResult {
  items: NormalizedItem[];
  profile: { name?: string; avatar?: string };
}

export async function fetchXTimeline(handle: string): Promise<XResult> {
  // The logged-out profile page is server-rendered with the ~5 newest tweets
  // embedded. No auth. Bulk history is not available — run on the hourly cron
  // and feed_items' INSERT OR IGNORE accumulates over time.
  const res = await fetch(`https://x.com/${encodeURIComponent(handle)}`, {
    headers: { "user-agent": UA, accept: "text/html" },
  });
  if (!res.ok) throw new Error(`x profile -> ${res.status}`);
  const html = await res.text();
  const ids = [
    ...new Set(
      [...html.matchAll(new RegExp(`/${handle}/status/(\\d{10,})`, "gi"))]
        .map((m) => m[1])
        .filter((x): x is string => typeof x === "string"),
    ),
  ];
  const out: NormalizedItem[] = [];
  let profile: XResult["profile"] = {};
  for (const id of ids) {
    const q = new URLSearchParams({ id, token: syndicationToken(id), lang: "en" });
    const t = await getJson<any>(`${SYND}?${q}`, { "user-agent": UA });
    const user = t.user ?? {};
    if ((user.screen_name ?? "").toLowerCase() !== handle.toLowerCase()) continue;
    profile = { name: user.name, avatar: user.profile_image_url_https };
    let created = t.created_at ?? "";
    try {
      created = new Date(created).toISOString();
    } catch { /* keep raw */ }
    const quoted = t.quoted_tweet
      ? {
          handle: t.quoted_tweet.user?.screen_name ?? "",
          text: t.quoted_tweet.text ?? "",
          url: `https://x.com/${t.quoted_tweet.user?.screen_name}/status/${t.quoted_tweet.id_str}`,
        }
      : null;
    out.push({
      source: "x",
      source_id: t.id_str,
      url: `https://x.com/${user.screen_name}/status/${t.id_str}`,
      author_handle: user.screen_name,
      title: null,
      text: t.text ?? "",
      created_at: created,
      like_count: t.favorite_count ?? 0,
      repost_count: t.retweet_count ?? 0,
      reply_count: t.reply_count ?? t.conversation_count ?? 0,
      view_count: null,
      thumb_url: null,
      extra: { media: xMedia(t), quoted },
    });
  }
  return { items: out, profile };
}

export async function resolveYoutubeChannel(input: string): Promise<string> {
  // Already a channel id.
  if (/^UC[\w-]{22}$/.test(input)) return input;
  const handle = input.startsWith("@") ? input.slice(1) : input;
  // Try @handle page, then /c/ and /user/ legacy paths.
  for (const path of [`/@${handle}`, `/c/${handle}`, `/user/${handle}`]) {
    const res = await fetch(`https://www.youtube.com${path}`, {
      headers: { "user-agent": UA },
    });
    if (!res.ok) continue;
    const html = await res.text();
    const m = html.match(/\/channel\/(UC[\w-]{22})/);
    if (m?.[1]) return m[1];
  }
  throw new Error("youtube channel not found");
}

export async function fetchYoutube(channelId: string): Promise<NormalizedItem[]> {
  const res = await fetch(
    `https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`,
    { headers: { "user-agent": UA } },
  );
  if (!res.ok) throw new Error(`youtube RSS -> ${res.status}`);
  const xml = await res.text();
  const channelTitle = pick(xml, /<author>\s*<name>([\s\S]*?)<\/name>/) ?? "";
  const out: NormalizedItem[] = [];
  for (const block of xml.match(/<entry>[\s\S]*?<\/entry>/g) ?? []) {
    const videoId = pick(block, /<yt:videoId>([^<]+)<\/yt:videoId>/);
    const title = pick(block, /<title>([\s\S]*?)<\/title>/);
    const published = pick(block, /<published>([^<]+)<\/published>/);
    if (!videoId || !published) continue;
    const desc = pick(block, /<media:description>([\s\S]*?)<\/media:description>/);
    const thumb = pick(block, /<media:thumbnail[^>]*url="([^"]+)"/);
    out.push({
      source: "youtube",
      source_id: videoId,
      url: `https://www.youtube.com/watch?v=${videoId}`,
      author_handle: channelTitle,
      title,
      text: title && desc ? `${title}\n\n${desc.slice(0, 500)}` : (title ?? desc ?? ""),
      created_at: published,
      like_count: 0,
      repost_count: 0,
      reply_count: 0,
      view_count: null,
      thumb_url: thumb,
    });
  }
  return out;
}
