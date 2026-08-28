# FastAPI + System Kit

> How to adapt the governance system to a FastAPI project (Python backend).
> Core patterns remain identical; only verification and file paths change.

## Where governance files go

- Keep `docs/` at the project root (same as standard setup)
- Do NOT mix governance files with `app/`, `tests/`, or `alembic/`

## Verification commands (SETUP_PROMPT Step 3 answer)

```bash
# Static
ruff check .                 # linter
mypy app/                   # type checker

# Tests
pytest                      # unit + integration suite

# Build (if applicable)
pip install -e .            # editable install

# Deploy
uvicorn app.main:app --reload
```

## Files that commonly need declaring in THREADS.md

| Mutex | Typical files |
|---|---|
| CODE | `app/`, `tests/`, `alembic/` |
| LEDGER | `docs/START_HERE.md`, `docs/TASKS.md`, `docs/workflow/BUILDLOG.md` |
| DB-CF | `alembic/versions/*`, `migrations/`, `.env` |

## Special FastAPI considerations

- **Alembic migrations** are DB-CF — never edit a migration already applied to staging/prod
- **Route files** (`app/api/`) are CODE — changing them affects live behavior
- **Pydantic models** in `app/schemas/` are CODE (part of the API contract)
- **Environment files** (`.env`) are DB-CF
- **Dependencies** (`requirements.txt`, `pyproject.toml`) — treat as LEDGER for pinning, CODE for adding new deps

## Preventing common FastAPI pitfalls

- **Migration conflicts** — declare `alembic/versions/` in THREADS.md; run `alembic history` before claiming DB-CF
- **Circular imports** — caught by `ruff check`; declare `app/` as CODE
- **Type errors in routes** — caught by `mypy app/` before commit
- **Untested endpoints** — `pytest` must pass for every route change
- **Database session leaks** — declare `app/database.py` / session management in DB-CF scope