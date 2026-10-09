#!/usr/bin/env bash
# __NAME__ plugin regression tests. Runs only in a temp folder (never touches the real repo).
# Usage: plugins/__NAME__/tests/run.sh [-k <part of name>] [-v]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SCRIPTS="$(cd "$HERE/../shared/scripts" && pwd)"
FILTER="" VERBOSE=0
while [ $# -gt 0 ]; do case "$1" in -k) FILTER="$2"; shift 2;; -v) VERBOSE=1; shift;; *) exit 2;; esac; done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/__NAME__-tests.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"; git config --global user.email t@e.x; git config --global user.name t; git config --global commit.gpgsign false
PASS=0 FAIL=0 SKIP=0
t() { # t <name> <function> — run separately so set -e is not ignored inside an if condition; hangs (e.g. waiting on stdin) are caught by a timeout
  local name="$1" fn="$2" rc=0 log="$WORK/log"
  [ -n "$FILTER" ] && [ "${name#*$FILTER}" = "$name" ] && return
  ( set -e; cd "$WORK"; "$fn" ) >"$log" 2>&1 & local pid=$!
  ( sleep "${TEST_TIMEOUT:-120}"; kill -TERM $pid 2>/dev/null && echo "timed out" >> "$log" ) & local wd=$!
  wait $pid || rc=$?; kill $wd 2>/dev/null; wait $wd 2>/dev/null
  if [ $rc = 0 ]; then echo "  PASS  $name"; PASS=$((PASS+1)); else echo "  FAIL  $name"; FAIL=$((FAIL+1)); sed 's/^/        /' "$log" | tail -20; fi
  [ $VERBOSE = 1 ] && sed 's/^/        /' "$log"; return 0
}
assert_eq() { [ "$1" = "$2" ] || { echo "expected [$2] ≠ actual [$1] ${3:-}"; return 1; }; }

test_inject_block() {
  local f="$WORK/x.md"; echo A | bash "$SCRIPTS/inject-block.sh" "$f" k - >/dev/null
  echo A | bash "$SCRIPTS/inject-block.sh" "$f" k - | grep -q '^='
  assert_eq "$(grep -c 'k:start' "$f")" 1
}

t "inject-block idempotent" test_inject_block
echo; echo "Result: PASS $PASS · FAIL $FAIL · SKIP $SKIP"; [ $FAIL = 0 ]
