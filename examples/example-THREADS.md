# Worked Example — THREADS.md During a Live Session

> This shows what `THREADS.md` looks like mid-day with four threads at
> different stages — including scoped parallel CODE and both isolation
> modes. Reference for what healthy registry state looks like.
> Example project is generic on purpose.

---

# THREADS.md — Taskloop Concurrency Registry

## Protocol

*(protocol rows unchanged from template — omitted here for brevity)*

## Active Threads

| Thread | Started | Tasks | Mutexes | Scope | Tree | Heartbeat | Status |
|---|---|---|---|---|---|---|---|
| alpha | 2026-08-26 09:02 | T-040 (sessions UUID migration) | DB-CF | db/migrations/ | main | 2026-08-26 13:40 | ACTIVE |
| beta | 2026-08-26 10:15 | T-041 (pagination endpoint) | CODE | src/api/ | ../taskloop-beta | 2026-08-26 13:52 | ACTIVE |
| gamma | 2026-08-26 13:30 | T-042 (user guide filters) | LEDGER | docs/guide/ | main | 2026-08-26 13:31 | ACTIVE |
| delta | 2026-08-26 11:00 | T-043 (billing refactor) | CODE | src/billing/ | copy-delta | 2026-08-26 13:58 | ACTIVE |

*What a fresh thread reads from this:*

- Want T-044 touching `src/api/`? **beta** owns that scope — but in an
  isolated worktree, so your claim isn't blocked; conflicts would surface
  at beta's merge-back. For same-scope work, prefer your own worktree.
- Want to edit `src/api/` in the MAIN tree? Blocked: beta's merge will
  land there; claim a different scope or an isolated mode.
- Want `db/migrations/`? Overlaps **alpha** (main tree, heartbeat 12 min
  ago — alive) → notify, don't start.
- Docs work in `docs/guide/`? gamma owns it. Anywhere else in docs? Your
  LEDGER claim proceeds — coordinate the brief registry lock, never
  blocked long.
- delta shows the no-git isolation mode: `copy-delta` is a folder copy
  that merges back under MERGE at close-out.

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
| epsilon | 2026-08-26 11:48 | T-039 auth test fix — flaky mock replaced with injected clock; 47/47 passing; BUILDLOG updated |
| zeta | 2026-08-25 16:20 | T-037 research done — bullmq vs pg-boss comparison posted to PENDING-OWNER #D-012 |

---

**Stale-lock example:** if alpha's heartbeat showed `2026-08-26 09:02`
(no update for 2h+), any thread may first *flag* it in the START_HERE.md §5
notifications — e.g., "gamma 14:05: alpha heartbeat stale on T-040" — and only
reclaim after that flag is visible. Never silently deregister another thread.

**Atomic-claim example:** beta and delta both tried to claim T-041 at
10:15. Both ran `register-thread.sh` simultaneously — the registry lock
serialized them, exactly one row landed, the loser was refused with the
winner's row. That refusal is the system working.
