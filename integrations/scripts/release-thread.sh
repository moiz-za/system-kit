#!/usr/bin/env bash
#
# release-thread.sh — atomic deregister + close-out for a registered thread.
#
# Under the REGISTRY lock:
#   1. Verify clean tree (git main-tree mode, CODE lane only).
#   2. Isolated trees (worktree/copy): merge back under the MERGE mutex,
#      then remove the tree (heartbeat stamped post-merge so a long
#      merge can never be reclaimed mid-close-out).
#   3. Move the THREADS.md row Active -> Recently Completed.
#   4. Flip TASKS.md CLAIMED -> DONE.
#   5. Remove the .kit-thread identity file.
#   6. CODE lane + deployable project: remind about the Deploy Handoff.
#
# Column-safe: all row fields resolved by HEADER NAME (v2/v3/v4).
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
. "$SCRIPT_DIR/lib/registry-parse.sh"

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

registry_acquire "$DOCS" REGISTRY || exit 1
cleanup() { registry_release "$DOCS" REGISTRY; }
trap cleanup EXIT

registry_read "$(cat "$THREADS")"

# Find own ACTIVE row (header-name resolution)
OWN_ROW=""; OWN_TASK=""; OWN_TREE="main"; OWN_LANE="CODE"
while IFS= read -r r; do
  [ -z "$r" ] && continue
  if [ "$(registry_col "$r" Thread)" = "$NAME" ]; then
    if [ "$(registry_col "$r" Status)" = "ACTIVE" ]; then
      OWN_ROW="$r"
      OWN_TASK="$(registry_col "$r" Tasks)"
      OWN_TREE="$(registry_col "$r" Tree main)"
      OWN_LANE="$(registry_col "$r" Lane CODE)"
    fi
  fi
done < <(registry_rows)
[ -n "$OWN_ROW" ] || fail "thread '$NAME' has no ACTIVE row in THREADS.md."

# Clean-tree handoff (git, main tree, CODE lane only). Governance
# metadata and the registry itself are always allowed untracked —
# threads are REQUIRED to update THREADS.md/TASKS.md at close-out.
if [ "$OWN_TREE" = "main" ] && [ "$OWN_LANE" = "CODE" ] && [ -n "$GITROOT" ]; then
  DIRTY="$(git -C "$GITROOT" status --porcelain 2>/dev/null | grep -vE '^\?\? (\.kit-thread|docs/\.locks/|docs/THREADS\.md|docs/workflow/)' || true)"
  if [ -n "$DIRTY" ]; then
    fail "working tree is dirty. Commit or stash before releasing CODE (clean-tree handoff)."
  fi
fi

NOW="$(date '+%Y-%m-%d %H:%M')"

# ---- Merge back isolated trees under MERGE ----
if [ "$OWN_TREE" != "main" ] && [ -d "$OWN_TREE" ]; then
  registry_acquire "$DOCS" MERGE || fail "MERGE mutex busy — another merge in flight. Retry shortly."
  if [ -n "$GITROOT" ] && [ -d "$OWN_TREE/.git" ]; then
    BRANCH="kit/$OWN_TASK-$NAME"
    if git -C "$GITROOT" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
      if ! git -C "$GITROOT" merge "$BRANCH" --no-edit >/dev/null 2>&1; then
        registry_release "$DOCS" MERGE
        fail "merge of '$BRANCH' had conflicts. Resolve in the repo, then re-run release."
      fi
    fi
    rm -f "$OWN_TREE/.kit-thread" 2>/dev/null || true
    git -C "$GITROOT" worktree remove "$OWN_TREE" >/dev/null 2>&1 || rm -rf "$OWN_TREE"
  else
    echo "MERGE: copying back changed files from '$OWN_TREE'..."
    ( cd "$OWN_TREE" && find . -type f ! -path './.kit-thread' ! -path './.git/*' ) 2>/dev/null \
      | while IFS= read -r f; do
      f="${f#./}"
      if [ ! -f "$PROJ/$f" ] || ! cmp -s "$OWN_TREE/$f" "$PROJ/$f"; then
        mkdir -p "$PROJ/$(dirname "$f")"
        cp "$OWN_TREE/$f" "$PROJ/$f" && echo "  merged: $f"
      fi
    done
    rm -rf "$OWN_TREE"
  fi
  # merge proves liveness — stamp it so a long merge can't be reclaimed
  if [ -f "$SCRIPT_DIR/heartbeat.sh" ]; then
    "$SCRIPT_DIR/heartbeat.sh" "$DOCS" "$NAME" >/dev/null 2>&1 || true
  fi
  registry_release "$DOCS" MERGE
fi

# ---- Move row Active -> Recently Completed ----
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

# ---- Flip TASKS.md CLAIMED -> DONE (escape sed metacharacters) ----
if [ -f "$TASKS" ] && [ -n "$OWN_TASK" ]; then
  ESC_NAME="$(printf '%s' "$NAME" | sed 's/[][\.*^$\/]/\\&/g')"
  sed "s@CLAIMED($ESC_NAME)@DONE@" "$TASKS" > "$TASKS.new" && mv "$TASKS.new" "$TASKS"
fi

# ---- Remove identity file ----
for f in "$GITROOT/.kit-thread" "$DOCS/.kit-thread" "$OWN_TREE/.kit-thread"; do
  rm -f "$f" 2>/dev/null || true
done

registry_release "$DOCS" REGISTRY
trap - EXIT

echo "RELEASED: $NAME — task $OWN_TASK DONE, moved to Recently Completed."
if [ "$OWN_LANE" = "CODE" ] && [ -f "$DOCS/workflow/DEPLOY_QUEUE.md" ]; then
  echo "  DEPLOY LANE: file a Deploy Handoff"
  echo "  (workflow/DEPLOY_HANDOFF_TEMPLATE.md) and add the queue entry —"
  echo "  the deploy thread refuses incomplete handoffs."
fi
echo "  Remaining close-out: BUILDLOG entry + PENDING-OWNER update if needed."
exit 0
