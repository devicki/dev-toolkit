# dstack plugin changelog

## 0.2.2
- `herdr-grok-delegate`: reuse a live grok only when the new work strictly needs state in that session (a process it still runs), matching poteto-mode's fresh-subagent default. Fix rounds, follow-ups, and retries go to a fresh grok with the prior brief and report; close the tab once the result is reviewed. A user who asks to continue in the same tab still gets it.
- `herdr-grok-delegate`: a grok that stopped without a report (exit 8) is answered through a fresh grok, not the same session. After a timeout (exit 6), `delegate.py wait` keeps waiting on the same task without sending a new prompt.
- `delegate.py`: `--effort low|medium|high|xhigh` passes grok's `--reasoning-effort` when a grok starts; new `wait --name --report` subcommand.
- `devicki-mode`: O3 closes each tab once its result is reviewed, matching `herdr-grok-delegate`. O1 passes each grok role's model and effort, from the pstack slug with poteto-mode's effort tiering (`grok-4.7-xhigh-fast` → `--model grok-4.7 --effort xhigh`).

## 0.2.1
- `devicki-mode`: drop the fixed 4-tab cap. Open as many grok tabs as the playbook asks for, throttle only heavy local builds, tests, or port use, and never move a grok role to the Agent tool to go faster.

## 0.2.0
- `devicki-mode`: pstack's poteto-mode as the base, read from the live pstack install, with every grok role (code playbooks, how explorer, why investigators, reflect tooling, swarm workers, the grok seats of panels) run as a grok tab through `herdr-grok-delegate`. At most 4 grok tabs at once.
- `pstack_path.py`: finds the live pstack install from `installed_plugins.json` (the cache keeps old versions).
- `herdr-grok-delegate`: read the `DELEGATE_EXIT=` line, not the last line (Claude Code appends `[exited with code N]` to background output).

## 0.1.0
- `herdr-grok-delegate`: delegate a task to grok in its own herdr tab (`grok:<name>`), wait for a `GROK_DONE` report file, then review the diff. Reuses a live grok by name, resends a dropped first prompt once, and reports failures as `DELEGATE_EXIT=<code>`.
