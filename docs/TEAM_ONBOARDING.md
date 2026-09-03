# Team Onboarding — System Kit for Non-Solo Teams

> You're a team (2+ humans) using the kit. This file covers the questions
> that don't come up when one person is the owner.

## Roles

| Role | What they do | Can claim |
|---|---|---|
| **Owner** | Approves irreversible actions, signs off on merges, arbitrates conflicts | All mutexes (final say) |
| **Operator** | Runs the governance system day-to-day: claims tasks, registers threads, enforces heartbeat checks | All mutexes except when Owner has explicitly held them |
| **Observer** | Watches THREADS.md and reads BUILDLOG; can comment on tasks but not claim | LEDGER (read-only views) |

Default in solo projects: Owner = Operator = the same person.

## Who can claim which lane / mutex

- **LEDGER** (STRATEGY / DOCS lanes) — anyone. Brief holds (seconds per
  edit, under the REGISTRY lock) are routine.
- **CODE** (CODE lane) — Operator or Owner, to a **declared scope**.
  Parallel CODE claims are fine when scopes are disjoint — the claim
  script verifies this; when in doubt, or for long tasks, use an
  isolated mode (worktree with git, folder-copy without).
- **DB-CF** — Owner only, by default. Migrations and infrastructure
  changes are risky enough that one person should hold this account.
  A more mature team can extend DB-CF to specific Operators.
- **DEPLOY** (DEPLOY lane) — Owner or an explicitly trusted Operator
  only: the lane executes on servers. It works exclusively from
  complete Deploy Handoffs and refuses incomplete ones; production
  deploys always need the owner's explicit word.

## How a new teammate joins

1. **Read** `docs/AGENT_BRIEF.md` (15 seconds) and `docs/START_HERE.md` (5 minutes).
2. **Skim** `docs/AGENTS.md` (the 10 universal laws). Sign off on them — the
   laws are binding, so any disagreement is a setup-phase conversation.
3. **Read** the 12 failure classes in `patterns/failure-classes.md` to
   understand the system's design intent.
4. **Add yourself** to a `TASKS.md` row as Observer; ask for an LEDGER
   claim first to prove you understand the protocol.
5. **Move to Operator** once the Owner signs off on your first LEDGER close.

## Review workflows for shared tasks

- **Single-owner task** — one Operator claims, closes, posts BUILDLOG entry.
- **Shared task** — one Operator leads, others comment in BUILDLOG.
  Don't try to claim the same task as two threads; the mutex model
  assumes one thread owns a task at a time.
- **Cross-team task** (e.g., frontend + backend coordination) — post
  in `docs/workflow/PENDING-OWNER.md` for a design decision; once the
  decision is recorded, claim the concrete implementation as a normal task.

## Escalation paths for conflicts

| Conflict | Resolution |
|---|---|
| Two threads want CODE at once | Whoever registered first wins; the other posts in `START_HERE.md §5` and waits |
| Stale thread (no heartbeat for 2h+) | Flag in `START_HERE.md §5`, then reclaim after flag is visible |
| Disagreement on a law | Owner decides; the law lives in `AGENTS.md` amendment log |
| Disagreement on a domain decision | `docs/workflow/PENDING-OWNER.md`; defaults proceed if no Owner response in 24h |
| Personal/priority override | Owner only. Logged in BUILDLOG with reason. |

## What "the team is healthy" looks like

- BUILDLOG is current within 24h of every commit
- THREADS.md has no rows without a heartbeat for 2h+
- PENDING-OWNER.md has zero open decisions older than 7 days
- No thread is stuck waiting on Owner more than 24h
- Scope declarations in THREADS.md match what threads actually touched

If any of these slips for a week, run a governance retro: read BUILDLOG
backwards, look for the friction, propose a process change in
PENDING-OWNER.md, amend the relevant `AGENTS.md` law if needed.