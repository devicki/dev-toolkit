# skill-spy

**English** · [한국어](README.ko.md)

A **mod** that shows a toast for each skill used in a turn, once the turn ends. It catches skills you type, like `/erd:design`, and skills Claude picks on its own from your request.

```
╭───────────────────────────╮
│ skill-spy                 │
│ ✦ erd:design ×2          │
╰───────────────────────────╯
╭───────────────────────────╮
│ skill-spy                 │
│ ✦ ponytail:ponytail      │
╰───────────────────────────╯
```

- One toast per skill. A skill used more than once shows a count, such as `×2`. A turn without skills shows nothing.
- Toasts appear in the top-right corner and stay for 60 seconds. Click one to close it, or hover over it to keep it open.

## Install

```
/plugin marketplace add devicki/dev-toolkit
/plugin install skill-spy@dev-toolkit
```

## Good to know

- A mod runs inside Claude Code with your user permissions. It has no sandbox.
- Under an organization-managed Claude Code (for example a company account), the `skill.prompt` event does not reach plugins you install yourself, so skill-spy does nothing there.
- A toast lasts at most 60 seconds and holds one line. Both are Claude Code limits.

## Development

```bash
claude plugin validate plugins/skill-spy
claude plugin test plugins/skill-spy
claude --plugin-dir plugins/skill-spy   # run with only this plugin loaded
```
