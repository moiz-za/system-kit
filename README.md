<div align="center">

# System Kit

**Governance infrastructure for AI-agent development teams.**

Copy one folder into any project. Paste one prompt into any agent.
Get instant multi-thread coordination, task tracking, verification gates,
and institutional memory.

[![Release](https://img.shields.io/github/v/release/moiz-za/system-kit?label=release&color=success)](https://github.com/moiz-za/system-kit/releases)
![Version](https://img.shields.io/badge/version-1.4.0-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

</div>

---

## Why I Built This

I'm not a professional developer. I build products with AI agents — and I hit
every failure in the book the hard way:

- Agents **inventing APIs and code that didn't exist**, then shipping it
- **Two agents editing the same files** at once, silently destroying work
- **API keys leaking into chat context**, on their way to external servers
- **Untested, broken code reaching production** because nothing forced a local check
- **Context resets erasing decisions**, so the same problems got re-solved for days
- **Numbers mislabeled** (lifetime totals shown as "new today") until users noticed

Each mistake cost real time, money, or trust. So instead of patching incidents
one by one, I wrote down the system that prevents each one — and proved it
across **26+ concurrent AI-agent sessions with zero code collisions**.

System Kit is that system, released so nobody else has to learn these lessons
the expensive way. No technical background needed: you paste one prompt,
answer plain-English questions, and your AI agent sets everything up.

## Contents

- [The Problem](#the-problem)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [What You Get](#what-you-get)
- [Patterns Included](#patterns-included)
- [Who It's For](#who-its-for)
- [Honest Limitations](#honest-limitations)
- [FAQ](#faq)
- [Repository Layout](#repository-layout)
- [Contributing](#contributing)

---

## The Problem

AI coding agents are incredibly productive — and completely ungoverned.
Run two in parallel without a system and the failures are predictable:

| Failure | What it costs you |
|---|---|
| Two agents edit the same files | Lost work, broken builds |
| Agent invents APIs that don't exist | Confidently wrong implementations |
| Syntax errors ship untested | Dead pages in production |
| Context compaction mid-task | Re-researching the same problem twice |
| Cumulative data shown as daily | Users catch it before you do |
| Dead models eat your requests | Quotas burned on routing errors |
| Keys read into chat context | Secrets sent to external servers |

System Kit prevents each of these with a documented, checkable mechanism.

---

## How It Works

```
1. GET      download this repo (green "Code" button → Download ZIP)
2. PASTE    SETUP_PROMPT.md → your AI agent, in your project
3. ANSWER   plain-English questions about your project and its rules
4. LIVE     the agent builds everything: task board · thread registry ·
            build log · checkpoints · operating laws
```

Every future thread follows one loop:

```
read START_HERE → claim a task → work it → close out → deregister
```

Collisions are prevented by the **three-mutex model** — separate locks for
separate concerns:

| Mutex | Guards | Hold duration |
|---|---|---|
| `CODE` | Source files | Task-long |
| `LEDGER` | Shared tracking docs | Seconds per edit |
| `DB-CF` | Database / cloud infrastructure | Action-long |

A docs-only thread needs only `LEDGER`, so it never waits behind a code
thread — and two code threads can never touch the same file.

---

## Quick Start

**1. Get the kit** — on this repo's page, click the green **Code** button →
**Download ZIP**, then unzip it anywhere.

**2. Open your AI agent in your project** — opencode, Claude Code, Cursor,
or any agent that can read files and write to your project.

**3. Paste the setup prompt** — open `SETUP_PROMPT.md` from the unzipped kit,
copy its whole contents, and paste it as your first message. Tell the agent
where the unzipped kit folder is.

**4. Answer the questions** — the agent scans your project, asks about it in
plain English, then copies the kit's `docs/` folder into your project and
fills in every file for you.

**That's it.** You never edit template files by hand. From now on, every new
agent thread starts at `docs/START_HERE.md` in your project.

> See a [fully initialized START_HERE.md](examples/example-START_HERE.md) and a
> [live THREADS registry](examples/example-THREADS.md) to know what "done"
> looks like before you start.

**What each folder is for:**

| Folder | Role |
|---|---|
| [`docs/`](docs/) | **The only folder that goes into your project** — the agent copies and fills it |
| [`patterns/`](patterns/) | Read-only references explaining *why* each rule exists |
| [`examples/`](examples/) | A finished setup, so you can see the end result |
| [`integrations/`](integrations/) | Optional extras (e.g., a CI compliance check) |

---

## What You Get

| Capability | How |
|---|---|
| Multi-thread coordination | Three-mutex concurrency model with live thread registry |
| Task queue with claim/lock/release | Single entry point + priority queue + conflict detection |
| Verification gates | Local-first testing, five-step order, owner verifies last |
| Institutional memory | Append-only ledgers + checkpoint/resume system |
| Push discipline | Ledger currency required; owner-gated deployments |
| Key isolation | Credentials handled internally; never exposed to agents or logs |
| Plain-language owner gate | Decisions in simple English; owner interrupted only when needed |
| Optional model rotation | Live availability probing for rotating free-tier catalogs |

---

## Patterns Included

Each pattern documents the real failure class it prevents:

| Pattern | Prevents |
|---|---|
| [Concurrency Protocol](patterns/concurrency.md) | Parallel threads overwriting each other's work |
| [Verification Standard](patterns/verification.md) | Untested code reaching production |
| [Security Checklist](patterns/security-checklist.md) | Credential leaks, injection, unsafe defaults |
| [Failure Classes](patterns/failure-classes.md) | Twelve documented bug classes — with evidence |
| [Cost-Zero Operation](patterns/cost-zero-operation.md) | Quota burn and surprise cloud bills |
| [Model Rotation](patterns/model-rotation.md) | Dead/rotated free-tier models breaking sessions |
| [Prompt Injection Defense](patterns/prompt-injection-defense.md) | Malicious instructions hidden in project data |
| [Context Window Management](patterns/context-window-management.md) | Decisions lost to context compaction |
| [Worktree Parallel Coding](patterns/worktree-parallel.md) | Serialized code threads when true parallelism is needed |

---

## Who It's For

- **Non-technical founders** building with AI agents who can't afford silent failures
- **Solo developers** running several agent threads across projects
- **Small teams** whose agents keep overwriting each other
- **Anyone on free tiers** juggling rotating model catalogs

Works with any language, framework, host, AI provider, and any number of
concurrent threads. **Zero dependencies** — it's markdown methodology, not
software.

---

## Honest Limitations

> This kit relies on agents *following documented protocols*. There is no
> runtime enforcement, no telemetry, no magic. If an agent ignores
> `THREADS.md`, nothing physically stops it — the kit makes correct behavior
> **explicit, checkable, and recoverable**, not automatic.
>
> Also: the mutex model assumes one shared filesystem (see the
> [worktree pattern](patterns/worktree-parallel.md) for true parallel edits),
> and templates are English-only.

---

## FAQ

**Do I need to be technical to use this?**
No. The setup is one pasted prompt plus plain-English questions — your AI
agent does the file work. You only ever make decisions, never edit templates.

**How is this different from just having an AGENTS.md?**
An AGENTS.md states rules; System Kit adds the machinery that makes rules
operational — a live lock registry, append-only history, checkpoint format,
and an initialization prompt that adapts all of it to your project.

**Does it work with my agent/tool?**
Yes. It's plain markdown instructions — any LLM agent that can read and write
files can follow it (opencode, Claude Code, Cursor, Codex CLI, custom agents).

**Does it phone home or collect anything?**
No. Zero telemetry, zero network calls, zero data collection. Copy the files,
own them forever.

---

## Repository Layout

| Path | Purpose |
|---|---|
| [`SETUP_PROMPT.md`](SETUP_PROMPT.md) | Paste into a new thread → initializes governance (incl. troubleshooting appendix) |
| [`docs/`](docs/) | The governance files the agent copies into your project and fills in |
| [`patterns/`](patterns/) | Read-only references explaining why each rule exists |
| [`examples/`](examples/) | Worked examples: initialized START_HERE + live THREADS registry |
| [`integrations/`](integrations/) | Optional extras — e.g., GitHub Actions governance-compliance check |

---

## Contributing

Patterns backed by **real incidents** are the most valuable contributions —
see [CONTRIBUTING.md](CONTRIBUTING.md) for the evidence-required proposal
format. Bug fixes and clarity improvements always welcome.

---

<div align="center">

**MIT License** — use it anywhere, adapt it freely.

If System Kit saved your agents from each other, consider starring the repo —
it helps other teams find it.

</div>
