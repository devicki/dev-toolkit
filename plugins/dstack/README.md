# dstack

**English** · [한국어](README.ko.md)

devicki's agent workflow on top of [pstack](https://github.com/cursor/plugins/tree/main/pstack): Claude leads, and Grok CLI sessions in [herdr](https://herdr.dev) tabs do delegated work.

## Skills

| Command | Purpose |
|---|---|
| `/dstack:devicki-mode` | Run a task in poteto-mode (pstack) with every grok role running as a grok tab in herdr. Type it directly; it never triggers on its own. |
| `/dstack:herdr-grok-delegate` | Hand a task to grok in its own herdr tab (`grok:<name>`), wait for its report, then review the diff. Also triggers on "delegate this to grok". |

## How a delegation runs

1. Claude writes a self-contained brief to a file.
2. `delegate.py` opens a tab `grok:<name>` and starts `grok --always-approve`, or reuses the live grok with that name.
3. grok reads the brief and writes a report ending in `GROK_DONE`. Claude is notified when the background run exits.
4. Claude reads the report, checks `git diff`, reruns the verification, and replies with its own verdict.

With [teamwire](../teamwire) installed, each grok also shows up in the Team pane.

## Requirements

- [pstack](https://github.com/cursor/plugins/tree/main/pstack) for `devicki-mode` (`/plugin marketplace add cursor/plugins`, `/plugin install pstack@cursor-plugins`)
- Claude Code running inside a herdr pane (`HERDR_ENV=1`)
- `grok` CLI on `PATH`

## Development

- Tests: `plugins/dstack/tests/run.sh` (uses a fake herdr; never touches the real session)
- Repository validation: `python3 scripts/validate.py`
- Authoring rules: [docs/skill-authoring.md](../../docs/skill-authoring.md)
