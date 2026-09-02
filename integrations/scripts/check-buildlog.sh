#!/usr/bin/env bash
#
# check-buildlog.sh — append-only discipline check for BUILDLOG.md (git).
#
# The BUILDLOG is the project's history: entries may be ADDED, never
# deleted or rewritten. This script compares the BUILDLOG in a commit
# range against its previous state and fails if any existing line was
# removed or modified. Appends and pure additions pass.
#
# Usage (from the project root, or pass the repo path):
#   ./check-buildlog.sh [git-repo] [commit-range]
#
#   git-repo       defaults to current directory
#   commit-range   defaults to HEAD~1..HEAD (the last commit)
#                  CI should pass $BASE_SHA..HEAD
#
# Exit 0  → append-only discipline held (or BUILDLOG absent/unchanged)
# Exit 1  → history was rewritten (lines removed or modified)
# Exit 2  → usage / not a git repo / BUILDLOG not tracked

set -u

REPO="${1:-.}"
RANGE="${2:-HEAD~1..HEAD}"

usage() {
  cat <<EOF
Usage: $0 [git-repo] [commit-range]
  git-repo       project root (default: current dir)
  commit-range   e.g. HEAD~1..HEAD or \$BASE..HEAD
EOF
}

git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "ERROR: '$REPO' is not a git repository — this check is git-only."
  echo "       Non-git projects: the BUILDLOG is the only audit trail;"
  echo "       pair with host-level backups instead."
  exit 2
}

# Locate the tracked BUILDLOG (docs/workflow/ or workflow/ or root)
BLOG="$(git -C "$REPO" ls-files '*BUILDLOG.md' | head -1)"
if [ -z "$BLOG" ]; then
  echo "WARN: no tracked BUILDLOG.md found — nothing to check."
  exit 0
fi

OLD="$(git -C "$REPO" show "${RANGE%%..*}:$BLOG" 2>/dev/null || true)"
if [ -z "$OLD" ]; then
  # range start has no BUILDLOG (first commit adding it) — pure addition
  echo "OK: BUILDLOG did not exist at range start — addition is append-only by definition."
  exit 0
fi

NEW="$(git -C "$REPO" show "${RANGE##*..}:$BLOG" 2>/dev/null || true)"

# Every line present in OLD must still exist in NEW (order-insensitive
# matching: appends anywhere in the table are fine; any vanished or
# altered line is a violation). Deleted-in-both cases and blank lines
# are skipped.
VIOLATIONS=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \|*) ;; *) continue ;; esac   # only table rows are history
  if ! printf '%s\n' "$NEW" | grep -qF -- "$line"; then
    echo "REMOVED/CHANGED ENTRY: $line"
    VIOLATIONS=1
  fi
done < <(printf '%s\n' "$OLD")

if [ "$VIOLATIONS" -eq 1 ]; then
  echo
  echo "FAIL: BUILDLOG history was rewritten. Corrections must be NEW entries"
  echo "referencing the old ones — never edits or deletions."
  exit 1
fi

echo "OK: BUILDLOG append-only discipline held ($BLOG, $RANGE)."
exit 0
