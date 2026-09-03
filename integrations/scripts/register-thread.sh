#!/usr/bin/env bash
#
# register-thread.sh — THE atomic claim operation for System Kit.
#
# Tier 0 (filesystem core) + optional Tier 1 (git) modes + four-lane
# thread system (STRATEGY / DOCS / CODE / DEPLOY). A claim is only
# valid through this script (or the manual protocol it enforces):
#
#   1. Acquire the REGISTRY lock (no two claims can interleave).
#   2. Reject duplicate ACTIVE thread names.
#   3. Scope-overlap check vs every ACTIVE main-tree row.
#   4. Insert the row into THREADS.md (upgrading an older-format
#      registry header to the current v4 columns in passing).
#   5. Flip the TASKS.md task row OPEN -> CLAIMED(<thread>).
#   6. Write the .kit-thread identity file (read by the pre-commit hook).
#   7. Release the lock.
#
# Usage:
#   register-thread.sh <docs-folder> <thread-name> <task-id> [mode] [scope...]
#   register-thread.sh <docs-folder> <thread-name> <task-id> --lane LANE [--model M] [mode] [scope...]
#
#     docs-folder   project governance folder (holds THREADS.md)
#     thread-name   unique short name, e.g. alpha
#     task-id       TASKS.md row ID, e.g. T-041
#     lane          STRATEGY | DOCS | CODE (default) | DEPLOY
#                   - lane sets the mutex automatically:
#                     STRATEGY/DOCS -> LEDGER · CODE -> CODE · DEPLOY -> DEPLOY
#                   - DEPLOY claims: check DEPLOY_QUEUE.md for a complete
#                     handoff before executing anything (refusal rule)
#     model         free-form observability label (which LLM the thread
#                   runs on). NEVER a gate or a law — lineups are swappable.
#     mode          main (default) | worktree (git) | copy (no-git isolation)
#     scope...      files/dirs this thread may write (dirs end with /).
#                   Required for CODE/DOCS lanes; globs supported
#                   (src/**/*.test.ts). STRATEGY/DEPLOY work on ledgers +
#                   handoffs, so a scope is optional for them.
#
# Exit 0  → registered; row added; task claimed
# Exit 1  → refused (duplicate, scope overlap, task not OPEN, lock timeout)
# Exit 2  → usage / input error

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/registry-lock.sh"
. "$SCRIPT_DIR/lib/scope-match.sh"
. "$SCRIPT_DIR/lib/registry-parse.sh"

usage() {
  cat <<EOF
Usage: $0 <docs-folder> <thread-name> <task-id> [--lane LANE] [--model M] [mode] [scope...]
  docs-folder   governance folder containing THREADS.md + workflow/TASKS.md
  thread-name   unique thread identifier (e.g. alpha)
  task-id       task row to claim (e.g. T-041)
  lane          STRATEGY | DOCS | CODE (default) | DEPLOY
  model         observability label for the LLM in use (never a gate)
  mode          main (default) | worktree | copy
  scope...      file(s)/dir(s) this thread may write; dirs end with /

Examples:
  $0 docs alpha T-041 main src/api/
  $0 docs plan1 T-050 --lane STRATEGY
  $0 docs dep1 T-060 --lane DEPLOY --model m2
EOF
}

[ "$#" -ge 3 ] || { usage; exit 2; }

DOCS="$1"; NAME="$2"; TASK="$3"; shift 3

# --- option parsing: --lane/--model first, then mode + scope ---
LANE="CODE"
MODEL=""
MODE="main"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lane)  [ "${2:-}" = "" ] && { usage; exit 2; }; LANE="$2"; shift 2 ;;
    --model) [ "${2:-}" = "" ] && { usage; exit 2; }; MODEL="$2"; shift 2 ;;
    main|worktree|copy) MODE="$1"; shift ;;
    -*) echo "ERROR: unknown option '$1'"; usage; exit 2 ;;
    *) break ;;  # first scope token — rest is scope
  esac
done

case "$LANE" in
  STRATEGY|DOCS|CODE|DEPLOY) : ;;
  *) echo "ERROR: lane must be STRATEGY, DOCS, CODE, or DEPLOY (got '$LANE')"; exit 2 ;;
esac

# lane -> mutex (the lane system's core mapping)
case "$LANE" in
  STRATEGY|DOCS) MUTEX="LEDGER" ;;
  CODE)          MUTEX="CODE" ;;
  DEPLOY)        MUTEX="DEPLOY" ;;
esac

# scope requirement by lane
SCOPE_REQUIRED="no"
case "$LANE" in
  CODE|DOCS) SCOPE_REQUIRED="yes" ;;
esac

SCOPE_LIST="$*"
if [ "$SCOPE_REQUIRED" = "yes" ] && [ "$#" -eq 0 ]; then
  echo "ERROR: lane $LANE requires a declared scope (files/dirs this thread may write)."
  echo "  Scope is what makes parallel claims safe."
  exit 2
fi

THREADS="$DOCS/THREADS.md"
TASKS="$DOCS/workflow/TASKS.md"
[ -f "$THREADS" ] || { echo "ERROR: no THREADS.md at '$THREADS'"; exit 2; }
[ -f "$TASKS" ]   || TASKS=""

PROJ="$(cd "$DOCS/.." && pwd)"
GITROOT="$(git -C "$PROJ" rev-parse --show-toplevel 2>/dev/null || true)"

fail() { echo "REFUSED: $*"; exit 1; }

registry_read "$(cat "$THREADS")"

# True (0) if claimed path $1 overlaps owned path $2 (dirs + globs).
overlap() {
  scope_entry_overlaps_entry "$1" "$2"
}

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

# Re-read under the lock (state may have changed since first read)
registry_read "$(cat "$THREADS")"

# Duplicate ACTIVE-name guard (header-matching rows only)
while IFS= read -r r; do
  [ -z "$r" ] && continue
  registry_row_matches_header "$r" || continue
  [ "$(registry_col "$r" Thread)" = "$NAME" ] && fail "thread '$NAME' is already registered."
done < <(registry_rows)

# Legacy/mismatched rows cannot be resolved by header position —
# warn until repaired (the next close-out of that thread upgrades its
# row in passing; the owner can also fix manually). Silently guessing
# columns on a mismatched row is how scope checks miss real overlaps.
MISMATCHED="$(while IFS= read -r r; do
  [ -z "$r" ] && continue
  registry_row_matches_header "$r" || printf '%s\n' "$(printf '%s' "$r" | awk -F'|' '{v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}')"
done < <(registry_rows))"
if [ -n "$MISMATCHED" ]; then
  echo "WARN: registry has rows older than its header (legacy columns):"
  printf '%s\n' "$MISMATCHED" | sed 's/^/  /'
  echo "  These rows bypass column-safe parsing. Ask each thread to close out"
  echo "  (its row upgrades in passing), or re-run SETUP_PROMPT to repair."
fi

# Format guard for isolated modes (need Scope/Tree columns present)
FMT="$(registry_format)"
if [ "$MODE" != "main" ] && { [ "$FMT" = "0" ] || [ "$FMT" = "2" ]; }; then
  fail "registry lacks Scope/Tree columns (format $([ "$FMT" = 0 ] && echo unrecognized || echo v2)) — isolated modes need them. Re-run SETUP_PROMPT (upgrade pass) or let a main-mode claim upgrade the table first."
fi

# Scope-overlap guard (main-tree claims vs main-tree owners).
# Isolated-tree claims (worktree/copy) skip this: their edits live in
# a separate tree and any collision surfaces at MERGE-guarded
# merge-back, not during work. DEPLOY/STRATEGY lanes hold no code
# scope in the working tree.
if [ "$GUARD_SCOPE" = "yes" ]; then
  for s in $SCOPE_LIST; do
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      # universal resolution: header rows by name, legacy rows by their
      # own layout — a legacy scope that escapes checking is a hole.
      if ! oscope="$(registry_col_any "$r" Scope "" 2>/dev/null)"; then
        fail "active row '$(registry_col_any "$r" Thread "?")' has an unrecognized column layout. Repair the registry before claiming."
      fi
      otree="$(registry_col_any "$r" Tree main)"
      oname="$(registry_col_any "$r" Thread "?")"
      [ "$otree" = "main" ] || continue
      if [ -n "$oscope" ] && overlap "$s" "$oscope"; then
        fail "scope '$s' overlaps active thread '$oname' (owns '$oscope')."
      fi
    done < <(registry_rows)
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

# Build the new row in the registry's CURRENT format — upgrading an
# older header (v2/v3) to v4 in passing so the table stays machine-
# readable. Existing rows keep their column count until they close;
# absent v4 fields read as defaults (Lane=CODE, Model=-) via the
# header-name resolver, so old rows parse correctly in every consumer.
UPGRADE="no"
[ "$FMT" = "4" ] || UPGRADE="yes"
NEW_HEADER="$(registry_v4_header)"
NEW_SEP="$(registry_v4_separator)"
MODEL_VAL="$MODEL"; [ -z "$MODEL_VAL" ] && MODEL_VAL="-"
NEW_ROW="| $NAME | $NOW | $TASK | $LANE | $MUTEX | $SCOPE_LIST | $TREE | $MODEL_VAL | $NOW | ACTIVE |"

TMP="$THREADS.tmp"
awk -v header="$NEW_HEADER" -v sep="$NEW_SEP" -v row="$NEW_ROW" -v upgrade="$UPGRADE" '
  /^## Active Threads/ { in_active = 1 }
  in_active && /^## / && !/^## Active Threads/ { in_active = 0 }
  in_active && /^\| *Thread/ {
    if (upgrade == "yes") {
      print header
      getline_sep = 1
      next
    }
    print; getline_sep = 1; next
  }
  getline_sep == 1 && /^\| *-+/ {
    if (upgrade == "yes") { print sep } else { print }
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

# Flip TASKS.md status (escape sed metacharacters in the name)
ESC_NAME="$(printf '%s' "$NAME" | sed 's/[][\.*^$\/]/\\&/g')"
if [ -n "$TASKS" ]; then
  sed "s@| $TASK |\(.*\)| OPEN |@| $TASK |\1| CLAIMED($ESC_NAME) |@" "$TASKS" > "$TASKS.new" \
    && mv "$TASKS.new" "$TASKS"
fi

# Identity file: lives in the tree this thread actually works in
if [ "$TREE" = "main" ]; then
  if [ -n "$GITROOT" ]; then IDFILE="$GITROOT/.kit-thread"; else IDFILE="$DOCS/.kit-thread"; fi
else
  IDFILE="$TREE/.kit-thread"
fi
printf 'thread=%s\ntask=%s\nlane=%s\nmodel=%s\nmode=%s\nscope=%s\ntree=%s\nregistered=%s\n' \
  "$NAME" "$TASK" "$LANE" "$MODEL_VAL" "$MODE" "$SCOPE_LIST" "$TREE" "$NOW" > "$IDFILE"

registry_release "$DOCS" REGISTRY
trap - EXIT

echo "REGISTERED: $NAME on $TASK (lane=$LANE, mutex=$MUTEX, tree=$TREE)"
echo "  Scope: ${SCOPE_LIST:--}"
[ -n "$MODEL" ] && echo "  Model: $MODEL (observability only)"
if [ "$LANE" = "CODE" ]; then
  echo "  Close-out: release-thread.sh + a completed Deploy Handoff"
  echo "  (workflow/DEPLOY_HANDOFF_TEMPLATE.md) if this project deploys."
elif [ "$LANE" = "DEPLOY" ]; then
  echo "  Next: open workflow/DEPLOY_QUEUE.md — claim the top entry whose"
  echo "  handoff is COMPLETE; refuse incomplete ones (refusal rule)."
fi
echo "  Next:  work your task; heartbeat.sh to stay alive; release-thread.sh to close out."
exit 0
