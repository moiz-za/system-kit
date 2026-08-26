# Verification Standard — Reference Pattern

> Prevents "it works on my machine" and dead-code-in-production.
> Every step exists because a real incident proved its necessity.

---

## The order (never rearranged, never skipped)

```
(a) FULL LOCAL SUITE
    Run the project's complete test suite + linter + security scan.
    An unverified change does not get committed.

(b) LOCAL RENDER/INTERACTION PASS
    For UI-touching changes: serve locally, interact with the changed
    surfaces, confirm they render and behave correctly.
    Syntax checks alone are NOT sufficient.

(c) COMMIT → PUSH → DEPLOY
    Only after (a) and (b) pass. Ledger entries must be current
    before the push happens — unrecorded changes don't get pushed.

(d) READ-ONLY LIVE SMOKE CHECK
    After deploy: key routes respond correctly, login flow works,
    no error banners, rendered scripts parse cleanly.
    Report results before handing off.

(e) OWNER FUNCTIONAL VERIFICATION
    Only after (d) reports clean. The owner is never the first person
    to discover breakage.
```

## Why each step exists

| Step | Prevents | Real incident |
|---|---|---|
| (a) Local suite | Broken logic reaching commit | Test suite caught 9 defects in a single pre-ship audit round |
| (b) Local interaction | Dead JavaScript reaching production | Inline scripts with syntax errors deployed — page rendered but all interactivity was dead; caught only when owner visited the page |
| (c) Commit gate | Unverified changes pushed | Multiple instances of "pushed then found broken" before this gate existed |
| (d) Live smoke check | Deploy failures going unnoticed | Deploy reported green but served pages returned errors due to environment differences |

## Failure classes this prevents

| Class | Example |
|---|---|
| Dead JS in production | Inline scripts with syntax errors — page loads but all interactive elements are dead |
| Cumulative totals shown as daily events | Dashboard displaying lifetime counters labeled as "new today" |
| Secrets committed to repo | API keys or tokens accidentally included in source files |
| Partial uploads to production | Manual deploy missing files — smoke check catches incomplete deploys |
| Environment-specific breakage | Code works locally but fails on server due to config differences |

## Security integration

Security checks are part of steps (a) and (d), not a separate phase:
- Step (a): dependency vulnerability scan + secret exposure check
- Step (d): verify auth flows work + no unauthorized endpoints exposed

## When to skip steps

NEVER. Each step catches a class of failure the others miss. If time pressure
demands skipping, the correct response is to reduce scope, not reduce verification.

## Real metrics

Across one development period: 76 issues caught by local suite, 3 by local render
pass, 2 by live smoke check that would have reached users. Zero production incidents
attributed to changes that followed this full protocol.
