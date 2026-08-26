# Integrations — Optional, Tool-Specific Extras

> The core kit (`templates/`, `patterns/`, `SETUP_PROMPT.md`) is deliberately
> methodology-only per CONTRIBUTING.md. Everything in this folder is **optional**
> glue for specific tools. Nothing here is required to run System Kit, and new
> integrations live only here — not in the core templates.

## Contents

| File | What it does |
|---|---|
| [`governance-check.yml`](governance-check.yml) | GitHub Actions workflow that validates governance compliance on every PR |

## What the compliance check verifies

1. **Relative link integrity** — every relative markdown link in the repo resolves
2. **Placeholder leaks** — no unfilled `[PROJECT NAME]` / `[DOMAIN LAWS ...]` markers
   outside the kit's own source files (`templates/`, `SETUP_PROMPT.md`, `integrations/`,
   `CHANGELOG.md`)
3. **Version consistency** — README version badge matches the latest CHANGELOG entry
4. **Registry present** — THREADS.md exists (repo root or `docs/`)

Add more project-specific gates as steps — the pattern is: cheap structural
checks in CI, expensive semantic checks by the verifying thread locally.

## Install

Copy the file to `.github/workflows/governance-check.yml` in your repository.
It runs on pull requests targeting `main`.
