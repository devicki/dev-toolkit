---
name: sync
description: >
  Keep the ERD current: regenerate docs, drift check, DBML→migrations, CI. Output: docs/schema, drift report, migrations.
  Triggers: "ERD 최신화", "마이그레이션 만들어줘" / "schema drift", "make erd failed".
  Not for: design (→ /erd:design), review (→ /erd:review), setup (→ /erd:init).
argument-hint: "[doc|drift|migrate|ci] [--project <unit>|--all-units]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
  - "Bash(scripts/erd-changed.sh *)"
  - "Bash(git status *)"
  - "Bash(git diff *)"
  - "Bash(git rev-parse *)"
---

# /erd:sync — synchronization and maintenance

> **One-line definition**: keep generated files, the source of truth and the real DB aligned. The user decides what to change.
> **Key outputs**: `<unit>/docs/schema/`, Drift report (`report-templates.md` §2), migration drafts, CI config

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — Hard rules, Prohibited (required)
- `references/errors.md` — responses per `ERD_EXIT` code (required on failure)
- `references/source-of-truth.md`, `references/migration-tools.md` — comparison and migrations per source of truth
- `references/tbls-guide.md` — tbls options, "Shared /tmp problem"
- `references/report-templates.md` — Drift report (§2), Completion report (§3)
- the project's `make erd`, `make erd-check`, `make erd-check-changed`, `scripts/erd-changed.sh`

## Hard rules (top priority) — full list in `rules.md`
1. Generate and check docs only with `make erd*` (R1). On failure, report the `ERD_EXIT` code verbatim and respond per `errors.md` (R5).
2. Differences are **proposals only**. The user decides which side to align — it may be a hotfix that exists only in the production DB.
3. Migrations are generated, nothing more. **Applying them to the target DB is done by the user**, or only on explicit request (R6).
4. Language (R8): reply in the user's language; text written into the project follows the unit's `ERD_LANG`.

## Step 0: target
- `units.md` "Resolving the target unit". At the repo root with no unit given, `doc`/`drift` cover all units (`make erd`).
- If there is no `erd.env`, `/erd:init`.

## Step 1: mode
Without arguments, `doc` → `drift` in order. Propose `migrate`/`ci` when needed.

| Mode | Situation | Approach |
|---|---|---|
| **doc** | Refresh docs | `make erd [P=<unit>]` → summarize changed docs (`git status <unit>/docs/schema`) and lint → for new tables without a viewpoint, propose a module and add it to `.tbls.yml` → re-run |
| **drift** | Drift check | Comparison table below → §2 report |
| **migrate** | Apply to DB (dbml source of truth) | Procedure below |
| **ci** | Automated checks | Procedure below |

### drift comparison table
| Comparison | Method |
|---|---|
| Docs ↔ source of truth | `make erd-check [P=<unit>]` (for a PR, `make erd-check-changed BASE=<ref>`) |
| ORM models ↔ migrations (migrations) | Tool check commands: `alembic check`, `python manage.py makemigrations --check --dry-run`, `npx prisma migrate diff …` (check `--help` for the installed version). If none, compare model code ↔ `docs/schema` directly |
| DBML ↔ backend entities (dbml) | Read entity/model code and compare tables, columns, types, nullability, relations |
| Source of truth ↔ real development/production DB | Only when the user provides connection info; read-only account recommended: `tbls diff '<DSN>' <unit>/docs/schema` (read-only, so an R1 exception) |

### migrate (ERD_SOURCE=dbml)
1. Check whether a migration tool / directory exists. If not, options: (a) early development → regenerating `db/schema.sql` is enough (b) adopt Atlas (c) written by hand. **The user decides on adoption.**
2. Atlas (in the unit folder; optional tool — if missing, only give install guidance):
   `atlas migrate diff <name> --dir file://db/migrations --to file://db/schema.sql --dev-url docker://postgres/16/dev` (MySQL: `docker://mysql/8/dev`)
3. Report risks in the generated SQL: DROP, a rename that came out as drop+add, NOT NULL added where data already exists.
- If `ERD_SOURCE=migrations`, instead of this procedure, guide/run the project tool's generate command (after user confirmation).

### ci
Add checks to CI (after user confirmation). Recommended: only changed units on PRs, everything on main.
```yaml
name: erd
on: [pull_request]
jobs:
  erd-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }          # needed to compare against the base branch
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm install -g @dbml/cli
      - run: |
          V=1.96.1
          curl -sSL https://github.com/k1LoW/tbls/releases/download/v$V/tbls_v${V}_linux_amd64.tar.gz | sudo tar xz -C /usr/local/bin tbls
      - run: make erd-check-changed BASE=origin/${{ github.base_ref }}
```
- With a migrations source of truth, add steps to install the language runtime and dependencies. For GitLab etc., express the same steps in that format.
- To make lint warnings fail too, set `ERD_CHECK_LINT=strict` in the unit's `erd.env`.

## Error handling
`references/errors.md` is authoritative. Common ones:
| ERD_EXIT | Action |
|---|---|
| 1 | Docs are stale → `make erd P=<unit>`, then advise committing them together |
| 3 | `/erd:doctor` |
| 5 | Docker permissions, or advise using a development server via `PG=` |
| 7 | Run `ERD_MIGRATE_CMD` directly in the unit folder to reproduce and report |
| 8 | If the message mentions /tmp permissions, `tbls-guide.md` "Shared /tmp problem" procedure |

## Checklist (before reporting)
- [ ] Commands run and their results (✔ or `ERD_EXIT`) reported verbatim
- [ ] drift uses the §2 report template; decisions are left to the user
- [ ] List of files to commit given (`<unit>/docs/schema/`, source-of-truth changes)

## Related skills
- `/erd:design` — when drift results require fixing the source of truth
- `/erd:review` — quality review of changes (`--changed`)
- `/erd:doctor` — tool problems
