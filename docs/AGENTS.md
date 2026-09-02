# AGENTS.md — [PROJECT NAME] Operating Laws

> Binding on every thread. Amend only via the designated amendment channel.
> Append new laws — never silently rewrite existing ones.

---

## ARTICLE I — Universal Laws (every project, every domain)

### Secrets & Credentials
- Keys, tokens, and credentials live ONLY in env vars, secret managers,
  or platform stores. Never in tracked files, conversations, or LLM context.
- Scripts that test connectivity handle credentials in-process and return
  sanitized results. Agents must never read, display, or transmit raw keys.

### Verification
- Nothing is "done" until tests pass locally.
- The live/production environment is never the first test bench.
  Order: (a) full local suite → (b) local render/interaction pass for UI →
  (c) commit → push → deploy → (d) read-only smoke check by agent →
  (e) owner functional verification LAST.
- Every change runs the full verification gate before commit.

### Communication
- All decisions presented to the owner in plain English with recommended defaults.
- Safe reversible choices proceed on documented defaults without asking.
- Owner interrupted ONLY for risky or irreversible actions.

### Data Honesty
- Cumulative totals are never labeled as daily events.
- Deltas computed from consecutive snapshots with clear labeling.
- Every claim traces to a verifiable source.

### Ledgers & History
- Build logs are append-only: every change gets its own timestamped entry.
- Corrections are new entries referencing the old ones. History is never rewritten.
- Integration manifests account for every file discovered during setup.

---

## ARTICLE II — Concurrency Protocol

### Thread Registration
Every thread registers before touching files — through the claim script
(`register-thread.sh`) when available, or manually following the same rules.
Registration includes: thread name · task claimed · scope · mode (main /
worktree / copy) · mutexes held · heartbeat.

### Mutexes
Four locks prevent collisions between parallel threads:
- **CODE**: exclusive write to a **declared scope** (one or more files/dirs).
  Multiple threads may hold CODE simultaneously **iff their scopes are
  disjoint** — machine-verified at claim time and at commit time (git hook).
  Declaring the whole repo reproduces the old single global CODE.
- **LEDGER**: append-only edits to own rows in shared tracking files.
  Every shared-ledger read-modify-write happens under the REGISTRY
  filesystem lock — parallel appends can never clobber rows.
- **DB-CF**: database/schema/cloud-infrastructure changes (action-long).
- **MERGE**: serializes merge-backs of isolated trees (worktrees and
  folder-copies) so the main tree is never in two half-merged states.

### Isolation modes (all projects, any environment)
- **main** — shared tree, parallel CODE via disjoint scopes. Works with
  or without git. This is the default for small/short tasks.
- **worktree** — git projects: each thread gets its own working tree +
  branch; conflicts surface only at merge-back, guarded by MERGE.
  Recommended default for long code tasks.
- **copy** — no-git projects: same isolation via a folder copy
  (`copy-<thread>/`) merged back under MERGE at close-out.

### Rules
1. Claim before working (scope must be disjoint from every ACTIVE main-tree
   thread). Deregister when done.
2. Never touch another thread's owned files.
3. Shared-ledger edits: append-only, own rows only, under the REGISTRY lock.
4. Restructures forbidden while any other thread is registered.
5. Stale threads (no heartbeat for 2h+) reclaimable after flagging.
6. Clean-tree handoff when releasing CODE.
7. Commits outside your declared scope are rejected (pre-commit hook, git
   projects). Registry/ledger files are always in scope for every thread.

---

## ARTICLE III — Domain Laws ([PROJECT NAME] Specific)

> Filled during setup based on the project's domain, stack, and constraints.
> These override or extend universal laws where the domain demands it.

<!-- [DOMAIN LAWS GO HERE — filled during initialization] -->

---

## ARTICLE IV — Amendment Process

Laws are added by appending to this file and logging in the amendment table.
Removing or softening a law requires owner approval + documented reason.
The sole amendment channel is the designated planning/governance thread
(or the owner directly, in solo projects).

---

## AMENDMENT LOG

| ID | Date | Change |
|---|---|---|
