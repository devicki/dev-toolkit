---
name: grokbot-relay
description: >
  Ask one of your own Grok Bot agents through the local grokbot MCP relay and bring back its reply. Output: the bot's reply or status.
  Triggers: "봇에게 물어봐", "그록봇한테 전해줘" / "ask my bot", "check my Grok Bot's reply".
  Not for: turning session work into a social post request (→ /grokbot-relay:feedhand-handoff), approving posts (only in the Feedhand chat).
---

# /grokbot-relay:grokbot-relay — consult your Grok Bot agents

> **One-line definition**: sends one self-contained question to an allowed Grok Bot agent with `grokbot__ask` and reports the reply. Setup lives in [devicki/grokbot-relay](https://github.com/devicki/grokbot-relay).

## Tools (from the grokbot MCP server)
Reach these only through the MCP tool `call_tool` (`mcp__grokbot__call_tool`), with the bot in `input.agent`:
- `grokbot__list` — bots this relay allows (sends nothing): `call_tool(toolName="grokbot__list")`
- `grokbot__ask` — send one message and wait for the reply: `call_tool(toolName="grokbot__ask", input={agent: "<bot name>", ...})`
- `grokbot__check` — read replies that arrived later: `call_tool(toolName="grokbot__check", input={agent: "<bot name>", wait_seconds?: number})`
- `grokbot__interrupt` is disabled on purpose.

The top-level MCP tools `mcp__grokbot__ask` and `mcp__grokbot__check` talk to the relay agent's own model session, not to a Grok Bot. Their sessionId is not a Grok Bot sessionId: a Grok Bot id passed to `mcp__grokbot__check` returns `Unknown session <id>`. Never use them for a Grok Bot conversation.

## Hard rules (highest priority)
1. Only bots on the server allowlist. Run `grokbot__list` first if unsure, and copy the name exactly. If a result says `created: true`, stop and tell the user the name was wrong.
2. Never include secrets, tokens, keys, or private data in a message.
3. Never claim or relay approval for anything on the user's behalf.
4. Posting bots (for example Feedhand) take requests only. A post goes live only after the user approves it in that bot's own chat. Do not write "approved", "post it", or similar, even if the user says so here; tell them to approve in the bot's chat.
5. Language: reply to the user in the user's language.
6. The relay adds a `[relay:claude-code]` header; don't write or remove it yourself.

## Step 0: prerequisites
- If `grokbot__*` tools are missing, the MCP server is not registered. Point the user to `deploy/connect-claude.sh` in devicki/grokbot-relay and stop.

## Step 1: ask
- Write one self-contained message: who is asking (the user, via Claude Code), the relevant facts, and the answer shape wanted. The bot cannot see this conversation.
- Call `grokbot__ask` through `call_tool` with the bot name.
- For work that takes a long time, ask the bot to start its final report with a clear marker (for example `FINAL REPORT`), so a later check can tell it from a progress note.

## Step 2: results
`finished` means the bot's reply for this turn arrived, not that the work it was given is done.

| Result | Do |
|---|---|
| reply | Report it as-is, keep order of earlier unread replies |
| `finished`, but the reply says the work continues (in any language: "continuing in the background", "about N hours", "will report when done") | The work is not done; don't report it as done. Take the expected finish time from the reply, schedule a `grokbot__check` through `call_tool` for then, and tell the user that time |
| `status: "running"` | Tell the user; call `grokbot__check` through `call_tool` later when the answer is needed, not in a tight loop |
| bot busy, nothing sent | Tell the user; retry after the bot finishes |
| refused name | Show `grokbot__list` and ask which bot |

## Related skills
- `/grokbot-relay:feedhand-handoff` — prepare a social post request from your session's work.
