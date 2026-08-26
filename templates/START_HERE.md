# START_HERE.md — [PROJECT NAME] Entry Point

> **THE single entry point for every new thread.**
> Read this → run model check → claim a task → work it → close it.
> If your target is locked or conflicting → notify, don't start.

---

## §0 LIVE MODEL SELECTION

Before claiming any task, verify which AI models are currently alive and routable.

### Procedure

1. Read your AI agent tool's configured credentials (auth/config file or keychain)
   to identify which AI providers have keys configured
2. For EACH keyed provider, query its live `/models` endpoint (not cache):
   ```bash
   curl -s https://{provider-base-url}/models \
     -H "Authorization: Bearer {key}"
   ```
3. Separate results into FREE models and PAID models
4. For top FREE candidates (max 3): send one tiny chat probe (~10 tokens,
   e.g., "Reply with exactly: OK") to verify routability
5. Eliminate any model that returns: errors, empty content, timeouts, or
   region-blocked responses
6. Rank survivors by: speed × context window × coding ability
7. PAID models are listed last as guaranteed fallback — never probed
8. Present recommendation with alternatives

### Rules

- Probe only FREE models; paid models are assumed always-available
- One probe per candidate model — no repeated hammering
- If a provider hits its daily limit or underperforms: suggest switching
  immediately without showing quota counters or internal metrics
- Handle all credentials internally — never echo keys in output
- Track daily probe count internally if the provider enforces rate limits;
  adjust probing frequency accordingly

### Output format

```
✅ RECOMMENDED: {model-id} ({provider}) — {context} ctx · {latency}s · healthy
✅ {model-id} ({provider}) — {context} ctx · {latency}s · healthy
⚠️ {model-id} ({provider}) — degraded: {reason}
❌ {model-id} — dead: {reason}

Guaranteed fallback: {paid-provider} (paid — always available)
```

---

## §1 THE RULE (read once, follow always)

0. **SELF-CLEAN:** while in THREADS.md, move any CLOSED rows down to completed.
1. **Open THREADS.md** — check active threads, held mutexes, heartbeats.
2. **Scan the task queue** for first OPEN task that:
   - is not locked by another thread
   - has no unmet dependency
   - requires only mutexes currently free
3. **CLAIM it** — register your row in THREADS.md BEFORE touching files.
4. **Work the task** per its spec. Heartbeat on resume after >1h.
5. **Close out:** tick done + append BUILDLOG + update PENDING-OWNER +
   deregister from THREADS.

## §2 CONFLICT & NOTIFY RULE

- Task LOCKED by live thread → DO NOT START. Post notification + report.
- Stale lock (>4h) → flag, then reclaim.
- Never touch another live thread's owned files.
- Shared-ledger edits: append-only, own rows only.
- Restructures need ALL-CLEAR.

## §3 TASK QUEUE

| ID | Task | Spec | Needs | Deps | Status |
|---|---|---|---|---|---|
| *(tasks appear here)* | | | | | |

## §4 LAWS DIGEST

1. Secrets never enter tracked files, conversations, or LLM context
2. Full verification suite passes locally before every commit
3. Production is NEVER the first test bench
4. Append-only ledgers; corrections reference old entries
5. Owner decisions in plain English with recommended defaults
6. Key-safe tooling: scripts handle credentials internally
7. Clean-tree handoff when releasing any mutex
8. Push-sync: ledgers current before push; law re-read after deploy
9. Compaction protocol: checkpoint first, re-read after reset
10. Data honesty: cumulative ≠ daily; labels match reality

Verification commands: *[fill per project]*

## §5 NOTIFICATIONS (append-only)

| When | Thread | Note |
|---|---|---|
| — | — | — |
