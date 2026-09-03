# THREADS.md — [PROJECT NAME] Concurrency Registry

> Live registry of running threads. Every thread registers before working.
> This file IS the lock store — claims written here are binding.
> All claims go through `register-thread.sh` (atomic + scope-checked).

---

## Protocol

1. **REGISTER** before working, via the claim script:
   `register-thread.sh <docs-folder> <thread> <task-id> [--lane LANE] [--model M] [mode] [scope...]`
   - **Lane** = STRATEGY / DOCS / CODE (default) / DEPLOY — declared at
     claim, never crossed mid-task (finish + close out + new claim instead).
     The lane sets the mutex automatically: STRATEGY/DOCS → LEDGER ·
     CODE → CODE · DEPLOY → DEPLOY.
   - **Model** = free-form observability label for the LLM in use.
     NEVER a gate or a law — lineups are swappable anytime.
   - **Scope** = every file/dir this thread may write (dirs end with `/`).
     Globs allowed: `src/**/*.test.ts` (** = any depth, * = one segment).
     Required for CODE/DOCS lanes. Two threads may hold CODE
     simultaneously **only if scopes are disjoint** — verified
     machine-side at claim time.
   - **Mode** = `main` (shared tree) · `worktree` (git isolation) ·
     `copy` (no-git isolation)
   - No script available? Follow the same rules by hand: check every
     ACTIVE row, verify disjoint scope, append your row, flip your task.
2. **MUTEXES:**
   - `CODE` = exclusive write to declared scope (parallel holders iff disjoint)
   - `LEDGER` = append-only edits to own rows in shared tracking files
   - `DB-CF` = database/schema/cloud-infrastructure changes
   - `DEPLOY` = all server execution, one deploy at a time
   - `MERGE` = one merge-back of an isolated tree at a time
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
7. **CODE-lane close-out includes a Deploy Handoff** (deployable
   projects): `workflow/DEPLOY_HANDOFF_TEMPLATE.md`, filled, linked
   from `workflow/DEPLOY_QUEUE.md`. DEPLOY threads refuse incomplete
   handoffs — the refusal is the system working.

## Active Threads

| Thread | Started | Tasks | Lane | Mutexes | Scope | Tree | Model | Heartbeat | Status |
|---|---|---|---|---|---|---|---|---|---|

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
