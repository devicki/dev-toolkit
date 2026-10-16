# grokbot-relay (Claude Code plugin)

Usage skill for asking your own Grok Bot agents (helper, botkit, 집순이, Feedhand, Watchless) from Claude Code through the grokbot MCP relay.

This plugin contains only the skill. The relay server, systemd deployment, and the Claude Code connect script live in **[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)**.

## Setup

1. Set up the relay: see [devicki/grokbot-relay](https://github.com/devicki/grokbot-relay) (한국어: [README.ko.md](https://github.com/devicki/grokbot-relay/blob/main/README.ko.md)).
2. Register the MCP server with [`deploy/connect-claude.sh`](https://github.com/devicki/grokbot-relay/blob/main/deploy/connect-claude.sh).
3. Install this plugin:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

Key rule: Feedhand is request-only. Posts go live only after you approve in the Feedhand chat; the relay never approves.
