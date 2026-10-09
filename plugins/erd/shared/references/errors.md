# Error handling table

> Baseline: `scripts/erd-doc.sh` (erd plugin 0.4.0), tbls 1.96, @dbml/cli 10.3 — 2026-10
> On failure the last line of output is `ERD_EXIT=<code> <kind>`. Pick the cause by code and follow the action below.
> The human-readable messages from `erd-doc.sh` are bilingual (Korean or English, per `ERD_LANG`); identify errors by the `ERD_EXIT` code/kind, not by message text.
> **Do not move on by guessing**: if you could not fix the cause, report the failure, its `ERD_EXIT` line and the output as-is.

## erd-doc.sh exit codes

| Code | Kind | Common causes | Action |
|---|---|---|---|
| 0 | success | | Summarize the result |
| 1 | diff / lint | In `check`, docs differ from the current schema; `docs/schema` missing; lint warnings with `ERD_CHECK_LINT=strict` | Tell the user to regenerate with `make erd P=<unit>` and commit the result together. If it is a CI failure, name the unit |
| 2 | usage / config | Multiple units but none specified, unit folder missing, invalid mode, bad `erd.env` value (DIALECT/SOURCE), DBML entry file missing, `.tbls.yml` missing, `migrations` with empty `ERD_MIGRATE_CMD` | Fix the arguments / `erd.env` as the message says. If config files are missing, `/erd:init` |
| 3 | missing-tool | tbls, dbml2sql, psql, docker or mysql not found | Check and install via `/erd:doctor`. Do not improvise install commands |
| 4 | dbml | DBML syntax error (`file(line,col): message`) | Fix that location. **dbml2sql exits 0 even on errors**, so the script judges by the log — do not run dbml2sql directly and mistake it for success |
| 5 | tempdb | Docker daemon unreachable, container not ready within 90 s, PG/MySQL connection failure, no CREATE DATABASE privilege | Advise on Docker permissions (add to group, log in again) or using an existing server via `PG=postgres://...`. Get connection details from the user |
| 6 | apply | SQL error while applying `db/schema.sql` (unknown type, invalid default expression, reserved-word column name, dialect mismatch) | Read the reported SQL error line and fix the DBML. Do not edit `db/schema.sql` directly |
| 7 | migrate | `ERD_MIGRATE_CMD` failed (dependencies not installed, `DATABASE_URL` not used, error in the migration itself) | Reproduce by running the command directly in the unit folder and report the cause. Change project settings only after the user confirms |
| 8 | tbls | tbls run failed: `.tbls.yml` syntax, table name not present in a viewpoint, **permission problem on the shared `/tmp/go-graphviz`** | If the output contains `go-graphviz ... permission denied` (the shared /tmp permission case), see `tbls-guide.md` "Shared /tmp problem". Otherwise fix `.tbls.yml` |

## Common situations outside the script

| Situation | Action |
|---|---|
| `make: scripts/erd-doc.sh: Permission denied` | `chmod +x scripts/erd-doc.sh` |
| `make erd` run outside the repo root | Move to the repo root and run it there (`erd.mk` is root-relative) |
| `syntax error` because an `erd.env` value contains spaces | Wrap the value in single quotes (`ERD_MIGRATE_CMD='alembic upgrade head'`) |
| Only lint warnings, success (0) | Summarize the warning list in the report. For auto-fixable ones (missing notes, etc.), ask whether to fix them |
| A production DB address is about to go into `PG=` / `ERD_MIGRATE_CMD` | **Stop**. Only temporary/development DBs are allowed (`rules.md`) |
