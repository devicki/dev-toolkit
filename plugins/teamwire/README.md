# teamwire

**English** · [한국어](README.ko.md)

A **mod** that draws your agent team as a live wiring diagram. When the lead session hands out work, a `Team` pane opens. It shows who is on the team, what each member was given, which model it runs, and where the current flows: out to a member while it works, back to the lead when an answer is waiting.

```
◆ TEAMWIRE  agent team, live                           ◆ LEAD · WAITING ON GROK·P2
╭─────────╮ ╭─────────╮ ╭─────────╮ ╭───────────╮ ╭─────────╮ ╭─────────╮
│ 3       │ │ 1       │ │ 1       │ │ 0         │ │ 1       │ │ 4m 12s  │
│ TEAM    │ │ WORKING │ │ REPLY   │ │ NEEDS YOU │ │ DONE    │ │ UPTIME  │
╰─────────╯ ╰─────────╯ ╰─────────╯ ╰───────────╯ ╰─────────╯ ╰─────────╯
busy    ▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱  1/3 members · 7 handoffs · last event 8s ago
context ▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱  38% · 376k / 1M tokens · $4.51

ORCHESTRATION ──────────────────────────────────── 3 wires · 2 live · 1-3 focus
              ╭─━━━━━━━━━━━━━━━━━━━━▶ ● [ grok·p2 ]      WORKING ◆
╭──────────╮  │                         herdr · grok · Grok 4.7 (xhigh)  1m 20s
│ ◆ LEAD   ├──┤                         Review the diff for bugs
│ opus 5.5 │  ├─◀┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅ ◉ [ Map callers ]  REPLY READY
│ ▰▰▱▱▱ 38%│  │                         subagent · Explore · haiku 5.5  34s · 9 tools
╰─high─────╯  │                         find every caller of parse()
              ╰─────────────────────── ✓ [ Writer ]       DONE

ACTIVITY ─────────────────────────────────────────────────────────── 9 events
▍ Map callers      finished in 34s · reply ready                          8s
▍ grok·p2          took a new task                                       1m

COMMS ─────────────────────────────────────────────────────────── 7 handoffs
lead → grok·p2  Review the diff for bugs                                  1m

[ c  clear finished ]  [ l  clear log ]
```

## What it shows

- **Dashboard**: the lead's state as a chip, tiles for TEAM / WORKING / REPLY / NEEDS YOU / DONE / UPTIME, a busy bar, and the lead's **context window** (`38% · 376k / 1M tokens`) with the session cost; green, amber past 60%, red past 85%.
- **ORCHESTRATION**: the lead at the centre of a rounded fan, one branch per member: name, state badge, `kind · agent · model · effort`, its time, tool calls and output tokens, and the task it was handed. The lead's box carries its model, a context gauge and its effort.
- **Current on the wires**: sparks run lead → member while it works, member → lead while its answer waits to be read, and surge for a few seconds after a message or handoff. An answer left unread for 5 minutes goes **stale** (`REPLY · 7m`) and stops pulling current.
- **Member to member**: when two members message each other, a rail on the right joins their rows for a few seconds, the arrow on the receiver.
- **FOCUS**: press a member's name (or its number, `1`–`9`) to open its full task, model, clock, spend and its last messages; press again to close.
- **ACTIVITY**: joins, work started, `finished in 34s · reply ready`, `done`, `failed`, `needs you`, `answer read by lead`, and `team stood down · 4 members · 3m 20s` when the last busy member finishes.
- **COMMS**: the last handoffs and messages, `from → to`, first line and age.
- **Alerts**: a toast when a member needs you (plus a desktop notification through your notification channel), when an answer is ready, when one fails, and when the team stands down.
- **Status line**: with the pane closed or not drawn, one line under the prompt keeps the team in sight: `◆ team 2 working · 1 reply · ctx 38% · /teamwire`.
- **States**: `WORKING`, `REPLY READY` (finished, not read yet), `NEEDS YOU` (an approval or a question is open, including a subagent's tool call waiting on your approval), `IDLE`, `DONE`, `FAILED`.

Each kind of member hangs on its own wire:

| Kind | Idle | Live |
|---|---|---|
| subagent | `┄┄┄` | `┅┅┅` |
| teammate (agent teams) | `═══` dim | `═══` lit |
| herdr (codex, grok, …) | `───` | `━━━` |
| session (another Claude session) | `┈┈┈` | `┉┉┉` |

## Where the data comes from

| Member | Source | Needs |
|---|---|---|
| Subagents, teammates | `agent.spawn`, `$.agent.list()`, `session.send` / `session.receive`; model and effort from each model request (`turn.step`); approvals from `tool.check`; tool calls and tokens from `tool.call` / `turn.complete` | nothing |
| The lead | `session.measure` (context window, cost), `turn.start` / `turn.complete` | nothing |
| Other Claude sessions | the lead's SendMessage (`session.send`) | nothing |
| CLI agents in herdr panes | the lead's `herdr agent prompt / send-keys / read / wait` commands; state from `herdr agent list` every 2 s; model read once from the agent's footer | [herdr](https://herdr.dev) |

Without herdr, everything but the external CLI agents works.

## Install

```
/plugin marketplace add devicki/dev-toolkit
/plugin install teamwire@dev-toolkit
```

The pane opens by itself on the first handoff. Close it and it stays closed for the session; `/teamwire` opens it again.

## Good to know

- **No tokens.** Hooks run inside Claude Code; nothing is added to the prompt or the conversation. The cost is local: one `herdr agent list` every 2 s while herdr members exist, and redraws (~7 per second) while current flows.
- Press keys (`c`, `l`, `1`–`9`) reach the pane once it holds the focus: click it, or ctrl+x tab.
- The pane opens unasked only on a terminal 144 columns or wider (110 once you have opened it).
- A mod runs inside Claude Code with your user permissions. It has no sandbox. teamwire runs the `herdr` command and nothing else.
- Under an organization-managed Claude Code, plugins you install yourself may not receive these events.
- Known limits: herdr calls built from variables or scripts are not detected; the CLI model is read from footers as they look today; messages between two members flash both wires instead of drawing a wire of their own.

## Development

```bash
claude plugin validate plugins/teamwire
claude plugin test plugins/teamwire
claude --plugin-dir plugins/teamwire   # run with only this plugin loaded
```

Inspired by [swarm](https://github.com/OneWave-AI/claude-code-mods) (MIT), which maps subagents and agent teams as a tree.
