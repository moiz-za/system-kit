# THREADS.md — [PROJECT NAME] Concurrency Registry

> Live registry of running threads. Every thread registers before working.
> This file IS the lock store — claims written here are binding.
> All claims go through `register-thread.sh` (atomic + scope-checked).

---

## Protocol

1. **REGISTER** before working, via the claim script:
   `register-thread.sh <docs-folder> <thread> <task-id> <mode> <scope...>`
   - **Scope** = every file/dir this thread may write (dirs end with `/`).
     Globs allowed: `src/**/*.test.ts` (** = any depth, * = one segment).
     Two threads may hold CODE simultaneously **only if scopes are
     disjoint** — verified machine-side at claim time (globs are checked
     conservatively: any plausibly shared path blocks the second claim).
   - **Mode** = `main` (shared tree) · `worktree` (git isolation) ·
     `copy` (no-git isolation)
   - No script available? Follow the same rules by hand: check every ACTIVE
     row, verify disjoint scope, append your row, flip your task to CLAIMED.
2. **MUTEXES:**
   - `CODE` = exclusive write to declared scope (parallel holders iff disjoint)
   - `LEDGER` = append-only edits to own rows in shared tracking files
   - `DB-CF` = database/schema/cloud-infrastructure changes
   - `MERGE` = one merge-back at a time (worktree/copy close-out)
3. **OWNERSHIP:** claimed task gives exclusive write to its checkpoint, its
   task row, and its plan sections. Never touch another live thread's files.
4. **SHARED LEDGERS:** append-only edits of own rows only, under the
   REGISTRY lock. Restructures need ALL-CLEAR.
5. **STALE RECLAMATION:** no heartbeat for 2h+ → flag in START_HERE
   notifications → anyone may reclaim after the flag is visible.
   `check-stale.sh <docs>/THREADS.md` finds stale rows for you
   (`--strict` fails CI / gates claims).
6. **DEREGISTER** via `release-thread.sh` when done (merges isolated trees,
   moves row to Recently Completed). Never deregister another live thread.

## Active Threads

| Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |
|---|---|---|---|---|---|---|---|

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
