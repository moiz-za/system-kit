#!/usr/bin/env bash
#
# check-scope-overlap.sh — Machine-checkable file scope declarations.
#
# Usage:
#   ./integrations/scripts/check-scope-overlap.sh <threads.md> <file...>
#
# Reads the Active Threads table in THREADS.md, extracts every live thread's
# "Shared Files" column, and checks whether any of the files you're about to
# claim are already owned by another active thread.
#
# Exit 0  →  clean, no overlap, safe to claim CODE
# Exit 1  →  overlap found, DO NOT claim CODE (see message)
# Exit 2  →  usage / input error
#
# Scope matching: exact path match OR directory containment
# (e.g. claiming "src/api/tasks.ts" when another thread owns "src/api/tasks.ts"
#  OR "src/api/" both count as overlap).
#
# Stale threads (>4h no heartbeat) are reported but NOT auto-claimed —
# reclaiming still requires the human step (flag in START_HERE.md §5).

set -eu

usage() {
  cat <<EOF
Usage: $0 <threads.md> <file...>
  threads.md  path to THREADS.md (Active Threads table)
  file...     the files this thread is about to claim

  Example:
    $0 docs/THREADS.md "src/api/tasks.ts" "src/api/schemas.ts"
EOF
}

if [ "$#" -lt 1 ]; then usage; exit 2; fi

THREADS_FILE="$1"
shift

if [ ! -f "$THREADS_FILE" ]; then
  echo "ERROR: THREADS.md not found at '$THREADS_FILE'"
  exit 2
fi

# Normalize: strip CR, drop blank lines, drop the header + separator rows.
# Shared Files is column 5 (Thread|Started|Tasks|Mutexes|Shared Files|Heartbeat|Status).
normalize() {
  sed 's/\r$//' "$THREADS_FILE" \
    | grep -v '^| *- ' \
    | grep -v '^| *Thread ' \
    | grep -v '^$'
}

overlap() {
  # $1 = claimed path, $2 = owner path
  local claim="$1" owner="$2"
  # Exact match
  [ "$claim" = "$owner" ] && return 0
  # Directory containment (owner is a directory prefix of claim, or vice versa)
  case "$claim" in
    "$owner"/*) return 0 ;;
  esac
  case "$owner" in
    "$claim"/*) return 0 ;;
  esac
  return 1
}

any_owners=()
while IFS= read -r line; do
  # Only ACTIVE rows; split on | and take field 5
  status=$(echo "$line" | awk -F'|' '{for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i)} print $NF}')
  files=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$5); print $5}')
  if [ -z "$files" ]; then continue; fi
  case "$status" in
    ACTIVE) : ;;
    *) continue ;;  # CLAIMED/COMPLETED/NOTIFY — only ACTIVE threads own files
  esac
  IFS=' ,' read -ra farr <<< "$files"
  for f in "${farr[@]}"; do
    [ -z "$f" ] && continue
    any_owners+=("$f")
  done
done < <(normalize)

if [ "${#any_owners[@]}" -eq 0 ]; then
  echo "No active threads own files. Clean claim."
  exit 0
fi

conflict=0
for claim in "$@"; do
  for owner in "${any_owners[@]}"; do
    if overlap "$claim" "$owner"; then
      echo "CONFLICT: '$claim' is already owned by an active thread (shared file: '$owner')"
      conflict=1
    fi
  done
done

if [ "$conflict" -eq 1 ]; then
  echo
  echo "DO NOT claim CODE for these files. Either:"
  echo "  - notify the owning thread (post in START_HERE.md §5), or"
  echo "  - claim a different OPEN task with a non-overlapping scope."
  exit 1
fi

echo "Clean: no scope overlap with any active thread. Safe to claim."
exit 0