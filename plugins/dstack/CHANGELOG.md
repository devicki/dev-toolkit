# dstack plugin changelog

## 0.2.0
- `devicki-mode`: pstack's poteto-mode as the base, read from the live pstack install, with every grok role (code playbooks, how explorer, why investigators, reflect tooling, swarm workers, the grok seats of panels) run as a grok tab through `herdr-grok-delegate`. At most 4 grok tabs at once.
- `pstack_path.py`: finds the live pstack install from `installed_plugins.json` (the cache keeps old versions).
- `herdr-grok-delegate`: read the `DELEGATE_EXIT=` line, not the last line (Claude Code appends `[exited with code N]` to background output).

## 0.1.0
- `herdr-grok-delegate`: delegate a task to grok in its own herdr tab (`grok:<name>`), wait for a `GROK_DONE` report file, then review the diff. Reuses a live grok by name, resends a dropped first prompt once, and reports failures as `DELEGATE_EXIT=<code>`.
