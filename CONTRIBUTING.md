# Contributing to System Kit

Thank you for considering a contribution. This kit exists because real failures proved
the need for every pattern in it. Your hard-won lessons are welcome here.

## What we accept

- **New patterns** that prevent a documented, reproducible failure class
- **Improvements** to existing templates or protocols
- **Translations** of the core documentation
- **Bug fixes** in the docs templates (typos, unclear instructions, broken examples)

## What we don't accept

- Domain-specific rules (this is a universal kit — adapt per project after deployment)
- Tool-specific integrations in core docs/patterns (keep them methodology,
  not implementation — optional tool glue lives separately in `integrations/`)
- Changes that weaken security isolation or verification standards

## How to contribute

1. Fork the repository
2. Create a branch: `git checkout -b your-feature-name`
3. Make your changes
4. Ensure all markdown files are valid and render correctly
5. Submit a pull request with a clear description of:
   - The problem you're solving
   - The failure class it prevents (if applicable)
   - Evidence from real usage if available

## Pattern proposal template

When proposing a new pattern, include:

```
## Failure class
What goes wrong without this pattern?

## Real incident
Has this actually happened? Describe it.

## Prevention mechanism
How does the pattern stop it?

## Evidence
Where has this been observed?
```

## Code of conduct

Be direct. Be useful. Share failures as generously as successes — the community
learns more from what broke than from what worked.
