#!/usr/bin/env python3
"""Delegate one task to a Grok CLI agent in its own herdr tab and wait for its report file.

Usage:
  delegate.py run --name NAME --brief FILE [--cwd DIR] [--model M] [--effort E] [--timeout SEC]
  delegate.py wait --name NAME --report FILE [--timeout SEC]
  delegate.py close --name NAME

Completion is the report file ending in GROK_DONE, not the pane state:
Grok can look idle while its own subagents still run.
The last stdout line is machine-readable: DELEGATE_EXIT=<code> <reason> [key=value ...].
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

EXIT = {"ok": 0, "usage": 2, "busy": 3, "gone": 4, "blocked": 5, "timeout": 6, "stalled": 7, "idle-no-report": 8}
DONE = "GROK_DONE"
EFFORTS = ("low", "medium", "high", "xhigh")  # what grok --reasoning-effort accepts
NAME_RE = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
POLL = float(os.environ.get("DSTACK_POLL", "5"))
STALL = float(os.environ.get("DSTACK_STALL", "90"))
IDLE_GRACE = float(os.environ.get("DSTACK_IDLE_GRACE", "180"))

PROTOCOL = """

---
Delegation protocol (from the lead session, follow it exactly):
- You are working for a lead agent that will review your diff. Stay inside the task above.
- Do not commit, push, or open a PR unless the task above says so.
- When finished, write your report to {report}. Include what you changed (files), how you verified it
  (commands and their real output), and open issues or anything you could not do.
- Write the report last. Its final line must be exactly {done}.
- If you cannot continue, still write the report with the reason, ending in {done}.
"""


def finish(reason: str, **kv) -> None:
    extra = " ".join(f"{k}={v}" for k, v in kv.items())
    print(f"DELEGATE_EXIT={EXIT[reason]} {reason} {extra}".rstrip())
    sys.exit(EXIT[reason])


def herdr_call(*args: str) -> tuple[dict | None, str | None]:
    """(result, error code). herdr prints {"result": ...} on stdout and {"error": {"code": ...}} on stderr."""
    p = subprocess.run(["herdr", *args], capture_output=True, text=True)
    try:
        out = json.loads(p.stdout if p.returncode == 0 else p.stderr or p.stdout)
    except json.JSONDecodeError:
        return None, "unparsable"
    if p.returncode == 0 and "result" in out:
        return out["result"], None
    return None, out.get("error", {}).get("code", "unknown")


def herdr(*args: str) -> dict | None:
    return herdr_call(*args)[0]


def agent(name: str) -> dict | None:
    r = herdr("agent", "get", name)
    return r and r.get("agent")


def pane_tail(name: str, lines: int = 25) -> str:
    p = subprocess.run(["herdr", "agent", "read", name, "--source", "recent-unwrapped", "--lines", str(lines)],
                       capture_output=True, text=True)
    return p.stdout.strip()


def start(name: str, cwd: str, model: str | None, effort: str | None) -> dict:
    # One tab per grok: several split panes in the lead's tab get too small to watch.
    r = herdr("tab", "create", "--workspace", os.environ["HERDR_WORKSPACE_ID"], "--cwd", cwd,
              "--label", f"grok:{name}", "--no-focus")
    if not r:
        print("✘ tab create failed", file=sys.stderr)
        finish("gone")
    pane, tab = r["root_pane"]["pane_id"], r["tab"]["tab_id"]
    grok_args = ["--always-approve"] + (["-m", model] if model else []) + (["--reasoning-effort", effort] if effort else [])
    if not herdr("agent", "start", name, "--kind", "grok", "--pane", pane, "--", *grok_args):
        print(f"✘ grok did not become ready in {pane}", file=sys.stderr)
        finish("stalled", tab=tab, pane=pane)
    print(f"+ started grok '{name}' in tab {tab} (grok:{name})")
    return agent(name) or {"pane_id": pane, "tab_id": tab}


def submit(name: str, text: str) -> str | None:
    """Send the prompt; None once grok has started on it, else the herdr error code."""
    for attempt in (1, 2):
        # --wait makes herdr confirm activity within 5s. A prompt sent right after start can be dropped
        # (seen in testing), and herdr reports that as agent_prompt_stalled, so one resend is safe.
        _, err = herdr_call("agent", "prompt", name, text, "--wait", "--timeout", "15000")
        if err in (None, "timeout"):
            return None
        if err != "agent_prompt_stalled" or attempt == 2:
            return err
        time.sleep(3)


def report_done(path: Path) -> bool:
    try:
        lines = [l for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]
    except OSError:
        return False
    return bool(lines) and lines[-1].strip() == DONE


def run(a: argparse.Namespace) -> None:
    brief = Path(a.brief).resolve()
    if not brief.is_file():
        print(f"✘ brief not found: {brief}", file=sys.stderr)
        finish("usage")
    cwd = str(Path(a.cwd or os.getcwd()).resolve())

    cur = agent(a.name)
    if cur and cur.get("agent") != "grok":
        print(f"✘ '{a.name}' is a {cur.get('agent')} agent, not grok", file=sys.stderr)
        finish("usage")
    if cur and cur.get("agent_status") in ("working", "blocked"):
        finish("busy", name=a.name, tab=cur.get("tab_id"), status=cur["agent_status"])
    if cur:
        print(f"= reusing grok '{a.name}' in tab {cur.get('tab_id')}")
        if a.model or a.effort:
            print("  --model/--effort apply only when a grok starts; ignored")
    else:
        cur = start(a.name, cwd, a.model, a.effort)
    pane, tab = cur["pane_id"], cur.get("tab_id")

    state = Path(os.environ.get("TMPDIR", "/tmp")) / f"dstack-{os.getuid()}"
    state.mkdir(mode=0o700, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    report = state / f"{a.name}-{stamp}.report.md"
    task = state / f"{a.name}-{stamp}.task.md"
    task.write_text(brief.read_text(encoding="utf-8") + PROTOCOL.format(report=report, done=DONE), encoding="utf-8")

    err = submit(a.name, f"Read {task} and do exactly what it says.")
    if err:
        print(pane_tail(a.name))
        print(f"✘ prompt not taken by '{a.name}': {err}", file=sys.stderr)
        finish("blocked" if err == "agent_blocked" else "stalled", name=a.name, tab=tab)
    print(f"~ task sent: {task}")
    watch(a.name, tab, report, a.timeout, seen_work=False)


def wait(a: argparse.Namespace) -> None:
    cur = agent(a.name)
    if not cur:
        finish("gone", name=a.name)
    # The task was already taken, so an idle grok means it stopped, not that the prompt stalled.
    watch(a.name, cur.get("tab_id"), Path(a.report), a.timeout, seen_work=True)


def watch(name: str, tab: str | None, report: Path, timeout: float, seen_work: bool) -> None:
    t0 = time.time()
    idle_since = None
    while True:
        if report_done(report):
            finish("ok", name=name, tab=tab, report=report)
        now = time.time()
        if now - t0 > timeout:
            finish("timeout", name=name, tab=tab, report=report)
        cur = agent(name)
        if not cur:
            finish("gone", name=name, tab=tab)
        status = cur.get("agent_status")
        if status == "blocked":
            print(pane_tail(name))
            finish("blocked", name=name, tab=tab)
        if status == "working":
            seen_work, idle_since = True, None
        elif not seen_work and now - t0 > STALL:
            print(pane_tail(name))
            finish("stalled", name=name, tab=tab)
        elif seen_work:
            idle_since = idle_since or now
            if now - idle_since > IDLE_GRACE:
                print(pane_tail(name))
                finish("idle-no-report", name=name, tab=tab, report=report)
        time.sleep(POLL)


def close(a: argparse.Namespace) -> None:
    cur = agent(a.name)
    if not cur:
        finish("gone", name=a.name)
    tab = cur["tab_id"]
    if herdr_call("tab", "close", tab)[1]:
        print(f"✘ could not close tab {tab}", file=sys.stderr)
        finish("blocked", name=a.name, tab=tab)
    print(f"- closed tab {tab}")
    finish("ok", name=a.name, tab=tab)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--name", required=True)
    r.add_argument("--brief", required=True)
    r.add_argument("--cwd")
    r.add_argument("--model")
    r.add_argument("--effort", choices=EFFORTS)
    r.add_argument("--timeout", type=float, default=3600)
    w = sub.add_parser("wait")
    w.add_argument("--name", required=True)
    w.add_argument("--report", required=True)
    w.add_argument("--timeout", type=float, default=3600)
    c = sub.add_parser("close")
    c.add_argument("--name", required=True)
    a = ap.parse_args()

    if os.environ.get("HERDR_ENV") != "1" or not os.environ.get("HERDR_PANE_ID"):
        print("✘ not running inside a herdr pane (HERDR_ENV=1 required)", file=sys.stderr)
        finish("usage")
    if not NAME_RE.match(a.name):
        print("✘ name must match [a-z][a-z0-9_-]{0,31}", file=sys.stderr)
        finish("usage")
    {"run": run, "wait": wait, "close": close}[a.cmd](a)


if __name__ == "__main__":
    main()
