# Skill-based, autonomous job discovery — design

Status: **implemented 2026-09-16.** The Open Risk below resolved to a
connector-*capability* gap, not just an availability one: the Google
Drive/Sheets connector confirmed routine-usable in a fresh session (Task 1)
turned out to be Drive file-management only — `create_file`/`update_file`,
no Sheets values API for row-level appends. The Output section's Sheet
branch was therefore never viable; the tracker is the Artifact-hosted page
described in the Fallback bullet, live at
https://claude.ai/artifact/X4QZdiqn9kecJrezmrmyoE. Everything else below
(discovery mode logic, filters, dedup, cron trigger) matches what shipped.
Supersedes: `scan.mjs`, `crawl-englishjobs.mjs`, `excel-tracker.mjs` as the daily discovery mechanism.

## Problem

The existing daily discovery pipeline has three problems the user asked to fix:

1. **Title-based, not skill-based.** `scan.mjs` (zero-token ATS scanner) and `crawl-englishjobs.mjs`
   (daily englishjobs.de crawl) both gate on job-title keyword lists (`portals.yml` →
   `title_filter`, and the Germany_Job_Boards.xlsx "Tier 1 role/category terms" search order).
   The user never asked for title-based matching — only skill/tool matching (SQL, SAP S/4HANA,
   Databricks, Power BI, etc.).
2. **Dead config.** `excel-tracker.mjs` and its `Job-Tracker.xlsx` output file no longer exist,
   but `config/profile.yml` (`excel_tracker.*`), `modes/_custom.md` (§1.x daily workflow), and
   `AGENTS.md` still document it as the live daily mechanism.
3. **Apply threshold stale.** `modes/_profile.md`'s "Apply Threshold" override is 2.7/5; the user
   wants 2.6/5. Independent of the discovery pipeline — governs `oferta`/auto-pipeline's
   worth-applying recommendation only.

## Scope

**Retire (disable scheduled tasks, leave scripts in the repo unused, don't delete):**
- `scan.mjs` and its `title_filter`/`search_queries` consumption of `portals.yml`
- `crawl-englishjobs.mjs` and the `CareerOps-EnglishJobsCrawl` scheduled task
- `excel-tracker.mjs`, `config/profile.yml` → `excel_tracker.*` and `job_board_crawl.*`, and the
  `CareerOps-ExcelTracker` scheduled task

**Add:**
- `modes/discover-jobs.md` — new discovery mode (design below)
- A cloud routine (via the `schedule` skill / `RemoteTrigger`) that runs it every 7 hours
- A hosted tracker (Google Sheet, primary; Artifact-hosted page, fallback — see Output below)

**Edit:**
- `modes/_profile.md` — apply threshold 2.7 → 2.6; plain-language rewrite of the hard-filter,
  location, and language sections (meaning unchanged, jargon reduced)
- `config/profile.yml` — remove `excel_tracker.*`, `job_board_crawl.*`
- `modes/_custom.md` — rewrite §1.x daily workflow to reference the new mode/routine instead of
  `excel-tracker.mjs`/`crawl-englishjobs.mjs`
- `AGENTS.md` — Main Files table (mark the three retired scripts as inactive; add the new mode),
  Skill Modes table (point "Searches for new offers" at `discover-jobs` instead of `scan`)

## Discovery mode: `modes/discover-jobs.md`

**Query construction.** Skill/tool/domain keywords only, pulled from `cv.md` — never job titles
and never the `target_roles`/archetype name lists in `config/profile.yml` or `modes/_profile.md`
(those remain valid for framing CVs and evaluations, just not for discovery queries). Seed list:
SQL, SAP S/4HANA, SAP MDG, Databricks, Power BI, Tableau, Collibra, MDM, data quality, data
governance, ETL — regenerated from `cv.md` each run, same principle as the retired
Germany_Job_Boards keyword-matrix mechanism, minus its title-first tiering.

**Search engine — tool-availability-aware, no separate local loop needed:**
- If a Nimble Web Search Agent tool is available in the running session (true today only for a
  local interactive Claude Code session, via the existing `nimble` plugin) → use it
  (`use_case: dataset_building`), one run finds the day's candidate list directly.
- Otherwise (true for the cloud routine, which has no Nimble connector attached — see Open Risk)
  → fall back to the built-in `WebSearch` tool, run once per keyword/query combination, merged
  and deduped locally within the run.

This is one mode, not two parallel mechanisms: the cloud routine gets WebSearch automatically
(it has no Nimble access), and if the user ever runs the same mode manually in a local session,
it gets Nimble automatically (richer results) — no extra configuration either way.

**Filtering.** Every candidate passes the existing hard filters already defined in
`modes/_profile.md` (Your Experience & Skill-Stack Fit, Your Language Policy, Your Company
Policy): 5+ years required → exclude; 2+ required modern-data-stack tools (dbt, Snowflake,
BigQuery, Redshift, Airflow, Kafka, Spark) → exclude; German-fluency requirement → exclude;
consulting/staffing/IT-services blocklist → exclude. These are hard excludes, not score
penalties — a candidate that fails one does not appear in the sheet at all.

**No scoring here.** This pipeline produces a curated discovery list, not an evaluation. No
score column, no 2.6 threshold applied at this stage — the existing `oferta`/auto-pipeline mode
still does the full A-F evaluation on demand when the user picks a row to pursue.

**Target volume.** Up to ~20 net-new (post-dedup) qualifying postings per run, when available;
never pad with weaker matches to hit the number.

## Output: hosted tracker

**Primary: Google Sheet**, via the newly-connected Google Drive/Sheets connector. Columns,
exactly as specified by the user:

| # | Job Title | Company | Fetched (date/time) | Status |
|---|-----------|---------|----------------------|--------|
| 1 | ...       | ...     | 2026-09-15 21:40 CEST | Not Applied |

- Status is constrained to exactly 4 values: `Not Applied` (default for every new row), `Applied`,
  `Interview`, `Rejected`.
- New rows are appended only — a run never overwrites a row's Status once the user has changed it.

**Fallback: Artifact-hosted tracker page**, same columns and status values, backed by the
Artifact database capability, if the Google Sheet connector turns out not to be attached to
routine sessions (see Open Risk below) at build time. Same dedup and append-only rules apply.

## Deduplication

Keyed on **company + job title** (not URL — matches this repo's existing convention; aggregator
and redirect links are known to change per-fetch, e.g. englishjobs.de's `/clickout/{id}` tokens).
Before inserting a row, the run reads the existing tracker (Sheet or Artifact DB) and skips any
candidate whose (company, title) pair already exists, regardless of that row's current Status.

## Trigger

A cloud routine (`schedule` skill / `RemoteTrigger`, `action: create`), cron `0 */7 * * *`
(every 7 hours, UTC), running against the `career-ops` GitHub repo, prompting the
`discover-jobs` mode. Runs independently of whether the user's computer is on. `allowed_tools`
includes `WebSearch` plus the standard file/Bash tools; `mcp_connections` includes the
Sheets/Drive connector once confirmed (see Open Risk).

## Threshold and doc-clarity edits (independent of the above)

- `modes/_profile.md` → "Your Apply Threshold": `2.7/5` → `2.6/5`. Same override mechanism,
  same rationale note, just the number changes.
- `modes/_profile.md` → Experience/Skill-Stack Fit, Location Policy, Language Policy sections:
  reworded for plain language. No rule changes — every exclusion, every location tier, every
  language condition stays exactly as strict/loose as it is today; only the wording simplifies.

## Open Risk — must confirm before the routine goes live

Three different connectors newly added this session (Nimble, then Google Drive) have failed to
appear in the routine-usable "Available MCP Connectors" list, identically, across repeated
checks — while `claude.ai/customize/connectors` and local `claude mcp list` both show them as
connected. The pattern (3/3 failures, no propagation over ~15 minutes) points to this
conversation's connector list being cached from session start rather than a per-connector delay.

**Before the routine is created with the Sheets connector attached, confirm in a brand-new
Claude Code session** (not `--continue`/`--resume` on this one) that the Google Drive/Sheets
connector appears in the routine-usable connector list with a `connector_uuid`. If it does,
build the routine with `mcp_connections` pointing at it. If it still doesn't, use the
Artifact-hosted fallback instead so the pipeline isn't blocked on an external product
limitation — everything else in this spec (mode logic, filters, dedup, cron trigger) is
identical either way.

## Explicitly out of scope

- Re-scoring or evaluating discovered postings (still `oferta`'s job)
- Changing `target_roles`/archetypes in `config/profile.yml` or `modes/_profile.md` (still used
  for CV/cover-letter framing, just not for discovery queries)
- `portals.yml`'s `title_filter`/`search_queries`/`job_board_directory` — left in place, unused
  once `scan.mjs` is retired; not deleted, since `discover-boards` mode may still reference the
  board directory for a different purpose (finding new boards, not finding jobs)
