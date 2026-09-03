#!/usr/bin/env bash
#
# validate-registry.sh — THREADS.md format validation.
#
# Catches the registry rot that breaks machine enforcement quietly:
# wrong column counts, empty required fields, unknown status values,
# unknown lanes, duplicate ACTIVE thread names, and unparseable
# heartbeat timestamps.
#
# Column-safe: resolves every column by HEADER NAME (v2/v3/v4 all
# validate; a v2/v3 row inside an upgraded v4 table is legal — absent
# Lane/Model read as defaults, and the row's own column count must
# match the header's column count).
#
# Usage:
#   ./validate-registry.sh <threads.md>
#
# Exit 0  → registry well-formed
# Exit 1  → format problems found (listed with row numbers)
# Exit 2  → usage / input error

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib/registry-parse.sh" ] && . "$SCRIPT_DIR/lib/registry-parse.sh"

usage() {
  echo "Usage: $0 <threads.md>"
}

[ "$#" -eq 1 ] || { usage; exit 2; }
THREADS_FILE="$1"
[ -f "$THREADS_FILE" ] || { echo "ERROR: THREADS.md not found at '$THREADS_FILE'"; exit 2; }

FAIL=0

# --- 1. Required sections exist ---
grep -q '^## Active Threads' "$THREADS_FILE" || { echo "MISSING SECTION: '## Active Threads'"; FAIL=1; }
grep -q '^## Recently Completed' "$THREADS_FILE" || { echo "MISSING SECTION: '## Recently Completed'"; FAIL=1; }

# --- 2. Header sanity + expected column count from the header itself ---
if [ -n "${REG_HEADER:-}" ] || true; then :; fi
registry_read "$(cat "$THREADS_FILE")"
if [ -z "$REG_HEADER" ]; then
  echo "MISSING HEADER: Active Threads table has no '| Thread ...' header row"
  exit 1
fi
FMT="$(registry_format)"
case "$FMT" in
  4) : ;;
  3) : ;;
  2) : ;;
  *) echo "UNKNOWN TABLE HEADER: $REG_HEADER (neither v2, v3, nor v4 format)"; exit 1 ;;
esac
# Every data row must carry the SAME pipe-field count as the header row
# (awk NF counts the empty fields before the first and after the last
# pipe — derive the expected count from the header itself, no guessing).
EXPECT_NF="$(printf '%s' "$REG_HEADER" | awk -F'|' '{print NF}')"

# --- 3. Row structure: column count + required fields + values ---
awk -F'|' -v expect_nf="$EXPECT_NF" '
  /^\| *Thread/ { next }
  /^\| *-+/ { next }
  /^\|/ {
    ln = NR
    if (NF != expect_nf) {
      printf "ROW %d: column count %d (expected %d for this header)\n", ln, NF, expect_nf
      bad = 1; next
    }
    for (i = 2; i <= 4; i++) {
      v = $i; gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v == "") { printf "ROW %d: empty required field (column %d)\n", ln, i; bad = 1 }
    }
    s = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", s)
    if (s != "" && s != "ACTIVE" && s != "CLOSED" && s != "NOTIFY" && s != "CLAIMED") {
      printf "ROW %d: unknown status \"%s\" (expected ACTIVE/CLOSED/NOTIFY/CLAIMED)\n", ln, s; bad = 1
    }
  }
  END { exit (bad ? 1 : 0) }
' "$THREADS_FILE" || FAIL=1

# --- 4. Per-row value checks via header-name resolution ---
LN=0
while IFS= read -r line; do
  LN=$((LN + 1))
  printf '%s' "$line" | grep -q '^|' || continue
  printf '%s' "$line" | grep -qE '^\| *-+|^\| *Thread' && continue
  # only rows inside the Active table
  RNAME="$(registry_col "$line" Thread)"
  [ -z "$RNAME" ] && continue
  RSTATUS="$(registry_col "$line" Status)"
  # Lane value check (v4+ only — absent column reads default CODE)
  if [ -n "${REG_IDX_LANE:-}" ]; then
    RLANE="$(registry_col "$line" Lane CODE)"
    case "$RLANE" in
      STRATEGY|DOCS|CODE|DEPLOY) ;;
      "") ;;
      *) echo "ROW $LN: unknown lane \"$RLANE\" (expected STRATEGY/DOCS/CODE/DEPLOY)"; FAIL=1 ;;
    esac
  fi
  # heartbeat format — warn only when clearly not a date
  if [ "$RSTATUS" = "ACTIVE" ]; then
    RHB="$(registry_col "$line" Heartbeat "")"
    if [ -n "$RHB" ] && ! printf '%s' "$RHB" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}'; then
      echo "ROW $LN: heartbeat \"$RHB\" not in YYYY-MM-DD HH:MM format"
      FAIL=1
    fi
  fi
done < "$THREADS_FILE"

# --- 5. Duplicate ACTIVE thread names ---
DUPS="$(awk -F'|' '
  /^\|/ && !/\| *-+/ && !/Thread *\|/ {
    status = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", status)
    if (status != "ACTIVE") next
    name = $2; gsub(/^[ \t]+|[ \t]+$/, "", name)
    if (name != "") print name
  }' "$THREADS_FILE" | sort | uniq -d)"
if [ -n "$DUPS" ]; then
  echo "DUPLICATE ACTIVE THREAD NAME(S): $DUPS"
  FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
  echo
  echo "Registry format problems found. Fix them before the next claim —"
  echo "malformed rows silently bypass machine enforcement."
  exit 1
fi

echo "OK: registry format valid (v$FMT — sections, columns, statuses, lanes, uniqueness)."
exit 0
