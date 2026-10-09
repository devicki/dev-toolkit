---
name: init
description: >
  Set up ERD management (single/monorepo): decide units, source of truth, language; install templates. Output: erd.env, .tbls.yml, erd.mk, scripts.
  Triggers: "ERD 세팅", "ERD 관리 도입" / "set up erd", "init erd".
  Not for: units with erd.env (→ /erd:design, /erd:sync).
argument-hint: "[--project <unit folder>] [--lang <ko|en>]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
---

# /erd:init — set up ERD management

> **One-line definition**: decide which folders are ERD units and what their source of truth is, then install the files with the script. No table design here (→ design/import).
> **Key outputs**: per unit `erd.env`·`.tbls.yml`(·`db/`); at the repo root `erd.mk`·`scripts/erd-doc.sh`·`scripts/erd-changed.sh`

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `scripts/find-units.sh [--json]` — repo layout, existing units, candidates (automatic run result below)
- `scripts/detect-project.sh <unit>` — per-unit DB type, ORM, reference assets
- `scripts/install-templates.sh` — **mandatory install helper** (idempotent, never overwrites, CLAUDE.md marker block)
- `scripts/check-tools.sh` — tool check
- `references/units.md` — unit concept, monorepo layout types
- `references/source-of-truth.md` — source-of-truth Decision table
- `references/migration-tools.md` — `ERD_MIGRATE_CMD` per tool
- `references/rules.md` — Hard rules, Prohibited

## Current repo (automatic scan result)

!`bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/find-units.sh || true`

## Hard rules (top priority) — full list in `rules.md`
1. Install files **only** via `install-templates.sh`. Never handle templates by hand with `cp`/`sed` (R2).
2. Unit layout, `ERD_SOURCE` and `ERD_LANG` are settled **by proposal, then user confirmation** (R4).
3. If project settings need changes (alembic env.py, prisma datasource, etc.), only propose them and edit after approval.
4. Language (R8): reply in the user's language; text written into the project follows the unit's `ERD_LANG`.

## Step 0: prerequisites
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh` — if dbml2sql/tbls are missing, ask whether to run `/erd:doctor` first (setup works without the tools).
- If the scan above shows existing units, do not set them up again. Summarize them and ask whether to add only the missing units.
- If an existing unit's `erd.env` has no `ERD_LANG`, propose adding it: decide the language as in step 2, then re-run `install-templates.sh` for that unit with its current arguments plus `--lang` (idempotent — existing files are kept and `ERD_LANG` is added).

## Step 1: decide the unit layout
Propose using `units.md` "Monorepo layout types". With `--project <folder>`, only that one folder.

| Situation | Unit |
|---|---|
| Single repo | Repo root (`.`) |
| Shared DB + several apps | The one folder that owns the schema. Other apps go in `--related` |
| DB per service | Each service folder that has a DB |
| Cannot tell | Show the scan result and ask |

Example proposal (get confirmation — unit layout, dialect, source and language in this one question batch):
```
Proposed ERD units
- apps/api   PostgreSQL · Alembic → migrations (alembic upgrade head)
- apps/pay   MySQL · none         → dbml
Related sources: apps/web → apps/api
Language (ERD_LANG): en — language of your request; README/CLAUDE.md are English too
```

## Step 2: decide the source of truth and language per unit
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect-project.sh <unit>` → DB type, ORM/migrations, reference assets.
- Propose `dbml` / `migrations` with the `source-of-truth.md` Decision table. If there is no hint of the DB type, ask.
- For `migrations`, pick `ERD_MIGRATE_CMD` from `migration-tools.md` (runs in the unit folder; the temporary DB is passed via `DATABASE_URL`).
- Decide `ERD_LANG` (`ko`|`en`) — the language of everything written into the project (R8). Default: the language of the user's request. If the existing README/CLAUDE.md/AGENTS.md are predominantly in the other language, propose that instead. `--lang` given → use it. Confirm it in the same question batch as dialect/source (step 1 example); never add an extra round just for the language.

## Step 3: install — run the helper
For each unit (from the repo root):
```bash
bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-templates.sh \
  --unit <unit> --name <English name> --dialect <postgres|mysql> --source <dbml|migrations> \
  --lang <ko|en> [--migrate-cmd '<command>'] [--related '<folder,folder>']
```
- Summarize the output's `+` (created) `=` (kept) `~` (updated) `!` (needs confirmation) markers in the report. If the last line is not `INSTALL_RESULT=ok`, explain the `!` items.
- `!` scripts differ from the plugin version: check for local edits with `git diff`, and after user confirmation re-run with `--update-scripts`.
- You may first show a `--dry-run` and get confirmation (recommended for monorepos with many files).
- The CLAUDE.md (or AGENTS.md) block is inserted by the script. Do not edit it by hand.

## Step 4: first docs or next step (per unit)
| Source of truth | Next |
|---|---|
| `migrations` | `make erd P=<unit>` → summarize the result → propose a module (viewpoints) layout and add it to `.tbls.yml` → `make erd P=<unit>` again |
| `dbml` + reference assets | `/erd:import --project <unit>` |
| `dbml` + no assets | `/erd:design --project <unit>` (interactive initial design). Delete `_example.dbml` after the first module |

## Error handling
`references/errors.md` + below.
| Situation | Action |
|---|---|
| install-templates.sh exit 2 | Fix as the argument error message says and re-run (name: letters, digits, `_`, `-`) |
| `make erd` fails | Respond per `errors.md` using the `ERD_EXIT` code |

## Checklist (before reporting)
- [ ] The user confirmed the unit layout, source of truth and `ERD_LANG`
- [ ] `INSTALL_RESULT=ok` for every unit (or the `!` items are explained)
- [ ] For migrations units, `make erd P=<unit>` was run once and the result checked
- [ ] The report follows `report-templates.md` §3 (unit list, installed files, next steps)

## Related skills
- `/erd:doctor` — when tools are missing
- `/erd:import` — build DBML from existing code, docs or a DB
- `/erd:design` — interactive initial design
