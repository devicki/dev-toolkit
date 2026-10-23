# Hard rules and prohibitions (shared by all dstack skills)

> Baseline: dstack plugin 0.1.0, herdr 2026-10, grok CLI (Grok 4.7) — 2026-10. Every rule states its **reason (a problem actually encountered)**.

## Hard rules

| # | Rule | Reason |
|---|---|---|
| R1 | Every herdr call for delegation **must** go through `${CLAUDE_PLUGIN_ROOT}/shared/scripts/delegate.py`. | A prompt sent right after `agent start` was dropped in testing; the script resends once on `agent_prompt_stalled`. herdr puts errors on stderr, not stdout. |
| R2 | Completion is the report file ending in `GROK_DONE`, never the pane state. | herdr documents that grok can be idle while its own subagents still run. |
| R3 | Run `delegate.py run` in the background (`run_in_background: true`). | A task can take up to an hour; a foreground Bash call times out at 10 minutes and blocks the session. |
| R4 | One tab per grok, labelled `grok:<name>`. | Split panes in the lead's tab became too small to watch with several groks. |
| R5 | Drive only agents this skill started by name. | The user runs their own unnamed grok and claude panes in the same session. |
| R6 | Review the diff and rerun the check before reporting. | A report is the delegate's self-assessment, not evidence. |
| R7 | If something could not be run or failed, report the exit code and reason as-is. No guessing. | |
| R8 | Language: reply in the user's language; briefs are English. | Files written into the user's project follow the project's language setting. |

## Prohibited

- ✗ Delegating deploys, force-pushes, data deletion, or tasks that need secrets (grok runs with `--always-approve`)
- ✗ Answering a grok approval dialog without asking the user
- ✗ Closing or prompting a tab the user opened
