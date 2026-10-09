# Hard rules and prohibitions (shared by all __NAME__ skills)

> Baseline: __NAME__ plugin 0.1.0 — <YYYY-MM>. Every rule states its **reason (a problem actually encountered)**.

## Hard rules

| # | Rule | Reason |
|---|---|---|
| R1 | <Deterministic work> **must** go through `${CLAUDE_PLUGIN_ROOT}/shared/scripts/<helper>`. No ad-hoc code. | <failure case> |
| R2 | If something could not be run or failed, report that fact and the exit code as-is. No guessing. | |
| R3 | Language: reply in the user's language; files written into the user's project follow the project's language setting. | Writing project files in a language the team does not use leaves teammates and agents unable to read them, and mixed-language text confuses both. |

## Prohibited

- ❌ <Editing generated files directly>
- ❌ <Running against dangerous targets (e.g. a production DB)>
