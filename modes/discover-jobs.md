# discover-jobs — Skill-based autonomous job discovery

Replaces `scan.mjs` and `crawl-englishjobs.mjs` (both retired 2026-09-15 — see
`docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`).

## What this mode does

Finds new job postings matching the user's actual skills and tools — never job
titles — and adds genuinely new ones to the hosted tracker. Runs both as a
7-hourly autonomous cloud routine and as a mode you can invoke manually in an
interactive session; the same instructions below cover both.

## Step 0: Activity log — write as you go, in plain language

The tracker artifact also holds a live `activity_log` collection the user
watches from any device while a run is happening. Log a short, plain-English
entry (no jargon, no tool names, no raw counts dumped without context) via
`ArtifactData` `set` at each milestone below — not batched at the end, write
each one the moment it happens, so the log is genuinely real-time:

1. Run started
2. Keyword set built (name how many keywords, not the tool call)
3. Search complete (how many candidate postings found)
4. Filters applied (how many passed, in plain terms — never dump the
   exclusion list, per the tracker's own "never overwhelm with excluded
   items" convention)
5. Dedup complete (how many were genuinely new)
6. Rows written (or "no new postings this run" — a legitimate, non-error
   outcome)
7. Run finished — or, if blocked (e.g. missing `cv.md`/`modes/_profile.md`),
   one clear entry saying what's missing and that nothing was written

Each entry is one document in collection `activity_log`, fresh `doc_id` (use
the run's start time in epoch milliseconds plus a small counter, e.g.
`1758000000000-3`, so entries never collide and sort correctly), fields:

```json
{
  "ts_iso": "2026-09-16T07:52:03Z",
  "ts_berlin": "2026-09-16 09:52 CEST",
  "ts_berlin_short": "09:52",
  "message": "Found 14 candidate postings from today's search"
}
```

Compute Berlin time with `TZ='Europe/Berlin' date '+%Y-%m-%d %H:%M %Z'`
(handles CET/CEST automatically) — never hardcode a UTC offset.

**Keep it clean:** one sentence per entry, plain language a non-technical
reader follows at a glance, newest-first is how the page renders it so don't
repeat context already implied by the previous entry. After writing, if the
`activity_log` collection has grown past 200 documents, delete the oldest
ones back down to 200 (`list` ordered by `ts_iso` ascending, `delete` the
overflow) — keeps the log itself the size the user actually reads, not an
unbounded history.

## Step 1: Build the query keyword set

Read `cv.md`. Extract skill/tool/domain terms actually documented there —
seed list (regenerate against the current `cv.md`, don't just reuse this list
verbatim if `cv.md` has changed): SQL, SAP S/4HANA, SAP MDG, Databricks,
Power BI, Tableau, Collibra, MDM, data quality, data governance, ETL.

**Never build a query from a job title or archetype name** (e.g. never search
for "Business Analyst" or "Data Quality Analyst" as a phrase) — those live in
`config/profile.yml` → `target_roles` and `modes/_profile.md` for CV/cover-letter
framing only, not for discovery.

## Step 2: Search — tool-availability-aware

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

Either path should aim for up to ~20 net-new (post-dedup, post-filter)
qualifying postings per run, when that many genuinely exist — never pad the
list with weaker matches to hit the number.

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

## Step 4: Dedup against the existing tracker

Read the current tracker (see Step 5). Before adding a candidate, check
whether a document with the same **(company, job title)** pair already exists
(case-insensitive, whitespace-normalized). If it does, skip it — do not add a
duplicate row, and do not touch that row's existing Status.

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
