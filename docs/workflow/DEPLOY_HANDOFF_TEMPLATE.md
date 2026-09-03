# DEPLOY_HANDOFF_TEMPLATE.md — Mandatory Close-Out Form for CODE-Lane Tasks

> **The four-lane rule:** a CODE thread commits and pushes, then STOPS —
> it never touches any server. Deployment is executed by a DEPLOY-lane
> thread from THIS form. **The deploy thread refuses incomplete
> handoffs** — missing version, rollback, smoke list, or gate evidence
> claimed without numbers. Refusal = a one-line note in the queue entry +
> notify the owner; nothing deploys until the CODE thread completes it.
> That refusal rule is what keeps this form honest.

---

## How to use

Copy everything between the lines into a new file
(`workflow/handoffs/<TASK-ID>.md` or your project's convention), then
fill EVERY item. "None" is a valid answer — an unfilled blank is not.

```
## Deploy Handoff — <TASK-ID> — <one-line what shipped>

1. PINNED VERSION: <git: full 40-char commit sha — non-git: release
   artifact reference (timestamp + BUILDLOG entry, or archive checksum)>
   PUSHED/STAGED: <yes/no> — VERIFIED HOW: <remote ref match / API
   check / checksum / log — never "assumed">
   REMOTE STATE AFTER PUSH: <sha or reference or n/a>

2. TARGET: <staging / production / both / remote host or service name>

3. WHAT CHANGED: <one paragraph, plain English — the deploy thread has
   NOT read your task's history and never will; this is all it gets.
   Write for a stranger>

4. DB PREREQUISITES: <exact SQL/commands + which environments — or
   "none". Per kit law: destructive DB changes are owner-approved and
   owner-executed; the deploy thread verifies, never improvises>

5. ENV / SECRETS CHANGES: <exact keys + value shape, or "none">

6. BUILD/CACHE STEPS BEYOND THE STANDARD CEREMONY:
   <e.g. "assets changed — run the asset build after pulling" / "none">

7. SMOKE LIST (deploy thread runs every item, reports pass/fail per item):
   - <specific route + expected result>
   - <specific behavior + expected outcome>
   - <at least one RENDERED-CONTENT check — grep the served output for
      the new thing. Status codes alone pass on stale builds; rendered
      output does not lie>

8. ROLLBACK: PRIOR-GOOD VERSION <sha or reference> —
   STEPS: <specific revert actions: which files/cache/data to revert,
   restore command, re-verify step>

9. GATE EVIDENCE: <suite passed/total> · lint <ok/fail> · typecheck
   <ok/fail> · build <ok/fail> · security scan <ok/fail> ·
   UI real-browser pass <done/n.a. — one line on what was clicked>

10. URGENCY: <routine / owner-requested / EMERGENCY>
```

---

## Filling notes (what "complete" means)

- **Item 1 is the contract.** No pinned version = no deploy. "Pushed"
  must be VERIFIED, not assumed — state how you checked.
- **Item 3 assumes zero shared context.** The deploy thread may run a
  different model, a different session, weeks later. Write for a
  stranger who knows nothing about your task.
- **Item 7 is where honesty lives.** If your smoke list would pass on
  the old build too, it is not a smoke list — test what THIS change
  shipped. Rendered-content checks, not just status codes.
- **Item 8 must actually work.** The deploy thread runs rollback steps
  verbatim under pressure; untested rollback steps are a defect.
- **Item 9 needs numbers.** "Gate green" without counts is refused —
  evidence, not assertion.

## Emergency path (production incidents only)

The owner's explicit word + a MINIMAL handoff (pinned version, gate
evidence with numbers, one-line what-changed, rollback) is sufficient
to move immediately — the full form follows within 24h after the
incident. Everything routine uses the full form before anything
deploys.

## Machine validation

```
./integrations/scripts/validate-deploy-handoff.sh <handoff.md>            # full
./integrations/scripts/validate-deploy-handoff.sh <handoff.md> --emergency
```

Exit 0 = complete. Exit 1 = REFUSED with the missing items listed —
the same check the deploy thread runs before executing.
