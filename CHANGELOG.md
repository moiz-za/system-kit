# Changelog

All notable changes to System Kit are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
