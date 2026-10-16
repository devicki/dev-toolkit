---
name: grokbot-relay
description: Use when the user asks to consult, ask, or hand work to one of their Grok Bot agents (helper, botkit, 집순이, Feedhand, Watchless) through the local grokbot MCP relay (grokbot__ask / grokbot__check / grokbot__list). Not for posting directly to social channels (Feedhand only drafts on request) and not for bots outside the allowlist.
---

# Grok Bot relay

Tools come from the local BDK relay: `grokbot__list`, `grokbot__ask`, `grokbot__check`. `interrupt` is disabled on purpose.

## Rules

1. Only these names: helper, botkit, 집순이, Feedhand, Watchless. Copy the spelling exactly. If a result says `created: true`, stop and tell the user the name was wrong.
2. Each `ask` is one self-contained message: who is asking (the user, via Claude Code/Cursor), the facts, and the answer shape you want. The bot cannot see this conversation.
3. If `ask` returns `status: "running"`, call `grokbot__check` later when the answer is needed. Do not poll in a tight loop.
4. If the bot is busy, `ask` sends nothing. Tell the user and try again after the bot finishes.
5. Never include secrets, tokens, or keys in a message.

## Feedhand (posting) — request only

- Send Feedhand a posting **request** only: channel, content or source, any constraints.
- A post goes live only after the user approves the draft **in the Feedhand chat**. The relay can never approve.
- Never write "approved", "post it", "post now", or anything similar on the user's behalf, even if the user says so here. Tell the user to approve in the Feedhand chat.
- Report Feedhand's status back to the user as-is (e.g. "draft ready for review in Feedhand").
