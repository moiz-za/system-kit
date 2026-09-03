# DEPLOY_QUEUE.md — The Deploy Lane's Entry Point

> A DEPLOY-lane thread opens THIS file first (its START_HERE
> equivalent), then the top entry whose handoff is complete.
> Adding entries: any CODE thread at close-out (via
> `DEPLOY_HANDOFF_TEMPLATE.md`) or the owner. The deploy thread
> re-reads this queue at every claim.
>
> **This project's deploy method** *(fill at setup from the owner's
> deploy answer — e.g. SSH pull + restart, copy/rsync to a host,
> platform CLI, manual handoff to the owner — this file only ships
> with a deploy target; pure local projects keep the DEPLOY lane
> dormant and delete this file)*

## Iron rules

1. **Refuse incomplete handoffs.** Missing version/rollback/smoke
   list/gate-evidence-without-numbers = one-line refusal in the entry
   + owner notified; nothing deploys until the CODE thread completes
   it. Validate first:
   `validate-deploy-handoff.sh <handoff.md>`
2. **Production needs the owner's explicit word.** Staging/test
   environments are agent-executable without per-deploy approval.
3. **Never write code. Never touch the working tree's git.** The
   deploy lane executes; it does not edit.
4. **Record every deploy** in BUILDLOG (version + files + smoke
   results) and flip the entry's status below.
5. **Emergency path** (production incidents only): owner's word +
   minimal handoff (version, evidence with numbers, what-changed,
   rollback) may deploy immediately; full form within 24h.

## Queue

| # | Task | Target | Handoff | Owner gate | Status |
|---|---|---|---|---|---|
| *(entries appear here — handoff links to a completed form)* | | | | | |

## Ceremony quick-reference

*(the steps below are the generic spine — the deploy-method note at the
top of this file defines your project's concrete commands)*

1. Validate the handoff (refuse if incomplete — rule 1)
2. Deploy the pinned version to the target (never "latest"; verify
   what landed matches what was pinned)
3. Apply DB changes if the handoff lists them (owner-executed per kit
   law; deploy thread verifies)
4. Run any build/cache steps the handoff lists beyond standard
5. Run the handoff's smoke list — every item, report pass/fail per item
6. Record in BUILDLOG (version + files + smoke) + flip the entry status
7. If any smoke fails: execute the handoff's rollback, re-verify, report

## Emergency path (prod incidents only)

Owner's word + pinned version + gate evidence with numbers + one-line
what-changed + rollback = sufficient to move now; the full handoff
follows within 24h after the fire is out.
