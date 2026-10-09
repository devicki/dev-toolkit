---
name: __SKILL__
description: >
  <What it does, one sentence>. Output: <artifacts (format/count)>.
  Triggers: "<한국어 트리거>", "<한국어 트리거>" / "<english trigger>", "<english trigger>".
  Not for: <case where it must not fire> (→ /__NAME__:<skill>), <case> (→ /__NAME__:<skill>).
argument-hint: "[<argument>]"
# disable-model-invocation: true   # turn on for heavy or side-effect-prone workflows (only when the user invokes it directly)
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
---

# /__NAME__:__SKILL__ — <title>

> **One-line definition**: <What>. <How lives in other skills>.
> **Key output**: `<file name pattern>`

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — Hard rules and prohibitions (required)
- `scripts/<helper>` — <deterministic work, use is mandatory>
<!-- Files used only by this skill go in the skill folder and are referenced as ${CLAUDE_SKILL_DIR}/<file> -->

## Hard rules (highest priority) — full list in `rules.md`
1. <Source restriction — only the specified files/APIs; no guessing from training knowledge>
2. <On failure, report it and stop>
3. <Output follows the standard template>
4. Language: reply in the user's language; files written into the user's project follow the project's language setting.

## Step 0: prerequisites / check required prior outputs

## Step 1: choose a mode
If the request makes it clear, don't ask. Ask once only when it is ambiguous.
| Mode | Situation | Initial approach |
|---|---|---|
| NEW | Nothing exists yet | |
| REVERSE | Existing code / outputs | |
| AUGMENT | Add to an existing result | |

## Step 2: collect (one batch at a time, mark required/optional, TBD allowed)

## Step 3: generate — run the helper
1. Collected data → (if needed) JSON shaped like `schema.example.json`
2. `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/<helper> <in> <out>`
3. If the script's validation output is not all ✅, report and re-run

## Decision table
| Condition | Result |
|---|---|

## Error handling
| Exit code / situation | Action |
|---|---|

## Checklist (before output)
- [ ]

## Related skills
- `/__NAME__:<skill>` — <relationship>
