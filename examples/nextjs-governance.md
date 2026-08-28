# Next.js + System Kit

> How to adapt the governance system to a Next.js project (React frontend).
> Core patterns remain identical; only verification and file paths change.

## Where governance files go

- Keep `docs/` at the project root (same as standard setup)
- Do NOT mix governance files with `app/`, `components/`, or `public/`

## Verification commands (SETUP_PROMPT Step 3 answer)

```bash
# Static
npm run lint          # next lint (ESLint)
npm run typecheck     # tsc --noEmit

# Unit + integration tests
npm test              # jest, vitest, playwright

# Build
npm run build         # next build (must compile clean)

# Deploy
vercel deploy         # or netlify, or custom
```

## Files that commonly need declaring in THREADS.md

| Mutex | Typical files |
|---|---|
| CODE | `app/*`, `components/*`, `lib/*`, `hooks/*` |
| LEDGER | `docs/START_HERE.md`, `docs/TASKS.md`, `docs/workflow/BUILDLOG.md` |
| DB-CF | `prisma/migrations/*`, `drizzle/*`, `supabase/migrations/*`, `.env.local` |

## Special Next.js considerations

- **App Router / Pages Router** files are CODE — editing them triggers rebuild
- **Server Components** run on server; editing them is CODE
- **Middleware** (`middleware.ts`) is CODE — affects routing
- **Prisma/Drizzle migrations** are DB-CF
- **Environment files** (`.env.local`, `.env.production`) are DB-CF / LEDGER
- **`next.config.js`** is CODE — changes affect build behavior

## Preventing common Next.js pitfalls

- **TypeScript errors** — `npm run typecheck` catches them before commit
- **Client/Server component confusion** — declare which files are Server Components in scope
- **Static generation failures** — `npm run build` catches them locally first
- **API route changes** — `app/api/*/route.ts` are CODE (server code)
- **Tailwind/PostCSS config** — `tailwind.config.ts`, `postcss.config.mjs` are CODE