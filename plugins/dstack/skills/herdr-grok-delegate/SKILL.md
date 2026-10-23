---
name: herdr-grok-delegate
description: >
  Hand a task to a Grok CLI session in its own herdr tab, wait for its report, then review the change yourself. Output: your review of grok's work, with its report path.
  Triggers: "grok한테 넘겨줘", "grok으로 위임해" / "delegate this to grok", "hand it to grok in herdr".
  Not for: asking a Grok Bot through the MCP relay (→ /grokbot-relay:grokbot-relay), sessions outside herdr.
argument-hint: "<task>"
allowed-tools:
  - "Bash(python3 ${CLAUDE_PLUGIN_ROOT}/shared/scripts/delegate.py *)"
---

# /dstack:herdr-grok-delegate — delegate to grok in a herdr tab

> **One-line definition**: writes a self-contained brief, runs grok in a tab named `grok:<name>`, waits for the report file, then reviews the diff. This session stays the owner of the result.
> **Key output**: `$TMPDIR/dstack-<uid>/<name>-<stamp>.report.md`

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — Hard rules with reasons (required)
- `scripts/delegate.py` — starts or reuses the grok tab, sends the task, waits for the report; use is mandatory

## Hard rules (highest priority) — full list in `rules.md`
1. Every herdr call goes through `delegate.py`. Never hand-roll `herdr agent prompt` for this skill.
2. Run `delegate.py run` with the Bash tool's `run_in_background: true`. You are notified when it exits; do not poll.
3. Only drive grok agents this skill started by name. Never prompt, reuse, or close the user's own panes.
4. You own the result. Read the report, then inspect the diff and rerun the key check yourself. Report your verdict, not grok's summary.
5. grok runs with `--always-approve`. Never delegate deploys, force-pushes, data deletion, or anything with secrets.
6. Language: reply in the user's language. Briefs are in English.

## Step 0: prerequisites
- `HERDR_ENV=1` and `command -v grok`. If either is missing, say so and stop.

## Step 1: name and place
- Name: `grok-<short-slug>` (pattern `[a-z][a-z0-9_-]{0,31}`). New work gets a new name. Reuse a live name only for a follow-up that needs that session's context.
- `--cwd`: the repository the task is about. Parallel grok runs that edit the same repo need separate worktrees (`git worktree add`), one `--cwd` each.

## Step 2: write the brief
grok cannot see this conversation. Write a file in your scratchpad with:
- Goal and why, in two or three sentences.
- Exact files, functions, or commands involved.
- Constraints: what must not change, style to match.
- Done criteria and the verification command whose output must be in the report.
- When a pstack principle or playbook applies, its absolute path (from `installPath` of `pstack@cursor-plugins` in `~/.claude/plugins/installed_plugins.json`). grok can read the file but does not list pstack skills.

`delegate.py` appends the report protocol (report path, `GROK_DONE` last line, no commit or push unless asked). Don't repeat it.

## Step 3: run
```
python3 ${CLAUDE_PLUGIN_ROOT}/shared/scripts/delegate.py run --name <name> --brief <file> [--cwd <dir>] [--model <grok model id>] [--timeout <sec, default 3600>]
```
Several independent tasks: one background run per name, sent in one response. Tell the user which tabs opened.

## Step 4: result
The last line is `DELEGATE_EXIT=<code> <reason> key=value ...`.

| Exit | Reason | Do |
|---|---|---|
| 0 | ok | Step 5 |
| 2 | usage | Fix the argument or prerequisite the message names |
| 3 | busy | The name is working or blocked. Wait, or use a new name |
| 4 | gone | The agent or tab closed. Start again with a new run |
| 5 | blocked | grok shows a dialog. Show the pane tail to the user and ask before answering |
| 6 | timeout | The tab is still open. Read the pane, then rerun with the same name to continue or close it |
| 7 | stalled | The prompt was not taken twice. Show the pane tail and stop |
| 8 | idle-no-report | grok stopped without a report, often to ask a question. Answer it with a follow-up run on the same name if you can; otherwise ask the user |

## Step 5: review and report
1. Read the report.
2. In `--cwd`: `git status` and `git diff`. Check the change does what the brief asked and nothing more.
3. Rerun the verification command yourself.
4. Reply: what changed, your verdict, the verification output you saw, open issues, and the tab name.
5. `delegate.py close --name <name>` when no follow-up is expected. Leave it open if the user wants to watch or continue.

## Checklist (before reply)
- [ ] Verdict is based on the diff and your own check, not only the report
- [ ] Every non-zero exit is reported with its reason
- [ ] Tabs left open are named in the reply

## Related skills
- `/grokbot-relay:grokbot-relay` — ask a Grok Bot agent instead of a local grok CLI
- teamwire (mod) — shows each delegated grok as a team member while it works
