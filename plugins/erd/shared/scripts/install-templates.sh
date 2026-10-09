#!/usr/bin/env bash
# ERD 관리 템플릿 설치 (/erd:init 전용 헬퍼). 여러 번 실행해도 안전하다 (멱등).
#
# 사용법:
#   install-templates.sh --unit <단위 폴더(레포 루트 기준, 단일 레포면 .)> --name <이름> \
#       --dialect <postgres|mysql> --source <dbml|migrations> \
#       [--migrate-cmd '<명령>'] [--related 'apps/web,apps/admin'] [--root <레포 루트>] \
#       [--update-scripts] [--dry-run]
#
# 하는 일
#   레포 루트(한 번): scripts/erd-doc.sh, scripts/erd-changed.sh, erd.mk, Makefile include, docs/ERD_GUIDE.md, .gitignore
#   단위 폴더:        erd.env(값 채움), .tbls.yml(이름 치환·관리 테이블 exclude), db/ (dbml 일 때)
#   에이전트 지침:    단위 CLAUDE.md(또는 AGENTS.md)에 마커 블록, 모노레포면 루트에 단위 목록 블록
# 규칙
#   - 기존 파일은 덮어쓰지 않는다. 단, 마커 블록은 항상 최신 내용으로 교체한다.
#   - scripts/erd-doc.sh, erd.mk 가 플러그인 버전과 다르면 '!' 로 알리고, --update-scripts 일 때만 교체한다.
# 출력: 줄마다 '+ 생성', '= 그대로', '~ 갱신', '! 확인 필요'. 마지막 줄 'INSTALL_RESULT=ok|warn'
# 종료 코드: 0 성공(경고 포함) | 2 인자 오류
set -euo pipefail

TPL="$(cd "$(dirname "$0")/../templates" && pwd)"
INJECT="$(cd "$(dirname "$0")" && pwd)/inject-block.sh"
ROOT="" UNIT="" NAME="" DIALECT="" SOURCE="" MIGRATE_CMD="" RELATED="" UPDATE_SCRIPTS=0 DRY=0
usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2;; --unit) UNIT="$2"; shift 2;; --name) NAME="$2"; shift 2;;
    --dialect) DIALECT="$2"; shift 2;; --source) SOURCE="$2"; shift 2;;
    --migrate-cmd) MIGRATE_CMD="$2"; shift 2;; --related) RELATED="$2"; shift 2;;
    --update-scripts) UPDATE_SCRIPTS=1; shift;; --dry-run) DRY=1; shift;;
    -h|--help) usage;; *) echo "알 수 없는 인자: $1" >&2; usage;;
  esac
done
[ -n "$UNIT" ] && [ -n "$NAME" ] || { echo "✘ --unit, --name 은 필수입니다" >&2; exit 2; }
case "$DIALECT" in postgres|mysql) ;; *) echo "✘ --dialect 는 postgres|mysql" >&2; exit 2;; esac
case "$SOURCE" in dbml|migrations) ;; *) echo "✘ --source 는 dbml|migrations" >&2; exit 2;; esac
[ "$SOURCE" = "migrations" ] && [ -z "$MIGRATE_CMD" ] && { echo "✘ --source migrations 에는 --migrate-cmd 가 필요합니다" >&2; exit 2; }
printf '%s' "$NAME" | grep -Eq '^[A-Za-z0-9_-]+$' || { echo "✘ --name 은 영문·숫자·_·- 만 사용" >&2; exit 2; }

ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ROOT="$(cd "$ROOT" && pwd -P)"
UNIT="${UNIT%/}"; UNIT="${UNIT#./}"; [ -z "$UNIT" ] && UNIT="."
U="$ROOT/$UNIT"
WARN=0
say() { echo "$1 ${2#$ROOT/}${3:+ ($3)}"; }
do_() { [ $DRY = 1 ] || "$@"; }

# 파일 복사 (없을 때만). 있으면 같으면 '=', 다르면 '!'(스크립트는 --update-scripts 시 교체)
place() { # place <템플릿 상대경로> <대상 절대경로> [script]
  local src="$TPL/$1" dst="$2" kind="${3:-}"
  if [ ! -e "$dst" ]; then
    do_ mkdir -p "$(dirname "$dst")"; do_ cp "$src" "$dst"; say "+" "$dst"
  elif cmp -s "$src" "$dst"; then
    say "=" "$dst"
  elif [ "$kind" = "script" ] && [ $UPDATE_SCRIPTS = 1 ]; then
    do_ cp "$src" "$dst"; say "~" "$dst" "플러그인 최신 버전으로 교체"
  elif [ "$kind" = "script" ]; then
    say "!" "$dst" "플러그인 버전과 다름 — 갱신하려면 --update-scripts"; WARN=1
  else
    say "=" "$dst" "이미 있음, 유지"
  fi
}

# 템플릿 치환 후 생성 (없을 때만)
render() { # render <템플릿 상대경로> <대상> <sed 식...>
  local src="$TPL/$1" dst="$2"; shift 2
  if [ -e "$dst" ]; then say "=" "$dst" "이미 있음, 유지"; return; fi
  do_ mkdir -p "$(dirname "$dst")"
  # 치환식이 없으면 그대로 복사 (sed 에 식 없이 파일만 주면 파일을 스크립트로 읽고 stdin 을 기다린다)
  if [ $DRY = 0 ]; then if [ $# -eq 0 ]; then cp "$src" "$dst"; else sed "$@" "$src" > "$dst"; fi; fi
  say "+" "$dst"
}

echo "# erd 템플릿 설치: 단위 '$UNIT' (루트 $ROOT)"
[ -d "$U" ] || { do_ mkdir -p "$U"; say "+" "$U/" "단위 폴더 생성"; }

# ── 레포 루트 (한 번) ─────────────────────────────────
place scripts/erd-doc.sh "$ROOT/scripts/erd-doc.sh" script
place scripts/erd-changed.sh "$ROOT/scripts/erd-changed.sh" script
[ $DRY = 1 ] || chmod +x "$ROOT/scripts/erd-doc.sh" "$ROOT/scripts/erd-changed.sh"
place erd.mk "$ROOT/erd.mk" script
if [ -f "$ROOT/Makefile" ]; then
  if grep -Eq '^[[:space:]]*-?include[[:space:]]+erd\.mk' "$ROOT/Makefile"; then say "=" "$ROOT/Makefile" "include erd.mk 있음"
  else [ $DRY = 1 ] || printf '\ninclude erd.mk\n' >> "$ROOT/Makefile"; say "~" "$ROOT/Makefile" "include erd.mk 추가"; fi
else
  [ $DRY = 1 ] || printf 'include erd.mk\n' > "$ROOT/Makefile"; say "+" "$ROOT/Makefile"
fi
place ERD_GUIDE.md "$ROOT/docs/ERD_GUIDE.md"
if [ -f "$ROOT/.gitignore" ] && grep -qx 'dbml-error.log' "$ROOT/.gitignore"; then say "=" "$ROOT/.gitignore"
else [ $DRY = 1 ] || printf 'dbml-error.log\n' >> "$ROOT/.gitignore"; say "~" "$ROOT/.gitignore" "dbml-error.log 추가"; fi

# ── 단위 폴더 ────────────────────────────────────────
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }   # 셸용 작은따옴표 인용 (bash 3.2 의 ${v//} 따옴표 처리 차이를 피해 sed 사용)
if [ -e "$U/erd.env" ]; then
  say "=" "$U/erd.env" "이미 있음, 유지 — 값 변경은 직접 편집"
else
  render erd.env "$U/erd.env" -e "s|^ERD_DIALECT=.*|ERD_DIALECT=$DIALECT|" -e "s|^ERD_SOURCE=.*|ERD_SOURCE=$SOURCE|"
  if [ $DRY = 0 ]; then
    tmp="$(mktemp)"
    MC="ERD_MIGRATE_CMD=$( [ -n "$MIGRATE_CMD" ] && shq "$MIGRATE_CMD" )" RS="ERD_RELATED_SOURCES=$( [ -n "$RELATED" ] && shq "$RELATED" )" \
      awk '/^ERD_MIGRATE_CMD=/ { print ENVIRON["MC"]; next } /^ERD_RELATED_SOURCES=/ { print ENVIRON["RS"]; next } { print }' "$U/erd.env" > "$tmp"
    cat "$tmp" > "$U/erd.env"; rm -f "$tmp"
  fi
fi
if [ -e "$U/.tbls.yml" ]; then
  say "=" "$U/.tbls.yml" "이미 있음, 유지"
else
  render .tbls.yml "$U/.tbls.yml" -e "s/__PROJECT_NAME__/$NAME/"
  if [ "$SOURCE" = "migrations" ] && [ $DRY = 0 ]; then
    cat >> "$U/.tbls.yml" <<'EOF'

# ORM/마이그레이션 도구의 관리용 테이블은 문서에서 제외
exclude:
  - alembic_version
  - django_migrations
  - _prisma_migrations
  - __drizzle_migrations
  - typeorm_metadata
  - SequelizeMeta
  - knex_migrations
  - knex_migrations_lock
  - flyway_schema_history
  - databasechangelog
  - databasechangeloglock
  - schema_migrations
  - ar_internal_metadata
  - __EFMigrationsHistory
  - goose_db_version
  - atlas_schema_revisions
EOF
  fi
fi
if [ "$SOURCE" = "dbml" ]; then
  DBT=$([ "$DIALECT" = "mysql" ] && echo MySQL || echo PostgreSQL)
  render db/schema.dbml "$U/db/schema.dbml" -e "s/__PROJECT_NAME__/$NAME/" -e "s/__DB_TYPE__/$DBT/"
  if ls "$U"/db/modules/*.dbml >/dev/null 2>&1; then say "=" "$U/db/modules/" "모듈 파일 있음, 예시 생략"
  else render db/modules/_example.dbml "$U/db/modules/_example.dbml"; fi
fi

# ── 에이전트 지침 (마커 블록: 항상 최신으로 교체) ─────
agent_file() { # CLAUDE.md 우선, 없고 AGENTS.md 만 있으면 그것
  if [ -f "$1/CLAUDE.md" ] || [ ! -f "$1/AGENTS.md" ]; then echo "$1/CLAUDE.md"; else echo "$1/AGENTS.md"; fi
}
P_ARG=$([ "$UNIT" = "." ] && echo "" || echo " P=$UNIT")
if [ "$SOURCE" = "dbml" ]; then
  ORIGIN="db/modules/*.dbml (DBML 이 설계 원본)"
  GEN="db/schema.sql, docs/schema/"
else
  ORIGIN="ORM 모델·마이그레이션 (\`$MIGRATE_CMD\`). DBML(db/schema.generated.dbml)은 파생물"
  GEN="db/schema.generated.dbml, docs/schema/"
fi
UNIT_BLOCK="$(cat <<EOF
## DB 스키마 (erd 플러그인)
- 이 폴더는 ERD 단위다 (\`erd.env\`, $DIALECT). 스키마 원본: $ORIGIN.
- 스키마를 바꾸면 레포 루트에서 \`make erd$P_ARG\` 로 docs/schema 를 갱신하고 같은 커밋에 포함한다.
- 생성물은 직접 수정하지 않는다: $GEN.
- 구조 파악: docs/schema/README.md, 모듈별 docs/schema/viewpoint-*.md, 기계용 docs/schema/schema.json.
- 설계·수정 /erd:design, 검토 /erd:review, 동기화 /erd:sync.
EOF
)"
if [ $DRY = 1 ]; then say "~" "$(agent_file "$U")" "erd:unit 블록 (dry-run)"
else printf '%s\n' "$UNIT_BLOCK" | bash "$INJECT" "$(agent_file "$U")" erd:unit - | sed "s#$ROOT/##"; fi

# 모노레포(루트가 아닌 단위가 있음)면 루트에 단위 목록 블록
UNITS="$(find "$ROOT" -name erd.env -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sed -E "s#^$ROOT/?##; s#/?erd\.env\$##" | sed 's#^$#.#' | sort)"
if [ "$UNIT" != "." ] || [ "$(printf '%s\n' "$UNITS" | grep -c .)" -gt 1 ]; then
  LIST="$(for u in $UNITS; do d=$(grep -h '^ERD_DIALECT=' "$ROOT/$u/erd.env" 2>/dev/null | cut -d= -f2); s=$(grep -h '^ERD_SOURCE=' "$ROOT/$u/erd.env" 2>/dev/null | cut -d= -f2); echo "  - \`$u\` ($d, $s)"; done)"
  ROOT_BLOCK="$(cat <<EOF
## ERD 단위 (erd 플러그인)
- 단위 = DB 하나 = erd.env 가 있는 폴더. 각 단위 폴더의 CLAUDE.md(또는 AGENTS.md)에 세부 규칙이 있다.
$LIST
- 전체 문서 갱신: \`make erd\`, 하나만: \`make erd P=<단위>\`, 목록: \`make erd-list\`.
EOF
)"
  if [ $DRY = 1 ]; then say "~" "$(agent_file "$ROOT")" "erd:units 블록 (dry-run)"
  else printf '%s\n' "$ROOT_BLOCK" | bash "$INJECT" "$(agent_file "$ROOT")" erd:units - | sed "s#$ROOT/##"; fi
fi

echo "INSTALL_RESULT=$([ $WARN = 0 ] && echo ok || echo warn)"
