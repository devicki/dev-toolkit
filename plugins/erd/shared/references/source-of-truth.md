# Choosing the schema source of truth

> Baseline: erd plugin 0.4.0 — 2026-10.

Before starting any ERD work, first decide **what the schema's source of truth is**. With two sources of truth, they overwrite each other and drift apart.
Record the decision in `ERD_SOURCE` in the ERD unit folder's `erd.env` (it can differ per unit, `units.md`).

## Decision table

| Project state | ERD_SOURCE | Source of truth | Role of DBML | Schema change flow |
|---|---|---|---|---|
| New, no migration tool | `dbml` | `db/modules/*.dbml` | Design source of truth | Edit DBML → `make erd` → (when applying to a DB) generate migration SQL |
| Has ORM/migration tool | `migrations` | ORM models + migrations | Derived document (`db/schema.generated.dbml`) | Edit models → generate migration (existing tool) → `make erd` |
| Only UI/API sources (DB not implemented) | `dbml` | Extracted draft DBML → source of truth once the user confirms | Design source of truth | Same as new |
| Only ERD/ADR documents | `dbml` | Documents → migrated to DBML, then DBML is the source of truth | Design source of truth | Same as new. Recommended: mark the original documents "migrated to DBML" |
| Only a production DB (no schema in code) | `dbml` | DBML extracted with `db2dbml` | Design source of truth | Subsequent changes: DBML → migration |

## Decision rules

1. If the `detect-project.sh <unit folder>` output shows a migration tool, **the default is `migrations`**.
   - However, if the migrations are effectively abandoned (no recent commits, far from the actual DB), confirm with the user.
2. No migration tool and no DBML → `dbml`.
3. If it is `migrations` and the user says "I want to design in DBML first":
   - Use DBML as a **design proposal** (`db/proposals/<name>.dbml`).
   - Once confirmed, apply it to the ORM models/migrations and regenerate the docs with `make erd`.
   - Switching the source of truth to DBML is a decision that needs team agreement; do not do it without the user's confirmation.
4. If the decision is unclear, show the Decision table and let the user choose.

## Prohibited per source of truth

- `dbml`: do not edit `docs/schema/` or `db/schema.sql` directly.
- `migrations`: do not hand-edit `db/schema.generated.dbml` (overwritten by the next `make erd`). Do not edit migration files that have already been applied.
- `migrations` + ADR documents: the source of truth stays the ORM. Link ADR decisions/explanations via `.tbls.yml` `comments:` (doc-only comments and labels). If they should also live as DB comments, propose ORM `comment=` + a new migration separately.
