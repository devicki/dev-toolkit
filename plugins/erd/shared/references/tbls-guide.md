# tbls usage guide

> Baseline: tbls 1.96.1 (https://github.com/k1LoW/tbls) — verified 2026-10. On a different version, check options with `tbls <command> --help`.

Official: https://github.com/k1LoW/tbls

## Role in this plugin

tbls reads a **live DB** (the temporary DB) and produces the following. Do not run it directly; use `make erd [P=<unit>]` / `scripts/erd-doc.sh <mode> <unit>` from the repo root. Paths below are relative to the ERD unit folder.

- `docs/schema/README.md` : list of all tables + full ERD (Mermaid)
- `docs/schema/viewpoint-<id>.md` : tables per module + module ERD
- `docs/schema/<schema>.<table>.md` : per-table columns, constraints, indexes, relations
- `docs/schema/schema.json` : machine-readable full schema (AI can use it to understand the structure)

## Main commands (erd-doc.sh builds the DSN)

| Command | Purpose |
|---|---|
| `tbls doc --dsn <DSN> --rm-dist` | Regenerate docs |
| `tbls diff <DSN> docs/schema` | Differences between docs and DB (prints them if any) |
| `tbls lint --dsn <DSN>` | Check the lint rules in `.tbls.yml` |
| `tbls out --dsn <DSN> -t mermaid --viewpoint <id>` | Output only a module ERD |

DSN formats: `postgres://user:pass@host:5432/db?sslmode=disable`, `mysql://user:pass@host:3306/db`, `sqlite:///path/to.db`

## .tbls.yml essentials

```yaml
name: my_project
docPath: docs/schema
er:
  format: mermaid
viewpoints:
  - id: order            # same name as db/modules/order.dbml
    name: Order module
    desc: Orders and order items (including the referenced users)
    tables: [orders, order_items, users]
lint:
  requireTableComment: { enabled: true }
  requireColumnComment: { enabled: true }
  requireForeignKeyIndex: { enabled: true }
  unrelatedTable: { enabled: true }
  requireViewpoints: { enabled: true }
```

- In a viewpoint's `tables`, list the module's own tables + **the key tables of other modules it references**, so relationships are visible.
- For DBs where table names carry a schema prefix (PostgreSQL schemas other than `public.`), write them as `schema.table`.
- Available lint rules: requireTableComment, requireColumnComment(exclude, excludeTables), requireIndexComment, requireConstraintComment, requireTriggerComment, requireTableLabels, unrelatedTable, columnCount(max), requireColumns(columns), duplicateRelations, requireForeignKeyIndex, labelStyleBigQuery, requireViewpoints.
- Exclude ORM bookkeeping tables (`alembic_version`, `_prisma_migrations`, `django_migrations`, `flyway_schema_history`, `schema_migrations`, etc.) from the docs:
  ```yaml
  exclude:
    - alembic_version
  ```

## comments — add descriptions and ADR links to the docs without touching code or DB

Where `ERD_SOURCE=migrations` units record ADR references or descriptions. On `make erd`, tbls layers these onto the DB structure when building the docs.

```yaml
comments:
  - table: users                     # prefix can be omitted for the public schema
    tableComment: "Users. ADR-003: soft delete"
    columnComments:
      deleted_at: "Deletion time, NULL = active (ADR-003)"
    labels: [ADR-003]                # shown in the Labels column of the README table list → find tables affected by each ADR
```

Behavior verified on 1.96.1:
- **`tableComment`/`columnComments` in the config replace the DB comment** (they are not merged). If the DB has a comment, put the existing wording from `docs/schema/<table>.md` first and append the ADR. Columns not specified keep their DB comment.
- `tbls lint` `requireTableComment`/`requireColumnComment` also accept config comments.
- If you change only the config and do not run `make erd`, `make erd-check` catches it as a difference (commit it together with the docs).
- For ADRs, write only the decision number + a one-line summary. Keep the body in the ADR document; do not copy it.

## Shared /tmp problem (multiple accounts using tbls on the same server)

Symptom: `panic: open /tmp/go-graphviz/...: permission denied` (`erd-doc.sh` prints `ERD_EXIT=8 tbls` with guidance)
Cause: a library inside tbls creates a cache in the shared `/tmp/go-graphviz`, and only the account that ran first can access it.

Fixes (in order of preference):
1. Server admin: `sudo apt install libpam-tmpdir` → each account gets `TMPDIR=/tmp/user/<UID>` automatically on next login.
   - If it still fails after logging in again, long-running processes (IDE server, herdr, tmux, etc.) are the reason. Run `sudo loginctl terminate-user <account>` and reconnect.
2. Per account: set `TMPDIR` to a personal folder and run (`scripts/erd-doc.sh` automatically uses `~/.cache/erd-tmp` when TMPDIR is empty).
3. Don't: `chmod 777` on `/tmp/go-graphviz` (it caches executable code, so it is a security risk).
