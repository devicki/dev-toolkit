# ERD units and monorepos

> Baseline: erd plugin 0.4.0 — 2026-10.

## Concept

**ERD unit = one DB (schema) = one folder containing `erd.env`.**

- Single repo, single DB: the repo root is the only unit.
- Monorepo: one unit per service folder that owns a DB. Apps without a DB (frontends, etc.) are not units but **related sources**.

Paths inside a unit folder (`db/`, `docs/schema/`, `.tbls.yml`, relative paths in `erd.env`) are all **relative to the unit folder**.
`scripts/erd-doc.sh` and `erd.mk` exist **only once, at the repo root**.

```
monorepo/
├── erd.mk  Makefile(include erd.mk)  scripts/erd-doc.sh  docs/ERD_GUIDE.md
├── apps/api/        ← unit: erd.env .tbls.yml db/ docs/schema/ CLAUDE.md
├── apps/billing/    ← unit: erd.env .tbls.yml docs/schema/ CLAUDE.md
└── apps/web/        ← not a unit (related source of api: ERD_RELATED_SOURCES)
```

## Resolving the target unit

Shared by all skills.

1. If the arguments contain `--project <folder>` (or `-p <folder>`), use that folder.
2. Otherwise, use "Target unit for current location" from `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/find-units.sh`:
   - The nearest `erd.env` walking up from the current location → that unit.
   - Only one unit in the repo → that unit.
   - Several units and the current location belongs to none → infer from the user's request (services, tables, files mentioned); if unclear, show the unit list and let the user choose.
   - `/erd:sync` and `/erd:review` can choose "all" (run per unit, one after another).
3. When starting work, state the target unit in one line: `Target: apps/api (PostgreSQL, ERD_SOURCE=dbml)`.
4. Run commands from the repo root with `make erd P=<unit>` or `scripts/erd-doc.sh <mode> <unit>`.

## Monorepo layout types

Used by init.

| Type | Detection hints | Unit placement |
|---|---|---|
| One shared DB + several apps | Migrations/ORM in only one place (e.g. `packages/db`, `apps/api`); other apps import that package | Only the folder holding the schema is a unit. The other apps go in `ERD_RELATED_SOURCES` |
| DB per service | Migrations/ORM per service, different DB connection settings (several DB services in docker-compose) | One unit per service |
| Mixed | Only some services own a DB | Only the DB-owning services are units |
| Undecidable | Not enough hints | Show the `find-units.sh` output and ask the user |

If two services share the same DB and migrations also live in both places (possibly an anti-pattern), do not decide arbitrarily; ask the user which side is the source of truth.

## Related sources (ERD_RELATED_SOURCES)

List the other folders that use this DB in the unit's `erd.env` (relative to the repo root, comma-separated).

```
ERD_RELATED_SOURCES='apps/web,apps/admin'
```

`/erd:import` (code), `/erd:review` and `/erd:design` read the unit folder together with the UI/API sources in these folders.

## Cross-unit references

Between units with different DBs.

- With different DBs, no FK is possible. Do not use DBML `ref`; mark it with a note instead:
  `user_id bigint [not null, note: 'User ID → api: users.id (other DB, no FK)']`
- `/erd:review` cross-checks such columns for type/meaning consistency using both units' docs (`<unit>/docs/schema/schema.json`).
- For a different schema in the same DB (PostgreSQL schema), an FK is possible within one unit using `schema.table`.

## Agent instruction placement

- Each unit folder gets a `CLAUDE.md` (or `AGENTS.md`) with a DB schema section dedicated to that unit. Claude Code also reads CLAUDE.md in the subfolder being worked on.
- The repo-root `CLAUDE.md` holds only a short unit list and `make erd [P=<unit>]` usage.
- These CLAUDE.md/AGENTS.md blocks are written in the unit's `ERD_LANG` (R8).

## CI

From the root, `make erd-check` checks every unit and fails if any one differs.
In PRs, `make erd-check-changed BASE=origin/<default branch>` checks **only the units whose schema changed** (`scripts/erd-changed.sh` groups commits, uncommitted changes and new files relative to the remote base branch by unit).
