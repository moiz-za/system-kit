#!/usr/bin/env bash
#
# release-thread.sh — atomic deregister + close-out for a registered thread.
#
# Under the REGISTRY lock:
#   1. Verify clean tree (git main-tree mode only).
#   2. Isolated trees (worktree/copy): merge back under the MERGE mutex,
#      then remove the tree.
#   3. Move the THREADS.md row Active -> Recently Completed.
#   4. Flip TASKS.md CLAIMED -> DONE.
#   5. Remove the .kit-thread identity file.
#
# Usage:
#   release-thread.sh <docs-folder> <thread-name> [summary]
#
# Exit 0  → released; task DONE; isolated tree merged/removed
# Exit 1  → refused (not registered, dirty tree, lock timeout, merge conflict)
# Exit 2  → usage error

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/registry-lock.sh"

usage() {
  cat <<EOF
Usage: $0 <docs-folder> <thread-name> [summary]
  summary   one-line close-out note for Recently Completed (optional)
EOF
}

[ "$#" -ge 2 ] || { usage; exit 2; }

DOCS="$1"; NAME="$2"; SUMMARY="${3:-task closed}"
THREADS="$DOCS/THREADS.md"
TASKS="$DOCS/workflow/TASKS.md"
[ -f "$THREADS" ] || { echo "ERROR: no THREADS.md at '$THREADS'"; exit 2; }

PROJ="$(cd "$DOCS/.." && pwd)"
GITROOT="$(git -C "$PROJ" rev-parse --show-toplevel 2>/dev/null || true)"

fail() { echo "REFUSED: $*"; exit 1; }

# Extract own ACTIVE row: "tasks|tree"
own_row() {
  awk -F'|' -v name="$NAME" '
    /^\|/ && !/\| *-+/ && !/Thread *\|/ {
      rname = $2; gsub(/^[ \t]+|[ \t]+$/, "", rname)
      if (rname != name) next
      status = $(NF-1); gsub(/^[ \t]+|[ \t]+$/, "", status)
      if (status != "ACTIVE") next
      tasks = $4; gsub(/^[ \t]+|[ \t]+$/, "", tasks)
      tree = (NF >= 10) ? $7 : "main"
      gsub(/^[ \t]+|[ \t]+$/, "", tree)
      if (tree == "") tree = "main"
      print tasks "|" tree
      exit
    }' "$THREADS"
}

registry_acquire "$DOCS" REGISTRY || exit 1
cleanup() { registry_release "$DOCS" REGISTRY; }
trap cleanup EXIT

INFO="$(own_row)"
[ -n "$INFO" ] || fail "thread '$NAME' has no ACTIVE row in THREADS.md."
TASK="${INFO%%|*}"; TREE="${INFO#*|}"

# Clean-tree handoff (git, main tree). Governance metadata and the
# registry itself are always allowed untracked — threads are REQUIRED
# to update THREADS.md/TASKS.md as part of close-out.
if [ "$TREE" = "main" ] && [ -n "$GITROOT" ]; then
  DIRTY="$(git -C "$GITROOT" status --porcelain 2>/dev/null | grep -vE '^\?\? (\.kit-thread|docs/\.locks/|docs/THREADS\.md|docs/workflow/)' || true)"
  if [ -n "$DIRTY" ]; then
    fail "working tree is dirty. Commit or stash before releasing CODE (clean-tree handoff)."
  fi
fi

NOW="$(date '+%Y-%m-%d %H:%M')"

# ---- Merge back isolated trees under MERGE ----
if [ "$TREE" != "main" ] && [ -d "$TREE" ]; then
  registry_acquire "$DOCS" MERGE || fail "MERGE mutex busy — another merge in flight. Retry shortly."
  if [ -n "$GITROOT" ] && [ -d "$TREE/.git" ]; then
    # git worktree: merge its branch back into the main tree
    BRANCH="kit/$TASK-$NAME"
    if git -C "$GITROOT" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
      if ! git -C "$GITROOT" merge "$BRANCH" --no-edit >/dev/null 2>&1; then
        registry_release "$DOCS" MERGE
        fail "merge of '$BRANCH' had conflicts. Resolve in the repo, then re-run release."
      fi
    fi
    # worktree remove refuses when untracked files exist (e.g. .kit-thread)
    rm -f "$TREE/.kit-thread" 2>/dev/null || true
    git -C "$GITROOT" worktree remove "$TREE" >/dev/null 2>&1 || rm -rf "$TREE"
  else
    # folder-copy merge-back: copy every file that differs from main
    echo "MERGE: copying back changed files from '$TREE'..."
    ( cd "$TREE" && find . -type f ! -path './.kit-thread' ! -path './.git/*' ) 2>/dev/null \
      | while IFS= read -r f; do
      f="${f#./}"
      if [ ! -f "$PROJ/$f" ] || ! cmp -s "$TREE/$f" "$PROJ/$f"; then
        mkdir -p "$PROJ/$(dirname "$f")"
        cp "$TREE/$f" "$PROJ/$f" && echo "  merged: $f"
      fi
    done
    rm -rf "$TREE"
  fi
  # A merge under MERGE proves liveness — stamp it into the row's
  # heartbeat so the thread cannot be reclaimed mid-close-out even if
  # the merge took longer than the staleness threshold.
  if [ -f "$SCRIPT_DIR/heartbeat.sh" ]; then
    "$SCRIPT_DIR/heartbeat.sh" "$DOCS" "$NAME" >/dev/null 2>&1 || true
  fi
  registry_release "$DOCS" MERGE
fi

# ---- Move row Active -> Recently Completed ----
# Ensure a Recently Completed section exists (append one if missing so
# close-out never fails on a hand-trimmed registry).
if ! grep -q '^## Recently Completed' "$THREADS"; then
  printf '\n## Recently Completed\n\n| Thread | Ended | Summary |\n|---|---|---|\n' >> "$THREADS"
fi
TMP="$THREADS.tmp"
awk -v name="$NAME" '
  /^## Active Threads/ { in_active = 1 }
  /^## Recently Completed/ { in_active = 0 }
  in_active && index($0, "| " name " |") == 1 { next }
  { print }
' "$THREADS" > "$TMP"

printf '| %s | %s | %s |\n' "$NAME" "$NOW" "$SUMMARY" > "$TMP.row"
awk -v rowfile="$TMP.row" '
  /^## Recently Completed/ { seen = 1 }
  seen == 1 && /^\| *-+/ && !done { print; while ((getline line < rowfile) > 0) print line; done = 1; next }
  { print }
' "$TMP" > "$TMP.2"

if awk '/^## Recently Completed/,0' "$TMP.2" | grep -qF "| $NAME |"; then
  mv "$TMP.2" "$THREADS"
  rm -f "$TMP" "$TMP.row"
else
  rm -f "$TMP" "$TMP.2" "$TMP.row"
  fail "could not write Recently Completed entry (format not recognized)."
fi

# ---- Flip TASKS.md CLAIMED -> DONE ----
if [ -f "$TASKS" ] && [ -n "$TASK" ]; then
  sed "s@CLAIMED($NAME)@DONE@" "$TASKS" > "$TASKS.new" && mv "$TASKS.new" "$TASKS"
fi

# ---- Remove identity file ----
for f in "$GITROOT/.kit-thread" "$DOCS/.kit-thread" "$TREE/.kit-thread"; do
  rm -f "$f" 2>/dev/null || true
done

registry_release "$DOCS" REGISTRY
trap - EXIT

echo "RELEASED: $NAME — task $TASK DONE, moved to Recently Completed."
echo "  Remaining close-out: BUILDLOG entry + PENDING-OWNER update if needed."
exit 0
