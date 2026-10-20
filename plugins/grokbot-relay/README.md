# grokbot-relay

**English** · [한국어](README.ko.md) · [日本語](README.ja.md) · [繁體中文](README.zh-TW.md)

A **skills** plugin for asking your own Grok Bot agents from Claude Code through the grokbot MCP relay, and for handing your session's work to Feedhand as a post request.

This plugin contains only skills. The relay server, systemd deployment, agent allowlist, and the Claude Code connect script live in **[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)**.

| Skill | Use |
|---|---|
| `/grokbot-relay:grokbot-relay` | Ask an allowed bot one self-contained question and bring back the reply (`grokbot__ask`, `check`, `list`) |
| `/grokbot-relay:feedhand-handoff` | Mine git log, PRs, changes and README/CHANGELOG, propose 2-3 post angles, and send Feedhand a structured request after you confirm. Server files in `media` (`{host, path, note}`) are fetched by Feedhand over SSH |

## Setup

1. Set up the relay and its allowlist: [devicki/grokbot-relay](https://github.com/devicki/grokbot-relay).
2. Register the MCP server with [`deploy/connect-claude.sh`](https://github.com/devicki/grokbot-relay/blob/main/deploy/connect-claude.sh).
3. Install this plugin:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

## Rules

- Claude never writes the final post. Feedhand owns voice and channel rules.
- Feedhand takes requests only. Posts go live only after you approve in the Feedhand chat; the relay never approves.
- No invented facts or numbers, and no secrets in requests.
- The relay adds a `[relay:claude-code]` header to every message; don't write or remove it yourself.
