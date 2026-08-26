# Worked Example — THREADS.md During a Live Session

> This shows what `THREADS.md` looks like mid-day with three threads at
> different stages. Reference for what healthy registry state looks like.
> Example project is generic on purpose.

---

# THREADS.md — Taskloop Concurrency Registry

## Protocol

*(protocol rows unchanged from template — omitted here for brevity)*

## Active Threads

| Thread | Started | Tasks | Mutexes | Shared Files | Heartbeat | Status |
|---|---|---|---|---|---|---|
| alpha | 2026-08-26 09:02 | T-040 (sessions UUID migration) | DB-CF | db/migrations/2026_08_sessions.sql | 2026-08-26 13:40 | ACTIVE |
| beta | 2026-08-26 10:15 | T-041 (pagination endpoint) | CODE | src/api/tasks.ts, src/api/schemas.ts | 2026-08-26 13:52 | ACTIVE |
| gamma | 2026-08-26 13:30 | T-042 (user guide filters) | LEDGER | docs/guide/filters.md | 2026-08-26 13:31 | ACTIVE |

*What a fresh thread reads from this:*

- Want to edit source files? CODE is held by **beta** → do NOT start code work.
  Claim a docs task or wait.
- Want T-040? Locked by **alpha** (heartbeat 12 min ago — alive) → notify, don't start.
- Docs work? gamma holds only LEDGER (seconds per edit) → your docs task can
  proceed; coordinate the brief LEDGER hold, never blocked long.

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
| delta | 2026-08-26 11:48 | T-039 auth test fix — flaky mock replaced with injected clock; 47/47 passing; BUILDLOG updated |
| epsilon | 2026-08-25 16:20 | T-037 research done — bullmq vs pg-boss comparison posted to PENDING-OWNER #D-012 |

---

**Stale-lock example:** if alpha's heartbeat showed `2026-08-26 09:02` (no
update for 4h+), any thread may first *flag* it in the START_HERE.md §5
notifications — e.g., "gamma 14:05: alpha heartbeat stale on T-040" — and only
reclaim after that flag is visible. Never silently deregister another thread.
