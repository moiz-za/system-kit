# Changelog

All notable changes to System Kit are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
