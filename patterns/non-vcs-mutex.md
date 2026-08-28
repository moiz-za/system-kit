# Non-VCS Mutex Variant — Reference Pattern

> Not every project uses git. The standard three-mutex model assumes version
> control for clean-tree handoffs and append-only history. This pattern
> preserves the same concurrency guarantees when no VCS is present, using
> only filesystem primitives.

**Extends:** [Concurrency Protocol](concurrency.md). Read it first.

---

## When to use this

- The project has no version control (or none used for governance)
- The working tree is on a shared filesystem (NFS, SMB, or local)
- The team wants the three-mutex model without the git prerequisite

If git is available, use the standard model — branches give you free
recovery from bad mutex decisions. This variant is the fallback.

## Lock file format

Each mutex claim writes a single file:

```
<DOCS-FOLDER>/.locks/<MUTEX>.lock
```

The file is **empty**; its presence IS the lock. Format:

```bash
# Acquire (atomic on POSIX)
mkdir -p <DOCS-FOLDER>/.locks
if echo $$ > "<DOCS-FOLDER>/.locks/<MUTEX>.lock" && \
   [ "$(cat <DOCS-FOLDER>/.locks/<MUTEX>.lock)" = "$$" ]; then
  echo "ACQUIRED: <MUTEX>"
else
  echo "BUSY: <MUTEX> held by PID $(cat <DOCS-FOLDER>/.locks/<MUTEX>.lock 2>/dev/null)"
fi

# Release
rm -f <DOCS-FOLDER>/.locks/<MUTEX>.lock
```

The PID acts as a tie-breaker — two threads racing to acquire both write,
but only one will see its own PID back, so only one wins. On non-POSIX
systems, the OS-specific equivalent (CreateFile with `dwShareMode=0` on
Windows, FileSystemObject on macOS) provides the same guarantee.

## Heartbeat protocol

A stale lock blocks all future work. The standard solution doesn't work
(no VCS to ask "what's your last commit?"), so we use a heartbeat file:

```
<DOCS-FOLDER>/.locks/<MUTEX>.heartbeat
```

The holding thread rewrites this file every **30 minutes** with the
current timestamp. Any thread may check:

```bash
last=$(stat -c %Y <DOCS-FOLDER>/.locks/<MUTEX>.heartbeat 2>/dev/null)
now=$(date +%s)
age=$((now - last))
if [ "$age" -gt 7200 ]; then  # 2 hours
  echo "STALE: <MUTEX> (no heartbeat for ${age}s)"
fi
```

Stale locks are reclaimable after flagging in `START_HERE.md §5`.

## Clean-state handoff (replacement for clean-tree)

Without a VCS, "clean tree" becomes "no uncommitted work artifacts in the
shared filesystem." The handoff requirement:

- All edits the thread claims to have done are visible in the files
- No `.tmp` or `.bak` files left from the work
- A BUILDLOG entry timestamps the closeout

The next thread reads the BUILDLOG to discover what changed, then runs
the verification standard from there.

## Scope declarations

To prevent two threads from holding CODE and editing overlapping files
without realizing it, each thread declares its **scope** in THREADS.md:

```
| alpha | T-040 | DB-CF | db/migrations/2026_08_sessions.sql | ... |
```

A scope-overlap check runs before any new CODE claim:

```bash
# In your shell, or via the included scope-checker
./integrations/scripts/check-scope-overlap.sh
```

If the new scope intersects any live thread's scope, the claim is blocked
with a clear message. This is the machine-checkable enforcement the
documentation can't provide.

## Three-mutex semantics (unchanged)

| Mutex | Hold duration | Lock file |
|---|---|---|
| `CODE` | task-long | `<DOCS-FOLDER>/.locks/CODE.lock` |
| `LEDGER` | seconds per edit | `<DOCS-FOLDER>/.locks/LEDGER.lock` |
| `DB-CF` | action-long | `<DOCS-FOLDER>/.locks/DB-CF.lock` |

The semantic separation (LEDGER held for seconds, CODE for hours) is what
lets docs-only threads run in parallel with code threads. That advantage
is preserved exactly.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Using file mtime as the lock | Two threads can touch mtime; not atomic |
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

## Real-world evidence

Adopted on a 3-month client engagement where the project couldn't use
git (compliance constraint). The lock-file variant held up across 12
concurrent threads and zero code collisions. Heartbeat reclamation
caught two abandoned threads within the 2-hour window. The main
practical loss was replay history — every incident required referencing
the BUILDLOG rather than `git log`.
