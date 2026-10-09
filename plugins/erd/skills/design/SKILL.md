---
name: design
description: >
  Interactive schema design/changes applied to the source of truth (DBML/ORM). Output: updated source + docs/schema.
  Triggers: "주문 테이블 설계해줘", "회원에 등급 추가" / "design the schema", "add a table for X".
  Not for: review (→ /erd:review), import from code/docs (→ /erd:import).
argument-hint: "[feature, module or change to design] [--project <unit folder>]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
---

# /erd:design — interactive design and changes

> **One-line definition**: narrow the requirements down with questions and turn them into a schema. Importing belongs to import, reviewing to review.
> **Key outputs**: the changed schema source of truth + `<unit>/docs/schema/viewpoint-<module>.md`

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — Hard rules, Prohibited (required)
- `references/dbml-conventions.md` — naming, notes, indexes, modules, **expensive to change, scale signals** (required)
- `references/source-of-truth.md` — what to change per source of truth
- `references/migration-tools.md` — generating migrations when the source of truth is migrations
- `references/units.md` — resolving the unit, references to another DB
- `references/report-templates.md` — Completion report (§3)
- `references/errors.md` — `ERD_EXIT` responses

## Hard rules (top priority) — full list in `rules.md`
1. **Propose → confirm → apply**. Do not change source-of-truth files before confirmation (R4).
2. Edit only the source of truth: `dbml` → `db/modules/*.dbml`; `migrations` → models + a new migration. With a migrations source of truth, DBML is only for proposals (`db/proposals/<name>.dbml`) (R3).
3. Update docs only with `make erd P=<unit>` (R1).
4. If something is unknown, leave it `[TBD]` and continue. Do not stall on questions (R7).
5. Language (R8): reply in the user's language; text written into the project follows the unit's `ERD_LANG`.

## Step 0: context (every time)
- Target unit: `units.md` "Resolving the target unit". State `Target: <unit> (<DB>, ERD_SOURCE=<value>)`. If there is no `erd.env`, `/erd:init`.
- **Prior outputs first**: read `docs/schema/README.md`, the relevant `viewpoint-*.md`, and table docs. If missing or stale, `make erd P=<unit>`.
- Read the screens, APIs and entities in the related sources (unit folder + `ERD_RELATED_SOURCES`) **before asking questions**. Do not ask what the code already tells you.

## Step 1: decide the mode (judge from the request, do not ask)
| Mode | Situation | Approach |
|---|---|---|
| Initial design | Almost no tables | Question order 1→5 below |
| Feature addition | New screen / requirement | Data to store → whether existing tables can be reused → new tables |
| Change | Modify existing tables/columns | Before/after diff + affected code (grep) + data migration risk |

## Step 2: questions — one batch (1–3) at a time
Separate required from optional. Do not re-ask what was already answered or is clear from the request or code.

| Order | Required | Optional |
|---|---|---|
| 1 | Core things (nouns) and main actions (verbs) | |
| 2 | User roles / org structure, multi-tenant or not | Permission model |
| 3 | Relations and cardinality between things (1:N, N:M) | |
| 4 | Status flow | Whether history must be kept |
| 5 | Deletion policy (soft delete?) | Audit columns, i18n / currency |

**Settle first** (`dbml-conventions.md` "Expensive to change"): table and column names, module ids, PK strategy, tenant key. Get confirmation on these before moving on.

## Step 3: design draft — checkpoint at each stage
1. **Conceptual level**: Mermaid erDiagram (tables and relations, key columns only) → "Is this structure right? Any missing relations?"
2. **Detailed DBML**: `dbml-conventions.md` rules (notes, FK indexes, naming) → confirm.
3. For decisions with real alternatives (status enum vs varchar, separate history, polymorphic relations): one line of pros/cons each + a recommendation.
4. If scale signals appear (more than 30 tables per module, more than 50 columns, etc.), point them out once.

## Step 4: apply
- New module: `db/modules/<module>.dbml` + `use` in `db/schema.dbml` + `.tbls.yml` viewpoint (id = file name).
- Reference to another module: `use { table x } from './<module>'`. Reference to another unit (another DB): a note instead of an FK (`units.md`).
- `make erd P=<unit>` → on failure use `ERD_EXIT` with `errors.md` → handle lint warnings.
- Migrations source of truth: edit models → generate a migration with the project tool (e.g. `alembic revision --autogenerate -m ...`, after user confirmation) → review and report the generated result → `make erd P=<unit>`.

## Step 5: applying to the DB (dbml source of truth)
| Stage | Guidance |
|---|---|
| Data need not be kept (early development) | Recreate the development DB from `db/schema.sql` |
| Data must be kept | `/erd:sync migrate` to create a migration for the changes (Atlas, etc.) |

## Decision table
| Condition | Result |
|---|---|
| Tables/columns nobody asked for | Do not add; only propose |
| Conflicts with existing rules (naming, types, common columns) | Follow the existing rules. To change them, make a "Rule change proposal" |
| Required item the user did not answer | `[TBD]` + a reasonable default, continue, report at the end |

## Error handling
`references/errors.md`. In particular, for `ERD_EXIT=4` (DBML syntax) and `6` (SQL apply), fix the DBML and re-run.

## Checklist (before reporting)
- [ ] Every new table has a `Note`, every new column a `note`
- [ ] FK columns are indexed
- [ ] New tables belong to a viewpoint (module)
- [ ] `make erd P=<unit>` ✔
- [ ] `[TBD]` list reported
- [ ] The report follows `report-templates.md` §3

## Related skills
- `/erd:review` — review the design against the code
- `/erd:sync` — migrations for applying to the DB (migrate), CI
- `/erd:import` — when there is something to extract from existing sources first
