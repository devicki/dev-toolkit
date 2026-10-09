---
name: review
description: >
  Review the ERD against code; severity-ranked fixes (all/module/table/PR diff). Output: review report.
  Triggers: "ERD 검토", "코드랑 ERD 맞는지" / "review the schema", "check ERD vs code".
  Not for: design/changes (→ /erd:design), drift check (→ /erd:sync).
argument-hint: "[module|table|all] [--changed [<base ref>]] [--fix] [--project <unit>|--all-units]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
  - "Bash(scripts/erd-changed.sh *)"
  - "Bash(git rev-parse *)"
  - "Bash(git diff *)"
---

# /erd:review — review and improvement proposals

> **One-line definition**: report only problems backed by evidence (code, docs), in a fixed format. Apply only the items the user picks.
> **Key output**: `report-templates.md` §1 "Review report"

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/review-checklist.md` — core violations C1–C5, checklist, **severity Decision table** (required)
- `references/report-templates.md` — Review report template (required)
- `references/rules.md` — Hard rules, Prohibited
- `references/units.md` — resolving the unit, checking references to another DB
- `scripts/detect-project.sh <unit>` — source locations
- the project's `scripts/erd-changed.sh` — changed-files mode

## Hard rules (top priority) — full list in `rules.md`
1. **No generic advice without evidence.** Attach `file:line` or a doc location to every finding. If no evidence is found, mark it "Needs confirmation".
2. Severity **follows the Decision table**. Do not invent criteria on the spot.
3. Output **exactly the Review report template**. End with the Data as of line (commit, doc generation time).
4. Do not modify files during the review. Apply only with `--fix` or after the user picks items (R4).
5. Language (R8): reply in the user's language; text written into the project follows the unit's `ERD_LANG`.

## Step 0: target and baseline data
- Target unit: `units.md` "Resolving the target unit". With `--all-units`, go unit by unit and finish with the cross-unit reference check (X1).
- Baseline: `docs/schema/schema.json` (if missing or older than the source of truth, run `make erd P=<unit>` first) + the source of truth (DBML or ORM models) + lint warnings from `make erd`.
- Data as of: `git rev-parse --short HEAD` (+ `git diff --quiet || echo dirty`), modification time of `docs/schema/README.md`.

## Step 1: scope (mode)
If the request makes it clear, do not ask.
| Scope | Situation | Target |
|---|---|---|
| Changes `--changed [ref]` | PR / branch review | Schema and related files from `scripts/erd-changed.sh --base <ref>` (default: the remote default branch), and only their tables |
| Module / table | Given as argument | That viewpoint / table + directly referenced tables |
| Everything | No argument | If more than 30 tables, show the module list and ask for priority |

## Step 2: compare with sources
Locate code with `detect-project.sh <unit>` and read only code in scope (unit folder + `ERD_RELATED_SOURCES`).
- Backend: entities / models, repositories / queries (WHERE/ORDER BY/JOIN), save and validation logic, DTOs
- Frontend: forms (required, length, options), lists (sort, filter), data shown on detail views
- Docs: ADRs, design docs
- Notes referencing another DB (`→ <unit>: …`) are checked against the other unit's `docs/schema/schema.json`
- With many modules, split exploration per module across Explore subagents. Put the unit path, target tables and what to look for (C1–C5 evidence) fully in the prompt; reuse agents already spawned via `SendMessage` instead of creating new ones. Run independent modules in parallel in one response.

## Step 3: judgment
1. **Core violations C1–C5 first**, all of them.
2. The rest of the checklist (P, M, D, N, A, X, U).
3. Severity from the `review-checklist.md` Decision table.

## Step 4: report
Exactly the `report-templates.md` §1 template, rendered in the user's language per R8 (Korean headings: the label table in `report-templates.md`). Problems that require changes on the code side go in the "Code change suggestions" section.

## Step 5: apply (optional)
- Only with `--fix` or the items the user picked. Same method as `/erd:design` step 4.
- For changes that affect production data, present a migration strategy as well and do not apply automatically.
- After applying, `make erd P=<unit>`.

## Error handling
| Situation | Action |
|---|---|
| `make erd` fails | `errors.md` (`ERD_EXIT`) — do not review without docs; fix it first, or state that the review is based on the source of truth only |
| `erd-changed.sh` exit 2 (no base ref) | Ask the user to specify `--changed <ref>` |
| Source location not found | Mark that item "Needs confirmation"; no guessing |

## Checklist (before reporting)
- [ ] All of C1–C5 judged (passed items go in the ✅ section)
- [ ] Every finding has an evidence location
- [ ] Severity matches the Decision table
- [ ] Data as of line included

## Related skills
- `/erd:design` — apply the picked items
- `/erd:sync` — drift check between docs, source of truth and DB; `erd-check-changed` in CI
