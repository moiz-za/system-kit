# Folder-Copy Parallel Coding — Reference Pattern

> Worktree isolation needs git. Many projects — local folders, no-VCS
> environments, compliance-constrained filesystems — have none. The
> folder-copy variant gives those projects the same guarantee: each
> thread works in its own copy, and a MERGE-guarded copy-back step
> consolidates changes into the main folder.

**Extends:** [Concurrency Protocol](concurrency.md). Read it first.
**Gitless twin of:** [Worktree Parallel Coding](worktree-parallel.md).

---

## When to use copy mode

- No git (or no VCS used for governance) AND a long code task needs true
  isolation from other threads
- Two no-git threads must touch overlapping files — serialized at
  copy-back (MERGE) instead of blocked outright

Small disjoint-scope tasks should stay in `main` mode — a copy costs
disk space and a merge-back step. Copies earn it on long or
overlapping-scope work.

## How it works

`register-thread.sh` handles the mechanics:

```bash
register-thread.sh docs alpha T-041 copy src/api/
```

1. Creates `copy-alpha/` next to the project folder — the full project
   minus `docs/` (the registry stays canonical in the main tree), minus
   git internals, minus other copies
2. Registers the row with `Tree = copy-alpha` (isolated rows never
   conflict with main-tree scopes)
3. At release: `release-thread.sh` holds the MERGE mutex, copies every
   changed file back into the main folder, deletes the copy

## Rules (additions to the standard protocol)

1. **Never edit the main folder while holding a copy.** The copy is your
   tree; the main folder belongs to main-mode threads and merges.
2. **Register the copy.** The THREADS.md row records it in the `Tree`
   column. An unregistered copy is an untracked lock.
3. **Copies are short-lived.** The longer a copy lives, the more the main
   folder drifts and the harder the merge-back. Close out within a day;
   if a task runs longer, re-merge (release + re-register) at checkpoints.
4. **Copy-back is part of close-out, under MERGE.** One merge at a time.
   Changed files overwrite main-folder state — review what differs before
   releasing (`diff -r main copy` if you want a preview).
5. **Registry edits still go to the main docs folder**, under the REGISTRY
   lock — copies deliberately exclude `docs/` so there is exactly one
   THREADS.md, ever.

## What merge-back does and does not handle

| Handles | Does NOT handle |
|---|---|
| New files created in the copy | Files changed in BOTH copy and main since the split |
| Files changed only in the copy | Deletions in the copy (main copy survives) |
| Renames (as delete+add, manual) | Binary diffs needing semantic merge |

A both-sides-changed file is silently overwritten main→copy at
merge-back. If parallel work on the same file is likely, re-merge early
and often, or don't use a copy for it at all.

## Failure modes this prevents vs introduces

| Prevented | Introduced (manage explicitly) |
|---|---|
| No-git threads blocking each other on scope | Both-sides-changed overwrites at merge |
| Mid-task scope-drift collisions | Stale copies accumulating after abandoned threads |
| — | Disk-space burn per copy |

Sweep for stale copies weekly: any `copy-*/` whose task closed or whose
thread has no ACTIVE row is hygiene debt — remove it and log the cleanup.

## Real-world evidence

Structural twin of the worktree flow, which teams ran with 2–3 parallel
trees and clean merges once registration became automatic. The no-git
deployment context (12 concurrent threads, filesystem locks, zero code
collisions) is documented in [Non-VCS Mutex](non-vcs-mutex.md) — this
pattern adds the isolation layer that deployment never had.
