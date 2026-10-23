#!/usr/bin/env python3
"""Print the install path of the current pstack plugin.

Claude Code keeps old plugin versions in its cache, so globbing the cache finds stale copies.
installed_plugins.json names the live one.
Last line: PSTACK_EXIT=0 root=<path> version=<v>  |  PSTACK_EXIT=3 not-installed
"""
import json
import sys
from pathlib import Path

reg = Path.home() / ".claude/plugins/installed_plugins.json"
try:
    plugins = json.loads(reg.read_text(encoding="utf-8"))["plugins"]
except (OSError, json.JSONDecodeError, KeyError):
    plugins = {}

entries = [e for key, es in plugins.items() if key.split("@")[0] == "pstack" for e in es]
live = [e for e in entries if (Path(e.get("installPath", "")) / "skills/poteto-mode/SKILL.md").is_file()]
if not live:
    print("✘ pstack is not installed. Run: /plugin marketplace add cursor/plugins, then /plugin install pstack@cursor-plugins",
          file=sys.stderr)
    print("PSTACK_EXIT=3 not-installed")
    sys.exit(3)
e = max(live, key=lambda e: e.get("lastUpdated", ""))
print(f"PSTACK_EXIT=0 root={e['installPath']} version={e.get('version', '?')}")
