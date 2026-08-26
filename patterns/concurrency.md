# Concurrency Protocol — Reference Pattern

> Prevents parallel agent threads from colliding. Proven across 26+ concurrent
> sessions with zero code collisions.

---

## The Three-Mutex Model

Most projects need exactly three locks. More can be added per domain.

### CODE
Exclusive right to edit tracked source files in the working tree.
Only one thread may hold CODE at any time.

**Hold duration:** task-long (claim to close-out)
**Handoff requirement:** clean tree (all scoped work committed or stashed + noted)

### LEDGER
Short-term access to shared tracking files (task boards, build logs, decision
trackers). Edits are surgical appends of the holder's own rows only.

**Hold duration:** seconds per edit
**Restriction:** file restructures forbidden while any other thread is registered

### DB-CF
Database schema changes, cloud infrastructure modifications, and anything that
alters state outside the working tree.

**Hold duration:** action-long

## Why three instead of one global lock

A single global lock serializes ALL work behind the slowest thread. With separate
mutexes, docs-only threads run fully parallel with code threads because they need
only LEDGER (seconds), not CODE (potentially hours). This is the primary throughput
advantage of the model.

## Clean-tree handoff

When releasing CODE, the thread must have:
- All declared-scope work committed (or stashed with a registry note)
- No uncommitted changes left in the tree
- Ledger entries current for everything done during the hold

This guarantees the next CODE holder starts from a known, clean state.

## Conflict resolution

| Situation | Response |
|---|---|
| Target task locked by live thread | Do not start; notify; claim different OPEN task |
| Required mutex held by live thread | Same: notify, wait, or claim non-conflicting work |
| Stale lock (>4h no heartbeat) | Flag it, then reclaim after flagging is visible |
| Shared file needs restructuring | ALL-CLEAR required (zero other registered threads) |

## Anti-pattern: single global lock

One lock for everything serializes docs-only work behind slow code tasks.
The three-mutex model exists specifically because a planning thread should never
wait for a debugging thread to finish. Separate concerns = parallel throughput.

## Real-world evidence

26+ concurrent sessions across multiple projects. Zero code collisions when the
protocol was followed. The one near-miss (a thread assumed a clean tree meant
another thread was done, but that thread was still active mid-task) led directly
to the heartbeat and ownership rules being added.
