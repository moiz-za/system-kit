#!/usr/bin/env bash
#
# governance-health.sh — one command, full governance sweep.
#
# Runs every kit validator against a project and prints a pass/warn/fail
# report with a summary score. Cheap (pure shell, seconds to run) —
# designed for: session start ("am I walking into a healthy repo?"),
# pre-push checks, or a weekly hygiene pass.
#
# Checks (each individually skippable if its target is absent):
#   structure   docs/ tree complete (START_HERE, AGENTS, THREADS,
#               workflow/, CHECKPOINTS/)
#   registry    THREADS.md format (validate-registry.sh)
#   scope       no overlapping ACTIVE main-tree scopes (--all)
#   stale       no ACTIVE thread without heartbeat 2h+ (--strict)
#   checkpoints no incomplete in-progress checkpoints
#   laws        AGENTS.md Articles I/II/IV present, amendment log
#               table exists
#   buildlog    tracked BUILDLOG.md exists (git projects)
#
# Usage:
#   ./governance-health.sh <docs-folder> [--no-stale]
#
#   --no-stale   skip the staleness check (e.g. CI: long-dead registries
#                from merged PRs would false-fail)
#
# Exit 0  → all checks passed
# Exit 1  → at least one check failed
# Exit 2  → usage / input error
#
# The per-check scripts must sit next to this one (as in the kit's
# integrations/scripts/ or a project's governance-scripts/ copy).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 <docs-folder> [--no-stale]
  docs-folder   the project's governance folder (holds THREADS.md)
  --no-stale    skip stale-thread detection (CI-friendly)
EOF
}

[ "$#" -ge 1 ] || { usage; exit 2; }
DOCS="$1"; shift || true
CHECK_STALE="yes"
[ "${1:-}" = "--no-stale" ] && CHECK_STALE="no"

[ -d "$DOCS" ] || { echo "ERROR: docs folder '$DOCS' not found"; exit 2; }
THREADS="$DOCS/THREADS.md"

PASS=0; WARN=0; FAIL=0
report() { # report pass|warn|fail <name> <detail>
  case "$1" in
    pass) PASS=$((PASS+1)); printf '  [PASS] %-12s %s\n' "$2" "$3" ;;
    warn) WARN=$((WARN+1)); printf '  [WARN] %-12s %s\n' "$2" "$3" ;;
    fail) FAIL=$((FAIL+1)); printf '  [FAIL] %-12s %s\n' "$2" "$3" ;;
  esac
}

run() { # run <script> <args...> — returns script exit; captures its output
  local out
  out="$("$SCRIPT_DIR/$1" "${@:2}" 2>&1)" || { printf '%s\n' "$out" | sed 's/^/         /' >&2; return 1; }
  return 0
}

echo "Governance health — $DOCS"
echo "------------------------------------------------"

# --- structure ---
STRUCT_OK="yes"
for f in START_HERE.md AGENTS.md THREADS.md workflow/TASKS.md workflow/BUILDLOG.md workflow/PENDING-OWNER.md; do
  [ -f "$DOCS/$f" ] || { report fail structure "missing $f"; STRUCT_OK="no"; }
done
[ -d "$DOCS/CHECKPOINTS" ] || { report warn structure "no CHECKPOINTS/ dir (template only)"; }
[ "$STRUCT_OK" = "yes" ] && report pass structure "all core files present"

# --- registry format ---
if [ -f "$THREADS" ]; then
  if [ -f "$SCRIPT_DIR/validate-registry.sh" ] && "$SCRIPT_DIR/validate-registry.sh" "$THREADS" >/dev/null 2>&1; then
    report pass registry "THREADS.md format valid"
  elif [ ! -f "$SCRIPT_DIR/validate-registry.sh" ]; then
    report warn registry "validate-registry.sh not installed — skipped"
  else
    report fail registry "THREADS.md format problems (run validate-registry.sh for detail)"
  fi
else
  report fail registry "THREADS.md missing"
fi

# --- scope overlap ---
if [ -f "$THREADS" ] && [ -f "$SCRIPT_DIR/check-scope-overlap.sh" ]; then
  if "$SCRIPT_DIR/check-scope-overlap.sh" "$THREADS" --all >/dev/null 2>&1; then
    report pass scope "no overlapping ACTIVE scopes"
  else
    report fail scope "ACTIVE threads declare overlapping scopes"
  fi
elif [ ! -f "$SCRIPT_DIR/check-scope-overlap.sh" ]; then
  report warn scope "check-scope-overlap.sh not installed — skipped"
fi

# --- staleness ---
if [ "$CHECK_STALE" = "yes" ] && [ -f "$THREADS" ]; then
  if [ -f "$SCRIPT_DIR/check-stale.sh" ]; then
    if "$SCRIPT_DIR/check-stale.sh" "$THREADS" --strict >/dev/null 2>&1; then
      report pass stale "no thread without heartbeat 2h+"
    else
      report fail stale "stale thread(s) — flag + reclaim or heartbeat"
    fi
  else
    report warn stale "check-stale.sh not installed — skipped"
  fi
fi

# --- checkpoints ---
if [ -d "$DOCS/CHECKPOINTS" ] && [ -f "$SCRIPT_DIR/validate-checkpoint.sh" ]; then
  if "$SCRIPT_DIR/validate-checkpoint.sh" "$DOCS" >/dev/null 2>&1; then
    report pass checkpoints "all in-progress checkpoints complete"
  else
    report fail checkpoints "incomplete checkpoint(s) — future threads will resume into broken state"
  fi
fi

# --- laws ---
AGENTS="$DOCS/AGENTS.md"
if [ -f "$AGENTS" ]; then
  LAWS_OK="yes"
  grep -q '^## ARTICLE I' "$AGENTS" || { report fail laws "Article I (Universal Laws) missing"; LAWS_OK="no"; }
  grep -q '^## ARTICLE II' "$AGENTS" || { report fail laws "Article II (Concurrency Protocol) missing"; LAWS_OK="no"; }
  grep -q '^## ARTICLE IV' "$AGENTS" || { report fail laws "Article IV (Amendment Process) missing"; LAWS_OK="no"; }
  grep -q '^## AMENDMENT LOG' "$AGENTS" || { report fail laws "Amendment Log table missing"; LAWS_OK="no"; }
  [ "$LAWS_OK" = "yes" ] && report pass laws "Articles I/II/IV + amendment log present"
else
  report fail laws "AGENTS.md missing"
fi

# --- buildlog tracked (git projects) ---
if git -C "$DOCS/.." rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$DOCS/.." ls-files --error-unmatch "$DOCS/workflow/BUILDLOG.md" >/dev/null 2>&1 \
     || git -C "$DOCS/.." ls-files '*BUILDLOG.md' | grep -q .; then
    report pass buildlog "BUILDLOG tracked in git"
  else
    report warn buildlog "BUILDLOG exists but untracked — commit it (it IS the history)"
  fi
fi

echo "------------------------------------------------"
echo "Summary: $PASS pass · $WARN warn · $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  echo "Status:  ATTENTION NEEDED — fix failures before claiming new work."
  exit 1
fi
echo "Status:  HEALTHY"
exit 0
