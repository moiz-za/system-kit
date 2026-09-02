# Integrations — Optional, Machine-Enforcement Extras

> The core kit (`docs/`, `patterns/`, `SETUP_PROMPT.md`) is deliberately
> methodology-only per CONTRIBUTING.md. Everything in this folder is
> **optional glue**: the enforcement scripts and CI workflow that make the
> documented protocol machine-checked. Nothing here is required to run
> System Kit — without a shell, the manual protocol in THREADS.md applies.

## Contents

| File | What it does |
|---|---|
| [`scripts/lib/registry-lock.sh`](scripts/lib/registry-lock.sh) | Shared noclobber filesystem lock — the atomicity primitive |
| [`scripts/register-thread.sh`](scripts/register-thread.sh) | THE atomic claim: lock → uniqueness → scope-disjoint check → row insert → task flip → identity file. Worktree/copy isolation modes built in; upgrades pre-v3 registries in passing |
| [`scripts/release-thread.sh`](scripts/release-thread.sh) | Atomic close-out: clean-tree check, MERGE-guarded merge-back, row → Recently Completed, task DONE |
| [`scripts/heartbeat.sh`](scripts/heartbeat.sh) | Stamp your THREADS.md row (commits count as heartbeats in git mode) |
| [`scripts/pre-commit-scope-check.sh`](scripts/pre-commit-scope-check.sh) | Git hook: rejects commits outside the thread's declared scope; registry files always allowed |
| [`scripts/check-scope-overlap.sh`](scripts/check-scope-overlap.sh) | Claim-mode overlap check + `--all` pairwise CI gate; supports old and new THREADS.md formats |
| [`scripts/check-stale.sh`](scripts/check-stale.sh) | Flags ACTIVE threads with no heartbeat for 2h+ (configurable via `KIT_STALE_HOURS`); `--strict` exits 1 for CI/claim guards; supports both table formats |
| [`scripts/validate-registry.sh`](scripts/validate-registry.sh) | THREADS.md format validation: sections, column counts, required fields, known statuses, duplicate ACTIVE names, heartbeat format |
| [`scripts/check-buildlog.sh`](scripts/check-buildlog.sh) | Git-only: fails when a commit range removed or modified existing BUILDLOG entries (append-only discipline) |
| [`scripts/governance-health.sh`](scripts/governance-health.sh) | One command, full sweep: structure + registry + scope + stale + checkpoints + laws + buildlog, with a pass/warn/fail score |
| [`scripts/validate-checkpoint.sh`](scripts/validate-checkpoint.sh) | Fails push if any in-progress checkpoint is incomplete |
| [`scripts/run-tests.sh`](scripts/run-tests.sh) | Zero-dependency test harness — simulates parallel sessions in filesystem and git modes (44 checks) |
| [`governance-check.yml`](governance-check.yml) | GitHub Actions PR gate: link integrity, placeholders, version, registry presence + format, pairwise scope, stale, BUILDLOG append-only, checkpoints |
| [`governance-watch.yml`](governance-watch.yml) | Optional daily watchdog: opens/updates ONE GitHub issue when governance needs attention |

## The thread lifecycle with scripts

```bash
# claim (atomic — racing claims: exactly one wins)
./integrations/scripts/register-thread.sh docs alpha T-041 main src/api/

# long code task needing isolation:
./integrations/scripts/register-thread.sh docs beta T-042 worktree src/api/
./integrations/scripts/register-thread.sh docs gamma T-043 copy src/api/   # no-git projects

# stay alive during long stretches without commits
./integrations/scripts/heartbeat.sh docs alpha

# spot abandoned threads (any thread may run this; --strict for CI)
./integrations/scripts/check-stale.sh docs/THREADS.md --strict

# full sweep in one command (session start / pre-push / weekly)
./integrations/scripts/governance-health.sh docs

# close out (merges isolated trees under MERGE, marks task DONE)
./integrations/scripts/release-thread.sh docs alpha "T-041 done: pagination added"
```

Scripts work with OR without git — only `pre-commit-scope-check.sh` and the
worktree mode require git. Pure-filesystem projects use main + copy modes.

## Install

**Scripts:** copy `integrations/scripts/` into the project (SETUP_PROMPT
does this automatically at setup — `governance-scripts/` by default).

**Tests:** this repo runs the harness on every push/PR via
[`.github/workflows/script-tests.yml`](../.github/workflows/script-tests.yml)
on both Ubuntu (GNU userland) and macOS (BSD userland) — portability bugs
like `sed -i` differences or bash 3.2 gaps surface before release.

**Pre-commit hook** (git projects, after owner approval):
```bash
cp governance-scripts/pre-commit-scope-check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**CI:** copy `governance-check.yml` to `.github/workflows/governance-check.yml`.
It runs on pull requests targeting `main`.

**Note:** the registry check expects `THREADS.md` to be *tracked* in the repo
(the normal case — a project's live registry is committed). It will fail in
repositories that keep their registry gitignored (like this kit's own private
`.dev/`); delete that step there or point it at your tracked registry path.

## What the compliance check verifies

1. **Relative link integrity** — every relative markdown link resolves
2. **Placeholder leaks** — no unfilled `[PROJECT NAME]` / `[DOMAIN LAWS ...]`
   markers outside the kit's own source files
3. **Version consistency** — README version badge matches the latest
   CHANGELOG entry
4. **Registry present + format valid** — THREADS.md exists and its rows
   parse (columns, statuses, no duplicate ACTIVE names)
5. **Pairwise scope safety** — no two ACTIVE main-tree threads declare
   overlapping scopes (`check-scope-overlap.sh --all`)
6. **No stale threads** — no ACTIVE row without a heartbeat for 2h+
   (`check-stale.sh --strict`)
7. **BUILDLOG append-only** — PRs that removed or modified existing
   BUILDLOG entries fail (`check-buildlog.sh` against the merge-base)
8. **Checkpoint completeness** — all checkpoints have required sections

Add more project-specific gates as steps — the pattern is: cheap structural
checks in CI, expensive semantic checks by the verifying thread locally.

## Optional watchdog

`governance-watch.yml` runs daily (and on demand) and opens or updates a
**single** GitHub issue titled "Governance attention needed" when the
health sweep or stale check fails — a visible signal for teams that don't
watch CI. It reuses one issue (never spams) and naturally stops once the
checks pass. Delete it if you prefer CI-only signals.

## Testing

Run the full harness from the kit root:

```bash
./integrations/scripts/run-tests.sh
```

Builds throwaway fixture projects (filesystem-only and git) and simulates
parallel thread sessions: atomic double-claims, overlap blocks, disjoint
parallel claims, heartbeats, worktree + folder-copy lifecycles,
commit-scope rejection. Fixtures live in a fresh temp directory OUTSIDE
the repository — nothing in your repo is touched.
