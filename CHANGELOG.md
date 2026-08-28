# Changelog

All notable changes to System Kit are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0] — 2026-08-28

### Added

- **Pattern: Non-VCS Mutex** (`patterns/non-vcs-mutex.md`) — filesystem lock-file
  replacement for git branches: the three-mutex model now works on projects
  without version control. Lock files with PID atomicity + heartbeat
  reclamation replace clean-tree handoff. SETUP_PROMPT Step 2 no longer blocks
  on git.
- **`docs/AGENT_BRIEF.md`** — a 30-second entry point at the repo root that no
  agent can skip. Every new thread reads it before touching anything.
- **`docs/TEAM_ONBOARDING.md`** — roles (Owner/Operator/Observer), who can claim
  which mutex, onboarding steps for new teammates, review workflows, and
  conflict escalation paths. For teams of 2+ humans.
- **Framework quick-starts** (`examples/`): Laravel, Next.js, FastAPI,
  monorepo — per-stack verification commands, mutex file mappings, and
  common pitfalls per stack.
- **Machine-checkable enforcement** — two scripts under `integrations/scripts/`:
  - `check-scope-overlap.sh` — fails a CODE claim if its scope overlaps another
    active thread's declared files
  - `validate-checkpoint.sh` — fails a push if any in-progress checkpoint is
    missing required sections or still has `[TASK-ID]`
- **CI gate extended** — the governance-compliance workflow now checks scope
  overlap and checkpoint completeness, in addition to links, placeholders,
  version, and registry presence.
- **SETUP_PROMPT Step 2** — added an explicit prompt-injection scan for the
  project files before ingestion.

### Changed

- **README:** repository-layout table now lists `AGENT_BRIEF.md` and the
  framework examples; "works with anything" claim now acknowledges the
  non-VCS variant; honest-limitations section links both new patterns
  (non-VCS mutex + worktree parallel).
- **SETUP_PROMPT Step 2** — no-git case is now a first-class supported shape,
  not a blocker.

### Why 2.0.0

The kit was previously advisory-only: it documented protocols that agents
*should* follow, but nothing could enforce them. This release adds the first
machine-checkable enforcement layer (scope overlap checker + checkpoint
validator as CI gates) and removes the git prerequisite. That is a step
change in what the kit can guarantee, not just more documentation.

## [1.5.1] — 2026-08-27

### Fixed

- **README now reflects v1.5.0 capabilities** — FAQ clarifies that web-chat
  agents without file access can also initialize the system (setup prompt
  embeds the full file-structure spec); Quick Start notes the dedicated-
  subfolder behavior when a project already has its own `docs/`.

## [1.5.0] — 2026-08-27

### Added

- **SETUP_PROMPT Step 4: from-scratch file-structure spec** — when the kit
  folder is not readable by the agent (e.g. web-chat agents without file
  access), the prompt now specifies each governance file's exact section
  layout so rebuilt systems match the kit's structure and worked examples.
- **SETUP_PROMPT Step 4: docs-folder collision guidance** — projects that
  already have a `docs/` with product documentation now get an explicit rule:
  governance files go in a dedicated subfolder, never mixed in.
- **SETUP_PROMPT Step 3:** verification-command question now tells
  non-technical owners they can say "I don't know" and get proposed defaults.

### Changed

- **docs/START_HERE.md:** optional model-selection block is now fully
  self-contained (no dangling reference to the kit's patterns folder, which
  is not copied into user projects); §1 start loop now includes checking
  PENDING-OWNER.md for unblocking decisions.
- **docs/AGENTS.md:** amendment channel clarified for solo projects (owner
  directly, when no governance thread exists).
- **SETUP_PROMPT Step 5:** archive instruction handles the case where no copy
  of the prompt lives in the project.
- **SETUP_PROMPT appendix mistake #6:** corrected behavior now matches the
  mistake (manifest after Step 1, system at Step 5).

### Fixed

- **docs/CHECKPOINTS/_TEMPLATE.md:** "gotchas, gotchas discovered" typo.
- **patterns/failure-classes.md:** missing `---` separator before Class 12.
- **patterns/cost-zero-operation.md:** provider table now carries an as-of
  date so stale free-tier numbers are recognizable as such.
- **patterns/failure-classes.md Class 3:** marketplace-specific wording
  ("favorites", "listings") genericized — the kit targets any project, any
  stack, any domain.
- **examples/example-START_HERE.md:** emoji status glyphs replaced with plain
  text markers (`[OK]` / `[WARN]` / `[DEAD]`).

## [1.4.1] — 2026-08-27

### Added

- **Banner** (`media/banner.svg`) — visual identity for the README, following
  the pattern of comparable repos (spec-kit, BMAD-METHOD).
- **Community section** — Discussions + Issues links in README.
- **Mermaid workflow diagram** — the thread loop now renders as a native
  GitHub diagram instead of ASCII art.

### Changed

- **README optimized against niche research** (github/spec-kit, BMAD-METHOD,
  awesome-claude-code): linked badge row incl. stars + discussions, GitHub
  callouts (`[!TIP]`/`[!NOTE]`/`[!WARNING]`) replacing plain blockquotes,
  founder story tightened to one paragraph (failure table carries the detail),
  TOC dropped in favor of BMAD-style scannable brevity.

## [1.4.0] — 2026-08-27

### Changed

- **BREAKING (folder rename): `templates/` is now `docs/`** — the governance
  files are now the actual docs folder an agent copies into your project and
  fills in. No more "templates" concept for users to understand: you get docs,
  the agent fills them. SETUP_PROMPT Step 4 now copies the kit's `docs/`
  directly when readable.
- **README rebuilt for non-technical users** — new "Why I Built This" founder
  story (the real incidents behind every pattern), terminal-free Quick Start
  (Download ZIP → paste prompt → answer questions), "Do I need to be
  technical?" FAQ, and a folder-purpose table making clear only `docs/` goes
  into your project.
- CI compliance check updated for the rename (placeholder exclusion now
  `docs/`); integrations docs aligned.

## [1.3.6] — 2026-08-26

### Changed

- **Quick Start folder clarity** — README now states explicitly that only
  `templates/` is copied into a project; `patterns/`, `examples/`, and
  `integrations/` are reference material that stays with the kit.

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
