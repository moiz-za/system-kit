# START_HERE.md — [PROJECT NAME] Entry Point

> **THE single entry point for every new thread.**
> Read this → claim a task → work it → close it.
> If your target is locked or conflicting → notify, don't start.

---

## OPTIONAL — MULTI-PROVIDER MODEL SELECTION

If this project runs multiple AI providers on rotating free-tier catalogs,
probe model availability live at every session start — never trust a cached
model list: query each provider's model endpoint, run one tiny health check
per candidate, rank the survivors, and keep a paid model as the guaranteed
fallback. Skip this section entirely if you use a single paid provider.

---

## §1 THE RULE (read once, follow always)

0. **SELF-CLEAN:** while in THREADS.md, move any CLOSED rows down to completed.
1. **Open THREADS.md** — check active threads, held mutexes, scopes, heartbeats.
   Also check `workflow/PENDING-OWNER.md` for decisions that may unblock tasks.
2. **Scan the task queue** for first OPEN task that:
   - is not locked by another thread
   - has no unmet dependency
   - has a scope that doesn't overlap any ACTIVE main-tree thread
3. **CLAIM it atomically** — BEFORE touching files:
   `register-thread.sh <docs-folder> <thread> <task-id> <mode> <scope...>`
   - mode `main` for small work in the shared tree
   - mode `worktree` (git) / `copy` (no git) for long code tasks needing isolation
   - No script available? Do the same checks by hand against every ACTIVE
     row, then append your row to THREADS.md.
4. **Work the task** per its spec, inside your declared scope only.
   Heartbeat on resume after breaks (`heartbeat.sh`); commits count as
   heartbeats in git projects. `check-stale.sh` spots abandoned threads.
5. **Close out** — `release-thread.sh <docs-folder> <thread> "<summary>"`
   (merges isolated trees back under MERGE, moves your row to completed,
   marks the task DONE). Then: append BUILDLOG + update PENDING-OWNER.

## §2 CONFLICT & NOTIFY RULE

- Task LOCKED by live thread → DO NOT START. Post notification + report.
- Scope overlaps an ACTIVE main-tree thread → DO NOT CLAIM. Choose a
  different task, wait, or use an isolated mode (worktree/copy).
- Stale lock (no heartbeat for 2h+) → flag, then reclaim.
- Never touch another live thread's owned files.
- Shared-ledger edits: append-only, own rows only, under the REGISTRY lock.
- Restructures need ALL-CLEAR.

## §3 TASK QUEUE

| ID | Task | Spec | Needs | Deps | Status |
|---|---|---|---|---|---|
| *(tasks appear here)* | | | | | |

## §4 LAWS DIGEST

1. Secrets never enter tracked files, conversations, or LLM context
2. Full verification suite passes locally before every commit
3. Production is NEVER the first test bench
4. Append-only ledgers; corrections reference old entries
5. Owner decisions in plain English with recommended defaults
6. Key-safe tooling: scripts handle credentials internally
7. Clean-tree handoff when releasing any mutex
8. Push-sync: ledgers current before push; law re-read after deploy
9. Compaction protocol: checkpoint first, re-read after reset
10. Data honesty: cumulative ≠ daily; labels match reality

Mode: *[fill at setup: GIT (worktree isolation + commit hooks) or
FILESYSTEM (scoped locks + optional folder-copy isolation)]*

Verification commands: *[fill per project]*

## §5 NOTIFICATIONS (append-only)

| When | Thread | Note |
|---|---|---|
| — | — | — |
