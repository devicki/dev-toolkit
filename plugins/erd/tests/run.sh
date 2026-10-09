#!/usr/bin/env bash
# erd 플러그인 회귀 테스트. 모든 시나리오는 임시 폴더의 샘플 프로젝트에서 실행한다 (실제 레포를 건드리지 않음).
#
# 사용법: plugins/erd/tests/run.sh [-k <이름 일부>] [-v]
#   임시 DB: PG=postgres://user:pass@host:5432 (개발용 서버, erd_doc_* DB 를 만들고 지움) 또는 Docker.
#            둘 다 없으면 DB 가 필요한 테스트는 SKIP.
#   필요 도구: bash, git, tbls, dbml2sql (없으면 해당 테스트 SKIP), psql (migrations 시나리오)
# 종료 코드: 실패가 하나라도 있으면 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SHARED="$(cd "$HERE/../shared" && pwd)"
SCRIPTS="$SHARED/scripts"
FILTER="" VERBOSE=0
while [ $# -gt 0 ]; do case "$1" in -k) FILTER="$2"; shift 2;; -v) VERBOSE=1; shift;; *) echo "알 수 없는 인자: $1"; exit 2;; esac; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/erd-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"   # 사용자 git 설정(서명 등)의 영향을 받지 않게
git config --global user.email test@example.com; git config --global user.name erd-test
git config --global init.defaultBranch main; git config --global commit.gpgsign false

PASS=0 FAIL=0 SKIP=0 FAILED=""
have() { command -v "$1" >/dev/null 2>&1; }
DB_OK=0
if [ -n "${PG:-}" ] && have psql && psql "$PG/postgres" -qc 'select 1' >/dev/null 2>&1; then DB_OK=1; DB_MODE="PG=$PG"
elif have docker && docker info >/dev/null 2>&1; then DB_OK=1; DB_MODE="docker"; unset PG
fi
TOOLS_OK=0; have tbls && have dbml2sql && TOOLS_OK=1

# ── 헬퍼 ─────────────────────────────────────────────
CUR=""
t() { # t <이름> <함수> [needs: db|tools]
  local name="$1" fn="$2" need="${3:-}"
  [ -n "$FILTER" ] && [ "${name#*$FILTER}" = "$name" ] && return
  if [ "$need" = db ] && { [ $DB_OK = 0 ] || [ $TOOLS_OK = 0 ]; }; then echo "  SKIP  $name (임시 DB 또는 tbls/dbml2sql 없음)"; SKIP=$((SKIP+1)); return; fi
  if [ "$need" = tools ] && [ $TOOLS_OK = 0 ]; then echo "  SKIP  $name (tbls/dbml2sql 없음)"; SKIP=$((SKIP+1)); return; fi
  CUR="$name"; local log="$WORK/log.$PASS.$FAIL"
  local rc=0
  # if 조건 안에서는 set -e 가 무시되므로 따로 실행. stdin 은 닫지 않는다(스크립트가 stdin 을 기다리는 버그를 잡기 위해 timeout 으로 감시)
  ( set -e; cd "$WORK"; "$fn" ) >"$log" 2>&1 & local pid=$!
  ( sleep "${ERD_TEST_TIMEOUT:-180}"; kill -TERM $pid 2>/dev/null && echo "시간 초과(${ERD_TEST_TIMEOUT:-180}s) — stdin 대기 등 멈춤 의심" >> "$log" ) & local wd=$!
  wait $pid || rc=$?
  kill $wd 2>/dev/null; wait $wd 2>/dev/null
  if [ $rc = 0 ]; then echo "  PASS  $name"; PASS=$((PASS+1))
  else echo "  FAIL  $name"; FAIL=$((FAIL+1)); FAILED="$FAILED\n  - $name"; sed 's/^/        /' "$log" | tail -25; fi
  [ $VERBOSE = 1 ] && sed 's/^/        /' "$log"
  return 0
}
assert_eq() { [ "$1" = "$2" ] || { echo "기대값 [$2] ≠ 실제값 [$1] ${3:-}"; return 1; }; }
assert_has() { printf '%s' "$1" | grep -q -- "$2" || { echo "출력에 [$2] 없음 ${3:-}"; printf '%s\n' "$1" | tail -10; return 1; }; }
rc_of() { set +e; "$@" >"$WORK/out" 2>&1; local r=$?; set -e; echo $r; }
out() { cat "$WORK/out"; }

new_repo() { # new_repo <이름> → 그 폴더로 이동한 서브셸에서 쓰도록 경로 출력
  local d="$WORK/$1"; rm -rf "$d"; mkdir -p "$d"; (cd "$d" && git init -q); echo "$d"
}
install_unit() { bash "$SCRIPTS/install-templates.sh" "$@" >/dev/null; }
dbml_module() { # dbml_module <단위> <모듈> <테이블...>
  local u="$1" m="$2"; shift 2; local f="$u/db/modules/$m.dbml"
  : > "$f"; for tb in "$@"; do printf "Table %s {\n  id bigint [pk, note: 'PK']\n  Note: '%s'\n}\n" "$tb" "$tb" >> "$f"; done
  rm -f "$u/db/modules/_example.dbml"
  grep -q "modules/$m'" "$u/db/schema.dbml" || echo "use * from './modules/$m'" >> "$u/db/schema.dbml"
}

# ── 시나리오 ─────────────────────────────────────────
test_inject_block_idempotent() {
  local f="$WORK/ib/CLAUDE.md"; mkdir -p "$WORK/ib"; printf '# P\n' > "$f"
  echo A | bash "$SCRIPTS/inject-block.sh" "$f" x - | grep -q '^+'
  echo A | bash "$SCRIPTS/inject-block.sh" "$f" x - | grep -q '^='
  echo 'B \n $HOME `x`' | bash "$SCRIPTS/inject-block.sh" "$f" x - | grep -q '^~'
  assert_eq "$(grep -c 'x:start' "$f")" 1
  grep -qF 'B \n $HOME `x`' "$f"
}

test_install_templates_single_idempotent() {
  local r; r="$(new_repo single)"; cd "$r"; printf 'all:\n\techo hi\n' > Makefile
  bash "$SCRIPTS/install-templates.sh" --unit . --name shop --dialect postgres --source dbml > o1
  assert_has "$(cat o1)" "INSTALL_RESULT=ok"
  for f in scripts/erd-doc.sh scripts/erd-changed.sh erd.mk erd.env .tbls.yml db/schema.dbml docs/ERD_GUIDE.md CLAUDE.md; do [ -e "$f" ] || { echo "없음: $f"; return 1; }; done
  [ -x scripts/erd-doc.sh ]
  grep -q 'Table example_items' db/modules/_example.dbml   # 회귀: 치환 없는 템플릿이 sed 로 처리되며 stdin 을 기다리던 버그
  bash "$SCRIPTS/install-templates.sh" --unit . --name shop --dialect postgres --source dbml > o2
  ! grep -Eq '^[+~!]' o2 || { echo "재실행에서 변경 발생"; cat o2; return 1; }
  assert_eq "$(grep -c 'include erd.mk' Makefile)" 1
  assert_eq "$(grep -c 'erd:unit:start' CLAUDE.md)" 1
}

test_install_templates_quoting_and_agents_md() {
  local r; r="$(new_repo q)"; cd "$r"; mkdir -p apps/pay; printf '# pay\n' > apps/pay/AGENTS.md
  bash "$SCRIPTS/install-templates.sh" --unit apps/pay --name pay --dialect mysql --source migrations \
    --migrate-cmd "for f in m/*.sql; do echo 'it''s' \"\$f\" | grep -c x & done" >/dev/null
  ( set -a; . apps/pay/erd.env; [ "$ERD_MIGRATE_CMD" = "for f in m/*.sql; do echo 'it''s' \"\$f\" | grep -c x & done" ] )
  grep -q 'erd:unit:start' apps/pay/AGENTS.md; [ ! -e apps/pay/CLAUDE.md ]
  grep -q '_prisma_migrations' apps/pay/.tbls.yml
  assert_eq "$(rc_of bash "$SCRIPTS/install-templates.sh" --unit x --name 'bad name' --dialect postgres --source dbml)" 2
}

test_single_doc_check_drift() {
  local r; r="$(new_repo s1)"; cd "$r"
  install_unit --unit . --name s1 --dialect postgres --source dbml
  dbml_module . core users orders
  assert_eq "$(rc_of make erd)" 0 "$(out)"
  [ -f docs/schema/README.md ] && [ -f docs/schema/schema.json ]
  assert_eq "$(rc_of make erd-check)" 0 "$(out)"
  dbml_module . core users orders items
  assert_eq "$(rc_of scripts/erd-doc.sh check)" 1
  assert_has "$(out)" "ERD_EXIT=1 diff"
}

test_exit_codes() {
  local r; r="$(new_repo ec)"; cd "$r"
  install_unit --unit . --name ec --dialect postgres --source dbml
  dbml_module . core a
  assert_eq "$(rc_of scripts/erd-doc.sh nope)" 2
  assert_eq "$(rc_of env PATH=/usr/bin:/bin bash scripts/erd-doc.sh doc)" 3 "$(out)"
  cp db/modules/core.dbml core.bak; printf 'Table bad {\n id bigint [pk\n}\n' >> db/modules/core.dbml
  assert_eq "$(rc_of scripts/erd-doc.sh doc)" 4; [ ! -e dbml-error.log ]; cp core.bak db/modules/core.dbml
  printf "Table c {\n  id notatype [pk, note: 'PK']\n  Note: 'c'\n}\n" >> db/modules/core.dbml
  assert_eq "$(rc_of scripts/erd-doc.sh doc)" 6; cp core.bak db/modules/core.dbml
  sed -i.b 's/^ERD_SOURCE=dbml/ERD_SOURCE=migrations/; s/^ERD_MIGRATE_CMD=.*/ERD_MIGRATE_CMD=false/' erd.env
  assert_eq "$(rc_of scripts/erd-doc.sh doc)" 7; mv erd.env.b erd.env
  echo "viewpoints: [{name: x, desc: x, tables: [no_such_table]}]" >> .tbls.yml
  assert_eq "$(rc_of scripts/erd-doc.sh doc)" 8
}

test_exit_code_tempdb() {
  local r; r="$(new_repo et)"; cd "$r"
  install_unit --unit . --name et --dialect postgres --source dbml; dbml_module . core a
  assert_eq "$(rc_of env PG=postgres://nobody@127.0.0.1:1 scripts/erd-doc.sh doc)" 5
}

test_monorepo_units() {
  have psql || { echo "psql 필요"; return 1; }
  local r; r="$(new_repo mono)"; cd "$r"; mkdir -p apps/api apps/pay/migrations apps/web
  echo '{"workspaces":["apps/*"]}' > package.json; echo '{"dependencies":{"react":"18"}}' > apps/web/package.json
  install_unit --unit apps/api --name api --dialect postgres --source dbml --related apps/web
  dbml_module apps/api user users
  printf "CREATE TABLE invoices (id serial primary key);\nCOMMENT ON TABLE invoices IS '청구';COMMENT ON COLUMN invoices.id IS 'PK';\n" > apps/pay/migrations/001.sql
  install_unit --unit apps/pay --name pay --dialect postgres --source migrations \
    --migrate-cmd 'for f in migrations/*.sql; do psql "$DATABASE_URL" -q -v ON_ERROR_STOP=1 -f "$f"; done'
  assert_eq "$(rc_of make erd)" 0 "$(out)"
  assert_has "$(out)" "ERD 단위: apps/api"; assert_has "$(out)" "ERD 단위: apps/pay"
  [ -f apps/pay/db/schema.generated.dbml ]
  assert_eq "$(rc_of scripts/erd-doc.sh doc)" 2; assert_has "$(out)" "ERD_EXIT=2 usage"
  assert_eq "$(cd apps/pay/migrations && rc_of ../../../scripts/erd-doc.sh check)" 0 "$(out)"
  assert_has "$(out)" "ERD 단위: apps/pay"
  assert_has "$(make erd-list)" "apps/pay"
  grep -q 'erd:units:start' CLAUDE.md; grep -q 'apps/pay' CLAUDE.md
  local j; j="$(bash "$SCRIPTS/find-units.sh" --json)"
  assert_has "$j" '"monorepo":true'; assert_has "$j" '"frontends":\["apps/web"\]'
  assert_has "$(cd apps/api && bash "$SCRIPTS/find-units.sh" --json)" '"target":"apps/api"'
}

test_changed_units() {
  local r; r="$(new_repo chg)"; cd "$r"; mkdir -p apps/api apps/pay apps/web/src
  install_unit --unit apps/api --name api --dialect postgres --source dbml --related apps/web
  install_unit --unit apps/pay --name pay --dialect postgres --source dbml
  dbml_module apps/api user users; dbml_module apps/pay bill invoices; echo x > apps/web/src/a.tsx
  git add -A; git commit -qm init; git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -qb feat
  dbml_module apps/api user users grades; git commit -qam grade
  echo y >> apps/web/src/a.tsx
  assert_eq "$(scripts/erd-changed.sh --names)" "apps/api"
  assert_has "$(scripts/erd-changed.sh)" "related  apps/web/src/a.tsx"
  assert_has "$(scripts/erd-changed.sh --json)" '"unit":"apps/api"'
  assert_eq "$(rc_of scripts/erd-changed.sh --base nope)" 2
}

test_changed_check_target() {
  local r; r="$(new_repo chk)"; cd "$r"; mkdir -p apps/a apps/b
  install_unit --unit apps/a --name a --dialect postgres --source dbml; install_unit --unit apps/b --name b --dialect postgres --source dbml
  dbml_module apps/a m t1; dbml_module apps/b m t2
  make erd >/dev/null; git add -A; git commit -qm init; git update-ref refs/remotes/origin/main HEAD
  assert_has "$(make erd-check-changed BASE=origin/main 2>&1)" "스키마가 바뀐 ERD 단위 없음"
  dbml_module apps/a m t1 t3
  assert_eq "$(rc_of make erd-check-changed BASE=origin/main)" 2 "$(out)"   # make 는 하위 실패 시 2
  assert_has "$(out)" "\[apps/a\] docs/schema"
  if out | grep -q "ERD 단위: apps/b"; then echo "바뀌지 않은 apps/b 까지 검사함"; return 1; fi
}

test_detect_and_check_tools_run() {
  local r; r="$(new_repo dt)"; cd "$r"; touch alembic.ini
  assert_has "$(bash "$SCRIPTS/detect-project.sh" .)" "Alembic"
  assert_has "$(bash "$SCRIPTS/check-tools.sh")" "MISSING="
}

echo "erd 플러그인 테스트 — 임시 DB: ${DB_MODE:-없음}, tbls/dbml2sql: $([ $TOOLS_OK = 1 ] && echo 있음 || echo 없음)"
t "inject-block 멱등"                  test_inject_block_idempotent
t "install-templates 단일 레포 멱등"   test_install_templates_single_idempotent
t "install-templates 인용·AGENTS.md"   test_install_templates_quoting_and_agents_md
t "detect·check-tools 실행"           test_detect_and_check_tools_run
t "changed-units 분류·기준 ref"        test_changed_units
t "단일 레포 doc·check·drift"          test_single_doc_check_drift   db
t "종료 코드 2·3·4·6·7·8"              test_exit_codes               db
t "종료 코드 5 (임시 DB 접속 실패)"     test_exit_code_tempdb         tools
t "모노레포 단위·대상 인식"            test_monorepo_units           db
t "erd-check-changed"                  test_changed_check_target     db
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ $FAIL = 0 ] || { printf "실패:$FAILED\n"; exit 1; }
