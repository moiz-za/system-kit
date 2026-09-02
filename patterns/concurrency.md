# Concurrency Protocol — Reference Pattern

> Prevents parallel agent threads from colliding. Proven across 26+
> concurrent sessions with zero code collisions; v3 adds machine-checked
> claims, scope-scoped CODE, and isolation modes so parallel work no
> longer queues behind a single global lock.

---

## The Four-Mutex Model

Most projects need exactly these locks. More can be added per domain.

### CODE — scoped, not global
Exclusive write to a **declared scope** (one or more files/dirs). Multiple
threads may hold CODE **simultaneously iff their scopes are disjoint** —
verified at claim time (register script / overlap checker) and at commit
time (pre-commit hook, git projects).

**Why scoped:** a single global CODE serializes ALL code work behind the
slowest thread. Two tasks touching `src/api/` and `src/ui/` are provably
independent — the scope declaration makes that proof machine-checkable
instead of hope-based. Declaring the whole repo as scope reproduces the
old conservative behavior when a task genuinely touches everything.

**Hold duration:** task-long (claim to close-out)
**Handoff requirement:** clean tree (all scoped work committed or stashed + noted)

### LEDGER
Short-term access to shared tracking files (task boards, build logs,
decision trackers). Edits are surgical appends of the holder's own rows
only, and every read-modify-write happens under the REGISTRY filesystem
lock — two threads appending simultaneously can never clobber rows.

**Hold duration:** seconds per edit
**Restriction:** file restructures forbidden while any other thread is registered

### DB-CF
Database schema changes, cloud infrastructure modifications, and anything
that alters state outside the working tree.

**Hold duration:** action-long

### MERGE
Serializes merge-backs of isolated trees (worktrees, folder-copies) so the
main tree is never in two half-merged states at once.

**Hold duration:** one merge

## Atomic claims — the registry lock

The registry itself is a shared file, so claiming through it has the same
race condition two threads editing any file would have. The fix: one
filesystem lock (`<DOCS-FOLDER>/.locks/REGISTRY.lock`) wraps every
registry read-modify-write — claim, release, heartbeat, task-status flip.
The lock uses atomic noclobber file creation; a 10s acquire timeout keeps
a crashed holder from freezing every other thread.

**Atomic claim sequence** (all inside the lock): read registry → verify
name unique → verify scope disjoint from every ACTIVE main-tree thread →
insert row → flip task OPEN→CLAIMED → write identity file (`.kit-thread`)
→ release.

## Enforcement layers

| Layer | What it checks | Where |
|---|---|---|
| Claim script | scope disjoint, task OPEN, name unique | `register-thread.sh` |
| Pre-commit hook | staged files inside declarer's scope | git projects |
| CI gate | no two ACTIVE threads overlap pairwise | `check-scope-overlap.sh --all` |
| Discipline | the manual protocol, when no shell exists | THREADS.md rules |

Where a POSIX shell exists, claims and commits are machine-checked.
Where none exists, the documented manual protocol applies — the rules
are identical, only the enforcement differs.

## Isolation modes

- **main** — shared tree + disjoint scopes. Universal default; needs nothing.
- **worktree** — git only: per-thread tree + branch. Conflicts surface at
  merge-back (under MERGE), never during work. See
  [Worktree Parallel Coding](worktree-parallel.md).
- **copy** — no-git twin: per-thread folder copy merged back under MERGE.
  See [Folder-Copy Parallel Coding](folder-copy-parallel.md).

## Clean-tree handoff

When releasing CODE, the thread must have:
- All declared-scope work committed (or stashed with a registry note)
- No uncommitted changes left in the tree (registry/ledger updates exempt —
  they ARE part of close-out)
- Ledger entries current for everything done during the hold

## Conflict resolution

| Situation | Response |
|---|---|
| Scope overlaps an ACTIVE main-tree thread | Claim refused — pick a non-overlapping task, or use worktree/copy mode |
| Target task locked by live thread | Do not start; notify; claim different OPEN task |
| Required mutex held by live thread | Same: notify, wait, or claim non-conflicting work |
| Stale lock (no heartbeat for 2h+) | Flag it, then reclaim after flagging is visible |
| Shared file needs restructuring | ALL-CLEAR required (zero other registered threads) |
| Out-of-scope file staged for commit | Rejected by hook — extend scope or unstage |

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Single global lock | Serializes docs work behind slow code tasks; kills throughput |
| Read-then-write registry claims without a lock | Two threads can both "win" the same task |
| Scope declared vaguely ("some files") | Overlap check can't run; parallelism reverts to hope |
| Skipping heartbeats on "short" tasks | Tasks expand; locks must expire |
| Deregistering another live thread | Destroys live work's protection |

## Heartbeat discipline

One spec everywhere (v3): stamp every ~30 minutes of active work; a row
with no heartbeat for 2h+ is stale and reclaimable after flagging. In git
projects every commit auto-counts as a heartbeat.

## Real-world evidence

26+ concurrent sessions across multiple projects with zero code collisions
under the original three-mutex model. The one near-miss (a thread assumed a
clean tree meant another thread was done, but that thread was still active
mid-task) led directly to the heartbeat and ownership rules. v3's machine
enforcement exists because the next class of near-misses was agents
skipping the documented protocol entirely — claims and commit-scope are
now checked, not trusted.
