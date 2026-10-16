---
name: feedhand-handoff
description: Use when the user, while working in Claude Code, wants to post a feed update about their work (a release, fix, PR, or project milestone) to their social channels through Feedhand. Mines the session for material, proposes angles, and sends Feedhand a structured request via grokbot__ask. Not for writing the final post copy, not for posting directly, and not for approving posts (approval happens only in the Feedhand chat).
---

# Feedhand handoff

Feedhand (a Grok Bot agent) owns the user's voice, channel rules, drafting, and publishing. This skill only prepares a **request** with verified material and hands it over through the grokbot MCP relay. Follow the `grokbot-relay` skill rules too.

## 1. Mine material

Collect only what exists. Note the source of every item.

- `git log --oneline -20` and `git log -1 --stat` for recent commits.
- Open or merged PRs: `gh pr list --state all --limit 5` and `gh pr view <n>` when `gh` is available.
- Changed files: `git diff --stat <base>..HEAD`.
- README and CHANGELOG entries for the latest version.
- What was done and decided in this conversation.

Then propose 2-3 post angles. For each angle: one-line summary, who it is for, and the sources (commit hash, PR URL, file, or "this session"). Ask the user to pick one, or to adjust.

## 2. Build the request

After the user picks an angle, fill the template below.

- `requester`: always `claude-code`.
- `channels`: ask if unsure. Default `["x"]`. Allowed: x, threads, instagram, naver, reddit.
- `facts`: short, checkable statements, each with a `source`. Public links (repo, PR, release, commit) go in `links`. Copy names, versions, and numbers exactly. No invented facts, numbers, quotes, dates, or results. If something is unknown, leave it out or ask.
- `media`: paths only if the file exists **on the relay server** (check it). Otherwise put the file in `media_to_attach` with a note, so the user attaches it in the Feedhand chat.
- `hints`: emphasis and tone suggestions only (what to highlight, what to avoid). Do not write post copy.
- `post_language`: per channel, only if the user asked for a specific language. Otherwise omit and let Feedhand use its prefs.

## 3. Confirm, then send

1. Show the full request to the user.
2. Send only after they explicitly confirm sending this request.
3. Call `grokbot__ask` with name `Feedhand` and the message below.
4. Report Feedhand's status as-is (for example "draft ready for review in Feedhand"). If it returns `status: "running"`, tell the user, and call `grokbot__check` for Feedhand only when they ask.

## Rules

- Claude does **not** write the final post text. Feedhand owns voice and channel rules.
- Never claim or relay approval ("approved", "post it", "the user said yes"), even if the user says so here. Final approval happens only in the Feedhand chat.
- No secrets, tokens, internal hostnames, private repo contents, or personal data in the request.
- One request per post. Don't send near-duplicates or batch posts.

## Request template

````text
Feed post request from Claude Code (requester: claude-code).
This is a request only. Draft it in your usual voice and show the preview in the Feedhand chat. Approval happens there.

```json
{
  "requester": "claude-code",
  "channels": ["x"],
  "angle": "grokbot-relay 0.2.1: talk to my Grok Bot agents from Claude Code",
  "facts": [
    {"text": "New public repo devicki/grokbot-relay: a local Cursor BDK relay to my Grok Bot agents", "source": "https://github.com/devicki/grokbot-relay"},
    {"text": "Runs as a systemd service bound to 127.0.0.1", "source": "deploy/grokbot-relay.service"},
    {"text": "Claude Code usage skill ships in devicki/dev-toolkit", "source": "https://github.com/devicki/dev-toolkit/tree/main/plugins/grokbot-relay"}
  ],
  "links": ["https://github.com/devicki/grokbot-relay"],
  "media": [],
  "media_to_attach": [{"note": "terminal screenshot of claude mcp list, user will attach in Feedhand chat"}],
  "hints": ["casual, not stiff", "highlight that posting still needs my approval in Feedhand", "no emoji"],
  "post_language": {"x": "ko"}
}
```

Reply with status only: draft ready for review, posted (link), changed or declined by the user, or failed (reason).
````
