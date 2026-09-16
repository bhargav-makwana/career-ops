# Skill-Based Autonomous Job Discovery Implementation Plan

## Execution log (2026-09-16)

Tasks 1-9 done, in order, with two corrections along the way (see commits):

- **Task 1:** `TRACKER_MODE` confirmed `sheet` in a fresh session
  (`connector_uuid: 99df73fe-0fe1-40d5-8b41-b3139dbb1424`), then **revised to
  `artifact`** once Task 9 found the connector has no Sheets values API for
  row appends (Drive file-management only). `.tracker-mode` now reads
  `artifact`.
- **Task 2:** N/A — `CareerOps-ExcelTracker`/`CareerOps-EnglishJobsCrawl`
  scheduled tasks don't exist on this machine; nothing to disable.
- **Tasks 3, 4, 8:** done directly (no commit — `config/profile.yml`,
  `modes/_profile.md`, `modes/_custom.md` are gitignored user-layer files).
- **Tasks 5, 6, 7:** committed to `main` directly (repo convention, no
  branch/worktree workflow in this history) — commits `a71e1cb6`, `c45c3857`,
  `f15173de`.
- **Task 9:** built the **Artifact-hosted branch**, not the Sheet branch —
  live at https://claude.ai/artifact/X4QZdiqn9kecJrezmrmyoE (commit
  `f4809c2d`). Corrected two files that had already been written assuming
  the Sheet branch: `modes/discover-jobs.md` (commit `b20aa4e1`), `AGENTS.md`
  (commit `95874105`). Spec's Open Risk resolved accordingly (commit
  `a8f601f6`).
- **Task 10 (cloud routine):** not yet created — pausing for the user to
  confirm the routine's prompt/schedule before it goes live and starts
  running autonomously every 7 hours.
- **Task 11 (retire stale memory entries):** not yet done.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace career-ops's title-based, partly-dead daily job-discovery pipeline (`scan.mjs` + `crawl-englishjobs.mjs` + `excel-tracker.mjs`) with one skill-keyword-based `discover-jobs` mode, run autonomously every 7 hours by a cloud routine (WebSearch) with a richer local fallback (Nimble Web Search Agent) when run interactively, writing deduped results to a hosted tracker.

**Architecture:** One new mode file (`modes/discover-jobs.md`) is the single source of discovery logic; it is tool-availability-aware (Nimble if present, else WebSearch) so the same prompt works unmodified in a cloud routine and in a local session. The three retired scripts and their scheduled tasks are disabled, not deleted. Output lands in a hosted tracker (Google Sheet if the Drive/Sheets connector is confirmed routine-usable, else a published Artifact page) with append-only, dedup-on-(company+title) writes.

**Tech Stack:** Node.js (repo's existing `.mjs` scripts, no framework — `node --test` for tests), YAML (`config/profile.yml`), Markdown mode prompts, Windows `Disable-ScheduledTask`, `RemoteTrigger`/`schedule` skill (cloud routines), Artifact tool (fallback tracker only).

**Spec:** `docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`

## Global Constraints

- Dedup key is **company + job title**, never the posting URL (spec: Deduplication).
- Tracker Status column has **exactly 4 values**: `Not Applied` (default for new rows), `Applied`, `Interview`, `Rejected` (spec: Output).
- A discovery run **never overwrites a row's Status** once the user has changed it — append-only for new rows, skip on dedup match (spec: Output, Deduplication).
- Discovery applies the **existing hard filters** from `modes/_profile.md` unchanged (5+ yrs required, 2+ required modern-stack tools, German-fluency requirement, consulting/staffing blocklist) — these are hard excludes, never score penalties (spec: Discovery mode).
- Discovery queries are built from **skill/tool keywords only** (SQL, SAP S/4HANA, SAP MDG, Databricks, Power BI, Tableau, Collibra, MDM, data quality, data governance, ETL), **never job titles** (spec: Discovery mode).
- No scoring/threshold is applied at discovery time — it is a curated list, not an evaluation (spec: Discovery mode).
- Retired scripts (`scan.mjs`, `crawl-englishjobs.mjs`, `excel-tracker.mjs`) are **disabled, not deleted** (spec: Scope).
- Routine cron is every 7 hours: `0 */7 * * *` (UTC) (spec: Trigger).
- The Google Drive/Sheets connector's routine-usability **must be confirmed in a brand-new Claude Code session** before it is wired into the routine; otherwise use the Artifact-hosted fallback (spec: Open Risk).

---

## File Structure

| File | Change | Responsibility |
|------|--------|-----------------|
| `modes/discover-jobs.md` | Create | The single discovery-mode prompt: query construction, tool-availability branching, hard filters, dedup instructions, output-write instructions |
| `tests/discover-jobs-mode.test.mjs` | Create | Structural checks: mode file exists and documents every required behavior; `AGENTS.md` references it |
| `modes/_profile.md` | Modify | Apply threshold 2.7 → 2.6; plain-language rewrite of 3 sections (meaning unchanged) |
| `config/profile.yml` | Modify | Remove `excel_tracker.*` and `job_board_crawl.*` blocks |
| `modes/_custom.md` | Modify | Rewrite §1.x daily-workflow section to reference `discover-jobs` + the routine instead of the retired scripts |
| `AGENTS.md` | Modify | Main Files table (mark 3 scripts inactive, add `discover-jobs.md` row); Skill Modes table (point job-search row at `discover-jobs`) |
| `docs/tracker-fallback-artifact.html` (fallback branch only) | Create | Source file for the published Artifact-hosted tracker page, if the Sheets connector isn't confirmed |
| (Windows Task Scheduler) | Modify (system, not repo) | Disable `CareerOps-ExcelTracker` and `CareerOps-EnglishJobsCrawl` |
| (claude.ai routine) | Create (cloud, not repo) | The `discover-jobs` cron routine itself |
| `~/.claude/projects/.../memory/job-tracker-single-source.md` | Modify | Mark retired — Job-Tracker.xlsx no longer exists, new tracker is Sheet/Artifact |
| `~/.claude/projects/.../memory/germany-job-boards-xlsx-source-of-truth.md` | Modify | Mark retired — was `crawl-englishjobs.mjs`'s keyword source, now unused |
| `~/.claude/projects/.../memory/MEMORY.md` | Modify | Update the two index lines above; no new memory needed |

---

## Task 1: Confirm Google Drive/Sheets connector routine-eligibility (branch point)

This task has no code — it's a verification gate. Its output (CONFIRMED or NOT-CONFIRMED) decides whether Task 8 builds the Google Sheet branch or the Artifact fallback branch. Do this task first; every later task that depends on the tracker type reads its result.

**Files:** none

**Interfaces:**
- Consumes: nothing
- Produces: `TRACKER_MODE` — a plain-text decision, either `sheet` or `artifact`, written to `docs/superpowers/plans/.tracker-mode` (gitignored scratch file, not part of the deliverable) so Task 8 and Task 9 can read it without re-running this check.

- [ ] **Step 1: Start a brand-new Claude Code session** (a fresh terminal, `claude` with no `--continue`/`--resume`) — not this one, since this conversation's connector list has already shown stale results 3 times in a row for newly-added connectors.

- [ ] **Step 2: In that fresh session, invoke the `schedule` skill and ask it to report the "Available MCP Connectors" list**, specifically whether a Google Drive or Google Sheets connector appears with a `connector_uuid`.

- [ ] **Step 3: Record the result.**

If it appears with a `connector_uuid`:
```bash
echo "sheet" > docs/superpowers/plans/.tracker-mode
```

If it does not appear:
```bash
echo "artifact" > docs/superpowers/plans/.tracker-mode
```

- [ ] **Step 4: Add the scratch file to `.gitignore`** (it's a build-time decision record, not a deliverable):

```bash
grep -qxF 'docs/superpowers/plans/.tracker-mode' .gitignore || echo 'docs/superpowers/plans/.tracker-mode' >> .gitignore
git add .gitignore
git commit -m "chore: ignore tracker-mode decision scratch file"
```

No further verification step — this task's "test" is the human-in-the-loop confirmation in Step 2, which is why it must happen in a fresh session rather than be assumed.

---

## Task 2: Disable the two retired Windows scheduled tasks

**Files:** none (system state change on the local machine)

**Interfaces:**
- Consumes: nothing
- Produces: nothing other tasks depend on programmatically (informational for the user)

- [ ] **Step 1: List current state before touching anything**

```powershell
Get-ScheduledTask -TaskName "CareerOps-ExcelTracker","CareerOps-EnglishJobsCrawl" | Select-Object TaskName, State
```

Expected: both show `Ready` or `Running` (currently enabled).

- [ ] **Step 2: Disable both tasks (reversible — not deleted)**

```powershell
Disable-ScheduledTask -TaskName "CareerOps-ExcelTracker" -Confirm:$false
Disable-ScheduledTask -TaskName "CareerOps-EnglishJobsCrawl" -Confirm:$false
```

- [ ] **Step 3: Verify both now show Disabled**

```powershell
Get-ScheduledTask -TaskName "CareerOps-ExcelTracker","CareerOps-EnglishJobsCrawl" | Select-Object TaskName, State
```

Expected: both show `Disabled`.

- [ ] **Step 4: Commit nothing (system-only change)** — instead, note the change in the next commit's message when Task 3 lands, since there's no repo file to commit here.

---

## Task 3: Remove dead Excel-tracker config from `config/profile.yml`

**Files:**
- Modify: `config/profile.yml` (remove `excel_tracker:` block, currently lines 99–143, and `job_board_crawl:` block, currently lines 145–157 — re-check exact line numbers before editing since earlier tasks in a real run may have already shifted them; match on the keys, not the line numbers)
- Test: `tests/discover-jobs-mode.test.mjs` (extended in Task 7; this task's own verification is inline below since `config/profile.yml` has no dedicated existing test file)

**Interfaces:**
- Consumes: nothing
- Produces: a `config/profile.yml` with no `excel_tracker` or `job_board_crawl` top-level keys — Task 5 (`modes/_custom.md` rewrite) must not reference either key afterward.

- [ ] **Step 1: Read the current file to get exact key boundaries**

```bash
node -e "const yaml=require('yaml'); const fs=require('fs'); const doc=yaml.parse(fs.readFileSync('config/profile.yml','utf8')); console.log(Object.keys(doc))"
```
(If the `yaml` package isn't available as a plain `require`, read the file directly and locate the two block headers `excel_tracker:` and `job_board_crawl:` by eye — both are top-level keys with no other top-level key nested between them per the current file.)

- [ ] **Step 2: Delete both blocks**, including their leading comment blocks (the multi-line `#` comments immediately above each key are part of the block being removed, not shared with a neighboring key). Leave every other top-level key (`candidate`, `target_roles`, `narrative`, `compensation`, `location`, `language`, `cv`, `cover_letter`) untouched.

- [ ] **Step 3: Verify the file still parses and the two keys are gone**

```bash
node -e "
const fs = require('fs');
const text = fs.readFileSync('config/profile.yml', 'utf8');
if (/^excel_tracker:/m.test(text)) { console.error('FAIL: excel_tracker still present'); process.exit(1); }
if (/^job_board_crawl:/m.test(text)) { console.error('FAIL: job_board_crawl still present'); process.exit(1); }
console.log('PASS: both dead blocks removed');
"
```

Expected: `PASS: both dead blocks removed`.

- [ ] **Step 4: Run the existing doctor check to confirm nothing else depends on the removed keys**

```bash
node doctor.mjs --json
```

Expected: `onboardingNeeded: false` (unchanged from before this edit) and no new entries in `missing` or `warnings` mentioning `excel_tracker` or `job_board_crawl`.

- [ ] **Step 5: Commit**

```bash
git add config/profile.yml
git commit -m "chore: remove dead excel-tracker and job-board-crawl config

Job-Tracker.xlsx no longer exists; excel-tracker.mjs and
crawl-englishjobs.mjs are being retired in favor of the discover-jobs
mode (see docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md)."
```

---

## Task 4: Update `modes/_profile.md` — threshold and plain-language rewrite

**Files:**
- Modify: `modes/_profile.md:93-95` (Apply Threshold section), and the three sections named below
- Test: `tests/discover-jobs-mode.test.mjs` (extended in Task 7)

**Interfaces:**
- Consumes: nothing
- Produces: `modes/_profile.md` with `2.6/5` as the apply threshold (no other file reads this value programmatically — it's read by the `oferta`/auto-pipeline mode prompts at run time, not parsed by any script)

- [ ] **Step 1: Update the threshold line**

Change:
```markdown
**Recommend applying at 2.7/5 or above** (not the system default of 4.0/5) — set 2026-09-09 after a full pipeline run against the current Berlin/DE data-analyst-adjacent market topped out at 3.5/5 across 11 real evaluations; a strict 4.0 bar left zero actionable candidates despite genuine SQL/data-quality overlap in several roles. Below 2.7 still means recommend against / SKIP. This threshold applies to the oferta/auto-pipeline "worth applying" recommendation language and to which evaluated postings get flagged for PDF generation — it does NOT change `config/profile.yml` → `excel_tracker.min_score_floor` (that stays 2.3, a separate purge gate for the Excel sheet).
```
to:
```markdown
**Recommend applying at 2.6/5 or above** (not the system default of 4.0/5) — set 2026-09-09, revised 2026-09-15, after a full pipeline run against the current Berlin/DE data-analyst-adjacent market topped out at 3.5/5 across 11 real evaluations; a strict 4.0 bar left zero actionable candidates despite genuine SQL/data-quality overlap in several roles. Below 2.6 still means recommend against / SKIP. This threshold applies to the oferta/auto-pipeline "worth applying" recommendation language and to which evaluated postings get flagged for PDF generation. (The Excel-sheet purge floor this note used to cross-reference no longer exists — see the discover-jobs mode for the current discovery pipeline, which does not score at all.)
```

- [ ] **Step 2: Rewrite "Your Experience & Skill-Stack Fit (HARD FILTER)" for plain language**, keeping every rule identical. Change:
```markdown
## Your Experience & Skill-Stack Fit (HARD FILTER)

**Set 2026-09-10 after explicit, angry pushback: never include a posting "with a gap" — either it's a real fit or it doesn't appear at all. A blended score that only clears the floor because location/other factors compensate for a real disqualifier is exactly the noise to eliminate, not caveat.**

- If a posting explicitly states a years-of-experience requirement of **5+** (e.g. "5+ years", "6+ years", "5-7 years") — hard exclude, full stop. You have ~3-4 years. Do not include it with a "Gap: 5+ yrs required" note; do not include it at all. (This extends the existing Staff-title hard exclude in excel-tracker.mjs — same logic, now also triggered by an explicit years-required number in the JD body, not just the word "Staff" in the title.)
- If a posting's **required** (not "nice to have"/"bonus"/"plus") tooling centers on a modern data-engineering stack you have no hands-on evidence for in cv.md — dbt, Snowflake, BigQuery, Redshift, Airflow, Kafka, Spark — hard exclude when 2 or more of these appear as requirements. One such tool mentioned as a bonus is fine to keep; two or more as the actual ask is a different job than the one you do.
- These are exclusions, not scoring penalties: a role that fails either check does not get a lower score, it gets left out entirely. No "Gap:" language in Notes for anything that made it into the sheet — if a caveat is worth writing down, the caveat is a reason to exclude, not a reason to include-with-an-asterisk.
```
to:
```markdown
## Your Experience & Skill-Stack Fit (HARD FILTER)

**Rule: a posting either fits or it doesn't appear at all — never include one with a caveat.**

- Posting asks for **5+ years** of experience (any phrasing: "5+ years", "6+ years", "5-7 years")? Leave it out completely. (You have ~3-4 years.) Do not include it with a note explaining the gap — just don't include it.
- Posting's **required** tools (not "nice to have") include **2 or more** of: dbt, Snowflake, BigQuery, Redshift, Airflow, Kafka, Spark? Leave it out completely — that's a different job than the one you do. One of these as a bonus/nice-to-have is fine to keep.
- Both checks are exclusions, not low scores: a posting that fails either one is left out entirely, never included with a "Gap:" note in its favor.
```

- [ ] **Step 3: Rewrite "Your Language Policy (HARD FILTER)" for plain language**, keeping every rule identical. Change:
```markdown
## Your Language Policy (HARD FILTER)

- Working language must be English. English-language postings → pass.
- Posting written in German is OK for discovery, BUT reject if the role requires fluent/business-fluent/C1+/native German ("verhandlungssicher", "fließend", "Deutsch als Arbeitssprache", "German required") or a German-only work environment.
- "German is a plus / B1-B2 nice-to-have" with English working language → pass.
- **HARD RULE (set 2026-09-10):** If the posting is written entirely in German AND there is no mention anywhere of English/language requirements — auto-reject, always. Do not include it, do not flag it for verification, just ignore it. This overrides the general "unclear → flag, don't auto-reject" rule below for this specific case (German-language posting + zero language signal of any kind).
- If language requirement is unclear for an otherwise English (or mixed-language-signal) posting → flag as "verify language" in reports, do not auto-reject.
```
to:
```markdown
## Your Language Policy (HARD FILTER)

- Working language must be English.
- A German-language posting is fine to consider, unless it requires fluent/business-fluent/C1+/native German ("verhandlungssicher", "fließend", "Deutsch als Arbeitssprache", "German required") — then exclude it.
- "German is a plus / B1-B2 nice-to-have" is fine, as long as English is still the working language.
- A posting written entirely in German with **no** language requirement mentioned anywhere → exclude automatically, no exceptions, don't even flag it for review.
- A posting where the language requirement is genuinely unclear (but the posting is otherwise English or mixed-language) → don't exclude it, but flag it in the report as "verify language."
```

- [ ] **Step 4: Rewrite "Your Location Policy" for plain language**, keeping every scoring tier and every number identical. Change:
```markdown
## Your Location Policy

**Availability:** Berlin (primary: on-site/hybrid/remote). Hybrid/remote only in North/North-Eastern Germany. Remote anywhere within Germany. EU Remote considered at lower priority. Non-EU excluded.
**Work authorization:** Permanent Residency — no sponsorship needed. Can start without visa delays.

**Changed 2026-09-10, explicit correction: location is a PREFERENCE, never a hard exclude.** A role that otherwise aligns on skills/domain/seniority/language must never be filtered out, SKIP-recommended, or dropped from a shortlist on location alone — Berlin is what's preferred, not a requirement. Location still factors into ranking/ordering (see scores below) so Berlin/remote options surface first, but a lower location score must never by itself drag an otherwise-strong role below the apply threshold or trigger a SKIP recommendation. If location is the only weak axis, say so plainly in Notes as a tradeoff to weigh, not a disqualifier.

**In evaluations (ranking, not gating):**
- Berlin — remote, hybrid, or on-site → 5.0
- Germany Remote (any company base) → 5.0
- Berlin hybrid specifically → 4.8
- Northern/North-Eastern Germany hybrid or remote (Hamburg, Bremen, Hannover, Leipzig, Dresden, Magdeburg, Rostock, Kiel, Lübeck, Braunschweig, Wolfsburg, Schwerin, Potsdam and surrounding regions) → 4.6
- EU Remote (company based in EU, not Germany) → 4.0 (always ranked below German options)
- Hybrid anywhere else in Germany → 3.5
- Fully on-site anywhere in Germany (outside Berlin) → 3.0
- On-site 5 days/week outside practical commute range → 3.0
- Outside EU → 2.0 (still not an auto-exclude — weigh case by case; visa/relocation reality can still make one impractical, but that is a judgment call to surface, not an automatic rule)
```
to:
```markdown
## Your Location Policy

**Where:** Berlin preferred (any arrangement). Also fine: North/North-Eastern Germany hybrid or remote, remote anywhere in Germany, EU-remote at lower priority. Non-EU is not preferred.
**Work authorization:** Permanent Residency — no sponsorship needed, can start anytime.

**Rule: location ranks roles, it never excludes one.** A role that's otherwise a strong fit is never dropped, SKIP'd, or scored below the apply threshold because of location alone. If location is the only weak point, say so plainly as a tradeoff — not a reason to exclude.

**Ranking scores (higher = surfaces first, never a cutoff):**
- Berlin (remote, hybrid, or on-site) or Germany Remote → 5.0
- Berlin hybrid specifically → 4.8
- North/North-Eastern Germany hybrid or remote (Hamburg, Bremen, Hannover, Leipzig, Dresden, Magdeburg, Rostock, Kiel, Lübeck, Braunschweig, Wolfsburg, Schwerin, Potsdam, and nearby) → 4.6
- EU Remote (non-Germany) → 4.0
- Hybrid elsewhere in Germany → 3.5
- Fully on-site elsewhere in Germany, or on-site outside a practical commute → 3.0
- Outside the EU → 2.0 (not an automatic exclude — note it as a tradeoff to weigh, since visa/relocation can still make it impractical)
```

- [ ] **Step 5: Verify no rule content changed, only wording** — diff the numbers/keywords specifically:

```bash
git diff modes/_profile.md | grep -E '^\+' | grep -oE '[0-9]\.[0-9]|5\+|2026-09-[0-9]+' | sort -u > /tmp/after-numbers.txt
git diff modes/_profile.md | grep -E '^-' | grep -oE '[0-9]\.[0-9]|5\+|2026-09-[0-9]+' | sort -u > /tmp/before-numbers.txt
diff /tmp/before-numbers.txt /tmp/after-numbers.txt
```

Expected diff output: only `2.7/5`/`2.6` (and the added `2026-09-15` revision date) differ — every location-tier and skill-count number (`5.0`, `4.8`, `4.6`, `4.0`, `3.5`, `3.0`, `2.0`, `5+`, `2`) appears on both sides unchanged.

- [ ] **Step 6: Commit**

```bash
git add modes/_profile.md
git commit -m "docs: lower apply threshold to 2.6/5, plain-language rewrite of hard filters

Threshold change is independent of the discover-jobs pipeline work.
Hard-filter/location/language sections reworded for clarity only --
every exclusion, score, and number is unchanged."
```

---

## Task 5: Write `modes/discover-jobs.md` — the new discovery mode

**Files:**
- Create: `modes/discover-jobs.md`

**Interfaces:**
- Consumes: `modes/_profile.md` (hard filters, read at prompt-execution time, not import time), `cv.md` (skill/tool keyword source)
- Produces: the mode content that Task 6's test checks for required sections, and that Task 9's routine prompt tells the cloud session to follow

- [ ] **Step 1: Create the mode file**

```markdown
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

The tracker is either a Google Sheet or a published Artifact page — check
`docs/superpowers/plans/.tracker-mode` in this repo (created by this
feature's implementation plan, Task 1) if present; otherwise ask the user
which one is live. For each genuinely new, filtered, deduped candidate,
append one row:

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
```

- [ ] **Step 2: Verify the file exists and is non-empty**

```bash
node -e "const fs=require('fs'); const c=fs.readFileSync('modes/discover-jobs.md','utf8'); if (c.length < 500) { console.error('FAIL: too short'); process.exit(1); } console.log('PASS: modes/discover-jobs.md written,', c.length, 'bytes');"
```

Expected: `PASS: modes/discover-jobs.md written, <N> bytes` with N > 500.

- [ ] **Step 3: Commit**

```bash
git add modes/discover-jobs.md
git commit -m "feat: add discover-jobs mode — skill-based, tool-availability-aware discovery

Single mode covers both the cloud routine (WebSearch) and manual local
runs (Nimble Web Search Agent when available). Replaces the title-based
matching in scan.mjs/portals.yml and crawl-englishjobs.mjs."
```

---

## Task 6: Write the structural test for `discover-jobs.md`

**Files:**
- Create: `tests/discover-jobs-mode.test.mjs`

**Interfaces:**
- Consumes: `modes/discover-jobs.md` (Task 5), `AGENTS.md` (Task 7)
- Produces: nothing further downstream — this is a leaf test

- [ ] **Step 1: Write the failing test**

```javascript
// tests/discover-jobs-mode.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const modeText = readFileSync(join(ROOT, 'modes', 'discover-jobs.md'), 'utf8');
const agentsText = readFileSync(join(ROOT, 'AGENTS.md'), 'utf8');

test('discover-jobs mode documents skill-based (not title-based) query construction', () => {
  assert.match(modeText, /never.*job title/i);
  assert.match(modeText, /SAP S\/4HANA/);
});

test('discover-jobs mode documents tool-availability branching (Nimble vs WebSearch)', () => {
  assert.match(modeText, /Nimble Web Search Agent/);
  assert.match(modeText, /WebSearch/);
});

test('discover-jobs mode documents dedup on company+title', () => {
  assert.match(modeText, /\(company, job title\)/);
});

test('discover-jobs mode documents the 4-value Status column and Not Applied default', () => {
  assert.match(modeText, /Not Applied/);
  for (const status of ['Applied', 'Interview', 'Rejected']) {
    assert.match(modeText, new RegExp(status));
  }
});

test('discover-jobs mode explicitly excludes scoring at discovery time', () => {
  assert.match(modeText, /do not score/i);
});

test('AGENTS.md Skill Modes table points job search at discover-jobs', () => {
  assert.match(agentsText, /`discover-jobs`/);
});
```

- [ ] **Step 2: Run it to verify it fails on the `AGENTS.md` assertion** (Task 5 already makes the `modes/discover-jobs.md` assertions pass; Task 7 hasn't run yet)

```bash
node --test tests/discover-jobs-mode.test.mjs
```

Expected: 5 pass, 1 fail (`AGENTS.md Skill Modes table points job search at discover-jobs`).

- [ ] **Step 3: Commit** (the test file, failing-as-expected state is fine to commit — Task 7 makes it fully green)

```bash
git add tests/discover-jobs-mode.test.mjs
git commit -m "test: add structural checks for the discover-jobs mode"
```

---

## Task 7: Update `AGENTS.md` — Main Files and Skill Modes tables

**Files:**
- Modify: `AGENTS.md` (Main Files table, currently around the `scan.mjs`/`excel-tracker.mjs`/`crawl-englishjobs.mjs` rows; Skill Modes table, the "Searches for new offers" row)

**Interfaces:**
- Consumes: nothing
- Produces: satisfies Task 6's last assertion

- [ ] **Step 1: In the Main Files table, replace the three retired-script rows.** Change:
```markdown
| `scan.mjs` | Zero-token portal scanner — hits Greenhouse/Ashby/Lever APIs directly, zero LLM cost |
```
to:
```markdown
| `scan.mjs` | **Retired 2026-09-15** (title-based matching; superseded by `discover-jobs` mode) — script left in repo, scheduled task removed, no longer invoked |
```

Change:
```markdown
| `excel-tracker.mjs` | Optional lightweight Excel tracker layered on `data/applications.md`/`data/pipeline.md` — aggregator-link resolution, real JD-body re-scoring (skill%/location/salary as separate honest columns), hard floor purge (`min_score_floor`, default 2.3 — applies to every "Not Applied" row, provisional or real), daily-minimum backfill (`min_daily_rows`, default 20 — auto-runs `scan.mjs` to top up when short), hyperlinked/dropdown `.xlsx` written outside the repo with Berlin-time "Last Updated" (`config/profile.yml` → `excel_tracker.*`). Deterministic keyword-match proxy, not a replacement for `oferta`. Run via `npm run excel-tracker` or the daily `CareerOps-ExcelTracker` scheduled task. |
```
to:
```markdown
| `excel-tracker.mjs` | **Retired 2026-09-15** — `Job-Tracker.xlsx` no longer exists; superseded by the hosted tracker the `discover-jobs` mode writes to. Script and `npm run excel-tracker` left in repo, `CareerOps-ExcelTracker` scheduled task disabled. |
```

Change:
```markdown
| `crawl-englishjobs.mjs` | Daily keyword crawl of englishjobs.de into `data/pipeline.md` + `data/scan-history.tsv` (source `englishjobs.de`) — the one user-approved exception to the manual-only job-discovery house rule (see `modes/_custom.md`). Standalone script, NOT a `providers/*.mjs` module: englishjobs.de re-syndicates talent.com/jooble/stepstone/jobmesh/tideri postings, which fails the provider layer's own "one source per provider, no meta-aggregators" policy (`providers/ADDING_A_PROVIDER.md`). Keywords in `portals.yml` → `englishjobs_de_crawl.keywords` (bare skill/tool terms only, never job-title phrases — the full candidate pool, edit by hand to try a new one). Reuses `title_filter`/`location_filter` from `portals.yml` and scan.mjs's company+role dedup key (not the URL — the site's `/clickout/{id}?...` links carry a signed redirect token not assumed stable day to day). Run via `node crawl-englishjobs.mjs` (`--dry-run` to preview, doesn't touch stats) or the daily `CareerOps-EnglishJobsCrawl` scheduled task (07:30, chains into `excel-tracker.mjs`; logs to `data/englishjobs-crawl.log`). |
```
to:
```markdown
| `crawl-englishjobs.mjs` | **Retired 2026-09-15** — superseded by the `discover-jobs` mode's skill-keyword search. Script left in repo, `CareerOps-EnglishJobsCrawl` scheduled task disabled. |
```

Add a new row (near the top of the table, since this is now the primary discovery mechanism):
```markdown
| `modes/discover-jobs.md` | Skill/tool-keyword-based (never title-based) job discovery — run every 7h by an autonomous cloud routine (WebSearch) and available for manual local runs (Nimble Web Search Agent). Writes to the hosted tracker (Google Sheet or Artifact page — see `docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`). |
```

- [ ] **Step 2: In the Skill Modes table, update the discovery row.** Change:
```markdown
| Searches for new offers | `scan` |
```
to:
```markdown
| Searches for new offers | `discover-jobs` |
```

- [ ] **Step 3: Run the structural test from Task 6 — it should now be fully green**

```bash
node --test tests/discover-jobs-mode.test.mjs
```

Expected: 6 pass, 0 fail.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "docs: point AGENTS.md at discover-jobs, mark scan/excel-tracker/englishjobs-crawl retired"
```

---

## Task 8: Rewrite `modes/_custom.md` §1.x daily workflow

**Files:**
- Modify: `modes/_custom.md` (the daily-workflow section, currently §1.1–§1.6 area referencing `crawl-englishjobs.mjs`/`excel-tracker.mjs`; the "Never create a second Excel file" house rule near line 219-220; the `CLIENT_REDIRECT_GATEWAY_HOSTS` reference near line 470-474)

**Interfaces:**
- Consumes: `docs/superpowers/plans/.tracker-mode` (Task 1's decision) to know whether to say "Google Sheet" or "Artifact page" in the rewritten text
- Produces: nothing further downstream

- [ ] **Step 1: Read `docs/superpowers/plans/.tracker-mode`** to know which tracker name to use in the rewrite (`sheet` → "the Google Sheet tracker"; `artifact` → "the hosted tracker page").

- [ ] **Step 2: Replace the daily-workflow steps.** Change (§1.4 area):
```markdown
1. `node crawl-englishjobs.mjs` — one generic pass per board from the
   directory, sequential, one board fully finished before the next.
2. `node excel-tracker.mjs` — real JD fetch, scoring, purge below floor,
   write `Job-Tracker.xlsx`.
3. Short of target → escalate up §1.6's ladder, then rerun step 2.
```
to:
```markdown
1. `discover-jobs` mode runs automatically every 7 hours via a cloud
   routine (WebSearch-based) and can also be run manually in a local
   session (Nimble Web Search Agent-based, same mode, richer results) —
   see `docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`.
2. Both paths write directly to {{TRACKER_NAME}}, deduped on
   (company, job title), append-only.
3. No manual escalation ladder — the mode targets ~20 net-new qualifying
   postings per run when that many genuinely exist, and simply reports a
   smaller number rather than padding with weaker matches.
```
(Replace `{{TRACKER_NAME}}` with "the Google Sheet tracker" or "the hosted tracker page" per Step 1's reading.)

- [ ] **Step 3: Replace the "Target vs. quality bar" section.** Change:
```markdown
### §1.5 Target vs. quality bar — quality ALWAYS wins

- **Target:** `config/profile.yml` → `excel_tracker.min_daily_rows` (20)
  genuinely-new, never-applied, English-workable, live postings per day.
- **Constraint:** `excel_tracker.min_score_floor` (2.3) plus every hard
  filter in `modes/_profile.md` (language, 5+ years, modern-data-stack,
  consulting/staffing employers, Staff-level titles).
```
to:
```markdown
### §1.5 Target vs. quality bar — quality ALWAYS wins

- **Target:** ~20 genuinely-new, deduped postings per `discover-jobs` run,
  when that many exist.
- **Constraint:** every hard filter in `modes/_profile.md` (language, 5+
  years, modern-data-stack, consulting/staffing employers) — no score
  floor at discovery time, since discovery no longer scores at all.
```

- [ ] **Step 4: Remove the now-dead escalation-ladder step.** Change:
```markdown
1. Rerun `excel-tracker.mjs` if its fetch budget (`max_fetches_per_run`) was
   exhausted before the backlog was consumed — raise the budget, don't
   re-diagnose. A longer run is not a failure.
```
to: delete this step entirely (renumber any steps after it in that list).

- [ ] **Step 5: Update the "Never create a second Excel file" house rule.** Change:
```markdown
- Never create a second Excel file. There is exactly one tracker:
  `config/profile.yml` → `excel_tracker.output_path`.
- Log every job board / career site you touch to the **"Discovered Sources"**
  worksheet in that same file (Source, Type, Company, Roles found, Verdict,
```
to (if `TRACKER_NAME` resolved to `sheet` in Step 1):
```markdown
- Never create a second tracker. There is exactly one: the Google Sheet
  the discover-jobs mode writes to.
- Log every job board / career site you touch to a **"Discovered Sources"**
  tab in that same Sheet (Source, Type, Company, Roles found, Verdict,
```
(or, if `TRACKER_NAME` resolved to `artifact`, replace "Google Sheet"/"tab" with "Artifact page"/"section" analogously.)

- [ ] **Step 6: Update the `excel-tracker.mjs` internals references** (the `CLIENT_REDIRECT_GATEWAY_HOSTS`, fetch-budget, and extractor paragraphs near the end of the file) to a single retirement note:
```markdown
**Retired 2026-09-15.** The paragraphs below describe `excel-tracker.mjs`
internals (bot-gating, fetch budget, extractor precision) that no longer
run — kept only as historical context for anyone reading old commits or
reports. Current discovery logic lives in `modes/discover-jobs.md`.
```
placed immediately above the first of those paragraphs, leaving the old text below it intact as historical record (don't delete history, just label it clearly dead).

- [ ] **Step 7: Verify no remaining live (non-historical) reference to the retired scripts**

```bash
grep -n 'excel-tracker.mjs\|crawl-englishjobs.mjs' modes/_custom.md
```

Expected: every match is inside a block that either says "Retired 2026-09-15" above it, or is the historical-context paragraph explicitly labeled as such in Step 6 — manually eyeball each match to confirm none reads as a live instruction.

- [ ] **Step 8: Commit**

```bash
git add modes/_custom.md
git commit -m "docs: rewrite _custom.md daily workflow for discover-jobs, retire old escalation ladder"
```

---

## Task 9: Build the hosted tracker (branch on Task 1's result)

**Files:**
- If `TRACKER_MODE=artifact`: Create `docs/tracker-fallback-artifact.html` (source file, published via the Artifact tool, not served from the repo)
- If `TRACKER_MODE=sheet`: no repo file — the Sheet is created directly via the connector's MCP tools

**Interfaces:**
- Consumes: `docs/superpowers/plans/.tracker-mode` (Task 1)
- Produces: a tracker URL (Sheet URL or Artifact URL) that Task 10's routine prompt references

- [ ] **Step 1: Read `docs/superpowers/plans/.tracker-mode`.**

- [ ] **Step 2a (if `sheet`):** Using the Google Drive/Sheets MCP tools now available in this session, create a new spreadsheet named "Career-Ops Job Tracker" with a single sheet/tab containing the header row `#`, `Job Title`, `Company`, `Fetched`, `Status`, and data-validation on the Status column restricted to exactly `Not Applied`, `Applied`, `Interview`, `Rejected` (Not Applied as the default for new rows). Record the resulting Sheet URL.

- [ ] **Step 2b (if `artifact`):** Load the `artifact-capabilities` and `artifact-design` skills (both required before authoring/publishing an Artifact page), then write `docs/tracker-fallback-artifact.html` implementing exactly this behavior, and publish it with the Artifact tool's `db` capability enabled:
  - A table view with columns `#`, `Job Title`, `Company`, `Fetched`, `Status`.
  - Status rendered as a `<select>` per row with exactly 4 options: `Not Applied` (default), `Applied`, `Interview`, `Rejected`; changing it writes to the row's document via `write_db` (`update`, not `set`, so only the Status field changes).
  - New rows are written by the `discover-jobs` mode (running with tool access to this Artifact's `write_db`) via `db_op: "set"` on a fresh `doc_id` (e.g. the next sequential `#`), never overwriting an existing `doc_id`.
  - No client-side dedup logic needed in the page itself — dedup happens in the discover-jobs mode before it writes, per Task 5 Step 4.

  Record the resulting Artifact URL.

- [ ] **Step 3: Verify the tracker is reachable and empty (0 rows) before the first real discovery run**

For `sheet`: open the Sheet URL, confirm the header row and empty body.
For `artifact`: 
```
Artifact({action: "read_db", url: "<the artifact URL>", db_op: "list", collection: "postings"})
```
Expected: empty list.

- [ ] **Step 4: Commit** (artifact branch only — the sheet branch has no repo file to commit)

```bash
git add docs/tracker-fallback-artifact.html
git commit -m "feat: add Artifact-hosted tracker fallback (Google Sheets connector not confirmed routine-usable)"
```

---

## Task 10: Create the cloud routine

**Files:** none (cloud resource, created via `RemoteTrigger`)

**Interfaces:**
- Consumes: `modes/discover-jobs.md` content (Task 5), the tracker URL (Task 9), `TRACKER_MODE` (Task 1)
- Produces: a routine ID and `https://claude.ai/code/routines/{id}` URL to hand to the user

- [ ] **Step 1: Load the `schedule` skill and `RemoteTrigger` tool** (`ToolSearch select:RemoteTrigger` if not already loaded).

- [ ] **Step 2: Construct the routine body.** If `TRACKER_MODE=sheet`, include the confirmed connector's `connector_uuid`/`name`/`url` from Task 1's fresh-session check in `mcp_connections`; if `artifact`, omit `mcp_connections` (the Artifact tool doesn't need a connector).

```json
{
  "name": "career-ops-discover-jobs",
  "cron_expression": "0 */7 * * *",
  "enabled": true,
  "job_config": {
    "ccr": {
      "environment_id": "env_01QTRiYQUmSVt8yFAZh8mEvm",
      "session_context": {
        "model": "claude-sonnet-5",
        "sources": [
          {"git_repository": {"url": "https://github.com/bhargav-makwana/career-ops"}}
        ],
        "allowed_tools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "WebSearch"]
      },
      "events": [
        {"data": {
          "uuid": "<generate a fresh lowercase v4 uuid>",
          "session_id": "",
          "type": "user",
          "parent_tool_use_id": null,
          "message": {
            "role": "user",
            "content": "Read and follow modes/discover-jobs.md in this repo exactly. You do not have a Nimble Web Search Agent tool in this session, so use the WebSearch fallback path (Step 2's 'Otherwise' branch). The hosted tracker is at <TRACKER_URL from Task 9>. Apply every hard filter from modes/_profile.md. Append only genuinely new, deduped rows; never modify an existing row's Status."
          }
        }}
      ]
    }
  },
  "mcp_connections": []
}
```

Fill in `<generate a fresh lowercase v4 uuid>` and `<TRACKER_URL from Task 9>` with real values before sending; if `TRACKER_MODE=sheet`, replace the empty `"mcp_connections": []` with the one-element array naming the confirmed connector.

- [ ] **Step 3: Create it**

```
RemoteTrigger({action: "create", body: <the JSON from Step 2>})
```

- [ ] **Step 4: Verify it was created and is enabled**

```
RemoteTrigger({action: "get", trigger_id: "<id from Step 3's response>"})
```

Expected: `enabled: true`, `cron_expression: "0 */7 * * *"`, `next_run_at` populated.

- [ ] **Step 5: Run it once immediately to confirm it actually works end-to-end**, rather than waiting up to 7 hours to find out:

```
RemoteTrigger({action: "run", trigger_id: "<id>"})
```

Then, after a few minutes:
```
RemoteTrigger({action: "list_runs", trigger_id: "<id>"})
RemoteTrigger({action: "get_run_log", session_id: "<latest session id from list_runs>"})
```

Expected: the run log shows the WebSearch calls happening, the hard filters being read from `modes/_profile.md`, and rows landing in the tracker — check the tracker URL directly to confirm at least one real new row appeared (or zero, with an explicit "no new qualifying postings this run" note, which is also a valid successful outcome).

- [ ] **Step 6: Report the routine URL to the user**: `https://claude.ai/code/routines/{id}`.

No git commit for this task — it's a cloud resource, not a repo change.

---

## Task 11: Retire the two stale memory entries

**Files:**
- Modify: `~/.claude/projects/C--Users-Bhargav-Makwana-Desktop-career-ops/memory/job-tracker-single-source.md`
- Modify: `~/.claude/projects/C--Users-Bhargav-Makwana-Desktop-career-ops/memory/germany-job-boards-xlsx-source-of-truth.md`
- Modify: `~/.claude/projects/C--Users-Bhargav-Makwana-Desktop-career-ops/memory/MEMORY.md`

**Interfaces:**
- Consumes: nothing
- Produces: nothing (leaf task; memory isn't read by any repo code, only by future conversations)

- [ ] **Step 1: Read the current `job-tracker-single-source.md`** and prepend a retirement note (don't delete the file — it explains why the old rule existed, useful history):

```markdown
---
name: job-tracker-single-source
description: RETIRED 2026-09-15 — Job-Tracker.xlsx no longer exists; new tracker is the hosted Sheet/Artifact from discover-jobs mode. Kept as history.
metadata:
  type: project
---

**RETIRED 2026-09-15.** Job-Tracker.xlsx (referenced below) was deleted/lost
and excel-tracker.mjs is retired. The current single tracker is whatever
`docs/superpowers/specs/2026-09-15-skill-based-job-discovery-design.md`'s
Output section names (Google Sheet or Artifact page) — see
[[skill-based-job-discovery]] if that memory exists, or the spec file
directly. Original content below, kept for history only.

[... original body follows unchanged ...]
```

- [ ] **Step 2: Read the current `germany-job-boards-xlsx-source-of-truth.md`** and apply the same retirement-note pattern (prepend, don't delete), noting it was `crawl-englishjobs.mjs`'s keyword source and that script is retired.

- [ ] **Step 3: Update `MEMORY.md`** — change the two index lines for these memories to note RETIRED, matching the existing style already used for `manual-job-search-direction.md` (already marked `RETIRED 2026-09-14` in the index — follow that exact pattern):

```markdown
- [Job tracker is single-source](job-tracker-single-source.md) — RETIRED 2026-09-15, Job-Tracker.xlsx no longer exists; see discover-jobs spec
- [Germany job boards xlsx = source of truth](germany-job-boards-xlsx-source-of-truth.md) — RETIRED 2026-09-15, crawl-englishjobs.mjs retired
```

- [ ] **Step 4: No automated test** — memory files aren't read by any repo script; verify by reading both files back and confirming the retirement note is present and the original content is still there below it.

- [ ] **Step 5: No git commit** — the memory directory is outside the `career-ops` repo (`~/.claude/projects/...`), not tracked by this repo's git.

---

## Final Verification (run after all tasks)

- [ ] **Step 1: Run the full existing test suite to confirm nothing broke**

```bash
node test-all.mjs
```

Expected: same pass count as before this feature, plus the 6 new tests from Task 6, 0 failures.

- [ ] **Step 2: Run the new test file directly**

```bash
node --test tests/discover-jobs-mode.test.mjs
```

Expected: 6 pass, 0 fail.

- [ ] **Step 3: Confirm both scheduled tasks are disabled**

```powershell
Get-ScheduledTask -TaskName "CareerOps-ExcelTracker","CareerOps-EnglishJobsCrawl" | Select-Object TaskName, State
```

Expected: both `Disabled`.

- [ ] **Step 4: Confirm the routine ran successfully at least once and the tracker has real rows (or an explicit zero-new-postings note) from that run** — re-check via `RemoteTrigger({action: "list_runs", ...})` and the tracker URL directly.

---

## Self-Review Notes (completed during plan authoring)

- **Spec coverage:** every spec section (Discovery mode, Output, Deduplication, Trigger, Threshold/doc edits, Open Risk, Explicitly out of scope) maps to a task above (Tasks 5/6/7 → Discovery mode; Task 9 → Output; Task 5 Step 4 → Deduplication; Task 10 → Trigger; Tasks 3/4/7/8 → the doc/config edits; Task 1 → Open Risk; "Explicitly out of scope" items are simply not tasked, confirmed absent from every task above).
- **Placeholder scan:** no TBD/TODO; every code/config block above is the literal content to write, not a description of it.
- **Type consistency:** `TRACKER_MODE` (`sheet`|`artifact`) is produced once in Task 1 and consumed identically in Tasks 8, 9, 10; the dedup key `(company, job title)` and the 4 Status values are named identically in the spec, Task 5's mode content, and Task 6's test.
