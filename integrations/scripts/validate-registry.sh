#!/usr/bin/env bash
#
# validate-registry.sh — THREADS.md format validation.
#
# Catches the registry rot that breaks machine enforcement quietly:
# wrong column counts, empty required fields, unknown status values,
# duplicate ACTIVE thread names, and unparseable heartbeat timestamps.
# Supports both table formats:
#   v3: | Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |
#   v2: | Thread | Started | Tasks | Mutexes | Shared Files | Heartbeat | Status |
#
# Usage:
#   ./validate-registry.sh <threads.md>
#
# Exit 0  → registry well-formed
# Exit 1  → format problems found (listed with row numbers)
# Exit 2  → usage / input error

set -u

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

# --- 2. Table structure: column counts and required fields ---
# awk sees a trailing empty field after the final pipe:
#   v3 rows: NF=10 · v2 rows: NF=9
awk -F'|' '
  /^\| *Thread/ { next }                     # header
  /^\| *-+/ { next }                          # separator
  /^\|/ {
    ln = NR
    if (NF != 10 && NF != 9) {
      printf "ROW %d: column count %d (expected 9 [v2] or 10 [v3-count incl. trailing empty])\n", ln, NF
      bad = 1; next
    }
    # required non-empty fields: Thread(2) Started(3) Tasks(4) Status(NF-1)
    for (i = 2; i <= 4; i++) {
      v = $i; gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v == "") { printf "ROW %d: empty required field (column %d)\n", ln, i; bad = 1 }
    }
    s = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", s)
    if (s != "" && s != "ACTIVE" && s != "CLOSED" && s != "NOTIFY" && s != "CLAIMED") {
      printf "ROW %d: unknown status \"%s\" (expected ACTIVE/CLOSED/NOTIFY/CLAIMED)\n", ln, s; bad = 1
    }
    # heartbeat format (v3: $8, v2: $7) — warn only if clearly not a date
    hb = (NF >= 10) ? $8 : $7
    gsub(/^[ \t]+|[ \t]+$/, "", hb)
    if (hb != "" && s == "ACTIVE" && hb !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/) {
      printf "ROW %d: heartbeat \"%s\" not in YYYY-MM-DD HH:MM format\n", ln, hb; bad = 1
    }
  }
  END { exit (bad ? 1 : 0) }
' "$THREADS_FILE" || FAIL=1

# --- 3. Duplicate ACTIVE thread names ---
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

# --- 4. Header declares a known format ---
HEADER="$(awk '/^\| *Thread/ {print; exit}' "$THREADS_FILE")"
if [ -n "$HEADER" ]; then
  printf '%s' "$HEADER" | grep -q 'Scope' || printf '%s' "$HEADER" | grep -q 'Shared Files' \
    || { echo "UNKNOWN TABLE HEADER: $HEADER (neither v3 nor v2 format)"; FAIL=1; }
fi

if [ "$FAIL" -eq 1 ]; then
  echo
  echo "Registry format problems found. Fix them before the next claim —"
  echo "malformed rows silently bypass machine enforcement."
  exit 1
fi

echo "OK: registry format valid (sections, columns, statuses, uniqueness)."
exit 0
