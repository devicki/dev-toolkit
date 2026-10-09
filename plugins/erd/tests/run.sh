#!/usr/bin/env bash
# erd plugin regression tests. Every scenario runs in a sample project in a temp folder (never touches a real repo).
#
# Usage: plugins/erd/tests/run.sh [-k <name substring>] [-v]
#   Temporary DB: PG=postgres://user:pass@host:5432 (a dev server; creates and drops erd_doc_* DBs) or Docker.
#                 Without either, DB tests are SKIPped.
#   Tools: bash, git, tbls, dbml2sql (tests SKIP without them), psql (migrations scenarios)
# Exit code: 1 if any test fails
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SHARED="$(cd "$HERE/../shared" && pwd)"
SCRIPTS="$SHARED/scripts"
FILTER="" VERBOSE=0
while [ $# -gt 0 ]; do case "$1" in -k) FILTER="$2"; shift 2;; -v) VERBOSE=1; shift;; *) echo "unknown argument: $1"; exit 2;; esac; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/erd-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"   # isolate from the user's git config (signing etc.)
git config --global user.email test@example.com; git config --global user.name erd-test
git config --global init.defaultBranch main; git config --global commit.gpgsign false

PASS=0 FAIL=0 SKIP=0 FAILED=""
have() { command -v "$1" >/dev/null 2>&1; }
DB_OK=0
if [ -n "${PG:-}" ] && have psql && psql "$PG/postgres" -qc 'select 1' >/dev/null 2>&1; then DB_OK=1; DB_MODE="PG=$PG"
elif have docker && docker info >/dev/null 2>&1; then DB_OK=1; DB_MODE="docker"; unset PG
fi
TOOLS_OK=0; have tbls && have dbml2sql && TOOLS_OK=1

# ── Helpers ──────────────────────────────────────────
CUR=""
t() { # t <name> <function> [needs: db|tools]
  local name="$1" fn="$2" need="${3:-}"
  [ -n "$FILTER" ] && [ "${name#*$FILTER}" = "$name" ] && return
  if [ "$need" = db ] && { [ $DB_OK = 0 ] || [ $TOOLS_OK = 0 ]; }; then echo "  SKIP  $name (no temporary DB or tbls/dbml2sql)"; SKIP=$((SKIP+1)); return; fi
  if [ "$need" = tools ] && [ $TOOLS_OK = 0 ]; then echo "  SKIP  $name (no tbls/dbml2sql)"; SKIP=$((SKIP+1)); return; fi
  CUR="$name"; local log="$WORK/log.$PASS.$FAIL"
  local rc=0
  # set -e is ignored inside an if condition, so run separately. Keep stdin open (a watchdog catches scripts waiting on stdin)
  ( set -e; cd "$WORK"; "$fn" ) >"$log" 2>&1 & local pid=$!
  ( sleep "${ERD_TEST_TIMEOUT:-180}"; kill -TERM $pid 2>/dev/null && echo "timeout (${ERD_TEST_TIMEOUT:-180}s) — hung, e.g. waiting on stdin" >> "$log" ) & local wd=$!
  wait $pid || rc=$?
  kill $wd 2>/dev/null; wait $wd 2>/dev/null
  if [ $rc = 0 ]; then echo "  PASS  $name"; PASS=$((PASS+1))
  else echo "  FAIL  $name"; FAIL=$((FAIL+1)); FAILED="$FAILED\n  - $name"; sed 's/^/        /' "$log" | tail -25; fi
  [ $VERBOSE = 1 ] && sed 's/^/        /' "$log"
  return 0
}
assert_eq() { [ "$1" = "$2" ] || { echo "expected [$2] ≠ actual [$1] ${3:-}"; return 1; }; }
assert_has() { printf '%s' "$1" | grep -q -- "$2" || { echo "[$2] not in output ${3:-}"; printf '%s\n' "$1" | tail -10; return 1; }; }
rc_of() { set +e; "$@" >"$WORK/out" 2>&1; local r=$?; set -e; echo $r; }
out() { cat "$WORK/out"; }

new_repo() { # new_repo <name> → prints the path, for use in a subshell that cd's there
  local d="$WORK/$1"; rm -rf "$d"; mkdir -p "$d"; (cd "$d" && git init -q); echo "$d"
}
install_unit() { bash "$SCRIPTS/install-templates.sh" "$@" >/dev/null; }
dbml_module() { # dbml_module <unit> <module> <tables...>
  local u="$1" m="$2"; shift 2; local f="$u/db/modules/$m.dbml"
  : > "$f"; for tb in "$@"; do printf "Table %s {\n  id bigint [pk, note: 'PK']\n  Note: '%s'\n}\n" "$tb" "$tb" >> "$f"; done
  rm -f "$u/db/modules/_example.dbml"
  grep -q "modules/$m'" "$u/db/schema.dbml" || echo "use * from './modules/$m'" >> "$u/db/schema.dbml"
}

# Migration runner: without psql (e.g. macOS + Docker Desktop) use psql inside a container against the host port
write_migrate_sh() { # write_migrate_sh <unit folder>  (applies its migrations/*.sql in order)
  cat > "$1/migrate.sh" <<'SH'
#!/usr/bin/env bash
set -e
for f in migrations/*.sql; do
  if command -v psql >/dev/null 2>&1; then psql "$DATABASE_URL" -q -v ON_ERROR_STOP=1 -f "$f"
  else u="$(printf '%s' "$DATABASE_URL" | sed -E 's#@(127\.0\.0\.1|localhost):#@host.docker.internal:#')"
       docker run --rm -i --add-host=host.docker.internal:host-gateway postgres:16 psql "$u" -q -v ON_ERROR_STOP=1 < "$f"; fi
done
SH
  chmod +x "$1/migrate.sh"
}

# ── Scenarios ────────────────────────────────────────
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
  for f in scripts/erd-doc.sh scripts/erd-changed.sh erd.mk erd.env .tbls.yml db/schema.dbml docs/ERD_GUIDE.md CLAUDE.md; do [ -e "$f" ] || { echo "missing: $f"; return 1; }; done
  [ -x scripts/erd-doc.sh ]
  grep -q 'Table example_items' db/modules/_example.dbml   # regression: a template without substitutions went through sed and waited on stdin
  bash "$SCRIPTS/install-templates.sh" --unit . --name shop --dialect postgres --source dbml > o2
  ! grep -Eq '^[+~!]' o2 || { echo "re-run changed something"; cat o2; return 1; }
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
  grep -q 'docs/schema/<table>.md' apps/pay/AGENTS.md   # MySQL: no schema prefix
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
  if have psql; then
    assert_eq "$(rc_of env PG=postgres://nobody@127.0.0.1:1 scripts/erd-doc.sh doc)" 5 "$(out)"
  else  # PG= mode needs psql → must report missing tool (3)
    assert_eq "$(rc_of env PG=postgres://nobody@127.0.0.1:1 scripts/erd-doc.sh doc)" 3 "$(out)"
    assert_has "$(out)" "psql"
  fi
}

test_monorepo_units() {
  local r; r="$(new_repo mono)"; cd "$r"; mkdir -p apps/api apps/pay/migrations apps/web
  write_migrate_sh apps/pay
  echo '{"workspaces":["apps/*"]}' > package.json; echo '{"dependencies":{"react":"18"}}' > apps/web/package.json
  install_unit --unit apps/api --name api --dialect postgres --source dbml --related apps/web --lang ko
  dbml_module apps/api user users
  printf "CREATE TABLE invoices (id serial primary key);\nCOMMENT ON TABLE invoices IS '청구';COMMENT ON COLUMN invoices.id IS 'PK';\n" > apps/pay/migrations/001.sql
  install_unit --unit apps/pay --name pay --dialect postgres --source migrations \
    --migrate-cmd './migrate.sh'   # no --lang: inherits ko from apps/api
  grep -q '^ERD_LANG=ko' apps/pay/erd.env
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

test_migrations_tbls_comments() {
  local r; r="$(new_repo mc)"; cd "$r"; mkdir -p migrations
  write_migrate_sh .
  printf "CREATE TABLE users (id serial primary key, deleted_at timestamptz);\nCOMMENT ON TABLE users IS '회원';COMMENT ON COLUMN users.id IS 'PK';\n" > migrations/001.sql
  install_unit --unit . --name mc --dialect postgres --source migrations --migrate-cmd './migrate.sh' --lang ko
  grep -q '.tbls.yml 의 comments:' CLAUDE.md; grep -q 'docs/schema/public.<테이블>.md' CLAUDE.md
  cat >> .tbls.yml <<'Y'
comments:
  - table: users
    tableComment: "회원. ADR-003: 소프트 삭제"
    columnComments:
      deleted_at: "삭제 시각, NULL=활성 (ADR-003)"
    labels: [ADR-003]
Y
  assert_eq "$(rc_of make erd)" 0 "$(out)"
  grep -q '회원. ADR-003' docs/schema/public.users.md
  grep -q 'NULL=활성 (ADR-003)' docs/schema/public.users.md
  grep -q '`ADR-003`' docs/schema/README.md          # label → find tables per ADR in the list
  assert_eq "$(rc_of make erd-check)" 0 "$(out)"
  ! out | grep -q 'comment required' || { echo "config comments not honored by lint"; out | tail; return 1; }
  sed -i.bak 's/NULL=활성/NULL=사용 중/' .tbls.yml && rm -f .tbls.yml.bak
  assert_eq "$(rc_of scripts/erd-doc.sh check)" 1 "changing only comments without regenerating docs must be a diff: $(out | tail -3)"
  assert_has "$(out)" "ERD_EXIT=1 diff"
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
  assert_has "$(make erd-check-changed BASE=origin/main 2>&1)" "No ERD unit with schema changes"
  dbml_module apps/a m t1 t3
  assert_eq "$(rc_of make erd-check-changed BASE=origin/main)" 2 "$(out)"   # make exits 2 when a recipe fails
  assert_has "$(out)" "\[apps/a\] docs/schema"
  if out | grep -q "ERD unit: apps/b"; then echo "checked unchanged apps/b too"; return 1; fi
}

test_language_en_ko_legacy() {
  local r; r="$(new_repo lang)"; cd "$r"
  # en: no Korean in any generated human-facing file
  bash "$SCRIPTS/install-templates.sh" --unit . --name lang --dialect postgres --source dbml --lang en > o1
  assert_has "$(cat o1)" "INSTALL_RESULT=ok"; grep -q '^ERD_LANG=en' erd.env
  grep -q '## DB schema (erd plugin)' CLAUDE.md
  for f in erd.env .tbls.yml docs/ERD_GUIDE.md CLAUDE.md db/schema.dbml db/modules/_example.dbml; do
    if LC_ALL=C grep -q $'[\xea-\xed][\x80-\xbf][\x80-\xbf]' "$f"; then echo "Korean text in en file: $f"; return 1; fi
  done
  assert_eq "$(rc_of scripts/erd-doc.sh bogus)" 2; assert_has "$(out)" "Mode must be doc|check|sql"
  # legacy 0.3.x unit (erd.env without ERD_LANG)
  local r2; r2="$(new_repo legacy)"; cd "$r2"
  install_unit --unit . --name legacy --dialect postgres --source dbml --lang ko
  grep -v '^ERD_LANG=' erd.env > e && cat e > erd.env && rm -f e
  assert_eq "$(rc_of scripts/erd-doc.sh bogus)" 2; assert_has "$(out)" "Mode must be"   # unset → en
  assert_eq "$(rc_of env ERD_LANG=ko scripts/erd-doc.sh bogus)" 2; assert_has "$(out)" "모드는"   # env override
  bash "$SCRIPTS/install-templates.sh" --unit . --name legacy --dialect postgres --source dbml > o2
  assert_has "$(cat o2)" "ERD_LANG not set"; assert_has "$(cat o2)" "INSTALL_RESULT=warn"
  bash "$SCRIPTS/install-templates.sh" --unit . --name legacy --dialect postgres --source dbml --lang ko > o3
  assert_has "$(cat o3)" "added ERD_LANG=ko"; grep -q '^ERD_LANG=ko' erd.env
  grep -q '## DB 스키마 (erd 플러그인)' CLAUDE.md
  assert_eq "$(rc_of scripts/erd-doc.sh bogus)" 2; assert_has "$(out)" "모드는 doc|check|sql"
  bash "$SCRIPTS/install-templates.sh" --unit . --name legacy --dialect postgres --source dbml --lang en > o4
  assert_has "$(cat o4)" "ERD_LANG=ko kept"   # erd.env wins; never silently switch
  bash "$SCRIPTS/install-templates.sh" --unit . --name legacy --dialect postgres --source dbml > o5
  ! grep -Eq '^[+~!]' o5 || { echo "re-run changed something"; cat o5; return 1; }
}

test_detect_and_check_tools_run() {
  local r; r="$(new_repo dt)"; cd "$r"; touch alembic.ini
  assert_has "$(bash "$SCRIPTS/detect-project.sh" .)" "Alembic"
  assert_has "$(bash "$SCRIPTS/check-tools.sh")" "MISSING="
}

echo "erd plugin tests — temporary DB: ${DB_MODE:-none}, tbls/dbml2sql: $([ $TOOLS_OK = 1 ] && echo yes || echo no)"
t "inject-block idempotent"           test_inject_block_idempotent
t "install-templates single repo idempotent" test_install_templates_single_idempotent
t "install-templates quoting, AGENTS.md" test_install_templates_quoting_and_agents_md
t "languages en/ko, legacy erd.env"   test_language_en_ko_legacy
t "detect/check-tools run"            test_detect_and_check_tools_run
t "changed-units categories, base ref" test_changed_units
t "single repo doc/check/drift"       test_single_doc_check_drift   db
t "exit codes 2/3/4/6/7/8"            test_exit_codes               db
t "exit code 5 (temporary DB unreachable)" test_exit_code_tempdb         tools
t "migrations unit .tbls.yml comments (ADR)" test_migrations_tbls_comments db
t "monorepo units and target"         test_monorepo_units           db
t "erd-check-changed"                  test_changed_check_target     db
echo
echo "Result: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ $FAIL = 0 ] || { printf "Failed:$FAILED\n"; exit 1; }
