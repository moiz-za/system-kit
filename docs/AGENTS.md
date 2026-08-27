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
Every thread registers before touching files. Registration includes:
thread name · task claimed · mutexes held · shared files touched · heartbeat.

### Mutexes
Three locks prevent collisions between parallel threads:
- **CODE**: exclusive right to edit source files (one thread at a time)
- **LEDGER**: short hold on shared tracking files (append-only edits only)
- **DB-CF**: database/schema/cloud-infrastructure changes

### Rules
1. Claim before working. Deregister when done.
2. Never touch another thread's owned files.
3. Shared-ledger edits are surgical appends of own rows only.
4. Restructures forbidden while any other thread is registered.
5. Stale threads (>4h no heartbeat) reclaimable after flagging.
6. Clean-tree handoff when releasing CODE.

---

## ARTICLE III — Domain Laws ([PROJECT NAME] Specific)

> Filled during setup based on the project's domain, stack, and constraints.
> These override or extend universal laws where the domain demands it.

<!-- [DOMAIN LAWS GO HERE — filled during initialization] -->

---

## ARTICLE IV — Amendment Process

Laws are added by appending to this file and logging in the amendment table.
Removing or softening a law requires owner approval + documented reason.
The sole amendment channel is the designated planning/governance thread.

---

## AMENDMENT LOG

| ID | Date | Change |
|---|---|---|
