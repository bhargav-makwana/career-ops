# Career-Ops -- AI Job Search Pipeline

Everything else lives in `AGENTS.md` (imported below) — it's the shared, canonical source read by every supported CLI, and it's kept more complete than this file (e.g. more languages, more skill modes, more file docs). This file holds only content that genuinely differs for Claude Code.

## ⛔ TOP-PRIORITY RULES — READ FIRST, EVERY SESSION

These are the non-negotiables, in priority order. If anything below conflicts with a rule further down in this file or in `AGENTS.md`, **these win.** Break one and the work is wrong no matter how good the rest is.

1. **CV & COVER-LETTER FORMAT — USE THE USER'S TEMPLATES, NEVER INVENT ONE.**
   - **CV:** ALWAYS generated from the docx template `templates/bhargav_makwana_cv.docx` and exported to PDF via Microsoft Word (COM automation: `ExportAsFixedFormat`, format `17`). This preserves the exact layout the user expects.
   - **NEVER render the CV through `templates/cv-template.html` / `generate-pdf.mjs`** — it produces a different-looking output the user does not want. `config/profile.yml` confirms: `cv.template: templates/bhargav_makwana_cv.docx`, `cv.output_format: docx`.
   - **Cover letter:** generated via `generate-cover-letter.mjs` + `templates/cover-letter-template.html` (this format is correct).
   - Confirm the CV format from the docx template as the **first step** of any CV task.

2. **NEVER FABRICATE CONTENT.** All user-facing text (CV, cover letters, emails, form answers) comes ONLY from `cv.md`, `config/profile.yml`, `modes/_profile.md`, `article-digest.md`, `writing-samples/`, `interview-prep/`, plus what the user says in-conversation. Reorder/reframe/emphasise — never invent. No unbacked metrics, no authorship claims. If a claim isn't backed, ask or leave it out.

3. **NEVER SUBMIT/SEND ANYTHING.** Fill forms, draft answers, generate PDFs — then STOP before Submit/Send/Apply. The user makes the final call, always.

4. **VERIFY THE POSTING IS LIVE** before treating it as applyable — see Offer Verification below. Never decide liveness from a bare WebSearch/WebFetch snippet.

5. **RESPECT THE DATA CONTRACT.** Personalization goes to `modes/_profile.md` or `config/profile.yml` — NEVER edit system-layer files (`modes/_shared.md`, scripts) for user-specific content. User-layer files are never auto-updated. Full list in `DATA_CONTRACT.md`.

## Offer Verification -- MANDATORY

Verify a posting is still live before applying — using the cheapest check that works (a false "expired" is worse than a slow check: it makes the user miss a real job):

1. **ATS-hosted postings (Greenhouse, Lever, ...) — API first, zero tokens:** run `node check-liveness.mjs <url>`. It hits the posting's public ATS JSON API directly (no browser, no tokens) and reports `active`/`expired`, falling back to a browser only when the API is inconclusive. A definitive `expired` from the API is authoritative.
2. **Non-ATS pages, or when the API is inconclusive — Playwright:** `browser_navigate` to the URL + `browser_snapshot`. Only footer/navbar without JD = closed; title + description + Apply = active.

**NEVER decide liveness from a bare WebSearch/WebFetch snippet** — use `check-liveness.mjs` (which does the API rung) or Playwright.

**Exception for batch workers (`claude -p`):** Playwright is unavailable in headless pipe mode. The API rung above still works for ATS postings; for non-ATS pages use WebFetch as a fallback and mark the report header `**Verification:** unconfirmed (batch mode)`.

> Note: `AGENTS.md`'s own Offer Verification section is out of date — it says to always use Playwright and doesn't mention `check-liveness.mjs`. This file's version above is the one Claude Code actually follows. Worth syncing `AGENTS.md` to match so Codex/OpenCode/etc. get the same zero-token check.

@AGENTS.md
<!-- Add anything Claude Code specific that other agents don't need -->
