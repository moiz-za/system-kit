# Integrations — Optional, Tool-Specific Extras

> The core kit is deliberately methodology-only (see CONTRIBUTING.md).
> Everything in this folder is **optional** glue for specific tools.
> Nothing here is required to run System Kit.

## Contents

| File | What it does |
|---|---|
| [`governance-check.yml`](governance-check.yml) | GitHub Actions workflow that validates governance compliance on every PR |

## What the compliance check verifies

1. **Relative link integrity** — every relative markdown link in the repo resolves
2. **Placeholder leaks** — no `[PROJECT NAME]` / `[DOMAIN]` markers left in tracked files
3. **Version consistency** — README version badge matches the latest CHANGELOG entry
4. **Registry sanity** — THREADS.md exists and has its required section headers

Add more project-specific gates as steps — the pattern is: cheap structural
checks in CI, expensive semantic checks by the verifying thread locally.

## Install

Copy the file to `.github/workflows/governance-check.yml` in your repository.
It runs on pull requests targeting `main`.
