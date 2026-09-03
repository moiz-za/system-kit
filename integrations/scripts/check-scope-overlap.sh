#!/usr/bin/env bash
#
# check-scope-overlap.sh — machine-checkable file scope declarations.
#
# Usage:
#   ./integrations/scripts/check-scope-overlap.sh <threads.md> <file...>     # claim mode
#   ./integrations/scripts/check-scope-overlap.sh <threads.md> --all         # CI mode
#
# Claim mode: check whether files you are about to claim overlap any
# ACTIVE main-tree thread's declared scope.
#
# CI mode (--all): verify no two ACTIVE threads' main-tree scopes
# overlap — the machine-checked parallel-safety gate.
#
# Column-safe: resolves Thread/Scope/Tree/Status by HEADER NAME via
# lib/registry-parse.sh — works on v2/v3/v4 registries (and any future
# column addition) without positional changes.
# Isolated-tree rows (worktree/copy) are excluded from main-tree
# conflict checks — their edits live in separate trees until merge.
#
# Exit 0  → clean, no overlap
# Exit 1  → overlap found, DO NOT claim / CI FAIL
# Exit 2  → usage / input error

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib/scope-match.sh" ] && . "$SCRIPT_DIR/lib/scope-match.sh"
if [ -f "$SCRIPT_DIR/lib/registry-parse.sh" ]; then
  . "$SCRIPT_DIR/lib/registry-parse.sh"
  PARSE_LIB="yes"
else
  PARSE_LIB="no"
fi

usage() {
  cat <<EOF
Usage: $0 <threads.md> <file...> | <threads.md> --all
  threads.md  path to THREADS.md (Active Threads table)
  file...     the files/dirs this thread is about to claim (claim mode)
  --all       check all ACTIVE threads pairwise (CI mode)

Examples:
  Claim:  $0 docs/THREADS.md "src/api/tasks.ts" "src/api/"
  CI:     $0 docs/THREADS.md --all
EOF
}

[ "$#" -ge 2 ] || { usage; exit 2; }

THREADS_FILE="$1"; shift

[ -f "$THREADS_FILE" ] || { echo "ERROR: THREADS.md not found at '$THREADS_FILE'"; exit 2; }

# Extract ACTIVE rows as "name|scope|tree" — universal resolution:
# header-matching rows by header name, legacy rows (count predating
# the header) by their own known layout. Never skipped — a legacy scope
# that escapes checking is a collision hole.
get_active() {
  if [ "$PARSE_LIB" = "yes" ]; then
    registry_read "$(cat "$THREADS_FILE")"
    local r
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      [ "$(registry_col_any "$r" Status "")" = "ACTIVE" ] || continue
      printf '%s|%s|%s\n' \
        "$(registry_col_any "$r" Thread "?")" \
        "$(registry_col_any "$r" Scope "")" \
        "$(registry_col_any "$r" Tree main)"
    done < <(registry_rows)
  else
    awk -F'|' '
      /^\|/ && !/\| *-+/ && !/Thread *\|/ {
        status = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", status)
        if (status != "ACTIVE") next
        name = $2; gsub(/^[ \t]+|[ \t]+$/, "", name)
        scope = $6; gsub(/^[ \t]+|[ \t]+$/, "", scope)
        tree = (NF >= 10) ? $7 : "main"
        gsub(/^[ \t]+|[ \t]+$/, "", tree)
        if (tree == "") tree = "main"
        print name "|" scope "|" tree
      }' "$THREADS_FILE"
  fi
}

overlap() { # $1 claimed path, $2 owner path (dirs end with /; globs supported)
  if type scope_entry_overlaps_entry >/dev/null 2>&1; then
    scope_entry_overlaps_entry "$1" "$2"
    return
  fi
  # fallback (standalone use without lib/scope-match.sh): plain prefix
  local claim="$1" owner="$2"
  { [ -z "$claim" ] || [ -z "$owner" ]; } && return 1
  [ "$claim" = "$owner" ] && return 0
  case "$claim" in "$owner"*) return 0 ;; esac
  case "$owner"  in "$claim"*) return 0 ;; esac
  return 1
}

# ---- CI mode: pairwise check of all ACTIVE threads ----
if [ "${1:-}" = "--all" ]; then
  shift  # drop --all
  TMPROWS="$(mktemp)"
  get_active > "$TMPROWS"
  if [ ! -s "$TMPROWS" ]; then
    echo "No active threads. Registry clean."
    rm -f "$TMPROWS"; exit 0
  fi
  conflict=0
  # nested read loops over the same file need distinct fds (bash 3.2 safe)
  while IFS= read -r r1 <&3; do
    [ -z "$r1" ] && continue
    while IFS= read -r r2 <&4; do
      [ -z "$r2" ] && continue
      [ "$r1" = "$r2" ] && continue  # same row — skip self-comparison
      IFS='|' read -r n1 s1 t1 <<< "$r1"
      IFS='|' read -r n2 s2 t2 <<< "$r2"
      # Only MAIN-tree scopes conflict during work; isolated-tree
      # (worktree/copy) edits live elsewhere and surface at MERGE.
      [ "$t1" = "main" ] && [ "$t2" = "main" ] || continue
      for p1 in $s1; do
        for p2 in $s2; do
          if overlap "$p1" "$p2"; then
            echo "CONFLICT (CI): '$n1' scope '$p1' overlaps '$n2' scope '$p2'"
            conflict=1
          fi
        done
      done
    done 4< "$TMPROWS"
  done 3< "$TMPROWS"
  rm -f "$TMPROWS"
  if [ "$conflict" -eq 1 ]; then
    echo "FAIL: overlapping scopes among ACTIVE threads."
    exit 1
  fi
  echo "Clean: no scope overlaps among active threads."
  exit 0
fi

# ---- Claim mode: proposed paths vs active main-tree owners ----
TMPROWS="$(mktemp)"
get_active | awk -F'|' '$3 == "main" {print $1 "|" $2}' > "$TMPROWS"

conflict=0
for claim in "$@"; do
  while IFS= read -r pair; do
    [ -z "$pair" ] && continue
    oname="${pair%%|*}"; oscope="${pair#*|}"
    if overlap "$claim" "$oscope"; then
      echo "CONFLICT: '$claim' overlaps active thread '$oname' (owns '$oscope')"
      conflict=1
    fi
  done < "$TMPROWS"
done
rm -f "$TMPROWS"

if [ "$conflict" -eq 1 ]; then
  echo
  echo "DO NOT claim this scope. Either:"
  echo "  - notify the owning thread (START_HERE.md notifications), or"
  echo "  - claim a different OPEN task with a non-overlapping scope, or"
  echo "  - use worktree/copy mode for isolated parallel work."
  exit 1
fi

echo "Clean: no scope overlap with any active main-tree thread. Safe to claim."
exit 0
