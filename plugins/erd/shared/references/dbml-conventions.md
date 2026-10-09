# DBML conventions

> Baseline: DBML syntax (@dbml/cli 10.3, including the module system `use`/`reuse`) — https://dbml.dbdiagram.io/docs/ , verified 2026-10.
> If the project already has its own conventions, those take precedence.

Full syntax: https://dbml.dbdiagram.io/docs/  (module system: https://dbml.dbdiagram.io/syntax/module-system)

## File layout

```
db/
├── schema.dbml            # entry point: Project block + list of use
└── modules/
    ├── user.dbml          # module = one business domain (users, orders, assets …)
    └── order.dbml
```

### Module split

- One module = one file = one `.tbls.yml` viewpoint (id same as the file name).
- Tables from other modules are imported with `use { table users } from './user'` and then referenced. `use` is not transitive.
- The entry point contains only `use * from './modules/<module>'`. Do not put table definitions in it.
- `TableGroup`, colors and sticky notes are only visualized in paid dbdiagram features, so modules are split by **file**.

## Referencing another ERD unit

In a monorepo, tables of a service with a different DB cannot be linked with `ref`. Mark them with a note instead (see `units.md`):

```dbml
user_id bigint [not null, note: 'User ID → api: users.id (other DB, no FK)']
```

## Naming

Identifiers are English snake_case regardless of `ERD_LANG`; notes/comments follow `ERD_LANG` (R8).

| Target | Rule | Example |
|---|---|---|
| Table | snake_case plural | `users`, `order_items` |
| Column | snake_case | `created_at` |
| PK | `id` | |
| FK | `<referenced table singular>_id` | `user_id` |
| Index | `idx_<table>_<column>` / unique `uq_<table>_<column>` | `idx_orders_user_id` |
| Boolean | `is_` / `has_` prefix | `is_active` |
| Date-time | `_at` suffix; date only: `_on` / `_date` | `paid_at` |

If the project already has different conventions (existing tables, ORM settings), **follow the existing conventions**. Do not impose new ones.

## Expensive to change (settle these first, at design time)

- Table and column names — once production data exists, a rename migration + code-wide changes are required
- Module id (= `db/modules/<id>.dbml` file name = `.tbls.yml` viewpoint id = doc file name `viewpoint-<id>.md`)
- PK strategy (bigint auto-increment / UUID) and whether there is a tenant key
- Meaning of status values (adding values is easy, but changing a meaning requires data migration)

## Scale signals

| Target | Typical | Signal to check |
|---|---|---|
| Tables per module | 3–15 | over 30 → consider splitting the module; 1–2 → consider merging with a neighboring module |
| Columns per table | 5–30 | over 50 → consider splitting off groups of columns with a different nature (can be enforced with lint `columnCount`) |
| Modules per unit (DB) | 3–12 | over 20 → review from an architecture standpoint whether to split the unit (service) |

Being outside these ranges is not wrong in itself. When a signal appears, confirm with the user once.

## Required (checked by tbls lint)

- A `Note` on every table and a `note` on every column (business meaning, written in the unit's `ERD_LANG` — R8).
- An index on FK columns (`indexes { user_id [name: 'idx_orders_user_id'] }`).
- Every table must belong to some module (viewpoint).
- For a table with no relationship to any other table, state in its note whether that is intentional.

## Recommended patterns

```dbml
Table orders {
  id bigint [pk, increment, note: 'PK']
  user_id bigint [not null, ref: > users.id, note: 'User who placed the order']
  status varchar(20) [not null, default: 'pending', note: 'pending | paid | canceled']
  total_amount numeric(12,2) [not null, default: 0, note: 'Order total (KRW)']
  created_at timestamptz [not null, default: `now()`, note: 'Created at']
  updated_at timestamptz [not null, default: `now()`, note: 'Updated at']
  deleted_at timestamptz [note: 'Soft-deleted at']

  indexes {
    user_id [name: 'idx_orders_user_id']
    (user_id, created_at) [name: 'idx_orders_user_id_created_at']
  }
  Note: 'Orders'
}
```

- For status values, default to `varchar + note` rather than `enum` (easier migrations). If the value set is fixed and DB-level validation is needed, use `enum` or `checks`.
- Money uses `numeric(p,s)`; floating point is prohibited.
- Time uses `timestamptz` on PostgreSQL.
- When common columns (`created_at`, etc.) repeat, `TablePartial` can be used:
  ```dbml
  TablePartial timestamps {
    created_at timestamptz [not null, default: `now()`, note: 'Created at']
    updated_at timestamptz [not null, default: `now()`, note: 'Updated at']
  }
  Table users { id bigint [pk]  ~timestamps  Note: 'Users' }
  ```

## Conversion commands (@dbml/cli)

| Command | Purpose |
|---|---|
| `dbml2sql db/schema.dbml --postgres -o db/schema.sql` | DBML → DDL (`--mysql`, `--mssql`, `--oracle`) |
| `sql2dbml dump.sql --postgres -o db/schema.dbml` | DDL → DBML |
| `db2dbml postgres '<conn>' -o db/schema.dbml` | Live DB → DBML (`mysql`, `mssql`, `snowflake`, `bigquery`, `oracle`) |

`dbml2sql` converts `Note` into `COMMENT ON ...`, so descriptions carry straight into the tbls docs.
On conversion failure a `dbml-error.log` is created; check its contents, then delete it.
