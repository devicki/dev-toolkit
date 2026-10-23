# dstack plugin changelog

## 0.1.0
- `herdr-grok-delegate`: delegate a task to grok in its own herdr tab (`grok:<name>`), wait for a `GROK_DONE` report file, then review the diff. Reuses a live grok by name, resends a dropped first prompt once, and reports failures as `DELEGATE_EXIT=<code>`.
