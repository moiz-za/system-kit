#!/usr/bin/env bash
#
# register-thread.sh — THE atomic claim operation for System Kit.
#
# Tier 0 (filesystem core) + optional Tier 1 (git) modes. A claim is
# only valid through this script (or the manual protocol it enforces):
#
#   1. Acquire the REGISTRY lock (no two claims can interleave).
#   2. Reject duplicate ACTIVE thread names.
#   3. Scope-overlap check vs every ACTIVE main-tree row.
#   4. Insert the row into THREADS.md Active Threads.
#   5. Flip the TASKS.md task row OPEN -> CLAIMED(<thread>).
#   6. Write the .kit-thread identity file (read by the pre-commit hook).
#   7. Release the lock.
#
# Usage:
#   register-thread.sh <docs-folder> <thread-name> <task-id> [mode] [scope...]
#
#     docs-folder   project governance folder (holds THREADS.md)
#     thread-name   unique short name, e.g. alpha
#     task-id       TASKS.md row ID, e.g. T-041
#     mode          main (default) | worktree (git) | copy (no-git isolation)
#     scope...      one or more files/dirs this thread may write.
#                   Directory scopes end with / (e.g. src/api/).
#
# Exit 0  → registered; row added; task claimed
# Exit 1  → refused (duplicate, scope overlap, task not OPEN, lock timeout)
# Exit 2  → usage / input error
#
# Scope matching: exact path OR directory containment (dir scopes keep
# their trailing slash; claims are matched as "<dir>*" prefixes).
# Isolated-tree threads (worktree/copy) do not conflict with main-tree
# scopes — their edits live elsewhere until MERGE-guarded merge-back.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/registry-lock.sh"

usage() {
  cat <<EOF
Usage: $0 <docs-folder> <thread-name> <task-id> [mode] [scope...]
  docs-folder   governance folder containing THREADS.md + workflow/TASKS.md
  thread-name   unique thread identifier (e.g. alpha)
  task-id       task row to claim (e.g. T-041)
  mode          main (default) | worktree | copy
  scope...      file(s)/dir(s) this thread may write; dirs end with /

Example:
  $0 docs alpha T-041 main src/api/ src/api/schemas.ts
EOF
}

[ "$#" -ge 3 ] || { usage; exit 2; }

DOCS="$1"; NAME="$2"; TASK="$3"; shift 3

MODE="main"
if [ "$#" -gt 0 ]; then
  case "$1" in
    main|worktree|copy) MODE="$1"; shift ;;
  esac
fi

if [ "$#" -eq 0 ]; then
  echo "ERROR: declare at least one scope path (file or dir)."
  echo "  Scope is what makes parallel CODE claims safe."
  exit 2
fi

THREADS="$DOCS/THREADS.md"
TASKS="$DOCS/workflow/TASKS.md"
[ -f "$THREADS" ] || { echo "ERROR: no THREADS.md at '$THREADS'"; exit 2; }
[ -f "$TASKS" ]   || TASKS=""

# Project root: parent of docs folder. Git root (if any) resolved from there.
PROJ="$(cd "$DOCS/.." && pwd)"
GITROOT="$(git -C "$PROJ" rev-parse --show-toplevel 2>/dev/null || true)"

fail() { echo "REFUSED: $*"; exit 1; }

# ---- Row parsing (both table formats) ----
# New: | Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |
# Old: | Thread | Started | Tasks | Mutexes | Shared Files | Heartbeat | Status |
# awk sees a trailing empty field after the final pipe, so Status = $(NF-1);
# Scope/Shared-Files is $6 in both; Tree exists only in new ($7 when NF>=10).

active_rows() { # emits "name|scope|tree" per ACTIVE row
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
    }' "$THREADS"
}

# True (0) if claimed path $1 overlaps owned path $2.
# Directory scopes end with / — containment is a simple prefix match.
overlap() {
  local claim="$1" owner="$2"
  { [ -z "$claim" ] || [ -z "$owner" ]; } && return 1
  [ "$claim" = "$owner" ] && return 0
  case "$claim" in "$owner"*) return 0 ;; esac
  case "$owner"  in "$claim"*) return 0 ;; esac
  return 1
}

SCOPE_LIST="$*"
NOW="$(date '+%Y-%m-%d %H:%M')"

# Worktree mode without git falls back to main-tree work — which MUST
# then be scope-checked like any main-tree claim. Copy mode never
# falls back (cp always available on POSIX).
GUARD_SCOPE="no"
case "$MODE" in
  main) GUARD_SCOPE="yes" ;;
  worktree) [ -n "$GITROOT" ] || GUARD_SCOPE="yes" ;;
esac

# ---- THE ATOMIC CLAIM (every step under the registry lock) ----
registry_acquire "$DOCS" REGISTRY || exit 1
cleanup() { registry_release "$DOCS" REGISTRY; }
trap cleanup EXIT

# Duplicate ACTIVE-name guard
while IFS= read -r r; do
  [ -z "$r" ] && continue
  [ "${r%%|*}" = "$NAME" ] && fail "thread '$NAME' is already registered."
done < <(active_rows)

# Scope-overlap guard (main-tree claims vs main-tree owners).
# Isolated-tree claims (worktree/copy) skip this: their edits live in
# a separate tree and any collision surfaces at MERGE-guarded
# merge-back, not during work.
if [ "$GUARD_SCOPE" = "yes" ]; then
  for s in $SCOPE_LIST; do
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      IFS='|' read -r oname oscope otree <<< "$r"
      [ "$otree" = "main" ] || continue
      if overlap "$s" "$oscope"; then
        fail "scope '$s' overlaps active thread '$oname' (owns '$oscope')."
      fi
    done < <(active_rows)
  done
fi

# Task-status guard
if [ -n "$TASKS" ]; then
  task_row="$(grep -F "| $TASK |" "$TASKS" | head -1)"
  [ -n "$task_row" ] || fail "task '$TASK' not found in $TASKS."
  status="$(printf '%s\n' "$task_row" | awk -F'|' '{v=$(NF-1); gsub(/^[ \t]+|[ \t]+$/,"",v); print v}')"
  [ "$status" = "OPEN" ] || fail "task '$TASK' is $status (not OPEN)."
fi

# ---- Mutations (safe: we hold the lock) ----

TREE="main"
case "$MODE" in
  worktree)
    if [ -n "$GITROOT" ]; then
      BRANCH="kit/$TASK-$NAME"
      TREE="$(cd "$GITROOT/.." && pwd)/$(basename "$GITROOT")-$NAME"
      if git -C "$GITROOT" worktree add "$TREE" -b "$BRANCH" >/dev/null 2>&1; then
        echo "TREE: git worktree created at '$TREE' (branch $BRANCH)"
      else
        echo "WARN: git worktree add failed — continuing in main tree."
        TREE="main"
      fi
    else
      echo "WARN: no git repo — worktree mode unavailable, continuing in main tree."
    fi
    ;;
  copy)
    # Folder-copy isolation (no-git). Copy project WITHOUT: docs/
    # (the registry stays canonical in the main tree), other copies,
    # git internals, and governance metadata.
    COPYDIR="$PROJ/copy-$NAME"
    rm -rf "$COPYDIR"
    if mkdir -p "$COPYDIR"; then
      copied=0
      for entry in "$PROJ"/* "$PROJ"/.[!.]*; do
        [ -e "$entry" ] || continue
        base="$(basename "$entry")"
        case "$base" in
          docs|copy-*|.git|.kit-thread) continue ;;
        esac
        cp -R "$entry" "$COPYDIR/" 2>/dev/null && copied=1
      done
      if [ "$copied" = "1" ]; then
        TREE="$COPYDIR"
        echo "TREE: folder-copy created at '$TREE'. Work there; merge back at release."
      else
        echo "WARN: folder-copy failed — continuing in main tree."
        rm -rf "$COPYDIR"
      fi
    fi
    ;;
esac

# Insert the THREADS.md row right after the Active Threads separator.
# v2 registries (7-column table, no Scope/Tree) are detected from the
# header row; a main-mode claim upgrades header + separator to the v3
# columns in passing, so the registry stays machine-readable. Isolated
# modes (worktree/copy) need the v3 columns up front — refuse on v2
# rather than half-upgrade.
REG_HEADER="$(awk '/^\| *Thread/ {print; exit}' "$THREADS")"
if [ "$MODE" != "main" ] && ! printf '%s' "$REG_HEADER" | grep -q 'Scope'; then
  fail "registry uses the pre-v3 table format (no Scope/Tree columns) — isolated modes need v3 format. Re-run SETUP_PROMPT (upgrade pass) or convert the Active Threads header to the v3 columns first."
fi
UPGRADE="no"
printf '%s' "$REG_HEADER" | grep -q 'Scope' || UPGRADE="yes"

TMP="$THREADS.tmp"
awk -v row="| $NAME | $NOW | $TASK | CODE | $SCOPE_LIST | $TREE | $NOW | ACTIVE |" -v upgrade="$UPGRADE" '
  /^## Active Threads/ { in_active = 1 }
  in_active && /^## / && !/^## Active Threads/ { in_active = 0 }
  in_active && /^\| *Thread/ {
    if (upgrade == "yes") {
      print "| Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |"
    } else {
      print
    }
    getline_sep = 1; next
  }
  getline_sep == 1 && /^\| *-+/ {
    if (upgrade == "yes") {
      print "|---|---|---|---|---|---|---|---|"
    } else {
      print
    }
    print row; getline_sep = 0; next
  }
  { print }
' "$THREADS" > "$TMP"

if grep -qF "| $NAME | $NOW | $TASK |" "$TMP"; then
  mv "$TMP" "$THREADS"
else
  rm -f "$TMP"
  fail "could not insert row into THREADS.md Active Threads table (format not recognized)."
fi

# Flip TASKS.md status
if [ -n "$TASKS" ]; then
  sed "s@| $TASK |\(.*\)| OPEN |@| $TASK |\1| CLAIMED($NAME) |@" "$TASKS" > "$TASKS.new" \
    && mv "$TASKS.new" "$TASKS"
fi

# Identity file: lives in the tree this thread actually works in
if [ "$TREE" = "main" ]; then
  if [ -n "$GITROOT" ]; then IDFILE="$GITROOT/.kit-thread"; else IDFILE="$DOCS/.kit-thread"; fi
else
  IDFILE="$TREE/.kit-thread"
fi
printf 'thread=%s\ntask=%s\nmode=%s\nscope=%s\ntree=%s\nregistered=%s\n' \
  "$NAME" "$TASK" "$MODE" "$SCOPE_LIST" "$TREE" "$NOW" > "$IDFILE"

registry_release "$DOCS" REGISTRY
trap - EXIT

echo "REGISTERED: $NAME on $TASK (tree=$TREE)"
echo "  Scope: $SCOPE_LIST"
echo "  Next:  work your task; heartbeat.sh to stay alive; release-thread.sh to close out."
exit 0
