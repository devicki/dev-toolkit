#!/usr/bin/env bash
# dstack plugin regression tests. Runs only in a temp folder, against a fake herdr (never the real session).
# Usage: plugins/dstack/tests/run.sh [-k <part of name>] [-v]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SCRIPTS="$(cd "$HERE/../shared/scripts" && pwd)"
FILTER="" VERBOSE=0
while [ $# -gt 0 ]; do case "$1" in -k) FILTER="$2"; shift 2;; -v) VERBOSE=1; shift;; *) exit 2;; esac; done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dstack-tests.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/tmp"; cp "$HERE/fake-herdr" "$WORK/bin/herdr"; chmod +x "$WORK/bin/herdr"
export PATH="$WORK/bin:$PATH" TMPDIR="$WORK/tmp" DSTACK_POLL=0.05 DSTACK_STALL=0.3 DSTACK_IDLE_GRACE=0.3
export HERDR_ENV=1 HERDR_PANE_ID=w1:p0 HERDR_WORKSPACE_ID=w1
PASS=0 FAIL=0 SKIP=0
t() { # t <name> <function> — run separately so set -e is not ignored inside an if condition; hangs are caught by a timeout
  local name="$1" fn="$2" rc=0 log="$WORK/log"
  [ -n "$FILTER" ] && [ "${name#*$FILTER}" = "$name" ] && return
  export FAKE_HERDR_STATE="$WORK/state-$fn.json" FAKE_MODE=ok
  ( set -e; cd "$WORK"; "$fn" ) >"$log" 2>&1 & local pid=$!
  ( sleep "${TEST_TIMEOUT:-60}"; kill -TERM $pid 2>/dev/null && echo "timed out" >> "$log" ) & local wd=$!
  wait $pid || rc=$?; kill $wd 2>/dev/null; wait $wd 2>/dev/null
  if [ $rc = 0 ]; then echo "  PASS  $name"; PASS=$((PASS+1)); else echo "  FAIL  $name"; FAIL=$((FAIL+1)); sed 's/^/        /' "$log" | tail -20; fi
  [ $VERBOSE = 1 ] && sed 's/^/        /' "$log"; return 0
}
assert_eq() { [ "$1" = "$2" ] || { echo "expected [$2] ≠ actual [$1] ${3:-}"; return 1; }; }
D() { python3 "$SCRIPTS/delegate.py" "$@" > "$WORK/out" 2>&1; local rc=$?; cat "$WORK/out"; return $rc; }
rc_of() { local rc=0; D "$@" >/dev/null || rc=$?; echo $rc; }
last() { tail -1 "$WORK/out"; }
state() { python3 -c "import json,sys;print(eval(sys.argv[1],{'s':json.load(open('$FAKE_HERDR_STATE'))}))" "$1"; }
echo "do it" > "$WORK/brief.md"

test_new_tab() {
  D run --name g1 --brief brief.md
  last | grep -q '^DELEGATE_EXIT=0 ok name=g1 tab=w1:t1 report=.*g1-.*\.report\.md$'
  assert_eq "$(state "s['tabs']['w1:t1']")" "grok:g1"
  assert_eq "$(state "s['agents']['g1']['argv']")" "['--always-approve']"
  grep -q 'GROK_DONE' "$WORK"/tmp/dstack-*/g1-*.task.md
  grep -q '^do it$' "$WORK"/tmp/dstack-*/g1-*.task.md
}
test_reuse_and_model() {
  D run --name g1 --brief brief.md --model grok-x --effort high >/dev/null
  assert_eq "$(state "s['agents']['g1']['argv']")" "['--always-approve', '-m', 'grok-x', '--reasoning-effort', 'high']"
  D run --name g1 --brief brief.md --effort low | grep -q "^= reusing grok 'g1' in tab w1:t1"
  grep -q 'ignored' "$WORK/out"
  assert_eq "$(state "s['agents']['g1']['argv']")" "['--always-approve', '-m', 'grok-x', '--reasoning-effort', 'high']"
  assert_eq "$(state "len(s['tabs'])")" 1
  assert_eq "$(rc_of run --name g2 --brief brief.md --effort max)" 2
}
test_busy() {
  D run --name g1 --brief brief.md >/dev/null
  python3 -c "import json;p='$FAKE_HERDR_STATE';s=json.load(open(p));s['agents']['g1']['agent_status']='working';json.dump(s,open(p,'w'))"
  assert_eq "$(rc_of run --name g1 --brief brief.md)" 3
}
test_not_grok() {
  echo '{"agents":{"c1":{"agent":"claude","pane_id":"w1:p9","tab_id":"w1:t9","agent_status":"idle"}},"tabs":{},"n":0,"log":[]}' > "$FAKE_HERDR_STATE"
  assert_eq "$(rc_of run --name c1 --brief brief.md)" 2
}
test_prompt_stalled_resends_once() {
  export FAKE_MODE=stall
  assert_eq "$(rc_of run --name g1 --brief brief.md)" 7
  assert_eq "$(state "s['log'].count('agent prompt')")" 2
}
test_idle_without_report() {
  export FAKE_MODE=noreport
  assert_eq "$(rc_of run --name g1 --brief brief.md)" 8
  last | grep -q 'idle-no-report'
}
test_timeout() {
  export FAKE_MODE=noreport DSTACK_IDLE_GRACE=100
  assert_eq "$(rc_of run --name g1 --brief brief.md --timeout 0.5)" 6
}
test_wait_after_timeout() {
  export FAKE_MODE=noreport DSTACK_IDLE_GRACE=100
  assert_eq "$(rc_of run --name g1 --brief brief.md --timeout 0.5)" 6
  local report; report="$(last | sed 's/.* report=//')"
  printf '# Report\n\nGROK_DONE\n' > "$report"
  assert_eq "$(rc_of wait --name g1 --report "$report")" 0
  assert_eq "$(state "s['log'].count('agent prompt')")" 1
}
test_wait_idle_and_gone() {
  D run --name g1 --brief brief.md >/dev/null
  assert_eq "$(rc_of wait --name g1 --report "$WORK/none.md")" 8
  assert_eq "$(rc_of wait --name nope --report "$WORK/none.md")" 4
}
test_guards() {
  assert_eq "$(HERDR_ENV= rc_of run --name g1 --brief brief.md)" 2
  assert_eq "$(rc_of run --name Bad --brief brief.md)" 2
  assert_eq "$(rc_of run --name g1 --brief missing.md)" 2
}
test_close() {
  D run --name g1 --brief brief.md >/dev/null
  assert_eq "$(rc_of close --name g1)" 0
  assert_eq "$(state "len(s['tabs'])")" 0
  assert_eq "$(rc_of close --name g1)" 4
}

fake_install() { # fake_install <home> <json entries for pstack@cursor-plugins>
  mkdir -p "$1/.claude/plugins"
  echo "{\"version\":2,\"plugins\":{\"pstack@cursor-plugins\":$2}}" > "$1/.claude/plugins/installed_plugins.json"
}
test_pstack_path_live_version() {
  local h="$WORK/home1"; mkdir -p "$h/old/skills/poteto-mode" "$h/new/skills/poteto-mode"
  touch "$h/old/skills/poteto-mode/SKILL.md" "$h/new/skills/poteto-mode/SKILL.md"
  fake_install "$h" "[{\"installPath\":\"$h/old\",\"version\":\"1\",\"lastUpdated\":\"2026-01\"},{\"installPath\":\"$h/new\",\"version\":\"2\",\"lastUpdated\":\"2026-10\"}]"
  assert_eq "$(HOME="$h" python3 "$SCRIPTS/pstack_path.py")" "PSTACK_EXIT=0 root=$h/new version=2"
}
test_pstack_path_missing() {
  local h="$WORK/home2" rc=0; mkdir -p "$h"
  HOME="$h" python3 "$SCRIPTS/pstack_path.py" > "$WORK/out" 2>&1 || rc=$?
  assert_eq "$rc" 3; grep -q '^PSTACK_EXIT=3 not-installed$' "$WORK/out"
  fake_install "$h" "[{\"installPath\":\"$h/gone\",\"version\":\"1\"}]"
  rc=0; HOME="$h" python3 "$SCRIPTS/pstack_path.py" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 3
}

t "pstack_path: picks the live install, not an old one" test_pstack_path_live_version
t "pstack_path: missing install or deleted folder" test_pstack_path_missing
t "run: new tab per grok, task carries the protocol" test_new_tab
t "run: reuse a live grok by name, pass --model and --effort" test_reuse_and_model
t "run: busy grok is not prompted" test_busy
t "run: refuses a non-grok agent" test_not_grok
t "run: dropped prompt is resent once, then stalled" test_prompt_stalled_resends_once
t "run: idle without a report" test_idle_without_report
t "run: timeout" test_timeout
t "wait: keeps waiting after a timeout, sends no new prompt" test_wait_after_timeout
t "wait: idle grok is idle-no-report, unknown name is gone" test_wait_idle_and_gone
t "guards: outside herdr, bad name, missing brief" test_guards
t "close: closes the tab, second close is gone" test_close
echo; echo "Result: PASS $PASS · FAIL $FAIL · SKIP $SKIP"; [ $FAIL = 0 ]
