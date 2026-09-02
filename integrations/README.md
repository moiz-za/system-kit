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
| [`scripts/register-thread.sh`](scripts/register-thread.sh) | THE atomic claim: lock → uniqueness → scope-disjoint check → row insert → task flip → identity file. Worktree/copy isolation modes built in |
| [`scripts/release-thread.sh`](scripts/release-thread.sh) | Atomic close-out: clean-tree check, MERGE-guarded merge-back, row → Recently Completed, task DONE |
| [`scripts/heartbeat.sh`](scripts/heartbeat.sh) | Stamp your THREADS.md row (commits count as heartbeats in git mode) |
| [`scripts/pre-commit-scope-check.sh`](scripts/pre-commit-scope-check.sh) | Git hook: rejects commits outside the thread's declared scope; registry files always allowed |
| [`scripts/check-scope-overlap.sh`](scripts/check-scope-overlap.sh) | Claim-mode overlap check + `--all` pairwise CI gate; supports old and new THREADS.md formats |
| [`scripts/validate-checkpoint.sh`](scripts/validate-checkpoint.sh) | Fails push if any in-progress checkpoint is incomplete |
| [`scripts/run-tests.sh`](scripts/run-tests.sh) | Zero-dependency test harness — simulates parallel sessions in filesystem and git modes (34 checks) |
| [`governance-check.yml`](governance-check.yml) | GitHub Actions workflow: link integrity, placeholder leaks, version consistency, registry presence, pairwise scope gate, checkpoint completeness |

## The thread lifecycle with scripts

```bash
# claim (atomic — racing claims: exactly one wins)
./integrations/scripts/register-thread.sh docs alpha T-041 main src/api/

# long code task needing isolation:
./integrations/scripts/register-thread.sh docs beta T-042 worktree src/api/
./integrations/scripts/register-thread.sh docs gamma T-043 copy src/api/   # no-git projects

# stay alive during long stretches without commits
./integrations/scripts/heartbeat.sh docs alpha

# close out (merges isolated trees under MERGE, marks task DONE)
./integrations/scripts/release-thread.sh docs alpha "T-041 done: pagination added"
```

Scripts work with OR without git — only `pre-commit-scope-check.sh` and the
worktree mode require git. Pure-filesystem projects use main + copy modes.

## Install

**Scripts:** copy `integrations/scripts/` into the project (SETUP_PROMPT
does this automatically at setup — `governance-scripts/` by default).

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
4. **Registry present** — THREADS.md exists (repo root or `docs/`)
5. **Pairwise scope safety** — no two ACTIVE main-tree threads declare
   overlapping scopes (`check-scope-overlap.sh --all`)
6. **Checkpoint completeness** — all checkpoints have required sections

Add more project-specific gates as steps — the pattern is: cheap structural
checks in CI, expensive semantic checks by the verifying thread locally.

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
