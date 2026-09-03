# Worked Example — THREADS.md During a Live Session

> This shows what `THREADS.md` looks like mid-day with five threads across
> all four lanes — scoped parallel CODE, both isolation modes, and a
> deploy lane. Reference for what healthy registry state looks like.
> Example project is generic on purpose.

---

# THREADS.md — Taskloop Concurrency Registry

## Protocol

*(protocol rows unchanged from template — omitted here for brevity)*

## Active Threads

| Thread | Started | Tasks | Lane | Mutexes | Scope | Tree | Model | Heartbeat | Status |
|---|---|---|---|---|---|---|---|---|---|
| alpha | 2026-08-26 09:02 | T-040 (sessions UUID migration) | CODE | DB-CF | db/migrations/ | main | - | 2026-08-26 13:40 | ACTIVE |
| beta | 2026-08-26 10:15 | T-041 (pagination endpoint) | CODE | CODE | src/api/ | ../taskloop-beta | - | 2026-08-26 13:52 | ACTIVE |
| gamma | 2026-08-26 13:30 | T-042 (user guide filters) | DOCS | LEDGER | docs/guide/ | main | - | 2026-08-26 13:31 | ACTIVE |
| delta | 2026-08-26 11:00 | T-043 (billing refactor) | CODE | CODE | src/billing/ | copy-delta | - | 2026-08-26 13:58 | ACTIVE |
| eps | 2026-08-26 12:00 | T-044 (prod release T-039) | DEPLOY | DEPLOY | - | main | - | 2026-08-26 13:15 | ACTIVE |

*What a fresh thread reads from this:*

- **Lanes first.** Want to write code? You're CODE lane — and CODE never
  touches servers, so T-044's deploy work is off-limits; file your handoff
  at close-out instead. Want to deploy? You're DEPLOY lane — open
  `workflow/DEPLOY_QUEUE.md` and take the top entry whose handoff
  validates; refuse incomplete ones.
- Want T-045 touching `src/api/`? **beta** owns that scope — but in an
  isolated worktree, so your claim isn't blocked; conflicts surface at
  beta's merge-back. For same-scope work, prefer your own worktree.
- Want `db/migrations/`? Overlaps **alpha** (main tree, heartbeat fresh)
  → notify, don't start.
- Docs work in `docs/guide/`? gamma owns it (DOCS lane, LEDGER mutex).
- eps shows the deploy lane mid-release: it claimed T-044, validated the
  handoff (version pinned, smoke list with rendered-content checks,
  rollback), and holds DEPLOY while executing — no other thread may
  touch servers meanwhile.

## Recently Completed

| Thread | Ended | Summary |
|---|---|---|
| zeta | 2026-08-26 11:48 | T-039 auth test fix — CODE lane; shipped with Deploy Handoff (queue #7); deployed + smoke green |
| eta | 2026-08-25 16:20 | T-037 research verdict — STRATEGY lane; buy-vs-build posted to PENDING-OWNER #D-012 |

---

**Stale-lock example:** if alpha's heartbeat showed `2026-08-26 09:02`
(no update for 2h+), any thread may first *flag* it in the START_HERE.md §5
notifications — e.g., "gamma 14:05: alpha heartbeat stale on T-040" — and only
reclaim after that flag is visible. Never silently deregister another thread.

**Atomic-claim example:** beta and delta both tried to claim T-041 at
10:15. Both ran `register-thread.sh` simultaneously — the registry lock
serialized them, exactly one row landed, the loser was refused with the
winner's row. That refusal is the system working.

**Refusal-rule example:** a CODE thread once closed out with "gate green,
ship it" and no smoke list. The deploy thread refused the handoff in one
line ("missing smoke list + evidence without numbers"), notified the
owner, and nothing deployed until the form was completed. That refusal
was the system working too.
