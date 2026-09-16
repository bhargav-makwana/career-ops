# discover-jobs — Skill-based autonomous job discovery

Replaces `scan.mjs` and `crawl-englishjobs.mjs` (both retired 2026-09-15 — see
`docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`).

## What this mode does

Finds new job postings matching the user's actual skills and tools — never job
titles — and adds genuinely new ones to the hosted tracker. Runs both as a
7-hourly autonomous cloud routine and as a mode you can invoke manually in an
interactive session; the same instructions below cover both.

## Step 0: Activity log — minimal, token-efficient

The tracker artifact holds a live `activity_log` collection the user checks
from any device. **Write exactly 2 entries per run, never more** — every
extra entry is an extra tool call and extra tokens, and this mode runs
autonomously many times a day, so verbosity here has a real ongoing cost:

1. **At the start:** one entry, e.g. `"Run started"`.
2. **At the end:** one entry summarizing the whole run in one line, e.g.
   `"Found 10 new postings (32 searched, 14 already applied/known, 8 failed a
   filter)"` or, if blocked, the reason nothing ran (e.g. `"Blocked — cv.md
   missing from this clone"`).

No per-search, no per-exclusion, no per-filter entries. If something needs
explaining beyond one line, it belongs in that posting's own tracker row, not
the log.

Each entry: one document in collection `activity_log`, fresh `doc_id` (run
start time in epoch ms plus a counter, e.g. `1758000000000-1`), fields:

```json
{
  "ts_iso": "2026-09-16T07:52:03Z",
  "ts_berlin_short": "09:52",
  "message": "Found 10 new postings (32 searched, 14 already known, 8 filtered out)"
}
```

Compute Berlin time with `TZ='Europe/Berlin' date '+%H:%M'` (handles
CET/CEST automatically). After writing the end-of-run entry, if
`activity_log` has grown past 50 documents, delete the oldest back down to
50 — this log is a quick pulse-check, not a history.

## Step 1: Build the query keyword set

Read `cv.md`. Extract skill/tool/domain terms actually documented there —
seed list (regenerate against the current `cv.md`, don't just reuse this list
verbatim if `cv.md` has changed): SQL, SAP S/4HANA, SAP MDG, Databricks,
Power BI, Tableau, Collibra, MDM, data quality, data governance, ETL.

**Never build a query from a job title or archetype name** (e.g. never search
for "Business Analyst" or "Data Quality Analyst" as a phrase) — those live in
`config/profile.yml` → `target_roles` and `modes/_profile.md` for CV/cover-letter
framing only, not for discovery.

## Step 2: Search — tool-availability-aware, keep going until the target is met

Check which search tool is available in the current session:

- **If a Nimble Web Search Agent tool is available** (true in a local
  interactive session with the `nimble` plugin enabled, false in the cloud
  routine): create one Web Search Agent run, `use_case: dataset_building`,
  effort `high`, prompting it to find job postings in Germany/EU-remote
  matching the keyword set from Step 1, for a mid-level (~3-4 years)
  candidate. Poll for the result.
- **Otherwise** (true in the cloud routine, which has no Nimble connector):
  use the built-in WebSearch tool, once per keyword or small keyword group
  (e.g. `"SAP MDG" OR "SAP S/4HANA" jobs Germany site:stepstone.de`,
  `SQL "data quality" Berlin jobs`), and merge/dedupe the results yourself
  within this run.

**Target: 10 genuinely new (post-filter, post-dedup) qualifying postings per
run — keep searching until you reach it, not just one shallow pass.** Vary
the query: different keyword combinations, different `site:` boards
(stepstone.de, linkedin.com, indeed.com, glassdoor.com, xing.com), different
phrasing. A single pass of ~10 searches is rarely enough — expect to run
20-40 before reaching 10 real net-new candidates, since most raw hits are
aggregator/category pages (Glassdoor/Indeed "N jobs in Berlin" listings, not
individual postings) or turn out to already be known (Step 4). Stop only when
you hit 10, or you've run ~40 searches and genuinely exhausted reasonable
query variety for this cycle — in that case report the honest, smaller
number in the end-of-run log entry rather than padding with weak matches.
Never lower the hard-filter bar (Step 3) to reach the number.

**WebFetch may be blocked in the cloud routine** (`EGRESS_BLOCKED` — a
network-egress policy on this environment, not fixable from within the
session). If a WebFetch call returns that error, don't retry it — judge the
posting from the WebSearch result's own title/snippet text instead. Only
WebSearch is guaranteed to work in the cloud path.

## Step 3: Apply hard filters

For each candidate, apply the hard filters from `modes/_profile.md` exactly as
written there (read that file now, don't rely on a cached summary):

- **Your Experience & Skill-Stack Fit (HARD FILTER)** — 5+ years required, or
  2+ required modern-data-stack tools (dbt, Snowflake, BigQuery, Redshift,
  Airflow, Kafka, Spark) → exclude entirely, no exceptions, no notes.
- **Your Language Policy (HARD FILTER)** — English working language required;
  German-fluency requirement → exclude; all-German posting with zero language
  signal → exclude.
- **Your Company Policy (HARD FILTER)** — consulting/IT-services/staffing
  blocklist → exclude the employer, not the posting, if it's an
  agency-sourced listing for an undisclosed end employer (see that section's
  distinction).

These are hard excludes. Do not score anything at this stage and do not
include a candidate "with a caveat" — a caveat worth writing down is a reason
to exclude, not a reason to include.

## Step 4: Exclude anything already known — two sources, both mandatory

A candidate is "already known" (never add it, regardless of how good a fit
it looks) if it matches either of these, by **company** (case-insensitive,
whitespace-normalized — a title match isn't required, since re-surfacing the
same company under a reworded title is exactly the noise this check exists
to catch):

1. **`data/applications.md`** — the user's real, authoritative application
   history. Read every row's Company column, every status included (not just
   "Applied" — an `Evaluated`/`SKIP`/`Rejected` company was already looked at
   and decided on, so it's not a fresh discovery either). This is the
   critical check: the hosted tracker below starts empty on day one and has
   no memory of anything applied to before `discover-jobs` existed, so
   skipping this step re-surfaces companies the user already interviewed
   with and was rejected from.
2. **The hosted tracker's own `postings` collection** (Step 5) — a
   **(company, job title)** pair already present there from a prior
   `discover-jobs` run.

Check both before adding anything. If a candidate matches either, skip it
silently — don't log it, don't add it, don't touch any existing row's Status.

## Step 5: Write new rows to the hosted tracker

The tracker is the Artifact-hosted page at
**https://claude.ai/artifact/X4QZdiqn9kecJrezmrmyoE** (`TRACKER_MODE=artifact`,
decided 2026-09-16 — the Google Drive connector available in this environment
is Drive file-management only, with no Sheets values API for row-level
appends, so the Sheet branch isn't viable; see
`docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`).

Use the `ArtifactData` tool (`ToolSearch select:ArtifactData` if not already
loaded) against that URL, collection `postings`:

1. `action: "list"` (or `"query"`) on `postings` to read existing rows for the
   Step 4 dedup check.
2. For each genuinely new, filtered, deduped candidate, `action: "set"` with
   a fresh `doc_id` (the next sequential integer, e.g. `"7"`, as a string —
   max existing `num` + 1) and `data`:

```json
{
  "num": 7,
  "title": "as posted",
  "company": "as posted (or \"?\" if genuinely undisclosed/agency-sourced)",
  "fetched": "2026-09-15 21:40 CEST",
  "status": "Not Applied"
}
```

`status` holds exactly 4 values: `Not Applied`, `Applied`, `Interview`,
`Rejected` — the user changes the latter three by hand in the page's UI as an
application progresses; this mode only ever writes `Not Applied`, never the
other three, and never `set`s over an existing `doc_id` (that would be an
overwrite, not an append — Step 4's dedup check is what prevents this).

Log every job board / career site touched this run to the same artifact's
`sources` collection the same way (`set` with a fresh `doc_id`): fields
`source`, `type`, `company`, `rolesFound`, `verdict`, `notes`, `date`.

## Out of scope for this mode

- Scoring or full A-F evaluation (still `oferta`/auto-pipeline, run manually
  by the user on a row they want to pursue)
- Changing `target_roles`/archetypes (still used for CV/cover-letter framing)
