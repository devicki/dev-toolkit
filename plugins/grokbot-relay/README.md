# grokbot-relay

Ask your own Grok Bot agents (helper, botkit, 집순이, Feedhand, Watchless) from Claude Code, Cursor, or a terminal through a **local** Cursor BDK relay (`cursor-grokbot-agents` extension). [한국어](README.ko.md)

> Status 0.1.0: scaffold checked against `@cursor/bdk` 0.2.25 docs. Items marked **VERIFY LOCALLY** are not tested yet.

## How it works

```
Claude Code / Cursor ──stdio──> bdk mcp ──HTTP (127.0.0.1)──> bdk serve (relay/) ──> your Grok Bot agents
```

- Allowlist: `relay/bot/extensions/grokbot/extension.ts`. `grokbot__interrupt` is removed by `tools/interrupt.ts`.
- Auth uses your own Cursor login on this machine. Nothing is stored in this repo.

## Install (local)

Requires Node.js 22+.

```bash
cd plugins/grokbot-relay/relay
npm install
npx bdk login                     # your Cursor account, in the browser
npx bdk validate
npx bdk dev                       # optional: try "who can you talk to?" in the playground

export GROKBOT_RELAY_TOKEN="$(openssl rand -hex 32)"   # keep it out of git
npx bdk serve --dir . --bearer-token "$GROKBOT_RELAY_TOKEN"
```

**VERIFY LOCALLY**
- the port and base URL `bdk serve` prints, and whether the MCP path is `/v1/mcp` or `/<slug>/v1/mcp`;
- that `serve` accepts `--bearer-token` (the CLI help lists it for serve) and listens on 127.0.0.1 only.

### Cursor

```bash
npx bdk mcp install --url http://127.0.0.1:<PORT> --bearer-token "$GROKBOT_RELAY_TOKEN" --name grokbot --print   # preview
npx bdk mcp install --url http://127.0.0.1:<PORT> --bearer-token "$GROKBOT_RELAY_TOKEN" --name grokbot
```

This writes the token into `~/.cursor/mcp.json`. Treat that file as a credential.

### Claude Code

```bash
export GROKBOT_RELAY_PORT=<PORT>
claude mcp add grokbot -- npx -y @cursor/bdk mcp --url "http://127.0.0.1:$GROKBOT_RELAY_PORT" --bearer-token "$GROKBOT_RELAY_TOKEN"
```

Or copy `.mcp.json.example` to your project's `.mcp.json`; it reads `GROKBOT_RELAY_PORT` and `GROKBOT_RELAY_TOKEN` from the environment. Then install this plugin for the `grokbot-relay` skill:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

## Safety

- Keep `serve` on loopback. Put an authenticating proxy in front before exposing it anywhere.
- `check` reads the bot conversation. Anyone who can reach the relay can read replies.
- All callers share one Grok Bot account and bot memory.
- **Feedhand is request-only.** Posts go live only after you approve in the Feedhand chat. The relay never approves.
- `bdk mcp` does not work with `--prod` hosted deployments. Run it locally.
