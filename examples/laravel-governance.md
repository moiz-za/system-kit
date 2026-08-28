# Laravel + System Kit

> How to adapt the governance system to a Laravel project (PHP backend).
> Core patterns remain identical; only verification and file paths change.

## Where governance files go

- Keep `docs/` at the project root (same as standard setup)
- Do NOT mix governance files with `app/`, `resources/`, or `database/`

## Verification commands (SETUP_PROMPT Step 3 answer)

```bash
# Static
php artisan lint          # php-cs-fixer
phpstan analyse           # type safety (if used)

# Unit + feature tests
php artisan test

# Build (if using asset compilation)
npm run prod              # or vite build

# Deploy
php artisan migrate --force
```

## Files that commonly need declaring in THREADS.md

| Mutex | Typical files |
|---|---|
| CODE | `app/Http/Controllers/*`, `routes/web.php`, `resources/views/*` |
| LEDGER | `docs/START_HERE.md`, `docs/TASKS.md`, `docs/workflow/BUILDLOG.md` |
| DB-CF | `database/migrations/*`, `database/seeders/*`, `.env` |

## Special Laravel considerations

- **Migrations are DB-CF** — treat them as infrastructure changes
- **Views and Blade files** are CODE (they're part of the working tree)
- **Artisan commands** that touch the filesystem are CODE
- **Composer update** — treat as LEDGER (updates composer.lock only)
- **Queue workers** — if they process file uploads, treat as CODE for those paths

## Preventing common Laravel pitfalls

- **Blade syntax errors** — caught by local test suite + `php artisan view:clear`
- **Migration drift** — always run `php artisan migrate:status` before claiming DB-CF
- **Cache collisions** — treat `storage/framework/cache/*` as CODE if written to
- **Session file conflicts** — use redis/database sessions, not file sessions