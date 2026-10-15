# teamwire

**English** · [한국어](README.ko.md)

A **mod** that draws your agent team as a live wiring diagram. When the lead session hands out work, a `Team` pane opens. It shows who is on the team, what each member was given, which model it runs, and where the current flows: out to a member while it works, back to the lead when an answer is waiting.

```
TEAMWIRE  4 members · 2 working · 1 reply · 0 needs you        lead: waiting on grok·p2

╭──────────╮
│ ◆ LEAD   ├┳━━━━━━━━━━━━━━━━━━━━━━━━▶ ● grok·p2              WORKING ⏳
│ opus 5.5 │┃                            herdr · grok · Grok 4.7 (xhigh)
╰─high─────╯┃                            Review the diff for bugs
            ┣◀┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅ ◉ Map callers          REPLY READY
            ┃                            subagent · Explore · haiku 5.5 · high
            ┃                            find every caller of parse()
            ┗────────────────────────── ○ grok·p3              IDLE
                                         herdr · grok · Grok 4.7 (xhigh)
                                         List the folders under plugins/

COMMS
lead → grok·p2  Review the diff for bugs  12s
```

## What it shows

- **Members**, one branch each: its name, a state badge, `kind · agent · model · effort`, and the task it was handed.
- **Current on the wires**: sparks run lead → member while it works, member → lead while its answer waits to be read, and surge for a few seconds after every message or handoff.
- **States**: `WORKING`, `REPLY READY` (finished, the lead has not read it yet), `NEEDS YOU` (an approval or question is open), `IDLE`, `DONE`, `FAILED`.
- **The lead**: model and effort in its box; `lead: waiting on <member>` and `⏳` while it blocks on one.
- **COMMS**: the last three handoffs and messages, `from → to`, first line and age.

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
| Subagents, teammates | `agent.spawn`, `$.agent.list()`, `session.send` / `session.receive`; model and effort from each model request (`turn.step`) | nothing |
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
