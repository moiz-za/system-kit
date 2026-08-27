# Context Window Management — Reference Pattern

> Agent context is ephemeral. Compaction summarizes it away at unpredictable
> boundaries, silently destroying decisions, gotchas, and architectural
> reasoning. This pattern makes files, not context, the memory.

**Prevents:** Failure Class 6 (history loss across context resets).

---

## The principle

Everything important lives in files *before* you need it. If a decision,
discovery, or constraint exists only in conversation context, treat it as
already lost. Summarization is never trusted as the record of anything that
matters.

## Checkpoint-before-compaction discipline

### Triggers — checkpoint immediately when ANY of these fire:

1. Context usage reaches ~70% (or the tool signals approaching compaction)
2. A significant decision was just made (architecture, tradeoff, rejection)
3. A non-obvious discovery just landed ("the API rejects bulk writes >100")
4. Before any mid-task model switch (see model-rotation pattern)
5. Before ending any session, even if the task looks "almost done"

### What goes into a checkpoint

Use `docs/CHECKPOINTS/_TEMPLATE.md`. Minimum viable content:

- **Last completed step** — specific enough to verify against files
- **Next step** — exactly what to do, so resume requires zero re-research
- **Key decisions + reasons** — especially rejected alternatives and why
- **Gotchas discovered** — things that seemed like they'd work but didn't
- **Verification state** — tests passing? lint clean? known breakage?

The test: could a stranger thread resume this task from the checkpoint alone,
without reading any conversation history? If not, it's incomplete.

## Re-entry protocol after reset

After compaction or a fresh session on an existing task:

1. Read START_HERE → claim check in THREADS.md
2. Read the checkpoint for your task
3. Re-read core docs (AGENTS.md laws — they bind regardless of your context loss)
4. Verify checkpoint claims against actual file state before continuing
   (checkpoints can be stale; trust files over notes when they conflict)
5. Only then continue work

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| "I'll checkpoint when I finish this step" | Compaction doesn't wait for step boundaries |
| Trusting post-compaction summary | Summaries drop constraints and keep narrative filler |
| Checkpointing only file changes, not reasoning | The diff is in git; the WHY is nowhere else |
| Skipping re-read of law files after reset | New context doesn't inherit the rules automatically |
| Assuming "almost done" tasks need no checkpoint | Almost-done tasks die hardest at context resets |

## Real-world evidence

Multiple sessions required full re-research of already-solved problems because
prior context was compacted away — re-discovering API quirks and re-making
decisions that had documented reasoning hours earlier. The checkpoint template
in this kit was built directly from those incidents.
