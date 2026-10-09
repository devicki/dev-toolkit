---
name: import
description: >
  Build or extend DBML from existing code, ORM/migrations, docs/ADRs or a DB. Output: db/modules/*.dbml + inferred-item list.
  Triggers: "소스코드에서 ERD 뽑아줘", "이 화면 보고 ERD 보강" / "reverse engineer ERD", "DBML from models".
  Not for: new design (→ /erd:design), review (→ /erd:review).
argument-hint: "[code|orm|docs|db|augment] [path...] [--project <unit folder>]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
---

# /erd:import — build or extend DBML from existing assets

> **One-line definition**: extract the schema from what already exists (code, docs, DB) and move it into DBML. Designing for new requirements belongs to design.
> **Key outputs**: `<unit>/db/modules/<module>.dbml`, `<unit>/docs/schema/`, list of `[inferred]` (`[추정]` in ko) items

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `scripts/find-units.sh`, `scripts/detect-project.sh <unit>` — find the target unit and source candidates
- `references/rules.md` — Hard rules, Prohibited (required)
- `references/dbml-conventions.md` — DBML writing rules, module split, scale signals
- `references/migration-tools.md` — ORM/migrations → DBML paths, `sql2dbml`/`db2dbml`
- `references/units.md` — resolving the unit, notation for references to another DB
- `references/report-templates.md` — Completion report template (§3)
- `references/errors.md` — `ERD_EXIT` responses

## Hard rules (top priority) — full list in `rules.md`
1. Write as definite values **only what you verified** in code or docs. Inferred types, lengths, nullability and relation directions get `[inferred]` in the note (R7).
2. Generate docs only with `make erd P=<unit>` (R1). Do not run `dbml2sql` directly to check syntax — it exits 0 even on errors.
3. If sources disagree, do not pick one arbitrarily; show the list of differences and get a decision.
4. Language (R8): reply in the user's language; text written into the project follows the unit's `ERD_LANG`.

## Step 0: target unit and prerequisites
- `units.md` "Resolving the target unit" (`--project` → nearest erd.env → the only unit if there is one → ask). State `Target: <unit> (<DB>, ERD_SOURCE=<value>)` at the start.
- If there is no `erd.env`, run `/erd:init` first.
- Source candidates: `detect-project.sh <unit>` + the folders in `ERD_RELATED_SOURCES` of `erd.env`.

## Step 1: choose the mode
If the request makes it clear, do not ask. Ask once only when ambiguous. Several sources can be combined (e.g. orm as the base + code to extend).

| Mode | Situation | Initial approach |
|---|---|---|
| **orm** | ORM models / migrations exist (`ERD_SOURCE=migrations`) | `make erd P=<unit>` → `db/schema.generated.dbml` + docs → compare with model code |
| **db** | Only a running DB exists | Get connection info, `db2dbml` → module split |
| **code** | Only UI/API/DTO sources (DB not implemented) | Extract entity candidates → user validation → columns and relations |
| **docs** | ERD, ADR, planning docs, table definition sheets | Collect docs → migrate to DBML → report differences between docs and against code |
| **augment** | **DBML already exists** and new sources (feature, screen) extend it | Read existing DBML → extract only the additions from the new source → match against existing tables (reuse / add column / new table) → propose as a diff |

## Step 2: procedure per mode

### orm
1. `make erd P=<unit>` (source of truth is the migrations). On failure, use `ERD_EXIT` with `errors.md`.
2. If there are no migrations or they cannot run, read the model code and write a DBML draft — label it "draft inferred from code"; uncertain values get `[inferred]`.
3. Report differences between models and generated output (fields in the model but missing from migrations, etc.).
4. If ADRs / design docs exist, continue with docs mode item 2 and link the decisions in `.tbls.yml` `comments:`.

### db
1. Get connection info from the user. **A read-only account is recommended**; if it is a production DB, confirm once more.
2. `db2dbml postgres '<conn>' -o <unit>/db/schema.imported.dbml` (MySQL: `mysql`) — this command only reads, so it is an R1 exception.
3. Restructure into `db/modules/*.dbml` following "Module split" (`dbml-conventions.md`).

### code
Read the unit folder + `ERD_RELATED_SOURCES`. Entities that appear to belong to another unit (another DB) are not added; report them separately as "other-unit candidates".

| Source | Hints |
|---|---|
| Frontend forms | Field names, types, required, maxLength, select options (status values) |
| Frontend list / detail | Displayed columns, sort/filter/search (→ index candidates) |
| Routes / menus | Domain boundaries (→ module candidates) |
| API specs (OpenAPI/GraphQL) | Resource = table candidate, nested paths (`/orders/{id}/items` → FK) |
| Backend DTOs / services | Stored and queried fields, joins, transaction groupings |

1. Entity candidate table `Entity | Evidence file | Evidence` → confirm with the user what to drop or merge.
2. Extract columns (uncertain → `[inferred]`), organize relations; N:M becomes a join table.
3. Common columns (id, created_at, etc.) follow project conventions.

### docs
1. Read by format: Markdown/text tables, image ERDs (read the content and transcribe), SQL/DBML exports (`sql2dbml` — a read-only conversion, so an R1 exception), Excel table definition sheets.
2. From ADRs, extract the **decisions** that affect the schema (soft delete, multi-tenancy, ID strategy) and first show them as a table `ADR decision | Affected tables/columns | Matches schema?`. Where to record them depends on `ERD_SOURCE`:
   - `dbml` → reference `ADR-xxx` in the relevant table/column note or the Project Note.
   - `migrations` → **`.tbls.yml` `comments:`** (`tableComment`, `columnComments`, `labels: [ADR-xxx]`). Do not touch the derived DBML (`schema.generated.dbml`) or ORM code. Writing rules: `tbls-guide.md` "comments" section — **a comment in the config replaces the DB comment**, so keep the existing comment (`docs/schema/<table>.md`) and put it first.
   - ADRs that contradict the schema are not recorded; report them as differences (Hard rule 3).
3. After migrating, propose marking the original doc "Migrated to DBML (db/modules)" (edit only after approval).

### augment
1. Read the existing `db/modules/*.dbml` and `docs/schema/schema.json` first (step 0: check prior outputs).
2. Extract the data the new source needs the same way as code mode, but organize **only the additions**.
3. Match against existing tables: same concept → add columns; new concept → new table; unclear → ask.
4. Propose as a before/after diff → apply after confirmation. Do not rename existing tables/columns (propose separately if needed).

## Step 3: module split, save, document
- Save tables per business domain in `db/modules/<module>.dbml` (see `dbml-conventions.md` "Module split" and "Scale signals"). Propose the boundary evidence (routes, packages, FK density) and confirm.
- Add `use * from './modules/<module>'` to `db/schema.dbml`, and the module to `.tbls.yml` viewpoints (id = file name).
- `make erd P=<unit>` → on failure respond to `ERD_EXIT` → for lint warnings that can be fixed automatically (missing notes), ask whether to fix them.

## Decision table
| Condition | Result |
|---|---|
| Type/constraint stated explicitly in code (entity annotations, migrations) | Definite value |
| Inferred only from screens / DTOs | `[inferred]` |
| Sources disagree | Do not settle; ask with the list of differences |
| Appears to belong to another DB | Exclude from this unit; report as "other-unit candidates" |

## Error handling
`references/errors.md` (by `ERD_EXIT` code) + below.
| Situation | Action |
|---|---|
| `db2dbml` connection fails | Ask the user to check the connection info; do not proceed on guesses |
| Image ERD is unreadable | List the parts that could not be read and mark them `[TBD]` |

## Checklist (before reporting)
- [ ] `make erd P=<unit>` ✔ (or failure code reported)
- [ ] Every table belongs to a module (viewpoint)
- [ ] (migrations + ADR) decisions are recorded in `.tbls.yml` `comments:` and visible in the `make erd` output docs
- [ ] The `[inferred]` / `[TBD]` list is included in the report
- [ ] Differences between sources were decided or marked as open
- [ ] The report follows `report-templates.md` §3

## Related skills
- `/erd:design` — settle `[inferred]` / `[TBD]` items in conversation, then design further features
- `/erd:review` — review the imported schema against the code
- `/erd:sync` — doc maintenance and CI afterwards
