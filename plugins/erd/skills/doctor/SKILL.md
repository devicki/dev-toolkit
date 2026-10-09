---
name: doctor
description: >
  Check/install ERD tools (tbls, @dbml/cli, Docker/psql). Output: tool status table.
  Triggers: "erd 도구 설치", "tbls 안 돼" / "install erd tools", "tbls not found".
  Not for: project setup (→ /erd:init), make erd failures (→ /erd:sync).
argument-hint: "[install]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh)"
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-tools.sh *)"
---

# /erd:doctor — check and install tools

> **One-line definition**: prepares the environment the ERD scripts need. Does not touch project files.

## Skill files (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `scripts/check-tools.sh` — check (read-only, last line `MISSING=<list>`)
- `scripts/install-tools.sh <tbls|dbml|all>` — **mandatory install helper** (installs for the current account without sudo; macOS prefers brew)
- `references/tbls-guide.md` — fix procedure for "Shared /tmp problem"

## Current state (automatic check result)

!`bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh`

## Hard rules
1. Install **only** via `install-tools.sh`. Do not improvise install commands (reason: the script handles missing global npm permissions, PATH, and per-architecture file names).
2. **Show the plan and get confirmation** before installing. If the `install` argument is given, tbls and dbml may be installed without confirmation.
3. For anything that needs sudo (Docker, psql, Node, libpam-tmpdir), **only show the commands**; do not run them.
4. Language (R8): reply in the user's language; text written into the project follows the unit's `ERD_LANG`.

## Procedure
1. Summarize the check result above as a ✅/⚠️/❌ table (keep explanations short).
2. If `MISSING=` is empty, say "Ready", point to the next step `/erd:init`, and stop.
3. Action per missing tool:

| Item | Action |
|---|---|
| `tbls`, `dbml2sql` | `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-tools.sh <tbls\|dbml\|all>` |
| `node` | Only explain how to install (e.g. Node 22 via nvm) — prerequisite for installing dbml |
| Docker / psql | Either one is enough. Docker (temporary DB created automatically) or psql + a development PostgreSQL server (`make erd PG=...`). Only show the install commands |
| `tbls-tmpdir` | `tbls-guide.md` "Shared /tmp problem": with admin rights, `libpam-tmpdir` + log in again; without, tell the user "`make erd` works because the script uses a private TMPDIR" |

4. After installing, run `check-tools.sh` again and confirm the result.
5. If a warning says `~/.local/bin` is not on PATH, give the per-shell command — bash/zsh: `export PATH="$HOME/.local/bin:$PATH"` (in the rc file), fish: `fish_add_path ~/.local/bin`.

## Error handling
| Situation | Action |
|---|---|
| install-tools.sh fails (network, npm error) | Report the last error in the output verbatim. Retry only once |
| Installed, but `check-tools.sh` still shows ❌ | PATH problem. Give the step 5 instructions |

## Checklist (before finishing)
- [ ] On re-check, `MISSING=` is empty, or the remaining items and reasons were reported
- [ ] Items needing sudo were only shown as commands

## Related skills
- `/erd:init` — next step: project setup
- `/erd:sync` — when doc generation fails (respond by `ERD_EXIT` code)
