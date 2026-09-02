# Worktree-Based Parallel Coding — Reference Pattern

> Scoped CODE lets threads with disjoint scopes edit the shared tree in
> parallel. When a long code task needs TRUE isolation — its own tree,
> its own branch, conflicts deferred to merge time — git worktrees
> extend the model. In git projects this is the recommended default
> for long code tasks, not an exception.

**Extends:** [Concurrency Protocol](concurrency.md). Read it first.

---

## When to use worktree mode

- Long code tasks (hours): a shared-tree claim holds scope for the whole
  duration, narrowing what other threads can do; a worktree costs nothing
  to anyone
- Overlapping-file risk: even well-meant scope declarations drift; a worktree
  makes drift harmless until merge
- Two tasks genuinely touch the same files (serialized by MERGE instead of
  blocked outright)

If a task is small and its scope is cleanly disjoint, `main` mode is
simpler — take it. Worktrees earn their setup cost on long or
risky-scope tasks.

## How it works

`register-thread.sh` handles the mechanics:

```bash
register-thread.sh docs alpha T-041 worktree src/api/
```

1. Creates `../project-alpha/` via `git worktree add` on branch `kit/T-041-alpha`
2. Registers the row with `Tree = ../project-alpha` (isolated rows never
   conflict with main-tree scopes)
3. Writes the identity file inside the worktree
4. At release: merges the branch back under the MERGE mutex, removes the tree

Each tree holds its own CODE claim — independent by construction. The
shared repository remains the single source of truth; LEDGER discipline
is unchanged (all registry edits go through the ONE canonical docs
location, under the REGISTRY lock).

## Rules (additions to the standard protocol)

1. **Register the tree.** The THREADS.md row records it in the `Tree`
   column. An unregistered tree is an untracked lock.
2. **One tree = one task = one CODE mutex.** Never run two tasks in one
   secondary tree; that recreates the collision problem at smaller scale.
3. **Merge is part of close-out.** A thread isn't done when its feature
   works; it's done when `release-thread.sh` merges cleanly and the tree
   is removed.
4. **MERGE serializes merge-backs.** One merge at a time, ever. A conflicted
   merge is the holder's to resolve before the next merge may start.
5. **Verification runs in-tree before merge**, same five-step standard as
   always. CI on the PR is the second gate, never the first.

## Failure modes this prevents vs introduces

| Prevented | Introduced (manage explicitly) |
|---|---|
| Long tasks narrowing shared-tree scope | Divergent branches → merge conflicts |
| Scope-drift mid-task collisions | Double resource burn (two agents, two test suites) |
| Blocked dependent work | Stale trees accumulating after abandoned tasks |

Sweep for stale trees weekly: `git worktree list` against THREADS.md
history. A tree whose task closed days ago but still exists is hygiene
debt — remove it and log the cleanup.

## Real-world evidence

Adopted after docs-only throughput proved the mutex model worked but long
code tasks created a visible queue. Teams running 2–3 worktrees with
strict registry rows report clean merges; the failures observed came from
unregistered trees — which is why the tree column and the claim script
now make registration automatic.
