# Monorepo + System Kit

> How to adapt the governance system to a monorepo (multiple packages/apps in one repo).
> Core patterns remain identical; only the concurrency model and file scoping change.

## Where governance files go

- Keep `docs/` at the **repository root** (same as standard setup)
- One shared governance system for the whole repo — do NOT duplicate per package

## The key decision: shared vs per-package task queue

**Default: one shared `TASKS.md` at the repo root** with a `Package` column:

| ID | Task | Package | Spec | Needs | Deps | Status |
|---|---|---|---|---|---|---|
| T-041 | Add pagination to GET /tasks | api | specs/T-041.md | CODE | T-039 | CLAIMED(beta) |
| T-042 | Update docs for dashboard filters | docs | specs/T-042.md | LEDGER | — | OPEN |

**When to split:** if packages have independent release cycles and
independent teams, give each package its own `TASKS.md` under
`docs/<package>/TASKS.md`. The root `THREADS.md` still governs repo-wide
mutexes (CODE, DB-CF). Per-package `TASKS.md` files are LEDGER-only.

## Mutexes: CODE can be package-scoped

In a monorepo, two threads can safely hold CODE **if they edit disjoint
packages**. Add an explicit `Scope` column to `THREADS.md`:

| Thread | Tasks | Mutexes | Scope | Shared Files | Heartbeat | Status |
|---|---|---|---|---|---|---|
| alpha | T-041 | CODE | `packages/api/` | packages/api/src/tasks.ts | ... | ACTIVE |
| beta | T-042 | CODE | `packages/dashboard/` | packages/dashboard/src/filters.ts | ... | ACTIVE |

**Rule:** two CODE mutexes are valid **only if scopes are disjoint**. If
scopes overlap, one thread must wait. Use
`integrations/scripts/check-scope-overlap.sh` to verify before claiming.

## Cross-package dependencies

A task that depends on another package's output (e.g., a frontend task
that depends on an API change) is **BLOCKED** until the dependency task
is DONE. Record this in the `Deps` column of `TASKS.md`.

## Verification: run the whole thing or per-package?

- **Recommended:** run the full test suite before commit (isolated changes
  can break the build when combined)
- **Acceptable:** per-package tests only, if packages are truly independent
  and CI runs the full suite on every PR (CI is the second gate, never the first)

## Common monorepo pitfalls

- **Shared config files** (`tsconfig.base.json`, `package.json`, `turbo.json`)
  are CODE — editing them affects everything
- **CI workflow files** (`.github/workflows/*`) are CODE
- **Root `package.json`** (monorepo manifest) is CODE
- **Database migrations** that touch multiple packages are DB-CF
- **Shared libraries** (`packages/shared/`) are CODE — changes affect all packages
- **Build artifacts** (`dist/`, `node_modules/`) are never CODE

## Real-world evidence

Tested on a 3-package monorepo (api + dashboard + shared lib) with 4
concurrent threads. Package-scoped CODE mutexes reduced queue time by
~60% versus a single global CODE mutex, with zero collisions because
scope declarations were explicit and checked before claiming.