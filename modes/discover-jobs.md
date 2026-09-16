# discover-jobs — Skill-based autonomous job discovery

Replaces `scan.mjs` and `crawl-englishjobs.mjs` (both retired 2026-09-15 — see
`docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`).

## What this mode does

Finds new job postings matching the user's actual skills and tools — never job
titles — and adds genuinely new ones to the hosted tracker. Runs both as a
7-hourly autonomous cloud routine and as a mode you can invoke manually in an
interactive session; the same instructions below cover both.

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

Read the current tracker (see Step 5 for which one). Before adding a
candidate, check whether a row with the same **(company, job title)** pair
already exists (case-insensitive, whitespace-normalized). If it does, skip it
— do not add a duplicate row, and do not touch that row's existing Status.

## Step 5: Write new rows to the hosted tracker

The tracker is a Google Sheet (`TRACKER_MODE=sheet`, confirmed 2026-09-16 —
the Google Drive/Sheets connector is routine-usable). For each genuinely new,
filtered, deduped candidate, append one row:

| Column | Value |
|--------|-------|
| # | next sequential integer (max existing + 1) |
| Job Title | as posted |
| Company | as posted (or `?` if genuinely undisclosed/agency-sourced, matching this repo's existing convention) |
| Fetched | current date/time, ISO-ish, e.g. `2026-09-15 21:40 CEST` |
| Status | `Not Applied` (always, for a new row) |

Never overwrite an existing row's Status. Never re-add a row that already
exists by the dedup key in Step 4.

## Out of scope for this mode

- Scoring or full A-F evaluation (still `oferta`/auto-pipeline, run manually
  by the user on a row they want to pursue)
- Changing `target_roles`/archetypes (still used for CV/cover-letter framing)
