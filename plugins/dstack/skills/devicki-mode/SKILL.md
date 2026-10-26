---
name: devicki-mode
description: >
  devicki's working mode: pstack's poteto-mode, with every grok role run as a Grok CLI session in its own herdr tab. Output: the matched playbook's reply.
  Triggers: "/dstack:devicki-mode", "devicki 모드로 해줘" / "work in devicki mode".
  Not for: one-off delegation to grok (→ /dstack:herdr-grok-delegate).
argument-hint: "<task>"
disable-model-invocation: true
allowed-tools:
  - "Bash(python3 ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
---

# /dstack:devicki-mode — poteto-mode with grok in herdr

> **One-line definition**: load pstack's poteto-mode as the base, then apply the overrides below. This file only holds the differences, so pstack updates reach this mode with no sync.

Task: $ARGUMENTS (empty: continue the current work).

## Step 0: load the base (every time this mode starts)
1. `python3 ${CLAUDE_PLUGIN_ROOT}/shared/scripts/pstack_path.py`. Take `root=` from the line starting `PSTACK_EXIT=`. Exit 3: tell the user to install pstack and stop.
2. Read in full, with the Read tool: `<root>/docs/harness/claude-code.md`, then `<root>/skills/poteto-mode/SKILL.md`. The Skill tool refuses most pstack skills; open any other pstack skill as `<root>/skills/<name>/SKILL.md`.
3. Follow poteto-mode exactly, mapped through the Claude Code adapter, except where an override below says otherwise. An override wins over poteto-mode, the adapter, and routed pstack skills.

## Overrides

### O1. grok roles run in herdr
Resolve each role's model the way poteto-mode says (the line in `~/.claude/rules/pstack-models.md`, else the skill default). The role is a **grok role** when the value is a `grok-*` slug, or when it is `inherit-parent` or `auto` and the pstack default for that role is a `grok-*` slug (Claude Code's setup-pstack writes grok defaults as `inherit-parent`). A role set to a Claude model (`opus xhigh`, `sonnet high`, …) is not a grok role.

- A grok role never uses the Agent tool. Run it through the **herdr-grok-delegate** skill (`${CLAUDE_PLUGIN_ROOT}/skills/herdr-grok-delegate/SKILL.md`): one named grok tab per subagent, `delegate.py run` in the background.
- Pass each grok role its model on `delegate.py run`. Start from the role's slug (for `inherit-parent` or `auto`, the pstack default slug) and set its effort per poteto-mode's **Match the model to the job**. Write `grok-<version>-<effort>[-fast]` as `--model grok-<version> --effort <effort>`. grok takes `low`, `medium`, `high`, `xhigh`, so use the nearest (`max` → `xhigh`). Drop `-fast`, as the adapter does for Claude slugs. If grok does not start with that model, rerun without `--model` and say so.
- A panel list (arena runners, architect runners, interrogate reviewers, arena cross-judge pool) keeps its count. Its grok entries run in herdr, its Claude entries run with Agent. This keeps the panel's model diversity in Claude Code.
- Every other role keeps poteto-mode's routing: `pstack:poteto-agent` or the subagent type the routed skill prescribes.

### O2. grok briefs
grok cannot see this conversation and does not list pstack skills. Each brief carries, besides what poteto-mode asks a subagent prompt to carry:
- The absolute path of `<root>/skills/poteto-mode/SKILL.md` and of each principle leaf the step applies, with "read these before any work".
- For a read-only role (how explorer, why investigators, reflect tooling, reviewers, judges): "Do not edit any file." Check `git status` in its `--cwd` afterward.
- For an editing role running beside others on the same repo: its own worktree as `--cwd`.

### O3. fan-out
No fixed cap: open as many grok tabs as the playbook asks for. pstack's swarm assumes cloud
workers, but here every grok runs on this machine. When several slices run heavy builds or tests,
or bind ports, run only as many at once as the machine handles and queue the rest.
Never move a grok role to the Agent tool to go faster. Close each tab with `delegate.py close`
once its result is reviewed (herdr-grok-delegate Step 5); a fix round goes to a fresh grok.

### O4. ownership
grok's report is a self-assessment. Before a grok result counts in any step, read its diff and rerun the check the step names, the same as poteto-mode's "you own every subagent's work".

### O5. reply language and style
Write the reply in the user's language and apply poteto-mode's **Writing the reply** rules to it. When another always-on style (such as ponytail) gives a different reply format, poteto-mode's format wins while this mode is active.

## Error handling
| Situation | Action |
|---|---|
| `PSTACK_EXIT=3` | Tell the user to install pstack, stop |
| `HERDR_ENV` is not 1 or `grok` is missing | Say grok roles cannot run in herdr here. Run them with Agent on the session model, and name each one in the reply |
| `DELEGATE_EXIT` non-zero | Handle it per the herdr-grok-delegate exit table, then continue the playbook |
| A pstack update renamed a section an override names | Apply the override by its intent, and tell the user which section moved |

## Related skills
- `/dstack:herdr-grok-delegate` — the delegation mechanics this mode uses
- `/pstack:poteto-mode` — the base, without the herdr overrides
- `/pstack:setup-pstack` — role models and budget; optional for this mode
