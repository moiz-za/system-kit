# Model Rotation — Reference Pattern

> Free-tier AI model catalogs rotate weekly without notice. Any workflow that
> hardcodes a model name will break. This pattern keeps threads productive
> across catalog churn.

**Prevents:** Failure Class 2 (dead models silently breaking workflows),
Failure Class 12 (stale catalog trust).

---

## The principle

Model availability is a *runtime property*, not configuration. A model ID that
worked yesterday may be removed, region-blocked, or degraded today. Treat
model selection like DNS: query live at every session start, never cache
availability decisions.

## The rotation procedure

1. **Enumerate providers** — which providers have configured credentials?
   (Read from credential store; never echo key material.)
2. **Query `/models` live** for each provider — never use cached catalogs.
3. **Classify**: FREE candidates vs PAID fallbacks.
4. **Probe top FREE candidates** (max 3) with one tiny chat request each:
   - Probe message: ~10 tokens ("Reply with exactly: OK")
   - Eliminate on: error, empty content, timeout, region-block response
5. **Rank survivors**: speed × context window × coding ability.
6. **Record the winner + alternatives** in the thread's working notes.
7. **Re-run at every session start.** Yesterday's result is not today's answer.

## Rotation rules

| Rule | Rationale |
|---|---|
| One probe per candidate — no hammering | Probes consume quota; repeated retries burn free limits |
| Paid models listed last, never probed | They are the guaranteed floor, assumed always-available |
| Switch immediately on degradation mid-session | Don't finish the session on a flaky model; migrate early |
| Track probe count internally if provider rate-limits | Stay under radar; adjust probing frequency |
| Re-evaluate monthly even when nothing broke | Dead models sometimes return; new ones appear |

## Mid-session failure handling

When the selected model starts failing mid-task:

1. Detect after 2 consecutive failures (not 1 — single flakes happen)
2. Checkpoint current state (see context-window-management pattern)
3. Re-run the rotation procedure from step 2
4. Resume task from checkpoint on the new model

Never attempt to "wait out" a dying model mid-session.

## Real-world evidence

- 3 of 8 free models died or became region-blocked within a single day of
  live testing.
- Sessions that skipped live probing routed to dead endpoints and burned
  minutes debugging routing errors before discovering the model was gone.
- Cached catalog data caused selection of models removed hours earlier.
