#!/usr/bin/env bash
# ERD 문서 생성: (DBML 또는 마이그레이션) → 임시 DB → tbls 문서
# 생성: erd 플러그인 (https://github.com/devicki/dev-toolkit)
#
# 사용법: scripts/erd-doc.sh [doc|check|sql]
#   doc   : docs/schema 를 새로 생성 + lint (기본)
#   check : 문서가 현재 스키마와 일치하는지 검사 (다르면 exit 1, CI용)
#   sql   : DBML → SQL 만 생성 (ERD_SOURCE=dbml 일 때)
#
# 설정: 프로젝트 루트의 erd.env (없으면 기본값)
# 환경변수로 덮어쓰기: PG=postgres://user:pass@host:5432  (기존 PostgreSQL 서버 사용)
#                      MY=mysql://user:pass@host:3306      (기존 MySQL 서버 사용)
set -euo pipefail
MODE="${1:-doc}"
cd "$(dirname "$0")/.."

# ── 설정 ─────────────────────────────────────────────
[ -f erd.env ] && set -a && . ./erd.env && set +a
ERD_DIALECT="${ERD_DIALECT:-postgres}"          # postgres | mysql
ERD_SOURCE="${ERD_SOURCE:-dbml}"                 # dbml | migrations
ERD_DBML_ENTRY="${ERD_DBML_ENTRY:-db/schema.dbml}"
ERD_SQL_OUT="${ERD_SQL_OUT:-db/schema.sql}"
ERD_MIGRATE_CMD="${ERD_MIGRATE_CMD:-}"           # ERD_SOURCE=migrations 일 때 실행할 명령 (DATABASE_URL 제공)
ERD_DERIVED_DBML="${ERD_DERIVED_DBML:-db/schema.generated.dbml}"
ERD_DOCKER_IMAGE="${ERD_DOCKER_IMAGE:-}"
DOC_DB="erd_doc"

# tbls의 공용 /tmp 권한 문제 예방 (계정별 임시 폴더)
if [ -z "${TMPDIR:-}" ] || [ "${TMPDIR:-}" = "/tmp" ]; then
  export TMPDIR="$HOME/.cache/erd-tmp"; mkdir -p "$TMPDIR"
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "✘ '$1' 이 필요합니다. Claude Code에서 /erd:doctor 를 실행하세요."; exit 2; }; }
need tbls

# ── 1. DBML → SQL ────────────────────────────────────
if [ "$ERD_SOURCE" = "dbml" ]; then
  need dbml2sql
  echo "▶ DBML → SQL ($ERD_DBML_ENTRY → $ERD_SQL_OUT)"
  dbml2sql "$ERD_DBML_ENTRY" "--$ERD_DIALECT" -o "$ERD_SQL_OUT" >/dev/null
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
  need psql
  echo "▶ 기존 PostgreSQL 서버에 임시 DB($DOC_DB) 생성"
  psql "$PG/postgres" -qc "DROP DATABASE IF EXISTS $DOC_DB" >/dev/null 2>&1 || true
  psql "$PG/postgres" -qc "CREATE DATABASE $DOC_DB" >/dev/null
  DSN="$PG/$DOC_DB?sslmode=disable"
  apply_sql() { psql "$PG/$DOC_DB" -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null; }
elif [ "$ERD_DIALECT" = "mysql" ] && [ -n "${MY:-}" ]; then
  need mysql
  echo "▶ 기존 MySQL 서버에 임시 DB($DOC_DB) 생성"
  mysql_exec "DROP DATABASE IF EXISTS $DOC_DB; CREATE DATABASE $DOC_DB" >/dev/null
  DSN="$MY/$DOC_DB"
  apply_sql() { mysql $(mysql_args) "$DOC_DB" < "$1"; }
else
  need docker
  PORT=$(( 40000 + RANDOM % 20000 )); CONTAINER="erd-doc-$$"
  if [ "$ERD_DIALECT" = "mysql" ]; then
    IMG="${ERD_DOCKER_IMAGE:-mysql:8}"
    echo "▶ Docker 임시 DB 실행 ($IMG)"
    docker run -d --name "$CONTAINER" -e MYSQL_ROOT_PASSWORD=erd -e MYSQL_DATABASE=$DOC_DB -p "$PORT:3306" "$IMG" >/dev/null
    until docker exec "$CONTAINER" mysql -uroot -perd -e 'select 1' "$DOC_DB" >/dev/null 2>&1; do sleep 1; done
    DSN="mysql://root:erd@127.0.0.1:$PORT/$DOC_DB"
    apply_sql() { docker exec -i "$CONTAINER" mysql -uroot -perd "$DOC_DB" < "$1"; }
  else
    IMG="${ERD_DOCKER_IMAGE:-postgres:16}"
    echo "▶ Docker 임시 DB 실행 ($IMG)"
    docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=erd -e POSTGRES_DB=$DOC_DB -p "$PORT:5432" "$IMG" >/dev/null
    until docker exec "$CONTAINER" pg_isready -U postgres -d $DOC_DB >/dev/null 2>&1; do sleep 1; done; sleep 1
    DSN="postgres://postgres:erd@127.0.0.1:$PORT/$DOC_DB?sslmode=disable"
    apply_sql() { docker exec -i "$CONTAINER" psql -q -v ON_ERROR_STOP=1 -U postgres -d $DOC_DB < "$1" >/dev/null; }
  fi
fi

# ── 3. 스키마 적용 ───────────────────────────────────
if [ "$ERD_SOURCE" = "dbml" ]; then
  echo "▶ 스키마 적용 ($ERD_SQL_OUT)"
  apply_sql "$ERD_SQL_OUT"
else
  [ -n "$ERD_MIGRATE_CMD" ] || { echo "✘ ERD_SOURCE=migrations 인데 ERD_MIGRATE_CMD 가 비어 있습니다 (erd.env)"; exit 2; }
  echo "▶ 마이그레이션 실행: $ERD_MIGRATE_CMD"
  DATABASE_URL="$DSN" ERD_DSN="$DSN" bash -c "$ERD_MIGRATE_CMD"
fi

# ── 4. 문서 생성 / 검사 ──────────────────────────────
if [ "$MODE" = "check" ]; then
  echo "▶ 문서 최신 여부 검사"
  DIFF=$(tbls diff "$DSN" docs/schema 2>&1) || true
  if [ -n "$DIFF" ]; then
    echo "$DIFF"
    echo "✘ docs/schema 가 현재 스키마와 다릅니다. 'make erd' 실행 후 함께 커밋하세요."
    exit 1
  fi
  tbls lint --dsn "$DSN"
  echo "✔ 문서가 최신입니다"
else
  echo "▶ 문서 생성 (docs/schema)"
  tbls doc --dsn "$DSN" --rm-dist >/dev/null
  if [ "$ERD_SOURCE" = "migrations" ] && command -v db2dbml >/dev/null 2>&1; then
    case "$ERD_DIALECT" in postgres) d=postgres; c="${DSN%%\?*}";; mysql) d=mysql; c="$DSN";; esac
    mkdir -p "$(dirname "$ERD_DERIVED_DBML")"
    db2dbml "$d" "$c" -o "$ERD_DERIVED_DBML" >/dev/null 2>&1 && echo "▶ 파생 DBML 갱신: $ERD_DERIVED_DBML" || true
  fi
  echo "▶ 품질 검사 (tbls lint)"
  tbls lint --dsn "$DSN" || echo "⚠ lint 경고가 있습니다 (위 내용 확인)"
  echo "✔ 완료: docs/schema/README.md"
fi
