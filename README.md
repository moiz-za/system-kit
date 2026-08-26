# System Kit

**Portable multi-thread governance infrastructure for AI-agent development teams.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

Copy one folder into any project. Give any AI agent thread the setup prompt.
Get instant: multi-thread coordination, task tracking, verification gates,
push discipline, key isolation, and institutional memory — from day one.

Built from real production incidents across 26+ concurrent AI-agent sessions.

---

## The Problem This Solves

AI agent threads are incredibly productive but without governance they:

- **Collide**: two agents editing the same files simultaneously → lost work
- **Hallucinate APIs**: invent methods that don't exist in your codebase → broken implementations
- **Ship dead code**: syntax errors reaching production because nobody tested locally first
- **Lose context mid-task**: compaction summarizes away critical details → expensive re-research
- **Mislabel data**: lifetime totals displayed as "new today" → user trust erodes
- **Burn quotas**: dead models consuming requests before you find a working one
- **Expose secrets**: API keys entering LLM context windows → sent to external servers

Every pattern in this kit was born from a real incident. Nothing is theoretical.

## Quick Start

### 1. Copy into your project

```bash
# Copy templates into your project's documentation area
cp -r templates/ your-project/docs/
```

### 2. Open a new AI agent thread

Paste the contents of `SETUP_PROMPT.md` as your first message.

### 3. Follow the initialization

The agent will scan your project, ask questions, build everything customized to your stack.

### 4. Every future thread starts here

Open `START_HERE.md` (created during setup) → claim a task → work it → close it.

## What You Get

| Capability | How |
|---|---|
| Multi-thread coordination | Three-mutex concurrency model (CODE / LEDGER / DB) |
| Task queue with claim/lock/release | Single entry point with priority queue + conflict detection |
| Verification gates | Local-first testing + post-deploy smoke checks |
| Institutional memory | Append-only ledgers + checkpoint/resume system |
| Model health checking | Live availability probing before every session |
| Push discipline | Ledger currency required; owner-gated deployments |
| Key isolation | Credentials handled internally; never exposed to agents or logs |
| Plain-language owner gate | Decisions in simple English; owner interrupted only when needed |

## Patterns Included

Each pattern is documented with the real failure it prevents:

- [Concurrency Protocol](patterns/concurrency.md) — three-mutex model for parallel safety
- [Verification Standard](patterns/verification.md) — local-first testing discipline
- [Security Checklist](patterns/security-checklist.md) — universal + AI-specific requirements
- [Failure Classes](patterns/failure-classes.md) — documented bug classes with prevention mechanisms
- [Cost-Zero Operation](patterns/cost-zero-operation.md) — free-tier rotation and resource management

## Documentation Structure

```
system-kit/
├── SETUP_PROMPT.md            ← THE initialization prompt (paste into any new thread)
├── README.md                  ← You are here
├── LICENSE                    ← MIT
├── CONTRIBUTING.md            ← How to contribute
├── CHANGELOG.md               ← Version history
│
├── templates/                 ← Copy these into any project's docs folder
│   ├── START_HERE.md          ← Entry point: model selection + task queue
│   ├── AGENTS.md              ← Operating laws framework
│   ├── THREADS.md             ← Concurrency registry template
│   ├── workflow/              ← Task board, build log, pending decisions
│   └── CHECKPOINTS/           ← Resume checkpoint format
│
└── patterns/                  ← Proven patterns with failure evidence
    ├── concurrency.md         ← Mutex model reference
    ├── verification.md        ← Testing discipline reference
    ├── security-checklist.md  ← Universal security requirements
    ├── failure-classes.md     ← Documented failure classes
    └── cost-zero-operation.md ← Free-tier resource management
```

## Requirements

None. This kit is methodology, not software. It works with:
- Any language, framework, or stack
- Any AI provider (OpenAI, Anthropic, Google, DeepSeek, open-source models)
- Any hosting platform
- Any number of concurrent agent threads
- Solo developers or teams

## License

MIT — use it anywhere, adapt it freely.
