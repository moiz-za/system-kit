#!/usr/bin/env bash
#
# heartbeat.sh — stamp the current time into your THREADS.md row.
#
# A heartbeat proves your thread is alive. Stale rows (no heartbeat for
# 2h+) are reclaimable after flagging in START_HERE.md notifications.
# The pre-commit hook records commits as heartbeats automatically;
# use this script for long work between commits or in filesystem-only
# mode.
#
# Usage:
#   heartbeat.sh <docs-folder> <thread-name>
#
# Exit 0  → heartbeat stamped
# Exit 1  → not registered / lock timeout
# Exit 2  → usage error

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/registry-lock.sh"

[ "$#" -eq 2 ] || { echo "Usage: $0 <docs-folder> <thread-name>"; exit 2; }

DOCS="$1"; NAME="$2"
THREADS="$DOCS/THREADS.md"
[ -f "$THREADS" ] || { echo "ERROR: no THREADS.md at '$THREADS'"; exit 2; }

registry_acquire "$DOCS" REGISTRY || exit 1
cleanup() { registry_release "$DOCS" REGISTRY; }
trap cleanup EXIT

NOW="$(date '+%Y-%m-%d %H:%M')"

# Replace own row's Heartbeat field.
# New format (NF>=10): Heartbeat = $8  ·  Old format (NF=9): Heartbeat = $7
TMP="$THREADS.tmp"
awk -F'|' -v name="$NAME" -v now="$NOW" '
  BEGIN { OFS = "|" }
  NF < 3 { print; next }  # non-table lines pass through untouched
  {
    rname = $2
    if (rname != "") { gsub(/^[ \t]+|[ \t]+$/, "", rname) }
    status = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", status)
    if (rname == name && status == "ACTIVE") {
      if (NF >= 10) { $8 = " " now " " } else { $7 = " " now " " }
      found = 1
    }
    print
  }
  END { exit (found ? 0 : 1) }
' "$THREADS" > "$TMP"

if [ $? -eq 0 ]; then
  mv "$TMP" "$THREADS"
else
  rm -f "$TMP"
  echo "REFUSED: thread '$NAME' has no ACTIVE row in THREADS.md."
  exit 1
fi

registry_release "$DOCS" REGISTRY
trap - EXIT

echo "HEARTBEAT: $NAME stamped $NOW"
exit 0
