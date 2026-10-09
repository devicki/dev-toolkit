# ERD guide

This project's ERD is managed with the Claude Code `erd` plugin (devicki/dev-toolkit).

## ERD units
- **ERD unit = one DB = a folder containing `erd.env`.** In a single repo it is the root; in a monorepo, each service folder that owns a DB.
- List units: `make erd-list`. Paths below (`db/`, `docs/schema/`) are relative to each unit folder.

## Principles
- `ERD_SOURCE` in `erd.env` decides the source of truth.
  - `dbml`: `db/modules/*.dbml` is the source. Change tables only there.
  - `migrations`: the ORM/migrations are the source. The DBML (`db/schema.generated.dbml`) and docs are derived.
- `db/schema.sql` and `docs/schema/` are generated — never edit them by hand.
- When the schema changes, run `make erd P=<unit>` and commit the docs in the same commit.

## Commands
| Command | Description |
|---|---|
| `make erd` | Generate docs + lint for every unit (Docker, or an existing server via `PG=`/`MY=`) |
| `make erd P=apps/api` | One unit only |
| `make erd-check [P=..]` | Check the docs are up to date (CI) |
| `make erd-sql [P=..]` | DBML → `db/schema.sql` |
| `make erd-list` | List ERD units |
| `make erd-view [P=..]` | View the docs in the terminal (glow) |

## Claude Code commands
| Command | Purpose |
|---|---|
| `/erd:doctor` | Check and install tools |
| `/erd:design` | Interactive design and changes |
| `/erd:review` | Review against the source code |
| `/erd:sync` | Refresh docs, check drift against code/DB, migration integration |

## Where to read the docs
- Everything: `docs/schema/README.md`
- Per module: `docs/schema/viewpoint-<module>.md`
- Per table: `docs/schema/<schema>.<table>.md`
