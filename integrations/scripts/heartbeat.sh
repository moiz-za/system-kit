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
# Column-safe: resolves the Heartbeat column by HEADER NAME (works on
# v2/v3/v4 registries; never writes the wrong column).
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
. "$SCRIPT_DIR/lib/registry-parse.sh"

[ "$#" -eq 2 ] || { echo "Usage: $0 <docs-folder> <thread-name>"; exit 2; }

DOCS="$1"; NAME="$2"
THREADS="$DOCS/THREADS.md"
[ -f "$THREADS" ] || { echo "ERROR: no THREADS.md at '$THREADS'"; exit 2; }

registry_acquire "$DOCS" REGISTRY || exit 1
cleanup() { registry_release "$DOCS" REGISTRY; }
trap cleanup EXIT

registry_read "$(cat "$THREADS")"

# Resolve the Heartbeat column index from the header by name; if the
# header lacks it (ancient hand-made tables), fall back to the field
# before Status.
HB_IDX="$(printf '%s' "$REG_HEADER" | awk -F'|' '
  { for (i = 1; i <= NF; i++) { v = $i; gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v == "Heartbeat") { print i; exit } } }')"
[ -z "$HB_IDX" ] && HB_IDX="AUTO"

NOW="$(date '+%Y-%m-%d %H:%M')"

TMP="$THREADS.tmp"
awk -v name="$NAME" -v now="$NOW" -v hb_idx="$HB_IDX" '
  BEGIN { OFS = "|" }
  /^## Active Threads/ { in_active = 1; print; next }
  in_active && /^## / && !/^## Active Threads/ { in_active = 0; print; next }
  in_active && (/^\| *Thread/ || /^\| *-+/) { print; next }
  in_active && /^\|/ {
    n = split($0, f, "|")
    rname = f[2]; gsub(/^[ \t]+|[ \t]+$/, "", rname)
    status = f[n-1]; gsub(/^[ \t]+|[ \t]+$/, "", status)
    if (rname == name && status == "ACTIVE") {
      idx = (hb_idx == "AUTO") ? (n - 2) : hb_idx + 0
      f[idx] = " " now " "
      line = ""
      for (i = 1; i <= n; i++) line = line (i > 1 ? "|" : "") f[i]
      print line
      found = 1
      next
    }
    print; next
  }
  { print }
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
