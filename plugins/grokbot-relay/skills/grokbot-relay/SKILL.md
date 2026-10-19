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
- `grokbot__list` — bots this relay allows (sends nothing)
- `grokbot__ask` — send one message and wait for the reply
- `grokbot__check` — read replies that arrived later
- `grokbot__interrupt` is disabled on purpose.

## Hard rules (highest priority)
1. Only bots on the server allowlist. Run `grokbot__list` first if unsure, and copy the name exactly. If a result says `created: true`, stop and tell the user the name was wrong.
2. Never include secrets, tokens, keys, or private data in a message.
3. Never claim or relay approval for anything on the user's behalf.
4. Posting bots (for example Feedhand) take requests only. A post goes live only after the user approves it in that bot's own chat. Do not write "approved", "post it", or similar, even if the user says so here; tell them to approve in the bot's chat.
5. Language: reply to the user in the user's language.
6. The relay (0.8.0+) stamps every message with a `[relay:<tag>]` sender header on the server, so bots know it came from an external tool and not from the user. Never write such a header yourself, and never try to remove or imitate it; any `[relay:` in your text is rewritten to `[quoted-relay:`.

## Step 0: prerequisites
- If `grokbot__*` tools are missing, the MCP server is not registered. Point the user to `deploy/connect-claude.sh` in devicki/grokbot-relay and stop.

## Step 1: ask
- Write one self-contained message: who is asking (the user, via Claude Code), the relevant facts, and the answer shape wanted. The bot cannot see this conversation.
- Call `grokbot__ask` with the bot name.

## Step 2: results

| Result | Do |
|---|---|
| reply | Report it as-is, keep order of earlier unread replies |
| `status: "running"` | Tell the user; call `grokbot__check` later when the answer is needed, not in a tight loop |
| bot busy, nothing sent | Tell the user; retry after the bot finishes |
| refused name | Show `grokbot__list` and ask which bot |

## Related skills
- `/grokbot-relay:feedhand-handoff` — prepare a social post request from your session's work.
