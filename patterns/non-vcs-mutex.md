# Non-VCS Mutex Variant — Reference Pattern

> Not every project uses git. The standard mutex model assumes version
> control for clean-tree handoffs and append-only history. This pattern
> preserves the same concurrency guarantees when no VCS is present,
> using only filesystem primitives — and in v3 it is the Tier 0 core:
> the same lock library, claim script, and scope rules the git path
> uses, minus the git-only extras.

**Extends:** [Concurrency Protocol](concurrency.md). Read it first.

---

## When to use this

- The project has no version control (or none used for governance)
- The working tree is on a shared filesystem (NFS, SMB, or local)
- The team wants the full mutex model without the git prerequisite

If git is available, use the standard model — branches give you free
recovery from bad mutex decisions. This variant is the standalone path.

## Tier 0: what works identically without git

v3 moved the entire claim pipeline into pure-filesystem scripts, so
no-git projects lose nothing on the concurrency core:

| Capability | Mechanism |
|---|---|
| Atomic claims | `register-thread.sh` under the REGISTRY filesystem lock |
| Scoped parallel CODE | Scope column + overlap check (machine-side, no git needed) |
| Task-claim race prevention | TASKS.md flips happen under the same REGISTRY lock |
| Heartbeats & stale reclamation | `heartbeat.sh`; 30-min stamps, 2h stale |
| Clean release | `release-thread.sh` moves rows, marks DONE |
| True isolation | `copy` mode → [Folder-Copy Parallel Coding](folder-copy-parallel.md) |

What no-git projects don't get: the pre-commit scope hook (no commits
exist to hook) and branch-based recovery. Enforcement is claim-time
only; after a claim, staying inside scope is discipline.

## Lock file format

Each mutex claim writes a single file:

```
<DOCS-FOLDER>/.locks/<MUTEX>.lock
```

The file holds the holder's PID; its presence IS the lock. Creation is
atomic via noclobber — only one racing writer can create it:

```bash
# Acquire (atomic on POSIX)
mkdir -p <DOCS-FOLDER>/.locks
if ( set -o noclobber; echo $$ > "<DOCS-FOLDER>/.locks/<MUTEX>.lock" ) 2>/dev/null; then
  echo "ACQUIRED: <MUTEX>"
else
  echo "BUSY: <MUTEX> held by PID $(cat <DOCS-FOLDER>/.locks/<MUTEX>.lock 2>/dev/null)"
fi

# Release (holder only)
rm -f <DOCS-FOLDER>/.locks/<MUTEX>.lock
```

On non-POSIX systems, the OS-specific equivalent (CreateFile with
`dwShareMode=0` on Windows, FileSystemObject on macOS) provides the
same guarantee.

## Heartbeat protocol

A stale lock blocks all future work. Without VCS you can't ask "what's
your last commit?", so the holding thread rewrites its heartbeat
(`heartbeat.sh` — every ~30 minutes of active work). Any thread may
check the heartbeat column; **no heartbeat for 2h+ = stale**, and the
lock is reclaimable after flagging in START_HERE.md notifications.

## Clean-state handoff (replacement for clean-tree)

Without a VCS, "clean tree" becomes "no uncommitted work artifacts in
the shared filesystem." The handoff requirement:

- All edits the thread claims to have done are visible in the files
- No `.tmp` or `.bak` files left from the work
- A BUILDLOG entry timestamps the closeout

The next thread reads the BUILDLOG to discover what changed, then runs
the verification standard from there.

## Scope declarations

Two threads holding CODE and editing overlapping files without
realizing it is the core risk the Scope column prevents. The claim
script checks overlap machine-side before any row is inserted
(`check-scope-overlap.sh` runs standalone in claim or CI mode, no git
required). If the new scope intersects any live main-tree thread's
scope, the claim is blocked with a clear message.

## Mutex semantics

| Mutex | Hold duration | Enforcement |
|---|---|---|
| `CODE` (scoped) | task-long | claim-time overlap check |
| `LEDGER` | seconds per edit | REGISTRY lock |
| `DB-CF` | action-long | lock file |
| `MERGE` | one copy-back | lock file |

The semantic separation (LEDGER held for seconds, CODE for hours) is
what lets docs-only threads run in parallel with code threads. That
advantage is preserved exactly.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Using file mtime as the lock | Two threads can touch mtime; not atomic |
| echo-then-read-back lock acquisition | Two racing writers can both verify their own PID — use noclobber |
| Locking per-file instead of per-mutex | Defeats the LEDGER-shared-across-docs purpose |
| Skipping heartbeats on "short" tasks | Tasks expand; locks must expire |
| Reusing the same lock file across mutexes | Defeats independent hold semantics |

## What this pattern does NOT solve

- **No recovery from deleted files** — without VCS, an `rm` is permanent.
  Pair with a host-level backup.
- **No multi-host locking** — works on one filesystem. For multi-host,
  the lock file must be on a shared mount (NFS, SMB) and the atomicity
  guarantees weaken across slow links.
- **No replay history** — the append-only ledger is the only audit trail.
- **No commit-time enforcement** — out-of-scope edits after a claim are
  discipline-only (git projects get the pre-commit hook).

## Real-world evidence

Adopted on a 3-month client engagement where the project couldn't use
git (compliance constraint). The lock-file variant held up across 12
concurrent threads and zero code collisions. Heartbeat reclamation
caught two abandoned threads within the 2-hour window. The main
practical loss was replay history — every incident required referencing
the BUILDLOG rather than `git log`.
