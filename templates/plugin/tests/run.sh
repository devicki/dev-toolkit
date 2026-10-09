#!/usr/bin/env bash
# __NAME__ 플러그인 회귀 테스트. 임시 폴더에서만 실행한다 (실제 레포를 건드리지 않음).
# 사용법: plugins/__NAME__/tests/run.sh [-k <이름 일부>] [-v]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SCRIPTS="$(cd "$HERE/../shared/scripts" && pwd)"
FILTER="" VERBOSE=0
while [ $# -gt 0 ]; do case "$1" in -k) FILTER="$2"; shift 2;; -v) VERBOSE=1; shift;; *) exit 2;; esac; done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/__NAME__-tests.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"; git config --global user.email t@e.x; git config --global user.name t; git config --global commit.gpgsign false
PASS=0 FAIL=0 SKIP=0
t() { # t <이름> <함수> — set -e 가 if 조건에서 무시되지 않도록 따로 실행, stdin 대기 등 멈춤은 timeout 으로 감시
  local name="$1" fn="$2" rc=0 log="$WORK/log"
  [ -n "$FILTER" ] && [ "${name#*$FILTER}" = "$name" ] && return
  ( set -e; cd "$WORK"; "$fn" ) >"$log" 2>&1 & local pid=$!
  ( sleep "${TEST_TIMEOUT:-120}"; kill -TERM $pid 2>/dev/null && echo "시간 초과" >> "$log" ) & local wd=$!
  wait $pid || rc=$?; kill $wd 2>/dev/null; wait $wd 2>/dev/null
  if [ $rc = 0 ]; then echo "  PASS  $name"; PASS=$((PASS+1)); else echo "  FAIL  $name"; FAIL=$((FAIL+1)); sed 's/^/        /' "$log" | tail -20; fi
  [ $VERBOSE = 1 ] && sed 's/^/        /' "$log"; return 0
}
assert_eq() { [ "$1" = "$2" ] || { echo "기대 [$2] ≠ 실제 [$1] ${3:-}"; return 1; }; }

test_inject_block() {
  local f="$WORK/x.md"; echo A | bash "$SCRIPTS/inject-block.sh" "$f" k - >/dev/null
  echo A | bash "$SCRIPTS/inject-block.sh" "$f" k - | grep -q '^='
  assert_eq "$(grep -c 'k:start' "$f")" 1
}

t "inject-block 멱등" test_inject_block
echo; echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"; [ $FAIL = 0 ]
