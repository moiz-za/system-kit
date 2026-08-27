# Worked Example — START_HERE.md After Initialization

> This shows what a completed `START_HERE.md` looks like after the setup prompt
> runs on a real project. Use it as a reference for the level of detail expected.
> Example project used: a small REST API with a web dashboard (generic on purpose).

---

# START_HERE.md — Taskloop Entry Point

> **THE single entry point for every new thread.**
> Read this → claim a task → work it → close it.
> If your target is locked or conflicting → notify, don't start.

---

## OPTIONAL — MULTI-PROVIDER MODEL SELECTION

*This project runs free-tier rotation, so Model Rotation applies. Last sweep: 2026-08-26.*

```
[OK]   RECOMMENDED: qwen3-coder-480b (OpenRouter :free) — 262k ctx · 1.8s · healthy
[OK]   gemini-2.5-flash (Google AI Studio) — 1M ctx · 0.9s · healthy
[WARN] deepseek-v3.1 (OpenRouter :free) — degraded: intermittent timeouts today
[DEAD] llama-4-maverick (OpenRouter :free) — dead: model removed from catalog

Guaranteed fallback: anthropic/claude-sonnet (paid — always available)
```

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
| T-041 | Add pagination to GET /tasks endpoint | specs/T-041-pagination.md | CODE | T-039 | OPEN |
| T-042 | Write user guide section for dashboard filters | specs/T-042-guide.md | LEDGER | — | OPEN |
| T-040 | Migrate sessions table to UUID keys | specs/T-040-sessions-uuid.md | DB-CF | — | CLAIMED(alpha) |
| T-039 | Fix flaky auth token refresh test | specs/T-039-auth-test.md | CODE | — | DONE |
| T-037 | Choose background job library (bullmq vs pg-boss) | PENDING-OWNER #D-012 | — | — | BLOCKED(owner decision) |

*How a fresh thread reads this:* T-041 is OPEN, unlocked, needs CODE (free) — claim it.
T-042 also qualifies but comes second in priority order. T-040 is locked by alpha.

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

Verification commands:

```bash
npm run lint && npm run typecheck   # static gates
npm test                            # unit + integration suite
npm run build                       # must compile clean
```

Deploy: push to `main` → CI deploys staging → owner approves prod promotion.

## §5 NOTIFICATIONS (append-only)

| When | Thread | Note |
|---|---|---|
| 2026-08-26 09:14 | gamma | Flagged beta lock stale (>4h) on T-036; reclaimed after flag visible |
| 2026-08-25 17:02 | alpha | T-037 moved to BLOCKED — decision posted in PENDING-OWNER #D-012 |
