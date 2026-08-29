#!/usr/bin/env bash
# Safe wrapper around `node update-system.mjs apply`.
#
# update-system.mjs already refuses to blindly commit the whole index when
# something unrelated is pre-staged (see its own comments around the #915
# bug) — it computes the correct scoped `git commit -m ... -- <pathspec>`
# form itself and prints it if its own git invocation fails (this happens on
# Windows when the pathspec list is long enough to exceed cmd.exe's ~8191
# char command-line limit). The one and only rule for finishing an update by
# hand is: run EXACTLY the command update-system.mjs prints, never a bare
# `git commit` — a bare commit sweeps in whatever else happens to be staged.
#
# This script automates that recovery deterministically instead of leaving
# it to manual (error-prone) copy-paste.
#
# Sensitive/user-layer files (cv.md, config/profile.yml, modes/_profile.md,
# modes/_custom.md, data/*, reports/*, output/*, the locked CV docx) are
# never part of what update-system.mjs stages in the first place — this
# script adds a belt-and-braces check that aborts loudly if any of them
# somehow show up in the diff about to be committed.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

SENSITIVE_PATTERN='^(cv\.md|config/profile\.yml|modes/_profile\.md|modes/_custom\.md|data/|reports/|output/|templates/bhargav_makwana_cv\.docx)'

check_json="$(node update-system.mjs check 2>&1)"
status="$(node -e "console.log(JSON.parse(process.argv[1]).status)" "$check_json" 2>/dev/null || echo "parse-error")"

if [ "$status" != "update-available" ]; then
  echo "safe-update: status=$status, nothing to do."
  exit 0
fi

# "update-available" with reason "system-files-changed" fires forever once
# local==remote for a customized install (CLAUDE.md is deliberately kept
# different from upstream's generic version, and SYSTEM_PATHS diffing has no
# concept of "known intentional customization"). Only act when the version
# itself is actually behind — otherwise this would re-run apply (and mint a
# new backup branch) every single time this script fires, forever, for no
# real update.
version_behind="$(node -e '
  const d = JSON.parse(process.argv[1]);
  const cmp = (a, b) => {
    const pa = a.split(".").map(Number), pb = b.split(".").map(Number);
    for (let i = 0; i < 3; i++) { if ((pa[i]||0) !== (pb[i]||0)) return (pa[i]||0) - (pb[i]||0); }
    return 0;
  };
  console.log(cmp(d.local, d.remote) < 0 ? "yes" : "no");
' "$check_json" 2>/dev/null || echo "no")"

if [ "$version_behind" != "yes" ]; then
  echo "safe-update: local already matches remote version; system-files-changed drift is expected local customization (e.g. CLAUDE.md), not a real update. Nothing to do."
  exit 0
fi

echo "safe-update: update available, applying..."
apply_log="$(mktemp)"
if node update-system.mjs apply >"$apply_log" 2>&1; then
  echo "safe-update: apply finished cleanly (no manual git step needed)."
  cat "$apply_log"
  rm -f "$apply_log"
  exit 0
fi

# apply() exited non-zero. If it's the known "finish manually" case, extract
# and run the EXACT recovery command block it printed (git add already ran
# inside apply(); only the commit step is left).
if grep -q "Please run manually to finish the update:" "$apply_log"; then
  recovery_cmd="$(sed -n '/Please run manually to finish the update:/,$p' "$apply_log" | tail -n +2 | sed 's/^[[:space:]]*//')"
  echo "safe-update: apply left a commit unfinished, running its own recovery command verbatim:"
  echo "$recovery_cmd"

  # Belt-and-braces: never let this recovery commit touch sensitive files,
  # regardless of what git status says right now.
  if git status --short | awk '{print $2}' | grep -qE "$SENSITIVE_PATTERN"; then
    echo "safe-update: ABORT — a sensitive/user-layer file is showing as changed. Not committing. Investigate manually." >&2
    cat "$apply_log"
    rm -f "$apply_log"
    exit 1
  fi

  eval "$recovery_cmd"
  echo "safe-update: recovery commit done."
  rm -f "$apply_log"
  exit 0
fi

echo "safe-update: apply failed for an unrecognized reason — not auto-recovering." >&2
cat "$apply_log"
rm -f "$apply_log"
exit 1
