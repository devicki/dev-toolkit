# dev-toolkit

**English** · [한국어](README.ko.md) · [日本語](README.ja.md) · [繁體中文](README.zh-TW.md)

A Claude Code plugin marketplace by devicki: plugins and mods for day-to-day development work.

| Plugin | Version | Type | What it does |
|---|---|---|---|
| [erd](plugins/erd) | 0.4.2 | Skills | Design, document and maintain project ERDs with DBML (source of truth) and tbls (docs, Mermaid ERD, lint). Monorepo aware. |
| [skill-spy](plugins/skill-spy) | 0.1.1 | Mod | When a turn ends, shows a toast for each skill that turn used. |
| [teamwire](plugins/teamwire) | 0.1.8 | Mod | A live wiring diagram of your agent team, with current flowing between the lead and each member. |
| [grokbot-relay](plugins/grokbot-relay) | 0.4.0 | Skills | Ask your Grok Bot agents from Claude Code through a local MCP relay, and hand session work to Feedhand as a post request. |

## Install

Inside Claude Code:

```
/plugin marketplace add devicki/dev-toolkit
/plugin install erd@dev-toolkit
/plugin install skill-spy@dev-toolkit
/plugin install teamwire@dev-toolkit
/plugin install grokbot-relay@dev-toolkit
```

From a shell:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install erd@dev-toolkit
claude plugin install skill-spy@dev-toolkit
claude plugin install teamwire@dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

To update, run `/plugin marketplace update dev-toolkit`, then `/reload-plugins` in any open session.

## skill-spy: see which skills ran

Skills often load without you noticing: Claude picks one from your request, or a subagent preloads one. skill-spy is a **mod** (a plugin with only a hooks module, no skills). When a turn ends, it shows one toast in the top-right corner for each skill that turn used:

![skill-spy toasts](docs/images/skill-spy.png)

- **It catches every way a skill starts:** typing `/name`, Claude calling the Skill tool on its own, and a subagent preloading a skill.
- **Repeats are counted:** if the same skill ran twice in one turn, the toast shows `×2`. A turn without skills shows nothing.
- **The toast stays for 60 seconds:** click it to close it sooner, or hover over it to keep it open.

How it works: the `skill.prompt` hook counts each skill as it loads. The `turn.complete` hook then shows the toasts and resets the count for the next turn. The whole mod is [`hooks/register.ts`](plugins/skill-spy/hooks/register.ts), about 30 lines.

Limits:

- Under an **organization-managed Claude Code** (for example a company account), `skill.prompt` does not reach plugins you install yourself, so skill-spy stays silent.
- The toast lasts at most 60 seconds and holds a single line. Both limits come from Claude Code.
- A mod runs inside Claude Code with your user permissions. It has no sandbox.

More: [plugins/skill-spy/README.md](plugins/skill-spy/README.md).

## teamwire: watch your agent team work

When the lead session hands out work, a `Team` pane opens with a wiring diagram: the lead on the left and one branch per member. Each member shows its state, `kind · agent · model · effort` and the task it was handed. Sparks run out to a member while it works and back to the lead while its answer waits to be read.

![teamwire pane](docs/images/teamwire.png)

- Members: subagents, agent-teams teammates, other Claude sessions, and, with [herdr](https://herdr.dev), CLI agents such as codex and grok in herdr panes.
- Each kind has its own wire (`┅` subagent, `═` teammate, `━` herdr, `┉` session).
- A dashboard with the lead's context window, an ACTIVITY log, FOCUS on one member, and alerts when a member needs you or the team stands down.
- It uses no tokens: the hooks only observe events and draw the pane.

More: [plugins/teamwire/README.md](plugins/teamwire/README.md).

## grokbot-relay: talk to your Grok Bot agents

Two skills that use the grokbot MCP relay from [devicki/grokbot-relay](https://github.com/devicki/grokbot-relay) (a local Cursor BDK server; set it up first).

| Command | Use |
|---|---|
| `/grokbot-relay:grokbot-relay` | Ask an allowed bot one question and bring back the reply |
| `/grokbot-relay:feedhand-handoff` | Turn this session's work (git log, PRs, changes) into a post request for Feedhand, sent only after you confirm |

Claude never writes the final post or approves it: Feedhand drafts, and you approve in the Feedhand chat.

More: [plugins/grokbot-relay/README.md](plugins/grokbot-relay/README.md).

## erd: schema design to docs

Write the schema in DBML and generate per-module docs, a Mermaid ERD and lint results with tbls, all kept in Git. If a project already has a migration tool (Alembic, Prisma, Flyway, …), that tool stays the source of truth and the docs are derived from it.

| Command | Use |
|---|---|
| `/erd:doctor` | Check and install tbls, @dbml/cli and Docker/psql (asks before installing) |
| `/erd:init` | Scan the project, choose the schema source, install templates |
| `/erd:import` | Build DBML from source code, ORM models or migrations, ERD/ADR docs, or a live DB |
| `/erd:design` | Design or change the schema interactively |
| `/erd:review` | Review the schema against backend and frontend code; findings ranked by severity |
| `/erd:sync` | Refresh docs, check drift, hook into migration generation, add CI checks |

![/erd:doctor](docs/images/erd-doctor.png)

A plain request works too, for example "design the tables for orders". Skills reply in your language. Files written into the project follow `ERD_LANG=ko|en` in the unit's `erd.env`.

More: [plugins/erd/README.md](plugins/erd/README.md) (Korean, with an English summary).

## Developing plugins

```bash
scripts/new-plugin.sh <name> --skill <first-skill> --desc "<description>"  # scaffold + add to marketplace
python3 scripts/validate.py [--base origin/main]                           # repo structure check (also runs in CI)
claude plugin validate .                                                    # official manifest check
plugins/<name>/tests/run.sh                                                 # plugin regression tests (erd)
claude plugin test plugins/<name>                                           # mod tests (hooks module)
claude --plugin-dir plugins/<name>                                          # run Claude Code with only this plugin loaded
```

```
.claude-plugin/marketplace.json   # marketplace catalog
plugins/<name>/                   # one folder per plugin, each with README.md and CHANGELOG.md
docs/skill-authoring.md           # skill writing rules
templates/plugin/                 # scaffold used by new-plugin.sh
scripts/                          # validate.py, new-plugin.sh
```

CI (`.github/workflows/validate.yml`) runs `validate.py`, `claude plugin validate .`, the skill-spy and teamwire tests, and the erd tests against Postgres.

Each plugin's changes are in its own `CHANGELOG.md`. Marketplace-level changes are in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
