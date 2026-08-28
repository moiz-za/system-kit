#!/usr/bin/env bash
#
# validate-checkpoint.sh — Fail if any in-progress checkpoint is incomplete.
#
# A checkpoint is complete if it has all 6 required sections filled in.
# Incomplete checkpoints are a worse signal than no checkpoint at all —
# future threads will trust them and resume into broken state.
#
# Usage:
#   ./integrations/scripts/validate-checkpoint.sh <docs-folder>
#
# Exit 0  →  all complete, push safe
# Exit 1  →  incomplete checkpoint(s) found
# Exit 2  →  input error

set -eu

usage() {
  cat <<EOF
Usage: $0 <docs-folder>
  docs-folder  the directory containing CHECKPOINTS/
EOF
}

[ "$#" -eq 1 ] || { usage; exit 2; }

DOCS_DIR="$1"
CKPT_DIR="$DOCS_DIR/CHECKPOINTS"

if [ ! -d "$CKPT_DIR" ]; then
  echo "No CHECKPOINTS directory at '$CKPT_DIR' — nothing to validate."
  exit 0
fi

# Required sections (in order)
SECTIONS=(
  "## Task"
  "## Where You Stopped"
  "## Files Touched"
  "## Key Decisions Made"
  "## Context the Next Thread Needs"
  "## Verification State"
)

# The literal template is exempt (ships with placeholders, by design)
fail=0
count=0

for ckpt in "$CKPT_DIR"/[!_]*.md; do
  [ -f "$ckpt" ] || continue
  count=$((count + 1))
  name=$(basename "$ckpt")
  echo "Checking $name..."
  for section in "${SECTIONS[@]}"; do
    if ! grep -qF "$section" "$ckpt"; then
      echo "  MISSING SECTION: $section"
      fail=1
    fi
  done
  # Reject obvious placeholder leftovers (TEMPLATE markers, or empty
  # task ID like [TASK-ID])
  if grep -q '\[TASK-ID\]' "$ckpt"; then
    echo "  UNRESOLVED PLACEHOLDER: [TASK-ID] still present"
    fail=1
  fi
done

if [ "$count" -eq 0 ]; then
  echo "No checkpoints found in $CKPT_DIR. Nothing to validate."
  exit 0
fi

if [ "$fail" -eq 1 ]; then
  echo
  echo "FAIL: $count checkpoint(s) have issues. Either:"
  echo "  - complete the missing sections, or"
  echo "  - delete the checkpoint if the task is done and BUILDLOG is current."
  exit 1
fi

echo
echo "OK: all $count checkpoint(s) complete. Push is safe."
exit 0