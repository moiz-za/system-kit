# Worktree-Based Parallel Coding — Reference Pattern

> The three-mutex model serializes CODE: one code thread at a time per
> working tree. This is correct for safety and sufficient for most teams.
> When you genuinely need simultaneous source edits, git worktrees extend
> the model instead of breaking it.

**Extends:** [Concurrency Protocol](concurrency.md). Read it first.

---

## When you actually need this

- Two code tasks are truly independent (disjoint files, no shared build state)
- Both are long (hours), and serializing wastes half a day
- You already hit the "docs-only threads fly, code threads queue" wall enough
  that throughput matters

If tasks touch overlapping files or one depends on the other's output,
**don't use worktrees — use the normal mutex queue.** Parallelism is not a
substitute for coordination; it multiplies the cost of skipping it.

## How it works

Each parallel code thread gets its own working tree off the same repository:

```bash
git worktree add ../project-taskname -b task/taskname
cd ../project-taskname
```

- Each tree holds its own CODE mutex — independent by construction
- The shared repository remains the single source of truth
- LEDGER discipline is unchanged: all registry/log edits still go through
  the ONE canonical docs location, append-only, own rows only

## Rules (additions to the standard protocol)

1. **Register the tree.** THREADS.md rows add a `Tree` column:
   `../project-taskname`. A tree without a registry row is an untracked lock.
2. **One tree = one task = one CODE mutex.** Never run two tasks in one
   secondary tree; that recreates the collision problem at smaller scale.
3. **Merge is part of close-out.** A thread isn't done when its feature works;
   it's done when its branch merges cleanly to main and the tree is removed:
   ```bash
   git worktree remove ../project-taskname
   ```
4. **Shared-file conflicts surface at merge, not during work.** Budget merge
   resolution time when claiming. If two claimed tasks both edit shared files,
   that should have blocked the second claim.
5. **Verification runs in-tree before merge**, same five-step standard as
   always. CI on the PR is the second gate, never the first.

## Failure modes this prevents vs introduces

| Prevented | Introduced (manage explicitly) |
|---|---|
| Serialized code threads idling | Divergent branches → merge conflicts |
| Blocked dependent work | Double resource burn (two agents, two test suites) |
| — | Stale trees accumulating after abandoned tasks |

Sweep for stale trees weekly: `git worktree list` against THREADS.md history.
A tree whose task closed days ago but still exists is hygiene debt.

## Real-world evidence

Adopted after docs-only throughput proved the mutex model worked but long
code tasks created a visible queue. Teams running 2–3 worktrees with strict
registry rows report clean merges; the failures observed came from skipping
rule 1 (unregistered trees) — which is why it's rule 1.
