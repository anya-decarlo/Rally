// Money refresher: FEC totals (federal) + Fair Elections (local) -> facts.
// Cadence gate: weekly on Mondays far out, daily inside 30 days to the race.
// Manual POST /api/refresh/money always runs (force). Dollars summed from
// API fields in code; nothing estimated, nothing invented.

export interface RefreshStatus {
  candidate_id: number;
  candidate: string;
  fec: { status: string; note?: string };
  fair_elections: { status: string; note?: string };
}

const DAY = 86_400_000;

export function dueForRefresh(electionDate: string | null, now: Date): boolean {
  if (!electionDate) return now.getUTCDay() === 1; // no race row: Mondays
  const days = Math.ceil(
    (new Date(electionDate + "T00:00:00Z").getTime() - now.getTime()) / DAY,
  );
  if (days <= 30) return true;
  return now.getUTCDay() === 1;
}

function money(n: number | null | undefined): string {
  if (n == null) return "—";
  return "$" + Math.round(n).toLocaleString("en-US");
}

function shortDate(iso: string | null | undefined): string {
  if (!iso) return "latest report";
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" });
}

async function upsertMoneyFact(
  env: Env,
  candidate: string,
  source: "FEC" | "Fair Elections",
  text: string,
  sort: number,
): Promise<void> {
  const now = new Date().toISOString();
  const updated = await env.DB.prepare(
    `UPDATE facts SET text = ?, fetched_at = ? WHERE candidate = ? AND source = ? AND category = 'money'`,
  )
    .bind(text, now, candidate, source)
    .run();
  if ((updated.meta.changes ?? 0) === 0) {
    await env.DB.prepare(
      `INSERT INTO facts (candidate, text, source, url, category, sort, fetched_at)
       VALUES (?, ?, ?, ?, 'money', ?, ?)`,
    )
      .bind(
        candidate,
        text,
        source,
        source === "FEC"
          ? "https://www.fec.gov/data/candidate/"
          : "https://fairelections.ocf.dc.gov/",
        sort,
        now,
      )
      .run();
  }
}

async function refreshFec(
  env: Env,
  candidateId: number,
  name: string,
  fecId: string | null,
  apiKey: string | undefined,
): Promise<{ status: string; note?: string }> {
  if (!fecId) return { status: "skipped", note: "no fec id" };
  if (!apiKey) return { status: "skipped", note: "FEC_API_KEY not set" };
  const url =
    `https://api.open.fec.gov/v1/candidate/${fecId}/totals/` +
    `?cycle=2026&full_election=true&api_key=${apiKey}`;
  const res = await fetch(url);
  if (!res.ok) return { status: "error", note: `FEC -> ${res.status}` };
  const data = (await res.json()) as { results?: Record<string, number | string | null>[] };
  const t = data.results?.[0];
  if (!t) return { status: "error", note: "no totals" };
  const text =
    `Raised ${money(t["receipts"] as number)} and spent ${money(t["disbursements"] as number)} ` +
    `(2026 cycle, thru ${shortDate(t["coverage_end_date"] as string)}). ` +
    `${money(t["individual_itemized_contributions"] as number)} itemized, ` +
    `${money(t["individual_unitemized_contributions"] as number)} small-dollar.`;
  await upsertMoneyFact(env, name, "FEC", text, 1);
  void candidateId;
  return { status: "ok" };
}

function norm(s: string): string {
  return s.toLowerCase().replace(/\s+/g, " ").trim();
}

async function refreshFairElections(
  env: Env,
  name: string,
): Promise<{ status: string; note?: string }> {
  const res = await fetch("https://fairelections.ocf.dc.gov/app/api/Public/SearchRegistrationDisclosure", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ electionYear: 2026 }),
  });
  if (!res.ok) return { status: "error", note: `FE -> ${res.status}` };
  const data = (await res.json()) as {
    searchData?: Array<{
      candidateName?: string;
      totalApprovedContributions?: number;
      totalApprovedContributors?: number;
      fairElectionPayoutsTotal?: number;
    }>;
  };
  const target = norm(name);
  const match = (data.searchData ?? []).find((r) => {
    const n = norm(r.candidateName ?? "");
    return n.includes(target) || target.includes(n);
  });
  if (!match) return { status: "skipped", note: "no 2026 FE registration" };
  const text =
    `Raised ${money(match.totalApprovedContributions)} from ` +
    `${match.totalApprovedContributors ?? "—"} DC donors + ` +
    `${money(match.fairElectionPayoutsTotal)} public funds (OCF Fair Elections, 2026).`;
  await upsertMoneyFact(env, name, "Fair Elections", text, 2);
  return { status: "ok" };
}

export async function refreshMoney(
  env: Env,
  candidateId?: number,
  force = false,
): Promise<RefreshStatus[]> {
  const { results } = await env.DB.prepare(
    candidateId ? "SELECT * FROM candidates WHERE id = ?" : "SELECT * FROM candidates",
  )
    .bind(...(candidateId ? [candidateId] : []))
    .all<{
      id: number;
      name: string;
      office: string | null;
      fec_candidate_id: string | null;
    }>();
  const apiKey = (env as Env & { FEC_API_KEY?: string }).FEC_API_KEY;
  const now = new Date();
  const out: RefreshStatus[] = [];
  for (const c of results) {
    if (!force && candidateId == null) {
      const race = c.office
        ? await env.DB.prepare("SELECT election_date FROM races WHERE office = ?")
            .bind(c.office)
            .first<{ election_date: string }>()
        : null;
      if (!dueForRefresh(race?.election_date ?? null, now)) {
        out.push({
          candidate_id: c.id,
          candidate: c.name,
          fec: { status: "skipped", note: "not due" },
          fair_elections: { status: "skipped", note: "not due" },
        });
        continue;
      }
    }
    const fec = await refreshFec(env, c.id, c.name, c.fec_candidate_id, apiKey);
    const fair_elections = await refreshFairElections(env, c.name);
    out.push({ candidate_id: c.id, candidate: c.name, fec, fair_elections });
  }
  return out;
}
