#!/usr/bin/env bash
#
# registry-lock.sh — shared filesystem-lock library for System Kit governance.
#
# Tier 0 (pure filesystem — works with or without git, on any POSIX host).
# One lock serializes every read-modify-write of the shared ledgers
# (THREADS.md, TASKS.md) so parallel threads can never clobber each
# other's rows. The same mechanism guards the MERGE mutex and the
# three-mutex lock files in filesystem-only mode.
#
# Usage (source this file):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/registry-lock.sh"
#   registry_acquire  <docs-folder> <lock-name>   # exits 1 on timeout
#   registry_release  <docs-folder> <lock-name>
#   registry_locked   <docs-folder> <lock-name>   # returns 0 if held
#
# Lock file: <docs-folder>/.locks/<lock-name>.lock
# Atomicity: noclobber create — only one racing writer can create the
# file; every other writer fails and waits. (echo-then-read-back is
# NOT atomic: two writers can both verify their own PID after
# interleaved overwrites.)
# 10s acquire timeout: a crashed holder never freezes other threads
# forever; recovery is a documented manual step (flag + remove).

registry_acquire() {
  local docs="$1" name="$2"
  local lockdir="$docs/.locks"
  mkdir -p "$lockdir" 2>/dev/null || true
  local lock="$lockdir/$name.lock"
  local tries=0
  while [ "$tries" -lt 100 ]; do  # ~10s at 0.1s intervals
    if ( set -o noclobber; echo "$$" > "$lock" ) 2>/dev/null; then
      return 0
    fi
    tries=$((tries + 1))
    sleep 0.1
  done
  echo "ERROR: could not acquire $name lock at '$lock' within 10s." >&2
  echo "  Another thread may be mid-edit, or a stale lock exists." >&2
  echo "  If no thread holds it (check THREADS.md), flag it in" >&2
  echo "  START_HERE.md notifications, then remove the file." >&2
  return 1
}

registry_release() {
  local docs="$1" name="$2"
  local lock="$docs/.locks/$name.lock"
  # Only the holder releases (PID must match). A non-holder's release
  # is a no-op — protects against one thread freeing another's lock.
  if [ "$(cat "$lock" 2>/dev/null)" = "$$" ]; then
    rm -f "$lock"
  fi
}

registry_locked() {
  local docs="$1" name="$2"
  [ -f "$docs/.locks/$name.lock" ]
}
