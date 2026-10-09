#!/usr/bin/env bash
# ERD docs: (DBML or migrations) → temporary DB → tbls docs
# Installed by the erd plugin (https://github.com/devicki/dev-toolkit)
#
# Usage: scripts/erd-doc.sh [doc|check|sql] [ERD unit folder]
#   doc   : regenerate docs/schema + lint (default)
#   check : verify the docs match the current schema (exit 1 if not; for CI)
#   sql   : generate SQL from DBML only (ERD_SOURCE=dbml)
#
# ERD unit = a folder containing erd.env (one per DB). A monorepo can have one per service.
# Without a unit argument: nearest erd.env upward from the current folder → else the only erd.env in the repo.
# Environment overrides: PG=postgres://user:pass@host:5432  (use an existing PostgreSQL server)
#                        MY=mysql://user:pass@host:3306      (use an existing MySQL server)
#                        ERD_LANG=ko|en                      (message language; default: the unit's erd.env, else en)
#
# Exit codes (on failure the last line is 'ERD_EXIT=<code> <kind>')
#   0 ok | 1 docs out of date (check) / strict lint failure | 2 usage/config error | 3 required tool missing
#   4 DBML conversion failed | 5 temporary DB failed | 6 schema apply failed | 7 migration command failed | 8 tbls failed
set -euo pipefail
fail() { # fail <code> <kind> <message...>
  local code="$1" kind="$2"; shift 2
  printf '✘ %s\n' "$*" >&2
  echo "ERD_EXIT=$code $kind"
  exit "$code"
}
m() { if [ "${ERD_LANG:-en}" = "ko" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }   # m <ko> <en>
MODE="${1:-doc}"
UNIT_ARG="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"   # physical path (macOS /var ↔ /private/var)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ── Resolve the target ERD unit ──────────────────────
find_up() {
  local d="$1"
  while :; do
    [ -f "$d/erd.env" ] && { echo "$d"; return 0; }
    { [ "$d" = "$REPO_ROOT" ] || [ "$d" = "/" ]; } && return 1
    d="$(dirname "$d")"
  done
}
list_units() {
  find "$REPO_ROOT" -name erd.env -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/vendor/*' -not -path '*/.venv/*' 2>/dev/null | sed 's#/erd.env$##' | sort
}
# Message language before the unit is known: ERD_LANG env → unit arg / nearest / first erd.env → en
if [ -z "${ERD_LANG:-}" ]; then
  for c in "$UNIT_ARG" "$(find_up "$(pwd -P)" || true)" "$(list_units | head -1)"; do
    [ -n "$c" ] && [ -f "$c/erd.env" ] || continue
    ERD_LANG="$({ grep -h '^ERD_LANG=' "$c/erd.env" 2>/dev/null || true; } | head -1 | cut -d= -f2 | tr -d "'\" ")"; break
  done
fi
if [ -n "$UNIT_ARG" ]; then
  [ -d "$UNIT_ARG" ] || fail 2 usage "$(m "단위 폴더가 없습니다: $UNIT_ARG" "Unit folder not found: $UNIT_ARG")"
  cd "$UNIT_ARG"
elif UNIT_DIR="$(find_up "$(pwd -P)")"; then
  cd "$UNIT_DIR"
else
  UNITS="$(list_units)"
  case "$(printf '%s' "$UNITS" | grep -c . || true)" in
    0) cd "$REPO_ROOT" ;;
    1) cd "$UNITS" ;;
    *) m "ERD 단위가 여러 개입니다:" "Multiple ERD units:"; echo; printf '%s\n' "$UNITS" | sed "s#^$REPO_ROOT/*#  #; s#^  \$#  .#"
       fail 2 usage "$(m "단위 폴더를 지정하세요. 예: scripts/erd-doc.sh $MODE <단위 폴더>  또는  make erd P=<단위 폴더>" "Specify a unit folder, e.g. scripts/erd-doc.sh $MODE <unit folder>  or  make erd P=<unit folder>")" ;;
  esac
fi
# Path relative to the repo root (no GNU realpath/python: works on stock macOS)
HERE="$(pwd -P)"
case "$HERE" in "$REPO_ROOT") UNIT_REL=".";; "$REPO_ROOT"/*) UNIT_REL="${HERE#"$REPO_ROOT"/}";; *) UNIT_REL="$HERE";; esac

# ── Settings (paths relative to the unit folder) ─────
[ -f erd.env ] && set -a && . ./erd.env && set +a
ERD_LANG="${ERD_LANG:-en}"
echo "■ $(m "ERD 단위" "ERD unit"): $UNIT_REL"
ERD_DIALECT="${ERD_DIALECT:-postgres}"          # postgres | mysql
ERD_SOURCE="${ERD_SOURCE:-dbml}"                 # dbml | migrations
ERD_DBML_ENTRY="${ERD_DBML_ENTRY:-db/schema.dbml}"
ERD_SQL_OUT="${ERD_SQL_OUT:-db/schema.sql}"
ERD_MIGRATE_CMD="${ERD_MIGRATE_CMD:-}"           # ERD_SOURCE=migrations: command to run (DATABASE_URL provided, runs in the unit folder)
ERD_DERIVED_DBML="${ERD_DERIVED_DBML:-db/schema.generated.dbml}"
ERD_DOCKER_IMAGE="${ERD_DOCKER_IMAGE:-}"
# Distinct temporary DB name per unit (no clashes on a shared server)
SLUG="$(printf '%s' "$UNIT_REL" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed -E 's/_+/_/g; s/^_//; s/_$//' | cut -c1-40)"
DOC_DB="erd_doc${SLUG:+_$SLUG}"

case "$MODE" in doc|check|sql) ;; *) fail 2 usage "$(m "모드는 doc|check|sql 중 하나입니다: $MODE" "Mode must be doc|check|sql: $MODE")";; esac
case "$ERD_DIALECT" in postgres|mysql) ;; *) fail 2 config "$(m "ERD_DIALECT 는 postgres|mysql 입니다: $ERD_DIALECT (erd.env)" "ERD_DIALECT must be postgres|mysql: $ERD_DIALECT (erd.env)")";; esac
case "$ERD_SOURCE" in dbml|migrations) ;; *) fail 2 config "$(m "ERD_SOURCE 는 dbml|migrations 입니다: $ERD_SOURCE (erd.env)" "ERD_SOURCE must be dbml|migrations: $ERD_SOURCE (erd.env)")";; esac
if [ "$ERD_SOURCE" = "dbml" ]; then
  [ -f "$ERD_DBML_ENTRY" ] || fail 2 config "$(m "DBML 진입 파일이 없습니다: $UNIT_REL/$ERD_DBML_ENTRY" "DBML entry file not found: $UNIT_REL/$ERD_DBML_ENTRY")"
else
  [ "$MODE" = "sql" ] && fail 2 usage "$(m "sql 모드는 ERD_SOURCE=dbml 에서만 쓸 수 있습니다" "sql mode only works with ERD_SOURCE=dbml")"
  [ -n "$ERD_MIGRATE_CMD" ] || fail 2 config "$(m "ERD_SOURCE=migrations 인데 ERD_MIGRATE_CMD 가 비어 있습니다 (erd.env)" "ERD_SOURCE=migrations but ERD_MIGRATE_CMD is empty (erd.env)")"
fi
[ -f .tbls.yml ] || [ "$MODE" = "sql" ] || fail 2 config "$(m "$UNIT_REL/.tbls.yml 이 없습니다 (/erd:init 으로 생성)" "$UNIT_REL/.tbls.yml not found (create it with /erd:init)")"

# Avoid tbls' shared /tmp permission problem (per-user temp folder)
if [ -z "${TMPDIR:-}" ] || [ "${TMPDIR%/}" = "/tmp" ]; then
  export TMPDIR="$HOME/.cache/erd-tmp"; mkdir -p "$TMPDIR"
fi

need() { command -v "$1" >/dev/null 2>&1 || fail 3 missing-tool "$(m "'$1' 이 필요합니다. Claude Code에서 /erd:doctor 를 실행하세요." "'$1' is required. Run /erd:doctor in Claude Code.")"; }
[ "$MODE" = "sql" ] || need tbls

TMP_PANIC="$(m "tbls 가 공용 /tmp 권한 문제로 실패했습니다. TMPDIR 을 개인 폴더로 지정하거나 관리자에게 libpam-tmpdir 설치를 요청하세요." "tbls failed on the shared /tmp permission problem. Point TMPDIR at a personal folder or ask an admin to install libpam-tmpdir.")"
# tbls wrapper: make the /tmp/go-graphviz permission problem obvious
run_tbls() {
  local out rc=0
  out="$(tbls "$@" 2>&1)" || rc=$?
  if [ $rc -ne 0 ]; then
    printf '%s\n' "$out" >&2
    if printf '%s' "$out" | grep -q 'go-graphviz.*permission denied'; then fail 8 tbls "$TMP_PANIC"; fi
    return $rc
  fi
  printf '%s' "$out"
}

# ── 1. DBML → SQL ────────────────────────────────────
if [ "$ERD_SOURCE" = "dbml" ]; then
  need dbml2sql
  echo "▶ DBML → SQL ($ERD_DBML_ENTRY → $ERD_SQL_OUT)"
  rm -f dbml-error.log
  # Note: dbml2sql exits 0 even on syntax errors and always creates an empty dbml-error.log → judge by its content
  dbml_out="$(dbml2sql "$ERD_DBML_ENTRY" "--$ERD_DIALECT" -o "$ERD_SQL_OUT" 2>&1)" || true
  if [ -s dbml-error.log ] || ! [ -s "$ERD_SQL_OUT" ]; then
    printf '%s\n' "$dbml_out" | sed '/A complete log/,$d' >&2
    rm -f dbml-error.log
    fail 4 dbml "$(m "DBML 변환 실패 ($UNIT_REL/$ERD_DBML_ENTRY). 위 위치(파일:줄,칸)를 고치세요." "DBML conversion failed ($UNIT_REL/$ERD_DBML_ENTRY). Fix the location above (file:line,col).")"
  fi
  rm -f dbml-error.log
  [ "$MODE" = "sql" ] && { echo "✔ $ERD_SQL_OUT"; exit 0; }
fi

# ── 2. Temporary DB ──────────────────────────────────
CONTAINER=""
cleanup() {
  if [ -n "${PG:-}" ]; then psql "$PG/postgres" -qc "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true; fi
  if [ -n "${MY:-}" ]; then mysql_exec "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true; fi
  if [ -n "$CONTAINER" ]; then docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

mysql_args() { # mysql://user:pass@host:port → mysql CLI args
  local u="${MY#mysql://}"; local cred="${u%@*}" hp="${u#*@}"
  echo "-u${cred%%:*} -p${cred#*:} -h${hp%%:*} -P${hp##*:}"
}
mysql_exec() { mysql $(mysql_args) -e "$1"; }

if [ "$ERD_DIALECT" = "postgres" ] && [ -n "${PG:-}" ]; then
  command -v psql >/dev/null 2>&1 || fail 3 missing-tool "$(m "PG= 로 기존 서버를 쓰려면 psql 이 필요합니다. psql 이 없으면 PG 없이 실행해 Docker 임시 DB 를 쓰세요." "Using an existing server via PG= requires psql. Without psql, run without PG to use a Docker temporary DB.")"
  echo "▶ $(m "기존 PostgreSQL 서버에 임시 DB($DOC_DB) 생성" "Creating temporary DB ($DOC_DB) on the existing PostgreSQL server")"
  psql "$PG/postgres" -qc "select 1" >/dev/null 2>&1 || fail 5 tempdb "$(m "PostgreSQL 서버 접속 실패: ${PG%%@*}@… (주소·계정·비밀번호 확인)" "Cannot connect to PostgreSQL: ${PG%%@*}@… (check host, user, password)")"
  psql "$PG/postgres" -qc "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true
  psql "$PG/postgres" -qc "CREATE DATABASE $DOC_DB" >/dev/null 2>&1 || fail 5 tempdb "$(m "임시 DB 생성 실패 (CREATE DATABASE 권한 필요): $DOC_DB" "Failed to create the temporary DB (needs CREATE DATABASE): $DOC_DB")"
  DSN="$PG/$DOC_DB?sslmode=disable"
  apply_sql() { psql "$PG/$DOC_DB" -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null; }
elif [ "$ERD_DIALECT" = "mysql" ] && [ -n "${MY:-}" ]; then
  need mysql
  echo "▶ $(m "기존 MySQL 서버에 임시 DB($DOC_DB) 생성" "Creating temporary DB ($DOC_DB) on the existing MySQL server")"
  mysql_exec "DROP DATABASE IF EXISTS $DOC_DB; CREATE DATABASE $DOC_DB" >/dev/null 2>&1 || fail 5 tempdb "$(m "MySQL 임시 DB 생성 실패 (접속 정보·권한 확인)" "Failed to create the MySQL temporary DB (check connection and privileges)")"
  DSN="$MY/$DOC_DB"
  apply_sql() { mysql $(mysql_args) "$DOC_DB" < "$1"; }
else
  need docker
  docker info >/dev/null 2>&1 || fail 5 tempdb "$(m "Docker 데몬에 접근할 수 없습니다 (권한: docker 그룹 추가 후 재로그인). 또는 PG=postgres://... 로 기존 서버를 쓰세요." "Cannot reach the Docker daemon (permissions: add yourself to the docker group and log in again). Or use an existing server with PG=postgres://...")"
  wait_ready() { local i; for i in $(seq 1 90); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done; fail 5 tempdb "$(m "임시 DB 컨테이너가 90초 안에 준비되지 않았습니다 (docker logs $CONTAINER)" "The temporary DB container was not ready within 90s (docker logs $CONTAINER)")"; }
  PORT=$(( 40000 + RANDOM % 20000 )); CONTAINER="erd-doc-$$"
  if [ "$ERD_DIALECT" = "mysql" ]; then
    IMG="${ERD_DOCKER_IMAGE:-mysql:8}"
    echo "▶ $(m "Docker 임시 DB 실행" "Starting Docker temporary DB") ($IMG)"
    docker run -d --name "$CONTAINER" -e MYSQL_ROOT_PASSWORD=erd -e MYSQL_DATABASE=$DOC_DB -p "$PORT:3306" "$IMG" >/dev/null || fail 5 tempdb "$(m "Docker 컨테이너 실행 실패" "Failed to start the Docker container") ($IMG)"
    wait_ready docker exec "$CONTAINER" mysql -uroot -perd -e 'select 1' "$DOC_DB"
    DSN="mysql://root:erd@127.0.0.1:$PORT/$DOC_DB"
    apply_sql() { docker exec -i "$CONTAINER" mysql -uroot -perd "$DOC_DB" < "$1"; }
  else
    IMG="${ERD_DOCKER_IMAGE:-postgres:16}"
    echo "▶ $(m "Docker 임시 DB 실행" "Starting Docker temporary DB") ($IMG)"
    docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=erd -e POSTGRES_DB=$DOC_DB -p "$PORT:5432" "$IMG" >/dev/null || fail 5 tempdb "$(m "Docker 컨테이너 실행 실패" "Failed to start the Docker container") ($IMG)"
    wait_ready docker exec "$CONTAINER" pg_isready -U postgres -d $DOC_DB; sleep 1
    DSN="postgres://postgres:erd@127.0.0.1:$PORT/$DOC_DB?sslmode=disable"
    apply_sql() { docker exec -i "$CONTAINER" psql -q -v ON_ERROR_STOP=1 -U postgres -d $DOC_DB < "$1" >/dev/null; }
  fi
fi

# ── 3. Apply the schema ──────────────────────────────
if [ "$ERD_SOURCE" = "dbml" ]; then
  echo "▶ $(m "스키마 적용" "Applying schema") ($ERD_SQL_OUT)"
  apply_sql "$ERD_SQL_OUT" || fail 6 apply "$(m "스키마 적용 실패 ($UNIT_REL/$ERD_SQL_OUT). 위 SQL 오류를 보고 DBML 을 고치세요 (타입·기본값·예약어 등)." "Schema apply failed ($UNIT_REL/$ERD_SQL_OUT). Fix the DBML using the SQL error above (types, defaults, reserved words, ...).")"
else
  echo "▶ $(m "마이그레이션 실행" "Running migrations"): $ERD_MIGRATE_CMD"
  DATABASE_URL="$DSN" ERD_DSN="$DSN" bash -c "$ERD_MIGRATE_CMD" || fail 7 migrate "$(m "마이그레이션 명령 실패: $ERD_MIGRATE_CMD (단위 폴더에서 실행됨, DATABASE_URL 사용 여부 확인)" "Migration command failed: $ERD_MIGRATE_CMD (runs in the unit folder; check that it uses DATABASE_URL)")"
fi

# ── 4. Generate / check docs ─────────────────────────
if [ "$MODE" = "check" ]; then
  echo "▶ $(m "문서 최신 여부 검사" "Checking docs are up to date")"
  [ -d docs/schema ] || fail 1 diff "$(m "docs/schema 가 없습니다. 'make erd P=$UNIT_REL' 로 먼저 생성하세요." "docs/schema not found. Generate it first with 'make erd P=$UNIT_REL'.")"
  DIFF=$(tbls diff "$DSN" docs/schema 2>&1) || true   # exits 1 when there is a diff, so judge by output
  printf '%s' "$DIFF" | grep -q 'go-graphviz.*permission denied' && fail 8 tbls "$TMP_PANIC"
  if [ -n "$DIFF" ]; then
    echo "$DIFF"
    fail 1 diff "$(m "[$UNIT_REL] docs/schema 가 현재 스키마와 다릅니다. 'make erd P=$UNIT_REL' 실행 후 함께 커밋하세요." "[$UNIT_REL] docs/schema differs from the current schema. Run 'make erd P=$UNIT_REL' and commit the result.")"
  fi
  echo "  $(m "문서가 최신입니다" "Docs are up to date")"
  if ! run_tbls lint --dsn "$DSN"; then
    if [ "${ERD_CHECK_LINT:-warn}" = "strict" ]; then fail 1 lint "$(m "[$UNIT_REL] lint 실패 (ERD_CHECK_LINT=strict)" "[$UNIT_REL] lint failed (ERD_CHECK_LINT=strict)")"; fi
    echo "⚠ $(m "lint 경고 (CI를 실패시키려면 erd.env 에 ERD_CHECK_LINT=strict)" "lint warnings (set ERD_CHECK_LINT=strict in erd.env to fail CI)")"
  fi
  echo "✔ [$UNIT_REL] $(m "검사 통과" "check passed")"
else
  echo "▶ $(m "문서 생성" "Generating docs") (docs/schema)"
  run_tbls doc --dsn "$DSN" --rm-dist >/dev/null || fail 8 tbls "$(m "tbls doc 실패 (.tbls.yml 문법·viewpoint 의 테이블 이름 확인)" "tbls doc failed (check .tbls.yml syntax and viewpoint table names)")"
  if [ "$ERD_SOURCE" = "migrations" ] && command -v db2dbml >/dev/null 2>&1; then
    case "$ERD_DIALECT" in postgres) d=postgres; c="${DSN%%\?*}";; mysql) d=mysql; c="$DSN";; esac
    mkdir -p "$(dirname "$ERD_DERIVED_DBML")"
    db2dbml "$d" "$c" -o "$ERD_DERIVED_DBML" >/dev/null 2>&1 && echo "▶ $(m "파생 DBML 갱신" "Derived DBML updated"): $ERD_DERIVED_DBML" || true
  fi
  echo "▶ $(m "품질 검사" "Quality check") (tbls lint)"
  run_tbls lint --dsn "$DSN" || echo "⚠ $(m "lint 경고가 있습니다 (위 내용 확인)" "lint warnings (see above)")"
  echo "✔ $(m "완료" "Done"): docs/schema/README.md"
fi
