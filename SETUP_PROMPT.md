# SETUP_PROMPT — Governance System Initialization

> Copy-paste this entire prompt into a new AI agent thread in your project.
> The agent will scan your project, ask questions, and build everything.

---

You are initializing a governance system for this project. Follow these steps
in exact order. Do not skip steps. Do not assume anything not stated here or
discovered during scanning.

## STEP 1 — EXISTING DOCUMENTATION CHECK

Ask the user:
"Do you already have internal documentation (laws, rules, task boards, logs)
for this project?"

**If YES:**
- Ask for the path to the documentation folder
- Read EVERY file in that folder recursively
- Catalog each file:
  - What it contains (laws? tasks? plans? logs? checkpoints?)
  - Whether it's current or historical
  - Whether it overlaps with any other file
- Produce an INTEGRATION MANIFEST listing every file found and its disposition:
  - INTEGRATED (moved into new structure)
  - REFERENCED (kept in place, linked from new docs)
  - FLAGGED (unreadable, needs owner attention)
  - MERGED (duplicates combined, both originals preserved in archive)
- Present the manifest to the user before proceeding
- Never delete any file. Move only. Originals preserved.

**If NO:**
- Note that all files will be created fresh from templates

## STEP 2 — CODEBASE SCAN

Scan the project codebase and report:

1. Primary language(s) and framework(s)
2. Build system / package manager
3. Test framework + how to run tests
4. Linter/formatter commands
5. CI/CD setup (if any)
6. Deploy method (SSH / FTP / container / serverless / none)
7. Security posture (auth system, encryption, API key handling)

Also check:
- Are there existing secrets exposed anywhere?
- Is there a pre-commit hook configured?
- What's the git remote / hosting situation?

### Special project shapes

- **Empty / greenfield project:** skip deep scanning; ask the owner what
  stack is planned and record it as provisional. Build the system anyway —
  governance works from day zero.
- **Monorepo:** treat the repo as ONE governed territory. Ask whether each
  package/app gets its own task queue or shares one. Default: one shared
  TASKS.md with a `Package` column added. Mutexes stay global to the repo.
- **Polyglot:** list every language's verification commands separately in
  START_HERE §4. Never merge them into one ambiguous command chain.
- **No test framework configured:** flag this to the owner as a governance
  gap — Law 2 (verify before commit) is unenforceable without one. Suggest
  the language's standard minimal option (one suggestion, not a survey),
  and record "verification = lint + build only" in START_HERE §4 until a
  test suite exists. Do NOT install anything without owner approval.
- **No git repository yet:** flag as a blocking prerequisite. The mutex
  model's clean-tree handoff and append-only history both assume version
  control. Ask the owner to run `git init` + first commit before the system
  goes LIVE; build all files meanwhile so confirmation is the only step left.

## STEP 3 — OWNER QUESTIONS

Ask the user these questions (plain language, one at a time if needed):

1. What is this project called and what does it do?
2. Who is it for? (personal use, clients, public product?)
3. What are the domain-specific rules? (things that must always or never happen)
4. How do you push/deploy changes? (method, frequency, who approves)
5. What verification commands must pass before committing?
6. Any security constraints specific to this domain?

Record ALL answers — they become the project's domain laws.

## STEP 4 — BUILD THE SYSTEM

Create the following structure in the documentation area:

> If the project has no documentation area yet (empty/greenfield project),
> create one at `docs/` in the repository root and say so explicitly when
> presenting the system. Never scatter governance files outside one folder.

```
[DOCS-FOLDER]/
├── START_HERE.md          ← Entry point: task claim → work → close out
├── AGENTS.md              ← Laws: universal + domain-specific + amendment log
├── THREADS.md             ← Live concurrency registry
├── workflow/
│   ├── TASKS.md           ← Task board (ID · Task · Spec · Needs · Status)
│   ├── BUILDLOG.md        ← Append-only history
│   └── PENDING-OWNER.md   ← Decisions waiting on owner
└── CHECKPOINTS/
    └── _TEMPLATE.md       ← Resume checkpoint format
```

Fill every file using:
- Universal patterns (defined below)
- Answers from Steps 1–3
- Domain-specific rules from owner

### Universal laws (include in every AGENTS.md):

1. **Secrets never enter tracked files, conversations, or LLM context.**
   Keys live in env vars, secret managers, or platform stores. Always.
2. **Verify before commit.** Run full test suite + linter + security scan locally
   before every commit. An unverified change does not get committed.
3. **Local-first verification.** The live/production environment is never the
   first test bench. Prove it works locally, then deploy, then smoke-check live.
4. **Append-only ledgers.** History is never rewritten. Every change gets its
   own entry. Corrections are new entries referencing the old ones.
5. **Plain-language owner gate.** All decisions presented to the owner in simple
   English with recommended defaults. Owner interrupted ONLY for risky actions.
6. **Key isolation in tooling.** Scripts that test connectivity handle credentials
   internally and return sanitized results. Agents must never read, display,
   or transmit raw keys.
7. **Clean-tree handoff.** Releasing a mutex requires committed (or stashed +
   noted) work. Next thread inherits a known state, not half-done changes.
8. **Push-sync protocol.** Before pushing: ledgers updated. After deploying:
   re-read law files to absorb concurrent changes from other threads.
9. **Compaction protocol.** At ~70% context or on compaction signal: checkpoint
   first, then re-read all core docs after context reset before continuing.
10. **Data honesty.** Cumulative totals are never labeled as daily events.
    Deltas are computed from consecutive snapshots. Labels match reality.

### Concurrency protocol (include in every THREADS.md):

Three mutexes prevent collisions between parallel threads:
- **CODE**: exclusive right to edit source files (one thread at a time)
- **LEDGER**: short hold on shared tracking files (append-only edits only)
- **DB-CF**: database/schema/cloud-infrastructure changes

Rules:
- Register before working; deregister when done
- Never touch another thread's owned files
- Stale threads (>4h no heartbeat) may be reclaimed after flagging
- Shared file restructures require ALL-CLEAR (zero other registered threads)

### Verification standard (include in START_HERE.md):

The live/production environment is NEVER the first test bench:
(a) Full local suite → (b) local render/interaction pass for UI →
(c) commit → push → deploy → (d) read-only live smoke check by agent →
(e) owner functional verification LAST.

## STEP 5 — PRESENT AND CONFIRM

Present the initialized system to the owner:
- Show the file tree
- Show the first task queue entry as example
- Confirm all domain laws are captured correctly
- Ask: "Is anything missing or incorrect?"

After owner confirms:
- Mark system as LIVE in the entry point
- The project now accepts task claims via the standard protocol
- Archive the setup prompt (rename with date suffix)

---

## QUALITY REMINDERS FOR THE INITIALIZING AGENT

- Read existing docs BEFORE asking questions (context prevents redundant asks)
- Never expose API keys, tokens, or secrets in any output
- If existing docs conflict with templates, ASK the owner which wins
- Suggest improvements you notice but NEVER auto-implement them
- Record everything in the build log as you go

---

## APPENDIX — TROUBLESHOOTING: COMMON INITIALIZATION MISTAKES

Known failure modes during setup. If you catch yourself doing any of these,
stop and correct before proceeding.

| # | Mistake | Why it fails | Correct behavior |
|---|---|---|---|
| 1 | Filling `[PROJECT NAME]` placeholders with invented names | Owner's actual name never asked; docs ship wrong | Ask in Step 3; use the owner's exact name |
| 2 | Inventing domain laws instead of asking | Fabricated rules bind every future thread wrongly | Domain laws come ONLY from owner answers |
| 3 | Skipping the existing-docs integration manifest | Old docs orphaned; institutional memory lost | Catalog EVERY file found; present manifest |
| 4 | Deleting "duplicate" files during integration | Destroys history; violates append-only spirit | Move + merge only; originals preserved |
| 5 | Writing verification commands you never ran | Broken gate blocks every future commit | Run each command once; record real output status |
| 6 | Building all files silently, then dumping them at once | Owner can't course-correct mid-setup | Present after Step 5 confirmation gate |
| 7 | Weakening the three-mutex model to one lock ("simplification") | Docs-only threads serialize behind code work | Preserve CODE/LEDGER/DB-CF separation always |
| 8 | Copying example content from this kit into live files | Placeholder/example text pollutes the real system | Templates are structure; fill from THIS project's reality |
| 9 | Reading credential files to "check provider health" | Secrets enter LLM context | Use key-safe tooling; sanitized results only |
| 10 | Marking the system LIVE without owner confirmation | Unvalidated governance becomes binding law | Step 5 confirmation is mandatory, not optional |
