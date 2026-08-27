# Changelog

All notable changes to System Kit are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.3.5] — 2026-08-26

### Changed

- **README professionally rebuilt** — centered header with dynamic release
  badge, table of contents, mutex table, patterns shown as a pattern→prevents
  table, worked-example callout linking both examples, cleaner section
  dividers and footer. All facts unchanged; all links verified.

## [1.3.4] — 2026-08-26

### Changed

- **Quick Start clarified** — README now states the setup prompt fills copied
  templates in place, or creates the `docs/` structure itself if step 1 was
  skipped. Removes the copy-then-build ambiguity.
- **`integrations/README.md`** — documented that the registry check expects a
  tracked `THREADS.md` (fails where the registry is gitignored, e.g. this
  kit's own private `docs/`).

## [1.3.3] — 2026-08-26

### Fixed

- **CI link-checker was dropping the filename** — the `sed` in
  `integrations/governance-check.yml` emitted `:line target` (no file) and
  mangled `http(s)` targets so the absolute-URL guard never fired, making the
  check report every external link as broken. Rewritten to emit
  space-separated `<file> <line> <target>`; verified against the repo.
- **CONTRIBUTING contradiction**: "no tool-specific integrations" now carves out
  the explicitly-optional `integrations/` folder, aligning the rules with the
  GitHub Actions example shipped since 1.3.0. Core `templates/` + `patterns/`
  remain methodology-only.
- Empty-folder validation refreshed (was stale since v1.3.1 edits); claim
  marked precise: tested with `git init`-first greenfield, not the literal
  no-git case.
- `integrations/README.md` header note aligned with the CONTRIBUTING carve-out.

## [1.3.2] — 2026-08-26

### Fixed

- **Example workflow link-checker bug** — the relative-link check in
  `integrations/governance-check.yml` used an `IFS=:` parse that glued the
  link target to the line number, so it always passed regardless of broken
  links, and depended on GNU-only `realpath`. Rewritten to split correctly
  and skip anchors/external URLs portably.
- **Placeholder-check false positives** — the workflow's placeholder scan
  flagged the kit's own `templates/`, `SETUP_PROMPT.md`, and `integrations/`
  files, which legitimately ship `[PROJECT NAME]` markers. Exclusions added.
- **Stale example copy** — `examples/example-START_HERE.md` still said
  "run model check" after the §0 removal in 1.3.1. Removed.
- **Ambiguous §5 reference** — `examples/example-THREADS.md` referenced a bare
  "§5"; clarified to "START_HERE.md §5 notifications".

### Changed

- `integrations/README.md` — check descriptions aligned with what the
  workflow actually verifies.

## [1.3.1] — 2026-08-26

### Changed

- **Model selection extracted from core template** — START_HERE no longer
  mandates live model probing as a universal step. Replaced with an optional
  pointer to the Model Rotation pattern; single-paid-provider projects skip it.
  Rationale: multi-provider free-tier assumption violated the kit's
  domain-neutrality principle.

## [1.3.0] — 2026-08-26

### Added

- **Pattern: Worktree-Based Parallel Coding** (`patterns/worktree-parallel.md`) —
  extends the three-mutex model to true simultaneous source edits via git
  worktrees; includes rules and explicit failure modes
- **Integration: Governance compliance check** (`integrations/governance-check.yml`) —
  optional GitHub Actions workflow validating link integrity, placeholder leaks,
  version consistency, and registry presence on PRs
- **Issue templates** — pattern proposal (evidence-required format) and bug report
- **Worked example** (`examples/example-THREADS.md`) — live registry with three
  threads at different stages plus stale-lock handling walkthrough
- Setup-prompt guidance for projects with no test framework and no git repository

## [1.2.0] — 2026-08-26

### Added

- **Pattern: Model Rotation** (`patterns/model-rotation.md`) — live-probing
  procedure for surviving free-tier catalog churn; covers mid-session failure
  handling and rotation rules
- **Pattern: Prompt Injection Defense** (`patterns/prompt-injection-defense.md`) —
  four defense layers for untrusted data in agent contexts; detection signals
  and honest limitations
- **Pattern: Context Window Management** (`patterns/context-window-management.md`) —
  checkpoint-before-compaction discipline with five triggers and re-entry protocol
- Governance system applied to this repo's own development (dogfooding):
  the kit now manages its own task board, build log, and thread registry

## [1.1.0] — 2026-08-26

### Added

- **Worked example** (`examples/example-START_HERE.md`) — fully filled-in entry point
  showing expected detail level after initialization
- **Troubleshooting appendix** in `SETUP_PROMPT.md` — ten documented initialization
  mistakes with correct behaviors
- **Edge-case guidance** in `SETUP_PROMPT.md` Step 2 — empty/greenfield projects,
  monorepos, and polyglot stacks
- Repository published at github.com/moiz-za/system-kit

### Fixed

- Case-mismatched filename references (`setup-prompt.md` → `SETUP_PROMPT.md`)
- Domain-specific reference removed from failure-classes (domain-neutral requirement)
- Inconsistent heading style across failure classes 6 and 12
- CHANGELOG pattern count corrected; cost-zero operation pattern now listed
- Tool-specific credential path genericized in START_HERE template
- README file tree updated to match actual structure (cost-zero pattern, CHECKPOINTS)

## [1.0.0] — 2026-08-26

### Added

- **Setup Prompt** (`SETUP_PROMPT.md`) — single-prompt initialization for any project
- **START_HERE template** — entry point with model selection, task queue, claim ritual
- **AGENTS template** — operating laws framework with universal + domain placeholder sections
- **THREADS template** — multi-thread concurrency registry with three-mutex model
- **Task board template** (`TASKS.md`) — ID · Task · Spec · Needs · Deps · Status columns
- **Build log template** (`BUILDLOG.md`) — append-only history format
- **Pending decisions template** (`PENDING-OWNER.md`) — decision tracker
- **Checkpoint template** (`CHECKPOINTS/_TEMPLATE.md`) — resume format
- **Patterns:**
  - Concurrency protocol (three-mutex model, proven across 26+ sessions)
  - Verification discipline (local-first standard, five-step order)
  - Failure classes (twelve documented classes with real incidents)
  - Security checklist
  - Cost-zero operation (free-tier rotation and resource management)
- **README.md** — professional documentation
- **CONTRIBUTING.md** — contribution guidelines
- **LICENSE** — MIT

### Security

- Key-isolation rules: credentials handled internally by scripts, never exposed to agents
- Pre-commit scanning requirement maintained across all templates
- Zero telemetry, zero phone-home, zero data collection in any template
