# START_HERE.md — [PROJECT NAME] Entry Point

> **THE single entry point for every new thread.**
> Read this → claim a task → work it → close it.
> If your target is locked or conflicting → notify, don't start.

---

## OPTIONAL — MULTI-PROVIDER MODEL SELECTION

If this project runs multiple AI providers on rotating free-tier catalogs,
apply System Kit's **Model Rotation pattern** at every session start:
live `/models` probing, tiny health checks per candidate, ranked survivors,
paid fallback last. Skip entirely if you use one paid provider.

---

## §1 THE RULE (read once, follow always)

0. **SELF-CLEAN:** while in THREADS.md, move any CLOSED rows down to completed.
1. **Open THREADS.md** — check active threads, held mutexes, heartbeats.
2. **Scan the task queue** for first OPEN task that:
   - is not locked by another thread
   - has no unmet dependency
   - requires only mutexes currently free
3. **CLAIM it** — register your row in THREADS.md BEFORE touching files.
4. **Work the task** per its spec. Heartbeat on resume after >1h.
5. **Close out:** tick done + append BUILDLOG + update PENDING-OWNER +
   deregister from THREADS.

## §2 CONFLICT & NOTIFY RULE

- Task LOCKED by live thread → DO NOT START. Post notification + report.
- Stale lock (>4h) → flag, then reclaim.
- Never touch another live thread's owned files.
- Shared-ledger edits: append-only, own rows only.
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

Verification commands: *[fill per project]*

## §5 NOTIFICATIONS (append-only)

| When | Thread | Note |
|---|---|---|
| — | — | — |
