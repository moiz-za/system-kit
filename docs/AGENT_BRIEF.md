# System Kit — Agent Brief

> Read this before touching anything. It takes 30 seconds.

---

This is a governance system for a project managed by multiple AI agent threads.
Its single job: prevent agents from colliding, losing work, or shipping untested code.

## The loop (repeat every session)

1. **Read** `docs/START_HERE.md`
2. **Claim** your task atomically:
   `register-thread.sh <docs-folder> <thread> <task-id> <mode> <scope...>`
   — scope must be disjoint from every ACTIVE main-tree thread (the script
   verifies this; your claim is refused on overlap)
3. **Work.** Stay inside your declared scope. Long code task? Use an
   isolated mode — `worktree` (git) or `copy` (no git).
4. **Close out.** `release-thread.sh <docs-folder> <thread> "<summary>"`,
   then update `docs/workflow/BUILDLOG.md` and `docs/workflow/PENDING-OWNER.md`.

## The three laws that cannot be broken

1. **Secrets never enter chat.** Keys live in env vars or secret stores only.
2. **Verify before commit.** Run the full local suite before every commit.
3. **Production is never the first test bench.** Prove it locally first.

## Before you claim anything

- Check `docs/THREADS.md` for active threads and their declared scopes
- Check `docs/workflow/PENDING-OWNER.md` for decisions that unblock tasks
- Check `docs/AGENTS.md` for the full law set

## If context is running low

Do not wait. Checkpoint first: `docs/CHECKPOINTS/_TEMPLATE.md`. Resume from the checkpoint after any reset.

## Questions?

Read `docs/START_HERE.md` — it has everything.
