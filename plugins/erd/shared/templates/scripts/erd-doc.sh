#!/usr/bin/env bash
# ERD 문서 생성: (DBML 또는 마이그레이션) → 임시 DB → tbls 문서
# 생성: erd 플러그인 (https://github.com/devicki/dev-toolkit)
#
# 사용법: scripts/erd-doc.sh [doc|check|sql] [ERD 단위 폴더]
#   doc   : docs/schema 를 새로 생성 + lint (기본)
#   check : 문서가 현재 스키마와 일치하는지 검사 (다르면 exit 1, CI용)
#   sql   : DBML → SQL 만 생성 (ERD_SOURCE=dbml 일 때)
#
# ERD 단위 = erd.env 가 있는 폴더 (DB 하나당 하나). 모노레포면 서비스마다 둘 수 있다.
# 단위 폴더를 생략하면: 현재 위치에서 위로 가장 가까운 erd.env → 없으면 레포 안 erd.env 가 하나일 때 그것.
# 환경변수로 덮어쓰기: PG=postgres://user:pass@host:5432  (기존 PostgreSQL 서버 사용)
#                      MY=mysql://user:pass@host:3306      (기존 MySQL 서버 사용)
#
# 종료 코드 (실패 시 마지막 줄에 'ERD_EXIT=<코드> <분류>' 출력)
#   0 성공 | 1 문서 불일치(check)·strict lint 실패 | 2 사용법·설정 오류 | 3 필수 도구 없음
#   4 DBML 변환 실패 | 5 임시 DB 준비 실패 | 6 스키마 적용 실패 | 7 마이그레이션 명령 실패 | 8 tbls 실행 실패
set -euo pipefail
fail() { # fail <코드> <분류> <메시지...>
  local code="$1" kind="$2"; shift 2
  printf '✘ %s\n' "$*" >&2
  echo "ERD_EXIT=$code $kind"
  exit "$code"
}
MODE="${1:-doc}"
UNIT_ARG="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"   # 물리 경로로 통일 (macOS /var ↔ /private/var)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ── 대상 ERD 단위 결정 ───────────────────────────────
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
if [ -n "$UNIT_ARG" ]; then
  [ -d "$UNIT_ARG" ] || fail 2 usage "단위 폴더가 없습니다: $UNIT_ARG"
  cd "$UNIT_ARG"
elif UNIT_DIR="$(find_up "$(pwd -P)")"; then
  cd "$UNIT_DIR"
else
  UNITS="$(list_units)"
  case "$(printf '%s' "$UNITS" | grep -c . || true)" in
    0) cd "$REPO_ROOT" ;;
    1) cd "$UNITS" ;;
    *) echo "ERD 단위가 여러 개입니다:"; printf '%s\n' "$UNITS" | sed "s#^$REPO_ROOT/*#  #; s#^  \$#  .#"
       fail 2 usage "단위 폴더를 지정하세요. 예: scripts/erd-doc.sh $MODE <단위 폴더>  또는  make erd P=<단위 폴더>" ;;
  esac
fi
# 레포 루트 기준 상대 경로 (GNU realpath·python 없이: macOS 기본 환경 호환)
HERE="$(pwd -P)"
case "$HERE" in "$REPO_ROOT") UNIT_REL=".";; "$REPO_ROOT"/*) UNIT_REL="${HERE#"$REPO_ROOT"/}";; *) UNIT_REL="$HERE";; esac
echo "■ ERD 단위: $UNIT_REL"

# ── 설정 (단위 폴더 기준 상대 경로) ──────────────────
[ -f erd.env ] && set -a && . ./erd.env && set +a
ERD_DIALECT="${ERD_DIALECT:-postgres}"          # postgres | mysql
ERD_SOURCE="${ERD_SOURCE:-dbml}"                 # dbml | migrations
ERD_DBML_ENTRY="${ERD_DBML_ENTRY:-db/schema.dbml}"
ERD_SQL_OUT="${ERD_SQL_OUT:-db/schema.sql}"
ERD_MIGRATE_CMD="${ERD_MIGRATE_CMD:-}"           # ERD_SOURCE=migrations 일 때 실행할 명령 (DATABASE_URL 제공, 단위 폴더에서 실행)
ERD_DERIVED_DBML="${ERD_DERIVED_DBML:-db/schema.generated.dbml}"
ERD_DOCKER_IMAGE="${ERD_DOCKER_IMAGE:-}"
# 단위마다 임시 DB 이름을 다르게 (같은 서버를 써도 충돌하지 않도록)
SLUG="$(printf '%s' "$UNIT_REL" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed -E 's/_+/_/g; s/^_//; s/_$//' | cut -c1-40)"
DOC_DB="erd_doc${SLUG:+_$SLUG}"

case "$MODE" in doc|check|sql) ;; *) fail 2 usage "모드는 doc|check|sql 중 하나입니다: $MODE";; esac
case "$ERD_DIALECT" in postgres|mysql) ;; *) fail 2 config "ERD_DIALECT 는 postgres|mysql 입니다: $ERD_DIALECT (erd.env)";; esac
case "$ERD_SOURCE" in dbml|migrations) ;; *) fail 2 config "ERD_SOURCE 는 dbml|migrations 입니다: $ERD_SOURCE (erd.env)";; esac
if [ "$ERD_SOURCE" = "dbml" ]; then
  [ -f "$ERD_DBML_ENTRY" ] || fail 2 config "DBML 진입 파일이 없습니다: $UNIT_REL/$ERD_DBML_ENTRY"
else
  [ "$MODE" = "sql" ] && fail 2 usage "sql 모드는 ERD_SOURCE=dbml 에서만 쓸 수 있습니다"
  [ -n "$ERD_MIGRATE_CMD" ] || fail 2 config "ERD_SOURCE=migrations 인데 ERD_MIGRATE_CMD 가 비어 있습니다 (erd.env)"
fi
[ -f .tbls.yml ] || [ "$MODE" = "sql" ] || fail 2 config "$UNIT_REL/.tbls.yml 이 없습니다 (/erd:init 으로 생성)"

# tbls의 공용 /tmp 권한 문제 예방 (계정별 임시 폴더)
if [ -z "${TMPDIR:-}" ] || [ "${TMPDIR%/}" = "/tmp" ]; then
  export TMPDIR="$HOME/.cache/erd-tmp"; mkdir -p "$TMPDIR"
fi

need() { command -v "$1" >/dev/null 2>&1 || fail 3 missing-tool "'$1' 이 필요합니다. Claude Code에서 /erd:doctor 를 실행하세요."; }
[ "$MODE" = "sql" ] || need tbls

# tbls 실행 래퍼: /tmp/go-graphviz 권한 문제를 알아보기 쉽게
run_tbls() {
  local out rc=0
  out="$(tbls "$@" 2>&1)" || rc=$?
  if [ $rc -ne 0 ]; then
    printf '%s\n' "$out" >&2
    if printf '%s' "$out" | grep -q 'go-graphviz.*permission denied'; then
      fail 8 tbls "tbls 가 공용 /tmp 권한 문제로 실패했습니다. TMPDIR 을 개인 폴더로 지정하거나 관리자에게 libpam-tmpdir 설치를 요청하세요."
    fi
    return $rc
  fi
  printf '%s' "$out"
}

# ── 1. DBML → SQL ────────────────────────────────────
if [ "$ERD_SOURCE" = "dbml" ]; then
  need dbml2sql
  echo "▶ DBML → SQL ($ERD_DBML_ENTRY → $ERD_SQL_OUT)"
  rm -f dbml-error.log
  # 주의: dbml2sql 은 문법 오류가 있어도 exit 0 이고, 성공해도 빈 dbml-error.log 를 만든다 → 로그 내용 유무로 판정
  dbml_out="$(dbml2sql "$ERD_DBML_ENTRY" "--$ERD_DIALECT" -o "$ERD_SQL_OUT" 2>&1)" || true
  if [ -s dbml-error.log ] || ! [ -s "$ERD_SQL_OUT" ]; then
    printf '%s\n' "$dbml_out" | sed '/A complete log/,$d' >&2
    rm -f dbml-error.log
    fail 4 dbml "DBML 변환 실패 ($UNIT_REL/$ERD_DBML_ENTRY). 위 위치(파일:줄,칸)를 고치세요."
  fi
  rm -f dbml-error.log
  [ "$MODE" = "sql" ] && { echo "✔ $ERD_SQL_OUT"; exit 0; }
fi

# ── 2. 임시 DB 준비 ──────────────────────────────────
CONTAINER=""
cleanup() {
  if [ -n "${PG:-}" ]; then psql "$PG/postgres" -qc "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true; fi
  if [ -n "${MY:-}" ]; then mysql_exec "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true; fi
  if [ -n "$CONTAINER" ]; then docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

mysql_args() { # mysql://user:pass@host:port → mysql CLI 인자
  local u="${MY#mysql://}"; local cred="${u%@*}" hp="${u#*@}"
  echo "-u${cred%%:*} -p${cred#*:} -h${hp%%:*} -P${hp##*:}"
}
mysql_exec() { mysql $(mysql_args) -e "$1"; }

if [ "$ERD_DIALECT" = "postgres" ] && [ -n "${PG:-}" ]; then
  command -v psql >/dev/null 2>&1 || fail 3 missing-tool "PG= 로 기존 서버를 쓰려면 psql 이 필요합니다. psql 이 없으면 PG 없이 실행해 Docker 임시 DB 를 쓰세요."
  echo "▶ 기존 PostgreSQL 서버에 임시 DB($DOC_DB) 생성"
  psql "$PG/postgres" -qc "select 1" >/dev/null 2>&1 || fail 5 tempdb "PostgreSQL 서버 접속 실패: ${PG%%@*}@… (주소·계정·비밀번호 확인)"
  psql "$PG/postgres" -qc "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true
  psql "$PG/postgres" -qc "CREATE DATABASE $DOC_DB" >/dev/null 2>&1 || fail 5 tempdb "임시 DB 생성 실패 (CREATE DATABASE 권한 필요): $DOC_DB"
  DSN="$PG/$DOC_DB?sslmode=disable"
  apply_sql() { psql "$PG/$DOC_DB" -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null; }
elif [ "$ERD_DIALECT" = "mysql" ] && [ -n "${MY:-}" ]; then
  need mysql
  echo "▶ 기존 MySQL 서버에 임시 DB($DOC_DB) 생성"
  mysql_exec "DROP DATABASE IF EXISTS $DOC_DB; CREATE DATABASE $DOC_DB" >/dev/null 2>&1 || fail 5 tempdb "MySQL 임시 DB 생성 실패 (접속 정보·권한 확인)"
  DSN="$MY/$DOC_DB"
  apply_sql() { mysql $(mysql_args) "$DOC_DB" < "$1"; }
else
  need docker
  docker info >/dev/null 2>&1 || fail 5 tempdb "Docker 데몬에 접근할 수 없습니다 (권한: docker 그룹 추가 후 재로그인). 또는 PG=postgres://... 로 기존 서버를 쓰세요."
  wait_ready() { local i; for i in $(seq 1 90); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done; fail 5 tempdb "임시 DB 컨테이너가 90초 안에 준비되지 않았습니다 (docker logs $CONTAINER)"; }
  PORT=$(( 40000 + RANDOM % 20000 )); CONTAINER="erd-doc-$$"
  if [ "$ERD_DIALECT" = "mysql" ]; then
    IMG="${ERD_DOCKER_IMAGE:-mysql:8}"
    echo "▶ Docker 임시 DB 실행 ($IMG)"
    docker run -d --name "$CONTAINER" -e MYSQL_ROOT_PASSWORD=erd -e MYSQL_DATABASE=$DOC_DB -p "$PORT:3306" "$IMG" >/dev/null || fail 5 tempdb "Docker 컨테이너 실행 실패 ($IMG)"
    wait_ready docker exec "$CONTAINER" mysql -uroot -perd -e 'select 1' "$DOC_DB"
    DSN="mysql://root:erd@127.0.0.1:$PORT/$DOC_DB"
    apply_sql() { docker exec -i "$CONTAINER" mysql -uroot -perd "$DOC_DB" < "$1"; }
  else
    IMG="${ERD_DOCKER_IMAGE:-postgres:16}"
    echo "▶ Docker 임시 DB 실행 ($IMG)"
    docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=erd -e POSTGRES_DB=$DOC_DB -p "$PORT:5432" "$IMG" >/dev/null || fail 5 tempdb "Docker 컨테이너 실행 실패 ($IMG)"
    wait_ready docker exec "$CONTAINER" pg_isready -U postgres -d $DOC_DB; sleep 1
    DSN="postgres://postgres:erd@127.0.0.1:$PORT/$DOC_DB?sslmode=disable"
    apply_sql() { docker exec -i "$CONTAINER" psql -q -v ON_ERROR_STOP=1 -U postgres -d $DOC_DB < "$1" >/dev/null; }
  fi
fi

# ── 3. 스키마 적용 ───────────────────────────────────
if [ "$ERD_SOURCE" = "dbml" ]; then
  echo "▶ 스키마 적용 ($ERD_SQL_OUT)"
  apply_sql "$ERD_SQL_OUT" || fail 6 apply "스키마 적용 실패 ($UNIT_REL/$ERD_SQL_OUT). 위 SQL 오류를 보고 DBML 을 고치세요 (타입·기본값·예약어 등)."
else
  echo "▶ 마이그레이션 실행: $ERD_MIGRATE_CMD"
  DATABASE_URL="$DSN" ERD_DSN="$DSN" bash -c "$ERD_MIGRATE_CMD" || fail 7 migrate "마이그레이션 명령 실패: $ERD_MIGRATE_CMD (단위 폴더에서 실행됨, DATABASE_URL 사용 여부 확인)"
fi

# ── 4. 문서 생성 / 검사 ──────────────────────────────
if [ "$MODE" = "check" ]; then
  echo "▶ 문서 최신 여부 검사"
  [ -d docs/schema ] || fail 1 diff "docs/schema 가 없습니다. 'make erd P=$UNIT_REL' 로 먼저 생성하세요."
  DIFF=$(tbls diff "$DSN" docs/schema 2>&1) || true   # 차이가 있으면 exit 1 이므로 출력으로 판정
  printf '%s' "$DIFF" | grep -q 'go-graphviz.*permission denied' && fail 8 tbls "tbls 가 공용 /tmp 권한 문제로 실패했습니다. TMPDIR 을 개인 폴더로 지정하세요."
  if [ -n "$DIFF" ]; then
    echo "$DIFF"
    fail 1 diff "[$UNIT_REL] docs/schema 가 현재 스키마와 다릅니다. 'make erd P=$UNIT_REL' 실행 후 함께 커밋하세요."
  fi
  echo "  문서가 최신입니다"
  if ! run_tbls lint --dsn "$DSN"; then
    if [ "${ERD_CHECK_LINT:-warn}" = "strict" ]; then fail 1 lint "[$UNIT_REL] lint 실패 (ERD_CHECK_LINT=strict)"; fi
    echo "⚠ lint 경고 (CI를 실패시키려면 erd.env 에 ERD_CHECK_LINT=strict)"
  fi
  echo "✔ [$UNIT_REL] 검사 통과"
else
  echo "▶ 문서 생성 (docs/schema)"
  run_tbls doc --dsn "$DSN" --rm-dist >/dev/null || fail 8 tbls "tbls doc 실패 (.tbls.yml 문법·viewpoint 의 테이블 이름 확인)"
  if [ "$ERD_SOURCE" = "migrations" ] && command -v db2dbml >/dev/null 2>&1; then
    case "$ERD_DIALECT" in postgres) d=postgres; c="${DSN%%\?*}";; mysql) d=mysql; c="$DSN";; esac
    mkdir -p "$(dirname "$ERD_DERIVED_DBML")"
    db2dbml "$d" "$c" -o "$ERD_DERIVED_DBML" >/dev/null 2>&1 && echo "▶ 파생 DBML 갱신: $ERD_DERIVED_DBML" || true
  fi
  echo "▶ 품질 검사 (tbls lint)"
  run_tbls lint --dsn "$DSN" || echo "⚠ lint 경고가 있습니다 (위 내용 확인)"
  echo "✔ 완료: docs/schema/README.md"
fi
