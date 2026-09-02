#!/usr/bin/env bash
#
# run-tests.sh — zero-dependency test harness for System Kit scripts.
#
# Builds throwaway fixture projects (filesystem-only and git) and
# simulates parallel thread sessions end-to-end:
#
#   T1  register: claim adds row, flips task, writes identity
#   T2  atomic double-claim: two simultaneous registers, exactly one wins
#   T3  scope overlap: second thread blocked from owned scope
#   T4  disjoint scopes: parallel CODE threads coexist
#   T5  heartbeat: stamp lands in own row only
#   T6  release: row moved to completed, task DONE, identity removed
#   T7  worktree mode: isolated tree, merge-back, tree removed
#   T8  folder-copy mode: copy created, merged back, removed
#   T9  pre-commit hook: in-scope allowed, out-of-scope rejected
#   T10 CI --all: overlapping registry fails, clean passes
#
# SAFETY: fixtures live in a fresh temp dir OUTSIDE this repository,
# and every git command is pinned to the fixture path (-C). The real
# repo is never touched.
#
# Usage: ./run-tests.sh [fixture-root]
# Fixture defaults to a temp dir; nothing in the repo is touched.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; FAILED_TESTS=()

ok()   { PASS=$((PASS+1)); echo "  ok    $1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); echo "  FAIL  $1"; }

# Portable in-place sed (macOS BSD sed needs -i ''; GNU sed needs -i)
sed_inplace() {
  local expr="$1" file="$2" tmp="${2}.sedtmp"
  sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
}

t() { # t <name> <expected-exit> <cmd...>
  local name="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  [ "$got" = "$want" ] && ok "$name" || bad "$name (exit $got, want $want)"
}
assert() { local n="$1"; shift; "$@" >/dev/null 2>&1 && ok "$n" || bad "$n (assert)"; }
refute() { local n="$1"; shift; "$@" >/dev/null 2>&1 && bad "$n (refute)" || ok "$n"; }

new_fixture() { # <name> <git:yes|no> — echoes path
  local name="$1" usegit="$2"
  local dir="$FIXROOT/$name"
  mkdir -p "$dir/docs/workflow" "$dir/src/api" "$dir/src/ui"
  cat > "$dir/docs/THREADS.md" <<'EOF'
# THREADS.md — Fixture Registry

## Protocol

## Active Threads

| Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |
|---|---|---|---|---|---|---|---|
| beta | 2026-09-02 09:00 | T-999 | CODE | src/api/ | main | 2026-09-02 09:00 | ACTIVE |

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
EOF
  cat > "$dir/docs/workflow/TASKS.md" <<'EOF'
# TASKS.md

| ID | Task | Spec | Needs | Deps | Status |
|---|---|---|---|---|---|
| T-100 | fixture task A | - | CODE | - | OPEN |
| T-101 | fixture task B | - | CODE | - | OPEN |
| T-102 | api cleanup | - | CODE | - | OPEN |
| T-103 | docs pass | - | LEDGER | - | OPEN |
EOF
  echo "x" > "$dir/src/api/tasks.ts"; echo "y" > "$dir/src/ui/app.ts"
  if [ "$usegit" = "yes" ]; then
    git -C "$dir" init -q
    git -C "$dir" add -A
    git -C "$dir" -c user.email=t@t -c user.name=t commit -qm init
  fi
  echo "$dir"
}

# ---- Fixture root safety: fresh temp dir, never inside this repo ----
KITREPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
FIXROOT="${1:-$(mktemp -d)}"
mkdir -p "$FIXROOT"
case "$FIXROOT/" in
  "$KITREPO"|"$KITREPO"/*)
    echo "ERROR: fixture root must live OUTSIDE the kit repo (got '$FIXROOT')."
    exit 2
    ;;
esac
[ -z "$KITREPO" ] || [ -d "$KITREPO/.git" ] || true
# refuse to run if a worktree of THIS repo would collide (defensive)
if [ -n "$KITREPO" ]; then
  if git -C "$KITREPO" worktree list 2>/dev/null | grep -v "^$KITREPO " | grep -q .; then
    echo "ERROR: stray kit worktrees detected. Remove them first (git worktree prune)."
    exit 2
  fi
fi
echo "System Kit script tests — fixture root: $FIXROOT"

# ================= FILESYSTEM MODE =================
echo; echo "filesystem mode (no git):"
FS="$(new_fixture fs1 no)"

t "T1 register basic claim" 0 "$SCRIPT_DIR/register-thread.sh" "$FS/docs" alpha T-100 main "src/ui/"
assert "T1a row present" grep -q '| alpha |' "$FS/docs/THREADS.md"
assert "T1b task flipped" grep -q '| T-100 |.*CLAIMED(alpha)' "$FS/docs/workflow/TASKS.md"
assert "T1c identity file" test -f "$FS/docs/.kit-thread"

# atomic double-claim: two simultaneous registers of SAME task; one must win
( "$SCRIPT_DIR/register-thread.sh" "$FS/docs" zeta1 T-101 main "src/z/" >/dev/null 2>&1 &
  "$SCRIPT_DIR/register-thread.sh" "$FS/docs" zeta2 T-101 main "src/z/" >/dev/null 2>&1
  wait ) || true
ZC=$(grep -cE '\| zeta[12] \|' "$FS/docs/THREADS.md" || true)
[ "$ZC" = "1" ] && ok "T2 atomic double-claim (winner count=1)" || bad "T2 atomic double-claim (count=$ZC)"
ZT=$(grep -c 'CLAIMED(zeta' "$FS/docs/workflow/TASKS.md" || true)
[ "$ZT" = "1" ] && ok "T2b task claimed once" || bad "T2b task claimed (count=$ZT)"

t "T3 scope overlap blocked" 1 "$SCRIPT_DIR/register-thread.sh" "$FS/docs" gamma T-102 main "src/api/tasks.ts"
t "T4 disjoint parallel OK" 0 "$SCRIPT_DIR/register-thread.sh" "$FS/docs" delta T-102 main "src/x/"
ACTIVE_N=$(grep -c '| ACTIVE |' "$FS/docs/THREADS.md" || true)
[ "$ACTIVE_N" = "4" ] && ok "T4a four ACTIVE rows coexist" || bad "T4a ACTIVE rows ($ACTIVE_N != 4)"

t "T5 heartbeat" 0 "$SCRIPT_DIR/heartbeat.sh" "$FS/docs" alpha
assert "T5a alpha stamped" grep -qE '\| alpha \|.*\| 2026-09-02 1[0-9]:[0-9]+ \| ACTIVE \|' "$FS/docs/THREADS.md"
assert "T5b beta heartbeat untouched" grep -q '| beta |.*| 2026-09-02 09:00 | ACTIVE |' "$FS/docs/THREADS.md"

# cleanup helper threads
"$SCRIPT_DIR/release-thread.sh" "$FS/docs" zeta1 "zeta test" >/dev/null 2>&1
"$SCRIPT_DIR/release-thread.sh" "$FS/docs" zeta2 "zeta test" >/dev/null 2>&1
"$SCRIPT_DIR/release-thread.sh" "$FS/docs" delta "delta test" >/dev/null 2>&1

t "T6 release" 0 "$SCRIPT_DIR/release-thread.sh" "$FS/docs" alpha "fixture A done"
assert "T6a moved to completed" grep -q '| alpha |.*| fixture A done |' "$FS/docs/THREADS.md"
refute "T6b no alpha in active" grep -q '| alpha |.*| ACTIVE |' "$FS/docs/THREADS.md"
assert "T6c task DONE" grep -q '| T-100 |.*DONE' "$FS/docs/workflow/TASKS.md"
refute "T6d identity gone" test -f "$FS/docs/.kit-thread"

t "T8 folder-copy mode" 0 "$SCRIPT_DIR/register-thread.sh" "$FS/docs" eps T-103 copy "src/ui/"
assert "T8a copy registered" grep -qE '\| eps \|.*copy-eps' "$FS/docs/THREADS.md"
assert "T8b copy dir exists" test -d "$FS/copy-eps"
# modify a file IN the copy, then release → merged back + removed
echo "// copy work" >> "$FS/copy-eps/src/ui/app.ts"
t "T8c release with merge-back" 0 "$SCRIPT_DIR/release-thread.sh" "$FS/docs" eps "copy test"
assert "T8d change merged to main" grep -q '// copy work' "$FS/src/ui/app.ts"
refute "T8e copy removed" test -d "$FS/copy-eps"

echo; echo "CI --all mode:"
t "T10 clean registry passes" 0 "$SCRIPT_DIR/check-scope-overlap.sh" "$FS/docs/THREADS.md" --all
# negative case: two ACTIVE rows with overlapping scopes must FAIL
OV="$(new_fixture fs_ov no)"
sed_inplace 's@| beta | 2026-09-02 09:00 | T-999 | CODE | src/api/ | main | 2026-09-02 09:00 | ACTIVE |@| beta | 2026-09-02 09:00 | T-999 | CODE | src/api/ | main | 2026-09-02 09:00 | ACTIVE |\
| beta2 | 2026-09-02 09:05 | T-998 | CODE | src/api/tasks.ts | main | 2026-09-02 09:05 | ACTIVE |@' "$OV/docs/THREADS.md"
t "T10b overlapping registry FAILS --all" 1 "$SCRIPT_DIR/check-scope-overlap.sh" "$OV/docs/THREADS.md" --all
# isolated trees never conflict with main-tree scope in --all
ISO="$(new_fixture fs_iso no)"
sed_inplace 's@| beta | 2026-09-02 09:00 | T-999 | CODE | src/api/ | main | 2026-09-02 09:00 | ACTIVE |@| beta | 2026-09-02 09:00 | T-999 | CODE | src/api/ | main | 2026-09-02 09:00 | ACTIVE |\
| iso | 2026-09-02 09:05 | T-998 | CODE | src/api/ | copy-iso | 2026-09-02 09:05 | ACTIVE |@' "$ISO/docs/THREADS.md"
t "T10c isolated tree coexists in --all" 0 "$SCRIPT_DIR/check-scope-overlap.sh" "$ISO/docs/THREADS.md" --all

# ================= GIT MODE =================
if command -v git >/dev/null 2>&1; then
echo; echo "git mode:"
GT="$(new_fixture gt1 yes)"

t "T7 worktree register" 0 "$SCRIPT_DIR/register-thread.sh" "$GT/docs" wt T-100 worktree "src/api/"
WTPATH="$(grep '| wt |' "$GT/docs/THREADS.md" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$7); print $7}')"
assert "T7a worktree exists" test -d "$WTPATH"
# work in the tree, commit, release (merge back)
echo "// wt work" >> "$WTPATH/src/api/tasks.ts"
git -C "$WTPATH" add -A >/dev/null 2>&1
git -C "$WTPATH" -c user.email=t@t -c user.name=t commit -qm "wt work" >/dev/null 2>&1
t "T7b release with merge" 0 "$SCRIPT_DIR/release-thread.sh" "$GT/docs" wt "worktree task done"
assert "T7c merged to main" git -C "$GT" log --oneline --grep="wt work" >/dev/null 2>&1
refute "T7d worktree removed" test -d "$WTPATH"

t "T9 hook: register" 0 "$SCRIPT_DIR/register-thread.sh" "$GT/docs" hk T-101 main "src/ui/"
cp "$SCRIPT_DIR/pre-commit-scope-check.sh" "$GT/.git/hooks/pre-commit"
chmod +x "$GT/.git/hooks/pre-commit"
( cd "$GT" && echo "z" >> src/ui/app.ts && git add src/ui/app.ts ) >/dev/null 2>&1
t "T9a in-scope commit ALLOWED" 0 git -C "$GT" -c user.email=t@t -c user.name=t commit -qm "in scope"
( cd "$GT" && echo "z" >> src/api/tasks.ts && git add src/api/tasks.ts ) >/dev/null 2>&1
t "T9b out-of-scope commit REJECTED" 1 git -C "$GT" -c user.email=t@t -c user.name=t commit -qm "out of scope"
git -C "$GT" reset -q --hard HEAD >/dev/null 2>&1 || true
"$SCRIPT_DIR/release-thread.sh" "$GT/docs" hk "hook test" >/dev/null 2>&1
else
echo; echo "git mode: SKIPPED (git unavailable)"
fi

# ================= SUMMARY =================
echo; echo "----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
echo "all green"
exit 0
