#!/usr/bin/env bash
#
# check-stale.sh — flag ACTIVE threads whose heartbeat has gone stale.
#
# The one protocol step that was still manual: spotting abandoned
# threads. This script reads THREADS.md, finds every ACTIVE row, and
# reports any whose heartbeat is older than the staleness threshold
# (default 2h per kit spec; override with KIT_STALE_HOURS).
#
# Heartbeats are timestamps in the registry ("YYYY-MM-DD HH:MM", local
# time — same format heartbeat.sh and register-thread.sh write). A
# missing/blank heartbeat counts as stale only when the row's Started
# timestamp is also old (a just-registered thread hasn't needed a
# refresh yet).
#
# Column-safe: resolves Thread/Started/Heartbeat/Status by HEADER NAME
# (v2/v3/v4 registries).
#
# Usage:
#   ./check-stale.sh <threads.md>              # human report, exit 0
#   ./check-stale.sh <threads.md> --strict     # also exit 1 if stale
#
# Exit 0  → no stale threads (or report-only with stale found)
# Exit 1  → --strict mode: stale thread(s) found — flag before reclaim
# Exit 2  → usage / input error
#
# Both table formats supported:
#   v3: | Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |
#   v2: | Thread | Started | Tasks | Mutexes | Shared Files | Heartbeat | Status |

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib/registry-parse.sh" ] && . "$SCRIPT_DIR/lib/registry-parse.sh"

usage() {
  cat <<EOF
Usage: $0 <threads.md> [--strict]
  --strict    exit 1 when stale threads are found (CI gate / claim guard)
  env         KIT_STALE_HOURS  staleness threshold (default: 2)
EOF
}

[ "$#" -ge 1 ] || { usage; exit 2; }

THREADS_FILE="$1"; shift || true
STRICT="no"
[ "${1:-}" = "--strict" ] && STRICT="yes"

[ -f "$THREADS_FILE" ] || { echo "ERROR: THREADS.md not found at '$THREADS_FILE'"; exit 2; }

STALE_HOURS="${KIT_STALE_HOURS:-2}"

# ---- Portable "YYYY-MM-DD HH:MM" -> epoch (local time) ----
# Strategy: `date -d` (GNU) → `date -j` (BSD/macOS) → awk mktime (gawk)
# → manual civil-date arithmetic (universal POSIX fallback, UTC-aligned:
# staleness only needs coarse age, so timezone skew of a few hours is
# acceptable for the manual path; the date-tool paths are exact).
registry_epoch() { # echoes epoch seconds, or nothing on failure
  local ts="$1" e
  # GNU date
  e="$(date -d "$ts" +%s 2>/dev/null)" || e=""
  # BSD/macOS date: "2026-09-02 13:18" -> -f "%Y-%m-%d %H:%M"
  if [ -z "$e" ]; then
    e="$(date -j -f '%Y-%m-%d %H:%M' "$ts" +%s 2>/dev/null)" || e=""
  fi
  if [ -n "$e" ] && [ "$e" -gt 0 ] 2>/dev/null; then
    printf '%s\n' "$e"
    return 0
  fi
  # Last resort: manual arithmetic (days since epoch, UTC)
  awk -v ts="$ts" 'BEGIN {
    n = split(ts, p, /[ :-]/)
    if (n < 5) exit 1
    Y = p[1] + 0; M = p[2] + 0; D = p[3] + 0; hh = p[4] + 0; mm = p[5] + 0
    if (Y < 1970 || M < 1 || M > 12 || D < 1 || D > 31) exit 1
    # days-from-civil algorithm (Howard Hinnant, public domain)
    y = (M <= 2) ? Y - 1 : Y
    era = int((y >= 0 ? y : y - 399) / 400)
    yoe = y - era * 400
    doy = int((153 * (M + (M > 2 ? -3 : 9)) + 2) / 5) + D - 1
    doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
    days = era * 146097 + doe - 719468
    print days * 86400 + hh * 3600 + mm * 60
  }' 2>/dev/null || true
}

NOW_EPOCH="$(date +%s)"
STALE_SECS=$(( STALE_HOURS * 3600 ))

# Extract ACTIVE rows: "name|heartbeat|started" — header-name
# resolution via lib/registry-parse.sh (v2/v3/v4-safe); legacy rows
# (column count predating the header) get positional resolution for
# known layouts; positional fallback only when the library is absent.
get_rows() {
  if type registry_read >/dev/null 2>&1; then
    registry_read "$(cat "$THREADS_FILE")"
    local r
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      # universal resolution — legacy rows resolve by their own layout
      [ "$(registry_col_any "$r" Status "")" = "ACTIVE" ] || continue
      printf '%s|%s|%s\n' \
        "$(registry_col_any "$r" Thread "?")" \
        "$(registry_col_any "$r" Heartbeat "")" \
        "$(registry_col_any "$r" Started)"
    done < <(registry_rows)
  else
    awk -F'|' '
      /^\|/ && !/\| *-+/ && !/Thread *\|/ {
        status = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", status)
        if (status != "ACTIVE") next
        name = $2; gsub(/^[ \t]+|[ \t]+$/, "", name)
        started = $3; gsub(/^[ \t]+|[ \t]+$/, "", started)
        # v2 (NF=9): HB=$8 · v3 (NF=10): HB=$8 · v4 (NF=12): HB=$10
        hb = (NF == 12) ? $10 : $8
        gsub(/^[ \t]+|[ \t]+$/, "", hb)
        print name "|" hb "|" started
      }' "$THREADS_FILE"
  fi
}

stale=0
while IFS= read -r r; do
  [ -z "$r" ] && continue
  IFS='|' read -r name hb started <<< "$r"
  [ -z "$name" ] && continue

  # Parse heartbeat; fall back to Started when heartbeat is blank/unparseable
  hb_epoch="$(registry_epoch "$hb")"
  note=""
  if [ -z "$hb_epoch" ] || [ "$hb_epoch" -le 0 ] 2>/dev/null; then
    hb_epoch="$(registry_epoch "$started")"
    note="(no usable heartbeat — using Started)"
  fi

  if [ -z "$hb_epoch" ] || [ "$hb_epoch" -le 0 ] 2>/dev/null; then
    echo "WARN: '$name' has unparseable timestamps (hb='$hb' started='$started') — check manually"
    continue
  fi

  age=$(( NOW_EPOCH - hb_epoch ))
  if [ "$age" -gt "$STALE_SECS" ]; then
    hours=$(( age / 3600 ))
    echo "STALE: '$name' — no heartbeat for ~${hours}h (last: ${hb}) ${note}"
    stale=1
  fi
done < <(get_rows)

if [ "$stale" -eq 1 ]; then
  echo
  echo "Reclaim protocol: flag the thread in START_HERE.md notifications"
  echo "first, then reclaim only after the flag is visible. Never silently"
  echo "deregister a thread that may still be live."
  [ "$STRICT" = "yes" ] && exit 1
  exit 0
fi

echo "OK: no stale threads (threshold ${STALE_HOURS}h)."
exit 0
