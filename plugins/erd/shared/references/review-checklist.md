# ERD review checklist and severity decision table

> Baseline: erd plugin 0.4.0 — 2026-10. Output format: `report-templates.md` §1 (Review report).
> Principle: report **only items backed by code or documents**. Do not write generic modeling advice (explanations of normalization, etc.).
> Suspicions with no evidence found go separately under "Needs confirmation".

## Step 1: core violations first (always checked)

| ID | Item | How to check |
|---|---|---|
| C1 | Table without a PK | constraints in `schema.json` |
| C2 | Stores another table's id but has no FK | column name `*_id` + joins/lookups in code |
| C3 | A value the code treats as required is nullable | entity `nullable=False`/`@NotNull`/required form field ↔ column |
| C4 | A business-unique value has no UNIQUE | duplicate-check logic in code (`exists by email`, etc.) ↔ constraint |
| C5 | Code ↔ schema mismatch (uses a nonexistent column, type/length mismatch) | entities, DTOs, queries ↔ columns |

## Step 2: rest of the checklist

| ID | Category | Item |
|---|---|---|
| P1 | Performance | Index on FK columns (lint `requireForeignKeyIndex`) |
| P2 | Performance | Composite index matching the WHERE/ORDER BY combinations of list screens and queries |
| P3 | Performance | Large TEXT/JSON columns in tables used for list queries |
| M1 | Modeling | Same value stored redundantly (if intentional denormalization, give the reason in the note) |
| M2 | Modeling | Join table for N:M relationships |
| M3 | Modeling | Floating point for money, timestamps without time zone (PostgreSQL) |
| M4 | Modeling | Soft delete (`deleted_at`) + UNIQUE conflict |
| M5 | Modeling | Missing multi-tenant key |
| D1 | Delete policy | Whether the FK `delete:` behavior matches business rules |
| D2 | Status values | Whether allowed values are stated in a note/check |
| N1 | Naming & docs | Consistent naming conventions (the project's existing conventions take precedence) |
| N2 | Naming & docs | Missing table Note / column note (lint) |
| N3 | Naming & docs | Module (viewpoint) membership |
| A1 | Decision docs | Schema contradicts decisions in ADRs/design docs |
| X1 | Cross-unit | Type/meaning mismatch in columns referencing another DB (note `→ <unit>:`) |
| U1 | Cleanup | Columns/tables no longer used by code (deletion candidates — confirm with the user) |

## Severity decision table (condition → severity)

Apply the first matching row from the top. If a judgment wavers, fix the table; do not improvise other criteria.

| Condition | Severity |
|---|---|
| C1, C2 and the code actually uses that relationship | 🚨 **Critical** |
| C3, C4 and the code has the corresponding validation/duplicate-check logic (the DB is not the last line of defense) | 🚨 **Critical** |
| C5 (code uses a nonexistent column or a different type → possible runtime error) | 🚨 **Critical** |
| M3 floating-point money, M4 unique conflict, X1 type mismatch | 🚨 **Critical** |
| C2·C3·C4 but weak evidence of use in code | ⚠️ **Warning** |
| P1, P2 (performance that becomes a problem as data grows) | ⚠️ **Warning** |
| D1, D2, M1, M2, M5, A1 | ⚠️ **Warning** |
| N1, N2, N3, P3, U1 | 💡 **Info** |
| Insufficient evidence | 🔎 **Needs confirmation** (no severity) |

For change proposals on tables holding production data, also state the migration risk (backfill, staged NOT NULL, locking).
Proposals that conflict with project rules or ADRs are separated out as a "Rule change proposal".
