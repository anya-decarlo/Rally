// Rally backend — routes for the iPhone app + crawl triggers.
// Sources: Bluesky (live), YouTube (live), X (stored, crawl pending).
// Ownership: a channel belongs to exactly one candidate or committee, so
// PAC / super PAC / IEC voice stays correlated with the money.
// Contract: schema/feed.schema.json.

import {
  fetchBluesky,
  fetchYoutube,
  resolveBlueskyProfile,
  resolveYoutubeChannel,
  type CandidateInput,
  type NormalizedItem,
  type Source,
} from "./crawl";

interface ChannelRow {
  id: number;
  channel_key: string;
  platform: string;
  platform_id: string;
  label: string | null;
  role: string;
  candidate_id: number | null;
  committee_id: number | null;
}

interface CommitteeRow {
  id: number;
  name: string;
  kind: string;
  candidate_id: number | null;
  stance: string | null;
}

interface SourceStatus {
  source: Source;
  status: "ok" | "skipped" | "pending" | "error";
  fetched: number;
  stored: number;
  note?: string;
}

const FEED_COLS = `id, candidate_id, committee_id, channel_key, source, source_id,
  url, author_handle, title, text, created_at, like_count, repost_count,
  reply_count, view_count, thumb_url, fetched_at`;

function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

function err(message: string, status = 500): Response {
  return json({ error: message }, status);
}

async function storeItems(
  env: Env,
  owner: { candidate_id: number; committee_id: number | null },
  channelKey: string | null,
  source: Source,
  items: NormalizedItem[],
  account?: { displayName?: string; avatar?: string; kind?: string },
): Promise<number> {
  const stmts = items.map((it) =>
    env.DB.prepare(
      `INSERT OR IGNORE INTO feed_items
        (id, candidate_id, committee_id, channel_key, source, source_id, url,
         author_handle, display_name, avatar, kind, title, text, created_at,
         like_count, repost_count, reply_count, view_count, thumb_url,
         media_json, quoted_json)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      `${source}:${it.source_id}`,
      owner.candidate_id,
      owner.committee_id,
      channelKey,
      source,
      it.source_id,
      it.url,
      it.author_handle,
      account?.displayName ?? null,
      account?.avatar ?? null,
      account?.kind ?? null,
      it.title,
      it.text,
      it.created_at,
      it.like_count,
      it.repost_count,
      it.reply_count,
      it.view_count,
      it.thumb_url,
      it.extra ? JSON.stringify(it.extra.media) : null,
      it.extra?.quoted ? JSON.stringify(it.extra.quoted) : null,
    ),
  );
  if (stmts.length === 0) return 0;
  const results = await env.DB.batch(stmts);
  return results.reduce((n, r) => n + (r.meta.changes ?? 0), 0);
}

async function crawlYoutubeChannels(
  env: Env,
  owner: { candidate_id: number; committee_id: number | null },
  channels: ChannelRow[],
): Promise<SourceStatus> {
  let fetched = 0;
  let stored = 0;
  let errors = 0;
  for (const ch of channels) {
    try {
      const items = await fetchYoutube(ch.platform_id);
      fetched += items.length;
      stored += await storeItems(env, owner, ch.channel_key, "youtube", items);
    } catch {
      errors++;
    }
  }
  if (channels.length === 0) {
    return { source: "youtube", status: "skipped", fetched: 0, stored: 0, note: "no channel" };
  }
  return {
    source: "youtube",
    status: errors === channels.length ? "error" : "ok",
    fetched,
    stored,
  };
}

async function getChannels(
  env: Env,
  owner: { candidate_id?: number; committee_id?: number },
): Promise<ChannelRow[]> {
  const { results } = await env.DB.prepare(
    `SELECT * FROM channels WHERE candidate_id IS ? AND committee_id IS ?`,
  )
    .bind(owner.candidate_id ?? null, owner.committee_id ?? null)
    .all<ChannelRow>();
  return results;
}

async function crawlCandidate(
  env: Env,
  c: CandidateInput,
  only?: Source[],
): Promise<{ candidate_id: number; sources: SourceStatus[] }> {
  const want = (s: Source): boolean => !only || only.includes(s);
  const sources: SourceStatus[] = [];

  if (want("bluesky") && c.bsky_handle) {
    // pipeline/accounts.json (mirrored in allowed_accounts) is the single
    // authority: unlisted handles are never crawled or served.
    const allowed = await env.DB.prepare(
      "SELECT kind FROM allowed_accounts WHERE platform = 'bluesky' AND handle = ?",
    )
      .bind(c.bsky_handle)
      .first<{ kind: string }>();
    if (!allowed) {
      sources.push({ source: "bluesky", status: "skipped", fetched: 0, stored: 0, note: "handle not in accounts.json" });
    } else {
      try {
        const { items, profile } = await fetchBluesky(c.bsky_handle, c.bsky_did);
        const stored = await storeItems(
          env,
          { candidate_id: c.id, committee_id: null },
          null,
          "bluesky",
          items,
          {
            displayName: profile.displayName,
            avatar: profile.avatar,
            kind: allowed.kind,
          },
        );
        sources.push({ source: "bluesky", status: "ok", fetched: items.length, stored });
      } catch (e) {
        sources.push({ source: "bluesky", status: "error", fetched: 0, stored: 0, note: String(e) });
      }
    }
  } else if (want("bluesky")) {
    sources.push({ source: "bluesky", status: "skipped", fetched: 0, stored: 0, note: "no handle" });
  }

  if (want("youtube")) {
    const channels = await getChannels(env, { candidate_id: c.id });
    sources.push(
      await crawlYoutubeChannels(env, { candidate_id: c.id, committee_id: null }, channels),
    );
  }

  if (want("x")) {
    sources.push({
      source: "x",
      status: c.x_handle ? "pending" : "skipped",
      fetched: 0,
      stored: 0,
      note: c.x_handle ? "handle stored — crawl pending X access decision" : "no handle",
    });
  }

  return { candidate_id: c.id, sources };
}

async function crawlCommittee(
  env: Env,
  c: CommitteeRow,
  only?: Source[],
): Promise<{ committee_id: number; sources: SourceStatus[] }> {
  const want = (s: Source): boolean => !only || only.includes(s);
  const sources: SourceStatus[] = [];
  if (want("youtube")) {
    const channels = await getChannels(env, { committee_id: c.id });
    // Committee items attach to the linked candidate so support/oppose
    // voice stays queryable with the candidate's own feed.
    const candidateId = c.candidate_id ?? -1;
    if (c.candidate_id == null) {
      sources.push({ source: "youtube", status: "skipped", fetched: 0, stored: 0, note: "committee not linked to a candidate" });
    } else {
      sources.push(
        await crawlYoutubeChannels(env, { candidate_id: candidateId, committee_id: c.id }, channels),
      );
    }
  }
  return { committee_id: c.id, sources };
}

async function handleFetch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const { pathname } = url;

  if (request.method === "GET" && pathname === "/api/health") {
    return json({ ok: true });
  }

  if (request.method === "GET" && pathname === "/api/candidates") {
    const { results } = await env.DB.prepare(
      `SELECT c.*,
        (SELECT COUNT(*) FROM feed_items f WHERE f.candidate_id = c.id AND f.committee_id IS NULL) AS post_count,
        (SELECT COUNT(*) FROM channels ch WHERE ch.candidate_id = c.id) AS channel_count,
        (SELECT COUNT(*) FROM committees k WHERE k.candidate_id = c.id) AS committee_count,
        (SELECT MAX(f.created_at) FROM feed_items f WHERE f.candidate_id = c.id) AS latest_item
       FROM candidates c ORDER BY c.id`,
    ).all();
    return json({ candidates: results });
  }

  if (request.method === "POST" && pathname === "/api/candidates") {
    let body: {
      name?: string;
      party?: string;
      office?: string;
      bsky_handle?: string;
      youtube?: string;
      youtube_role?: string;
      x_handle?: string;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return err("invalid JSON body", 400);
    }
    if (!body.name) return err("name is required", 400);
    if (!body.bsky_handle && !body.youtube && !body.x_handle) {
      return err("at least one source (bsky_handle, youtube, x_handle) is required", 400);
    }

    let did: string | null = null;
    let handle: string | null = null;
    let kind: string | null = null;
    if (body.bsky_handle) {
      try {
        const p = await resolveBlueskyProfile(body.bsky_handle);
        did = p.did;
        handle = p.handle;
      } catch {
        return err("bluesky handle not found", 422);
      }
      const allowed = await env.DB.prepare(
        "SELECT kind FROM allowed_accounts WHERE platform = 'bluesky' AND handle = ?",
      )
        .bind(handle)
        .first<{ kind: string }>();
      if (!allowed) return err("handle not in accounts.json — not served", 422);
      kind = allowed.kind;
    }

    let channelId: string | null = null;
    if (body.youtube) {
      try {
        channelId = await resolveYoutubeChannel(body.youtube);
      } catch {
        return err("youtube channel not found", 422);
      }
    }

    const bskyKind = kind ?? "personal";
    if (!["official", "personal"].includes(bskyKind)) {
      return err("bsky_kind must be official or personal", 400);
    }

    try {
      const row = await env.DB.prepare(
        `INSERT INTO candidates (name, party, office, bsky_handle, bsky_did, bsky_kind, x_handle)
         VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING *`,
      )
        .bind(body.name, body.party ?? null, body.office ?? null, handle, did, bskyKind, body.x_handle ?? null)
        .first();
      const candidateId = (row as { id: number }).id;
      if (channelId) {
        await env.DB.prepare(
          `INSERT OR IGNORE INTO channels
            (channel_key, platform, platform_id, label, role, candidate_id)
           VALUES (?, 'youtube', ?, ?, ?, ?)`,
        )
          .bind(
            `youtube:${channelId}`,
            channelId,
            body.youtube,
            body.youtube_role ?? "official",
            candidateId,
          )
          .run();
      }
      return json({ candidate: row }, 201);
    } catch (e) {
      if (String(e).includes("UNIQUE")) return err("candidate already tracked", 409);
      throw e;
    }
  }

  if (request.method === "GET" && pathname === "/api/committees") {
    const { results } = await env.DB.prepare(
      `SELECT k.*,
        (SELECT COUNT(*) FROM channels ch WHERE ch.committee_id = k.id) AS channel_count,
        (SELECT COUNT(*) FROM feed_items f WHERE f.committee_id = k.id) AS post_count
       FROM committees k ORDER BY k.id`,
    ).all();
    return json({ committees: results });
  }

  if (request.method === "POST" && pathname === "/api/committees") {
    let body: {
      name?: string;
      kind?: string;
      candidate_id?: number;
      stance?: string;
      fec_id?: string;
      ocf_name?: string;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return err("invalid JSON body", 400);
    }
    if (!body.name || !body.kind) return err("name and kind are required", 400);
    const kinds = ["candidate_committee", "pac", "super_pac", "iec", "party", "other"];
    if (!kinds.includes(body.kind)) return err(`kind must be one of ${kinds.join(", ")}`, 400);
    if (body.stance && !["support", "oppose"].includes(body.stance)) {
      return err("stance must be support or oppose", 400);
    }
    try {
      const row = await env.DB.prepare(
        `INSERT INTO committees (name, kind, candidate_id, stance, fec_id, ocf_name)
         VALUES (?, ?, ?, ?, ?, ?) RETURNING *`,
      )
        .bind(
          body.name,
          body.kind,
          body.candidate_id ?? null,
          body.stance ?? null,
          body.fec_id ?? null,
          body.ocf_name ?? null,
        )
        .first();
      return json({ committee: row }, 201);
    } catch (e) {
      if (String(e).includes("UNIQUE")) return err("committee already tracked", 409);
      throw e;
    }
  }

  if (request.method === "POST" && pathname === "/api/channels") {
    let body: {
      candidate_id?: number;
      committee_id?: number;
      platform?: string;
      input?: string;
      label?: string;
      role?: string;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return err("invalid JSON body", 400);
    }
    const hasCandidate = body.candidate_id != null;
    const hasCommittee = body.committee_id != null;
    if (hasCandidate === hasCommittee) {
      return err("exactly one of candidate_id or committee_id is required", 400);
    }
    if (body.platform !== "youtube" || !body.input) {
      return err("platform must be 'youtube' with an input (@handle or channel id)", 400);
    }
    const roles = ["official", "campaign", "committee", "personal", "pac", "iec", "other"];
    if (body.role && !roles.includes(body.role)) {
      return err(`role must be one of ${roles.join(", ")}`, 400);
    }
    let platformId: string;
    try {
      platformId = await resolveYoutubeChannel(body.input);
    } catch {
      return err("youtube channel not found", 422);
    }
    try {
      const row = await env.DB.prepare(
        `INSERT INTO channels
          (channel_key, platform, platform_id, label, role, candidate_id, committee_id)
         VALUES (?, 'youtube', ?, ?, ?, ?, ?) RETURNING *`,
      )
        .bind(
          `youtube:${platformId}`,
          platformId,
          body.label ?? body.input,
          body.role ?? "official",
          body.candidate_id ?? null,
          body.committee_id ?? null,
        )
        .first();
      return json({ channel: row }, 201);
    } catch (e) {
      if (String(e).includes("UNIQUE")) return err("channel already tracked", 409);
      throw e;
    }
  }

  const feedMatch = pathname.match(/^\/api\/candidates\/(\d+)\/feed$/);
  if (request.method === "GET" && feedMatch?.[1]) {
    const candidateId = Number(feedMatch[1]);
    const limit = Math.min(
      Math.max(parseInt(url.searchParams.get("limit") ?? "20", 10) || 20, 1),
      100,
    );
    const before = url.searchParams.get("before");
    const source = url.searchParams.get("source");
    const committees = url.searchParams.get("committees"); // support|oppose|all
    const { results } = await env.DB.prepare(
      `SELECT ${FEED_COLS} FROM feed_items f
       WHERE ((f.candidate_id = ? AND f.committee_id IS NULL)
          OR (f.candidate_id = ? AND f.committee_id IN (
                SELECT id FROM committees
                WHERE candidate_id = ?
                  AND (? IS NULL OR ? = 'all' OR stance = ?))))
         AND (? IS NULL OR created_at < ?)
         AND (? IS NULL OR source = ?)
       ORDER BY created_at DESC LIMIT ?`,
    )
      .bind(
        candidateId, candidateId, candidateId,
        committees, committees, committees,
        before, before, source, source, limit,
      )
      .all();
    return json({ items: results });
  }

  const committeeFeedMatch = pathname.match(/^\/api\/committees\/(\d+)\/feed$/);
  if (request.method === "GET" && committeeFeedMatch?.[1]) {
    const limit = Math.min(
      Math.max(parseInt(url.searchParams.get("limit") ?? "20", 10) || 20, 1),
      100,
    );
    const before = url.searchParams.get("before");
    const { results } = await env.DB.prepare(
      `SELECT ${FEED_COLS} FROM feed_items f
       WHERE committee_id = ? AND (? IS NULL OR created_at < ?)
       ORDER BY created_at DESC LIMIT ?`,
    )
      .bind(Number(committeeFeedMatch[1]), before, before, limit)
      .all();
    return json({ items: results });
  }

  if (request.method === "POST" && pathname === "/api/crawl") {
    let candidateId: number | undefined;
    let committeeId: number | undefined;
    let sources: Source[] | undefined;
    try {
      const body = (await request.json()) as {
        candidate_id?: number;
        committee_id?: number;
        sources?: Source[];
      };
      candidateId = body.candidate_id;
      committeeId = body.committee_id;
      sources = body.sources;
    } catch {
      // Empty body = crawl everything.
    }
    if (committeeId != null) {
      const row = await env.DB.prepare("SELECT * FROM committees WHERE id = ?")
        .bind(committeeId)
        .first<CommitteeRow>();
      if (!row) return err("committee not found", 404);
      return json({ crawled: [await crawlCommittee(env, row, sources)] });
    }
    const { results } = await env.DB.prepare(
      candidateId ? "SELECT * FROM candidates WHERE id = ?" : "SELECT * FROM candidates",
    )
      .bind(...(candidateId ? [candidateId] : []))
      .all<CandidateInput>();
    const { results: committees } = await env.DB.prepare(
      "SELECT * FROM committees",
    ).all<CommitteeRow>();
    const crawled = [];
    for (const c of results) {
      crawled.push(await crawlCandidate(env, c, sources));
    }
    if (candidateId == null) {
      for (const k of committees) {
        crawled.push(await crawlCommittee(env, k, sources));
      }
    }
    return json({ crawled });
  }

  // ---- App contract (pipeline/schema.md shapes) ----
  // Served for the iOS app. posts.json matches Posts.swift Decoders exactly.

  if (request.method === "GET" && pathname === "/rally/posts.json") {
    const { results } = await env.DB.prepare(
      `SELECT f.*, c.name AS candidate_name
       FROM feed_items f JOIN candidates c ON c.id = f.candidate_id
       WHERE f.source = 'bluesky'
       ORDER BY f.created_at DESC`,
    ).all();
    const posts = results.map((r: Record<string, unknown>) => {
      const post: Record<string, unknown> = {
        id: r["id"],
        platform: "bluesky",
        candidate: r["candidate_name"],
        account: {
          handle: r["author_handle"],
          displayName: r["display_name"],
          avatar: r["avatar"],
          kind: r["kind"] ?? "personal",
        },
        text: r["text"],
        createdAt: r["created_at"],
        url: r["url"],
        media: r["media_json"] ? JSON.parse(r["media_json"] as string) : [],
        metrics: {
          likes: r["like_count"],
          reposts: r["repost_count"],
          replies: r["reply_count"],
        },
      };
      if (r["quoted_json"]) post["quoted"] = JSON.parse(r["quoted_json"] as string);
      return post;
    });
    return json({ generatedAt: new Date().toISOString(), posts });
  }

  if (request.method === "GET" && pathname === "/rally/facts.json") {
    const { results } = await env.DB.prepare(
      `SELECT candidate, text, source, url, category FROM facts ORDER BY candidate, sort`,
    ).all<{ candidate: string; text: string; source: string; url: string; category: string | null }>();
    const { results: portraits } = await env.DB.prepare(
      `SELECT candidate, file, source, license, credit, page FROM portraits`,
    ).all<Record<string, string>>();
    const byCandidate: Record<string, Record<string, string>> = {};
    for (const p of portraits) byCandidate[p["candidate"] as string] = p;
    const candidates: Record<string, { facts: unknown[]; portrait?: unknown }> = {};
    for (const f of results) {
      const entry = (candidates[f.candidate] ??= { facts: [] });
      const fact: Record<string, unknown> = { text: f.text, source: f.source, url: f.url };
      if (f.category) fact["category"] = f.category;
      entry.facts.push(fact);
    }
    for (const [name, p] of Object.entries(byCandidate)) {
      const entry = (candidates[name] ??= { facts: [] });
      entry["portrait"] = {
        file: p["file"],
        source: p["source"],
        license: p["license"],
        credit: p["credit"],
        page: p["page"],
      };
    }
    return json({ generatedAt: new Date().toISOString(), candidates });
  }

  if (request.method === "GET" && pathname === "/rally/videos.json") {
    // Curated clips table ONLY — crawlers never write here.
    const { results } = await env.DB.prepare(`SELECT * FROM clips`).all<
      Record<string, unknown>
    >();
    const videos: Record<string, unknown[]> = {};
    for (const c of results) {
      const clip: Record<string, unknown> = {
        id: c["id"],
        platform: c["platform"],
        title: c["title"],
        channel: c["channel"],
        url: c["url"],
        embedUrl: c["embed_url"],
        verifiedBy: c["verified_by"],
      };
      if (c["channel_url"]) clip["channelUrl"] = c["channel_url"];
      if (c["published_at"]) clip["publishedAt"] = c["published_at"];
      if (c["duration"] != null) clip["duration"] = c["duration"];
      if (c["thumb"]) clip["thumb"] = c["thumb"];
      (videos[c["candidate"] as string] ??= []).push(clip);
    }
    return json({ generatedAt: new Date().toISOString(), videos });
  }

  return err("not found", 404);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handleFetch(request, env);
    } catch (e) {
      console.error(JSON.stringify({ msg: "fetch failed", error: String(e) }));
      return err("internal error", 500);
    }
  },

  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    const { results } = await env.DB.prepare("SELECT * FROM candidates").all<CandidateInput>();
    const { results: committees } = await env.DB.prepare("SELECT * FROM committees").all<CommitteeRow>();
    const out = [];
    for (const c of results) out.push(await crawlCandidate(env, c));
    for (const k of committees) out.push(await crawlCommittee(env, k));
    console.log(JSON.stringify({ msg: "cron crawl done", crawled: out }));
  },
} satisfies ExportedHandler<Env>;
