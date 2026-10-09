# Hard rules and Prohibited (shared by all erd skills)

> Baseline: erd plugin 0.4.0 — 2026-10. Each skill's "Hard rules" section points to this document.
> Every rule carries its **reason (a problem actually encountered)**. Do not work around a rule while its reason still holds.

## Hard rules

| # | Rule | Reason |
|---|---|---|
| R1 | Generate and check docs **only** from the repo root with `make erd [P=<unit>]` / `make erd-check` (or `scripts/erd-doc.sh <mode> <unit>`). Do not improvise by combining `tbls`, `dbml2sql`, `psql`, `docker run` yourself. | ① tbls panics under other accounts because of permissions on the shared `/tmp/go-graphviz` (the script avoids this with a per-user TMPDIR). ② **dbml2sql exits 0 even on syntax errors**, so running it directly looks like success (the script judges by the log). ③ The script handles temporary DB names, cleanup and per-unit paths consistently. |
| R2 | Set up projects **only** with `install-templates.sh`. Do not copy or substitute templates by hand with `cp`/`sed`. | Manual work causes missed substitutions, overwritten existing files and duplicate CLAUDE.md blocks. The script is idempotent and never overwrites. |
| R3 | Modify only the schema source of truth (`ERD_SOURCE` in `erd.env`). `dbml` → `db/modules/*.dbml`; `migrations` → ORM models + a new migration. | With two sources of truth they overwrite each other (`source-of-truth.md`). |
| R4 | Do not change source-of-truth files before the user confirms (propose → confirm → apply). Exception: the user explicitly asked for the change to be applied. | Schema changes affect code and data across the board. |
| R5 | Report results based on script output and file contents. If something could not run or failed, **state that fact and the `ERD_EXIT` code as-is**; never summarize it as if it succeeded. | Guessed reports lead the user into wrong commits (`errors.md`). |
| R6 | Use only Docker or a **development** server the user designated for the temporary DB. | `erd-doc.sh` creates and drops the temporary DB (`DROP DATABASE`). |
| R7 | Mark values not verified in code with the inferred marker `[inferred]` (`[추정]` in ko) and values the user has not decided yet with `[TBD]` in the note, and keep going. List them at the end of the report. | Keeps questions from blocking progress without hiding what is unconfirmed. |
| R8 | Language. (a) Conversation and reports use the language of the user's latest message; report-template headings are rendered in that language (Korean labels: `report-templates.md`). (b) Everything written into the project — DBML notes, `.tbls.yml` comments, CLAUDE.md/AGENTS.md text, proposal files, migration comments, the inferred marker — uses `ERD_LANG` from the unit's `erd.env` (`ko`\|`en`). If unset, follow the language of the existing project docs (README, CLAUDE.md) and ask once if unclear. (c) Identifiers (table/column/index names, viewpoint ids, file names) are always English snake_case regardless of language. | 0.3.x wrote Korean into every project; English-speaking teammates and agents could not read generated files, and mixed-language notes confuse both. |

## Prohibited

- ❌ Editing `docs/schema/`, `db/schema.sql`, `db/schema.generated.dbml` directly (generated files — overwritten by the next `make erd`). For a `migrations` unit, descriptions and ADR references go in `.tbls.yml` `comments:`
- ❌ Putting a production DB address in `PG=`, `MY=`, `ERD_MIGRATE_CMD` or `tbls` arguments
- ❌ Editing a migration file that has already been applied (committed/deployed) — add a new migration instead
- ❌ Committing `dbml-error.log` (it is in `.gitignore`)
- ❌ Adding a DBML `ref` to a table in another ERD unit (another DB) — mark it with a note instead (`units.md`)
- ❌ Treating a table/column rename as a simple edit — if production data exists, present a rename migration strategy together with the affected code (grep)
- ❌ Adding tables/columns nobody asked for "for later" — if one seems needed, only propose it
- ❌ Substituting a similar general-purpose tool (another ERD skill, an ad-hoc script) when this plugin's script exists
- ❌ Writing project files in a language other than the unit's `ERD_LANG` (R8)
