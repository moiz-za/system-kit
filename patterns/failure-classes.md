# Failure Classes — What This System Prevents

> Every pattern in this kit exists because a real incident proved the need.
> These are documented so future projects don't re-learn them the hard way.
> Each class includes: what happens, root cause, and the prevention mechanism.

---

## Class 1 — Concurrent Edit Collisions
**Severity:** CRITICAL
**What happens:** Two agents edit the same file simultaneously → changes mixed or overwritten → broken code or lost work.
**Root cause:** No coordination mechanism between parallel workers.
**Prevention:** Mutex protocol + thread registry. Each thread owns declared files exclusively. Clean-tree handoff between holders.
**Real evidence:** 26+ concurrent sessions across multiple projects with zero collisions when protocol followed.

---

## Class 2 — Dead Model Silently Breaking Workflows
**Severity:** MEDIUM
**What happens:** An AI model that worked yesterday is removed/unavailable today. Every run fails at routing with confusing errors.
**Root cause:** Free-tier catalogs rotate constantly; providers remove models without notice; upstream channels go down intermittently.
**Prevention:** Live model health probing before every session (not cached data). Dead models eliminated before work begins. Multi-provider rotation as fallback.
**Real evidence:** 3 of 8 free models died/blocked within a single day during live testing.

---

## Class 3 — Cumulative Totals Labeled as Daily Events
**Severity:** HIGH
**What happens:** A dashboard displays "980 NEW events" when 980 is the lifetime total across all items. Charts render as flat lines because cumulative values barely change daily.
**Root cause:** Metrics stored as cumulative counters (e.g., third-party APIs exposing lifetime totals) treated as if they were daily deltas.
**Prevention:** Pairwise daily-delta transform: gained(d) = total(d) − total(previous day), clamped ≥0. Labels must match what the number actually represents.
**Real evidence:** Owner immediately spotted "980 new events" as wrong — user trust erodes when displayed data is obviously incorrect.

---

## Class 4 — Secrets Exposed Through Agent Context Windows
**Severity:** CRITICAL
**What happens:** Agent reads a config file containing API keys → keys enter the conversation context → sent to external AI provider servers → potentially logged, trained on, or exposed.
**Root cause:** No isolation between credential storage and agent context window.
**Prevention:** Scripts handle credentials internally and return only sanitized results. Agents never read raw key material. Key-safe tooling pattern enforced.
**Real evidence:** Multiple near-misses where config files containing keys were almost read directly by agents.

---

## Class 5 — Dead JavaScript Reaching Production
**Severity:** HIGH
**What happened:** Inline scripts with syntax errors deployed to production. Page rendered visually but all interactivity was dead. Users saw a working-looking page that did nothing.
**Root cause:** Only syntax-checking was done, not actual render/interaction testing. The specific error was a corrupted character-escape map in template code.
**Prevention:** Local render/interaction pass required before commit (step b of verification standard). Syntax checking alone is insufficient.
**Real evidence:** Two separate production incidents before this pattern was codified.

---

## Class 6 — History Loss Across Context Resets
**Severity:** HIGH
**What happens:** AI agent context window fills → compaction summarizes → important decisions, discovered gotchas, and architectural reasoning lost in summarization → next session repeats solved problems or contradicts prior decisions.
**Root cause:** Critical state lived only in agent memory, not persisted to files.
**Prevention:** Checkpoint-before-compaction protocol + append-only ledgers. Files are the memory; summarization is never trusted as the record of anything important.
**Real evidence:** Multiple sessions required re-research of already-solved problems because prior context was compacted away.

---

## Class 7 — Unrecorded Changes Silently Pushed
**Severity:** MEDIUM
**What happens:** Code pushed to production without corresponding ledger entries → no audit trail for what changed or why → future debugging impossible.
**Root cause:** Push executed before documentation was updated.
**Prevention:** Pre-push gate: ledger currency is mandatory. An unrecorded change does not get pushed.
**Real impact:** Breaks audit trail, makes rollback decisions uninformed, violates institutional memory principles.

---

## Class 8 — Region-Locked Resources Blocking Entire Workflows
**Severity:** MEDIUM
**What happens:** An API endpoint accessible from the developer's home network is blocked when accessed from a server in a different region/datacenter.
**Root cause:** Provider geo-restrictions, regional policy enforcement, or hosting-network egress filtering.
**Prevention:** Multi-region connectivity testing during setup. Multi-provider rotation for critical services. Document which endpoints work from which regions.
**Real evidence:** Same key worked from developer's laptop but returned 403 from production server for identical request.

---

## Class 9 — Hallucinated APIs and Endpoints
**Severity:** HIGH
**What happens:** Agent invents API methods, class properties, or endpoints that don't exist in the actual codebase → implementation looks correct but fails at runtime.
**Root cause:** LLM generates plausible-looking code based on patterns rather than verifying against the actual codebase.
**Prevention:** Always verify generated code against the real codebase structure before accepting. Use type checkers and IDE diagnostics. Never trust an agent's claim about what exists without grep-level confirmation.
**Real evidence:** Multiple instances where agents referenced non-existent methods or used wrong parameter names confidently.

---

## Class 10 — Cost Explosion From Uncontrolled AI Usage
**Severity:** MEDIUM-HIGH
**What happens:** Free-tier quotas consumed by automated probing/testing, leaving nothing for productive work. Or paid API usage scales unexpectedly with task complexity.
**Root cause:** No visibility into per-provider consumption rates; no budget enforcement.
**Prevention:** Free-tier rotation with automatic provider switching. Per-model health probing uses minimal tokens. Quota tracking internal but actionable.
**Real evidence:** 1,800/2,000 GitHub Actions minutes consumed in one month from repeated deploy cycles.

---

## Class 11 — Prompt Injection Through Project Data
**Severity:** HIGH
**What happens:** Malicious content in project files (README comments, code strings, dependency names) injects instructions into the LLM's context → agent takes unintended actions or leaks information.
**Root cause:** LLM cannot distinguish instructions embedded in data from legitimate system prompts.
**Prevention:** Structured context labeling. Data enters the model clearly marked as untrusted input. Tool-calling restricted to explicitly authorized operations. Output validated against expected schema before execution.
**Real evidence:** Increasingly common as AI agents interact with more external data sources.

---

## Class 12 — Stale Catalog Trust
**Severity:** MEDIUM
**What happens:** Cached model/provider lists become stale → threads select models that no longer exist or miss newly available ones.
**Root cause:** Catalog data read from cache instead of queried live.
**Prevention:** Real-time /models queries at thread startup (never trust cache for availability). Cache only for performance optimization, with staleness detection.
