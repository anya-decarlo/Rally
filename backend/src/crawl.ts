// Source fetchers: Bluesky (public AppView, keyless) + YouTube (channel RSS,
// keyless). X has no keyless path — handled as pending until access is decided.
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
