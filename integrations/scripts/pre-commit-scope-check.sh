#!/usr/bin/env bash
#
# pre-commit-scope-check.sh — Tier 1 (git) enforcement hook.
#
# Rejects commits containing files OUTSIDE the committing thread's
# declared scope. Scope comes from .kit-thread (written by
# register-thread.sh, read here). No identity file → human/owner
# commit → warn and allow.
#
# Side effect: stamps .locks/last-commit so commits count as
# heartbeats (atomic append; no registry lock needed).
#
# Install (from the project root, once):
#   cp <kit>/integrations/scripts/pre-commit-scope-check.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Exit 0  → commit allowed (all staged files in scope, or no identity)
# Exit 1  → commit REJECTED (out-of-scope file staged)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib/scope-match.sh" ] && . "$SCRIPT_DIR/lib/scope-match.sh"

GITDIR="$(git rev-parse --git-dir 2>/dev/null)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

# Locate identity file: this tree first, then main tree (worktrees)
IDFILE=""
for c in "$ROOT/.kit-thread" "$GITDIR/.kit-thread"; do
  [ -f "$c" ] && IDFILE="$c" && break
done

stamp_commit() { # commit-as-heartbeat
  for d in "$ROOT/docs/.locks" "$ROOT/docs"; do
    if [ -d "$d" ]; then
      printf '%s\n' "$(date '+%Y-%m-%d %H:%M')" >> "$d/last-commit" 2>/dev/null || true
      return
    fi
  done
}

if [ -z "$IDFILE" ]; then
  echo "[kit] no .kit-thread identity — human/owner commit, allowing."
  stamp_commit
  exit 0
fi

THREAD="$(grep '^thread=' "$IDFILE" | cut -d= -f2-)"
SCOPE="$(grep '^scope=' "$IDFILE" | cut -d= -f2-)"
[ -z "$SCOPE" ] && { echo "[kit] identity malformed (no scope) — allowing."; exit 0; }

fail=0
while IFS= read -r staged; do
  [ -z "$staged" ] && continue
  case "$staged" in
    # Governance surface: threads are REQUIRED to keep the registry,
    # task board, logs, and checkpoints current — always in scope.
    .kit-thread|docs/THREADS.md|docs/workflow/*|docs/CHECKPOINTS/*|docs/.locks/*) continue ;;
  esac
  inside=0
  if type scope_list_contains_path >/dev/null 2>&1; then
    if scope_list_contains_path "$SCOPE" "$staged"; then inside=1; fi
  else
    for s in $SCOPE; do
      case "$s" in
        */) case "$staged" in "$s"*) inside=1; break ;; esac ;;
        *)  [ "$staged" = "$s" ] && { inside=1; break; } ;;
      esac
    done
  fi
  [ "$inside" -eq 1 ] || { echo "[kit] OUT OF SCOPE: '$staged' not in '$THREAD' scope: $SCOPE"; fail=1; }
done < <(git diff --cached --name-only)

if [ "$fail" -eq 1 ]; then
  echo "[kit] COMMIT REJECTED — staged files outside declared scope."
  echo "[kit] Unstage them, or release + re-register with wider scope."
  exit 1
fi

stamp_commit
echo "[kit] scope check passed for thread '$THREAD'"
exit 0
