# Four-Lane Thread System — Reference Pattern

> An agent that can both write code and execute on servers is a single
> point of failure. The lanes split that blast radius: STRATEGY plans,
> DOCS writes content, CODE writes code (and can never touch a
> server), DEPLOY executes on servers (and can never write code). The
> **Deploy Handoff** connects the two halves — and the **refusal rule**
> keeps it honest.

**Extends:** [Concurrency Protocol](concurrency.md). Read it first.

---

## The four lanes

| Lane | Thread type | Does | NEVER does | Typical work |
|---|---|---|---|---|
| STRATEGY | Planning/analysis | Specs, plans, research verdicts, decision framing | Write code; touch any server; push | Feature specs, architecture options, buy-vs-build verdicts |
| DOCS | Non-code content | Copy, guides, ledger syncs, handoff documents | Write code; touch any server; push | User guides, content packs, release notes |
| CODE | Coding | Write/fix/debug; full verification gate (real-browser pass for UI); commit + push per the project's push law; **files a Deploy Handoff at close-out** | **Touch any server** — no deploy of any kind | Features, fixes, refactors |
| DEPLOY | Release execution | **All server execution**; executes from complete handoffs only; refuses incomplete ones; records every deploy | Write code; touch the working tree's git | Releases, rollbacks, emergency fixes |

Rules that make the lanes real:

- A lane is **declared at claim time** and never crossed mid-task —
  finish, close out, open a new claim. (A mid-task detour across lanes
  is exactly the failure the split exists to prevent.)
- The lane **sets the mutex automatically**: STRATEGY/DOCS hold LEDGER,
  CODE holds CODE, DEPLOY holds DEPLOY.
- Lanes and isolation modes are **orthogonal** — a CODE-lane thread
  still picks main / worktree / copy for its working tree. Lanes say
  WHAT a thread may do; scopes say WHERE it may write.

## The push/deploy split

The CODE holder commits AND pushes (while its context is fresh) and
then **stops** — it never touches a server. Deployment of that pinned
version is executed by the DEPLOY holder from the handoff. Production
deploys need the owner's explicit word; staging/test environments are
agent-executable. The post-deploy smoke check is the DEPLOY holder's
duty (it runs the handoff's smoke list); the owner's functional
verification still comes last, unchanged.

## The Deploy Handoff (the load-bearing wall)

Every CODE close-out on a deployable project produces a completed
handoff (template: `workflow/DEPLOY_HANDOFF_TEMPLATE.md`):

1. **Pinned version** — git: full commit sha; non-git: release
   artifact reference (timestamp + BUILDLOG entry, or archive
   checksum) — plus HOW the push/staging was verified, never assumed
2. Target environment
3. What changed — one paragraph, plain English, **written for a
   stranger who never read your task** (the deploy thread may be a
   different model, a different session, weeks later)
4. DB prerequisites (exact commands; destructive changes are
   owner-executed per kit law)
5. Env/secrets changes
6. Build/cache steps beyond the standard ceremony
7. **Smoke list** — specific checks including at least one
   rendered-content check; status codes alone pass on stale builds
8. **Rollback** — prior-good version + concrete steps that actually
   work under pressure
9. **Gate evidence with numbers** — suite counts, lint/typecheck/build
   results, real-browser pass note. "Green" without numbers is refused
10. Urgency — routine / owner-requested / emergency

**The refusal rule (binding):** the DEPLOY thread REFUSES an
incomplete handoff — missing version, missing rollback, missing smoke
list, or gate evidence claimed without numbers. Refusal = a one-line
post in the queue entry + notify the owner; nothing deploys until the
CODE thread completes the handoff. **This rule is what keeps the wall
honest; without it the handoff is decorative.** The party with the most
to lose from an incomplete handoff (the one executing on production)
is the one who must reject it — that is the entire trick.

`workflow/DEPLOY_QUEUE.md` is the deploy lane's entry point: entries
link their handoff, the deploy thread claims the top complete one.

## Emergency path (production incidents only)

Process systems that demand full ceremony during a fire get bypassed
silently. The emergency path gives prod incidents a legitimate minimal
route: the owner's word + pinned version + gate evidence with numbers
+ one-line what-changed + rollback is sufficient to move immediately;
the full form follows within 24h. Everything routine uses the full
handoff before anything deploys.

## Handoff invalidation

A newer push does **not** invalidate a queued handoff: deploy the
version that was verified, not whatever landed after it. The next
release ships through its own handoff on the queue.

## When to use / not use

**Use when:** the project deploys anywhere (server, host, remote
service) and more than one agent works in parallel. The lanes pay for
themselves the first time a coding mistake can't reach production
because the deploy thread refused a vague handoff.

**Skip when:** the project has no deployment target (a purely local
folder) — the DEPLOY lane stays dormant (the queue/handoff templates
aren't installed; the lane exists in the docs only), and STRATEGY/DOCS
may not justify their overhead in a solo two-thread setup. The lane
system is the most opinionated kit feature — adopt it when the blast
radius is real.

## Honest costs

- The 10-item handoff is a **deliberate overhead tax** on every
  routine deploy. That is the price of the wall. Small projects can
  feel it; the emergency path exists for fires, not for skipping
  ceremony on routine work.
- The DEPLOY lane's quality ceiling is the runbook's quality. A novel
  deploy shape not covered by the project's ceremony note gets
  refused-or-asked, never improvised — by design.

## Failure modes this prevents vs introduces

| Prevented | Introduced (manage explicitly) |
|---|---|
| Coding errors deploying straight to prod | Handoff overhead on small routine changes |
| "Deployed the latest, not the verified" releases | Queue entries going stale (deploy thread re-validates handoffs each claim) |
| Vague, unaccountable deploys ("it worked locally") | Over-strict refusal friction (the fix is completing the handoff, not weakening the rule) |
| Secrets/credentials crossing into server-access sessions | — |

## Real-world evidence

Derived from a production multi-agent system that ran a single
code+deploy thread and discovered the hard way that one agent holding
both the keyboard and the server keys multiplies every mistake into an
outage. The lane split, the handoff form, and especially the refusal
rule were designed around that scar — plus the recurring lesson that
exit codes lie (rendered output doesn't) and that "verified" must mean
"stated HOW", not "assumed".
