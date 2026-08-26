# System Kit

**Stop your AI agents from destroying each other's work.**

Portable governance infrastructure for AI-agent development teams — copy one
folder into any project, paste one prompt into any agent, and get instant:
multi-thread coordination, task tracking, verification gates, push discipline,
key isolation, and institutional memory.

Built from real production incidents across 26+ concurrent AI-agent sessions.
Zero code collisions when followed. Nothing here is theoretical.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-1.3.1-blue)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

---

## The Problem

AI coding agents (opencode, Claude Code, Cursor, Codex…) are incredibly
productive and completely ungoverned. Run two in parallel without a system and:

| Failure | What it costs you |
|---|---|
| Two agents edit the same files | Lost work, broken builds |
| Agent invents APIs that don't exist | Confidently wrong implementations |
| Syntax errors ship untested | Dead pages in production |
| Context compaction mid-task | Re-research the same problem twice |
| Cumulative data shown as daily | Users catch it before you do |
| Dead models eat your requests | Quotas burned on routing errors |
| Keys read into chat context | Secrets sent to external servers |

Every pattern in this kit exists because one of these actually happened.

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│  1. COPY   templates/ → your-project/docs/              │
│  2. PASTE  SETUP_PROMPT.md → new agent thread           │
│  3. ANSWER agent asks about your stack + domain rules   │
│  4. DONE   governance live: task board, thread registry │
│            build log, checkpoints, laws                 │
└─────────────────────────────────────────────────────────┘

Every future thread:  read START_HERE → claim a task → work
                      → close out → deregister
```

Collisions are prevented by the **three-mutex model**: `CODE` (source files),
`LEDGER` (tracking docs), `DB-CF` (infrastructure) are locked separately — so
a docs-only thread never waits behind a code thread, and two code threads can
never touch the same file.

## Quick Start

```bash
# 1. Copy templates into your project's documentation area
cp -r templates/ your-project/docs/
```

2. Open a new AI agent thread and paste the contents of [`SETUP_PROMPT.md`](SETUP_PROMPT.md)
3. Answer the agent's questions — it scans your project and builds everything
4. Every future thread starts at the generated `START_HERE.md`

See a [fully initialized START_HERE.md](examples/example-START_HERE.md) to know
what "done" looks like before you start.

## What You Get

| Capability | How |
|---|---|
| Multi-thread coordination | Three-mutex concurrency model (CODE / LEDGER / DB-CF) |
| Task queue with claim/lock/release | Single entry point + priority queue + conflict detection |
| Verification gates | Local-first testing, five-step order, owner verifies last |
| Institutional memory | Append-only ledgers + checkpoint/resume system |
| Optional model rotation | Live availability probing for rotating free-tier catalogs |
| Push discipline | Ledger currency required; owner-gated deployments |
| Key isolation | Credentials handled internally; never exposed to agents or logs |
| Plain-language owner gate | Decisions in simple English; owner interrupted only when needed |

## Patterns Included

Each pattern documents the real failure it prevents:

- [Concurrency Protocol](patterns/concurrency.md) — three-mutex model for parallel safety
- [Verification Standard](patterns/verification.md) — local-first testing discipline
- [Security Checklist](patterns/security-checklist.md) — universal + AI-specific requirements
- [Failure Classes](patterns/failure-classes.md) — twelve documented bug classes with evidence
- [Cost-Zero Operation](patterns/cost-zero-operation.md) — free-tier rotation and resource management
- [Model Rotation](patterns/model-rotation.md) — surviving weekly free-catalog churn
- [Prompt Injection Defense](patterns/prompt-injection-defense.md) — containing untrusted data in agent contexts
- [Context Window Management](patterns/context-window-management.md) — checkpoint-before-compaction discipline
- [Worktree Parallel Coding](patterns/worktree-parallel.md) — extending the mutex model to true simultaneous edits

## Who It's For

- **Solo developers** running several agent threads across projects
- **Small teams** whose agents keep overwriting each other
- **Anyone on free tiers** juggling rotating model catalogs
- **Agent-framework builders** who want a proven governance methodology

Works with any language, framework, host, AI provider, and any number of
concurrent threads. Zero dependencies — it's markdown methodology, not software.

## Honest Limitations

This kit relies on agents *following documented protocols*. There is no runtime
enforcement, no telemetry, no magic. If an agent ignores THREADS.md, nothing
stops it — the kit makes correct behavior explicit, checkable, and recoverable,
not automatic. See also: single-machine mutex assumption, English-only templates.

## FAQ

**How is this different from just having an AGENTS.md?**
An AGENTS.md states rules; System Kit adds the machinery that makes rules
operational — a live lock registry, append-only history, checkpoint format,
and an initialization prompt that adapts all of it to your project.

**Does it work with my agent/tool?**
Yes. It's plain markdown instructions — any LLM agent that can read and write
files can follow it (opencode, Claude Code, Cursor, Codex CLI, custom agents).

**Does it phone home / collect anything?**
No. Zero telemetry, zero network calls, zero data collection. Copy the files,
own them forever.

## Documentation

| File | Purpose |
|---|---|
| [`SETUP_PROMPT.md`](SETUP_PROMPT.md) | Paste into a new thread → initializes governance (+ troubleshooting appendix) |
| [`templates/`](templates/) | Copy into your project: entry point, laws, thread registry, workflow boards |
| [`patterns/`](patterns/) | Read-only references explaining why each rule exists |
| [`examples/`](examples/) | Worked examples: initialized START_HERE and a live THREADS registry |
| [`integrations/`](integrations/) | Optional extras — e.g., GitHub Actions governance-compliance check |

## Contributing

Patterns backed by real incidents are the most valuable contributions — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the proposal format. Bug fixes and
clarity improvements always welcome.

## License

MIT — use it anywhere, adapt it freely.
