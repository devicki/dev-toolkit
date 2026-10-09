#!/usr/bin/env bash
# Install ERD management templates (helper for /erd:init only). Safe to re-run (idempotent).
#
# Usage:
#   install-templates.sh --unit <unit folder (relative to repo root; . for a single repo)> --name <name> \
#       --dialect <postgres|mysql> --source <dbml|migrations> [--lang <ko|en>] \
#       [--migrate-cmd '<command>'] [--related 'apps/web,apps/admin'] [--root <repo root>] \
#       [--update-scripts] [--dry-run]
#
# What it does
#   Repo root (once): scripts/erd-doc.sh, scripts/erd-changed.sh, erd.mk, Makefile include, docs/ERD_GUIDE.md, .gitignore
#   Unit folder:      erd.env (values filled), .tbls.yml (name, migration-table excludes), db/ (dbml only)
#   Agent guidance:   marker block in the unit's CLAUDE.md (or AGENTS.md); in a monorepo, a unit-list block at the root
# Language (--lang): human-facing files and agent blocks are written in ko or en and ERD_LANG is recorded in erd.env.
#   Without --lang: the unit's existing ERD_LANG → another unit's ERD_LANG → en.
#   An existing erd.env without ERD_LANG gets it added only when --lang is given (otherwise '!').
# Rules
#   - Never overwrite existing files, except marker blocks, which are always replaced with the latest content.
#   - If scripts/erd-doc.sh, erd-changed.sh or erd.mk differ from the plugin version, report '!' and replace only with --update-scripts.
# Output: one line each: '+ created', '= unchanged', '~ updated', '! needs attention'. Last line 'INSTALL_RESULT=ok|warn'
# Exit codes: 0 success (including warnings) | 2 bad arguments
set -euo pipefail

TPL="$(cd "$(dirname "$0")/../templates" && pwd)"
INJECT="$(cd "$(dirname "$0")" && pwd)/inject-block.sh"
ROOT="" UNIT="" NAME="" DIALECT="" SOURCE="" MIGRATE_CMD="" RELATED="" LANG_ARG="" UPDATE_SCRIPTS=0 DRY=0
usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2;; --unit) UNIT="$2"; shift 2;; --name) NAME="$2"; shift 2;;
    --dialect) DIALECT="$2"; shift 2;; --source) SOURCE="$2"; shift 2;; --lang) LANG_ARG="$2"; shift 2;;
    --migrate-cmd) MIGRATE_CMD="$2"; shift 2;; --related) RELATED="$2"; shift 2;;
    --update-scripts) UPDATE_SCRIPTS=1; shift;; --dry-run) DRY=1; shift;;
    -h|--help) usage;; *) echo "unknown argument: $1" >&2; usage;;
  esac
done
[ -n "$UNIT" ] && [ -n "$NAME" ] || { echo "✘ --unit and --name are required" >&2; exit 2; }
case "$DIALECT" in postgres|mysql) ;; *) echo "✘ --dialect must be postgres|mysql" >&2; exit 2;; esac
case "$SOURCE" in dbml|migrations) ;; *) echo "✘ --source must be dbml|migrations" >&2; exit 2;; esac
case "$LANG_ARG" in ""|ko|en) ;; *) echo "✘ --lang must be ko|en" >&2; exit 2;; esac
[ "$SOURCE" = "migrations" ] && [ -z "$MIGRATE_CMD" ] && { echo "✘ --source migrations requires --migrate-cmd" >&2; exit 2; }
printf '%s' "$NAME" | grep -Eq '^[A-Za-z0-9_-]+$' || { echo "✘ --name may only use letters, digits, _ and -" >&2; exit 2; }

ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ROOT="$(cd "$ROOT" && pwd -P)"
UNIT="${UNIT%/}"; UNIT="${UNIT#./}"; [ -z "$UNIT" ] && UNIT="."
U="$ROOT/$UNIT"
WARN=0
say() { echo "$1 ${2#$ROOT/}${3:+ ($3)}"; }
do_() { [ $DRY = 1 ] || "$@"; }
envlang() { { grep -h '^ERD_LANG=' "$1" 2>/dev/null || true; } | head -1 | cut -d= -f2 | tr -d "'\" "; }

# Language: --lang → this unit's erd.env → another unit's erd.env → en
EXIST_LANG="$(envlang "$U/erd.env")"
OTHER_LANG=""
for f in $(find "$ROOT" -name erd.env -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort); do
  OTHER_LANG="$(envlang "$f")"; [ -n "$OTHER_LANG" ] && break
done
L="${EXIST_LANG:-${LANG_ARG:-${OTHER_LANG:-en}}}"
case "$L" in ko|en) ;; *) L=en;; esac
I18N="i18n/$L"

# Copy a file (only if missing). Existing: same → '=', different → '!' (scripts are replaced with --update-scripts)
place() { # place <template path> <target absolute path> [script]
  local src="$TPL/$1" dst="$2" kind="${3:-}"
  if [ ! -e "$dst" ]; then
    do_ mkdir -p "$(dirname "$dst")"; do_ cp "$src" "$dst"; say "+" "$dst"
  elif cmp -s "$src" "$dst"; then
    say "=" "$dst"
  elif [ "$kind" = "script" ] && [ $UPDATE_SCRIPTS = 1 ]; then
    do_ cp "$src" "$dst"; say "~" "$dst" "replaced with the plugin version"
  elif [ "$kind" = "script" ]; then
    say "!" "$dst" "differs from the plugin version — pass --update-scripts to update"; WARN=1
  else
    say "=" "$dst" "exists, kept"
  fi
}

# Create from a template with substitutions (only if missing)
render() { # render <template path> <target> <sed expressions...>
  local src="$TPL/$1" dst="$2"; shift 2
  if [ -e "$dst" ]; then say "=" "$dst" "exists, kept"; return; fi
  do_ mkdir -p "$(dirname "$dst")"
  # No expressions → plain copy (sed given only a file reads it as the script and waits on stdin)
  if [ $DRY = 0 ]; then if [ $# -eq 0 ]; then cp "$src" "$dst"; else sed "$@" "$src" > "$dst"; fi; fi
  say "+" "$dst"
}

echo "# erd template install: unit '$UNIT' (root $ROOT, lang $L)"
[ -d "$U" ] || { do_ mkdir -p "$U"; say "+" "$U/" "unit folder created"; }

# ── Repo root (once) ─────────────────────────────────
place scripts/erd-doc.sh "$ROOT/scripts/erd-doc.sh" script
place scripts/erd-changed.sh "$ROOT/scripts/erd-changed.sh" script
[ $DRY = 1 ] || chmod +x "$ROOT/scripts/erd-doc.sh" "$ROOT/scripts/erd-changed.sh"
place erd.mk "$ROOT/erd.mk" script
if [ -f "$ROOT/Makefile" ]; then
  if grep -Eq '^[[:space:]]*-?include[[:space:]]+erd\.mk' "$ROOT/Makefile"; then say "=" "$ROOT/Makefile" "include erd.mk present"
  else [ $DRY = 1 ] || printf '\ninclude erd.mk\n' >> "$ROOT/Makefile"; say "~" "$ROOT/Makefile" "added include erd.mk"; fi
else
  [ $DRY = 1 ] || printf 'include erd.mk\n' > "$ROOT/Makefile"; say "+" "$ROOT/Makefile"
fi
place "$I18N/ERD_GUIDE.md" "$ROOT/docs/ERD_GUIDE.md"
if [ -f "$ROOT/.gitignore" ] && grep -qx 'dbml-error.log' "$ROOT/.gitignore"; then say "=" "$ROOT/.gitignore"
else [ $DRY = 1 ] || printf 'dbml-error.log\n' >> "$ROOT/.gitignore"; say "~" "$ROOT/.gitignore" "added dbml-error.log"; fi

# ── Unit folder ──────────────────────────────────────
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }   # single-quote for the shell (sed avoids bash 3.2 ${v//} quoting differences)
if [ -e "$U/erd.env" ]; then
  say "=" "$U/erd.env" "exists, kept — edit values by hand"
  if [ -z "$EXIST_LANG" ] && [ -n "$LANG_ARG" ]; then
    [ $DRY = 1 ] || printf '\n# Language for docs, comments and agent instructions: ko | en\nERD_LANG=%s\n' "$L" >> "$U/erd.env"
    say "~" "$U/erd.env" "added ERD_LANG=$L"
  elif [ -z "$EXIST_LANG" ]; then
    say "!" "$U/erd.env" "ERD_LANG not set (messages default to en) — re-run with --lang ko|en"; WARN=1
  elif [ -n "$LANG_ARG" ] && [ "$LANG_ARG" != "$EXIST_LANG" ]; then
    say "!" "$U/erd.env" "ERD_LANG=$EXIST_LANG kept (--lang $LANG_ARG ignored) — edit erd.env to change"; WARN=1
  fi
else
  render "$I18N/erd.env" "$U/erd.env" -e "s|^ERD_DIALECT=.*|ERD_DIALECT=$DIALECT|" -e "s|^ERD_SOURCE=.*|ERD_SOURCE=$SOURCE|"
  if [ $DRY = 0 ]; then
    tmp="$(mktemp)"
    MC="ERD_MIGRATE_CMD=$( [ -n "$MIGRATE_CMD" ] && shq "$MIGRATE_CMD" )" RS="ERD_RELATED_SOURCES=$( [ -n "$RELATED" ] && shq "$RELATED" )" \
      awk '/^ERD_MIGRATE_CMD=/ { print ENVIRON["MC"]; next } /^ERD_RELATED_SOURCES=/ { print ENVIRON["RS"]; next } { print }' "$U/erd.env" > "$tmp"
    cat "$tmp" > "$U/erd.env"; rm -f "$tmp"
  fi
fi
if [ -e "$U/.tbls.yml" ]; then
  say "=" "$U/.tbls.yml" "exists, kept"
else
  render "$I18N/.tbls.yml" "$U/.tbls.yml" -e "s/__PROJECT_NAME__/$NAME/"
  if [ "$SOURCE" = "migrations" ] && [ $DRY = 0 ]; then
    if [ "$L" = ko ]; then printf '\n# ORM/마이그레이션 도구의 관리용 테이블은 문서에서 제외\n' >> "$U/.tbls.yml"
    else printf '\n# Exclude ORM/migration bookkeeping tables from the docs\n' >> "$U/.tbls.yml"; fi
    cat >> "$U/.tbls.yml" <<'EOF'
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
  render "$I18N/db/schema.dbml" "$U/db/schema.dbml" -e "s/__PROJECT_NAME__/$NAME/" -e "s/__DB_TYPE__/$DBT/"
  if ls "$U"/db/modules/*.dbml >/dev/null 2>&1; then say "=" "$U/db/modules/" "module files present, example skipped"
  else render "$I18N/db/modules/_example.dbml" "$U/db/modules/_example.dbml"; fi
fi

# ── Agent guidance (marker blocks, always replaced with the latest) ─
agent_file() { # CLAUDE.md first; AGENTS.md only if it exists and CLAUDE.md does not
  if [ -f "$1/CLAUDE.md" ] || [ ! -f "$1/AGENTS.md" ]; then echo "$1/CLAUDE.md"; else echo "$1/AGENTS.md"; fi
}
P_ARG=$([ "$UNIT" = "." ] && echo "" || echo " P=$UNIT")
if [ "$L" = ko ]; then
  TABLE_DOC=$([ "$DIALECT" = "mysql" ] && echo "<테이블>.md" || echo "public.<테이블>.md")
  if [ "$SOURCE" = "dbml" ]; then
    ORIGIN="db/modules/*.dbml (DBML 이 설계 원본)"; GEN="db/schema.sql, docs/schema/"; OVERVIEW="db/schema.dbml(+ db/modules/)"
    NOTE_LINE="- 테이블·컬럼 설명과 ADR 참조는 DBML note 에 쓴다."
  else
    ORIGIN="ORM 모델·마이그레이션 (\`$MIGRATE_CMD\`). DBML(db/schema.generated.dbml)은 파생물"; GEN="db/schema.generated.dbml, docs/schema/"; OVERVIEW="db/schema.generated.dbml"
    NOTE_LINE="- 테이블·컬럼 설명과 ADR 참조는 .tbls.yml 의 comments: 에 쓴다 (생성물·ORM 코드 대신)."
  fi
  UNIT_BLOCK="$(cat <<EOF
## DB 스키마 (erd 플러그인)
- 이 폴더는 ERD 단위다 (\`erd.env\`, $DIALECT, ERD_LANG=ko). 스키마 원본: $ORIGIN.
- 스키마를 바꾸면 레포 루트에서 \`make erd$P_ARG\` 로 docs/schema 를 갱신하고 같은 커밋에 포함한다.
- 생성물은 직접 수정하지 않는다: $GEN.
- 테이블·컬럼·관계를 참조하는 작업(쿼리·모델·API/DTO·마이그레이션·화면 폼) 전에 확인: 전체 개요 $OVERVIEW → 모듈 docs/schema/viewpoint-*.md → 테이블 docs/schema/$TABLE_DOC (컬럼·제약·인덱스·관계·ADR 라벨). 추측으로 컬럼을 만들지 않는다.
$NOTE_LINE
- 설계·수정 /erd:design, 검토 /erd:review, 동기화 /erd:sync.
EOF
)"
else
  TABLE_DOC=$([ "$DIALECT" = "mysql" ] && echo "<table>.md" || echo "public.<table>.md")
  if [ "$SOURCE" = "dbml" ]; then
    ORIGIN="db/modules/*.dbml (DBML is the design source)"; GEN="db/schema.sql, docs/schema/"; OVERVIEW="db/schema.dbml (+ db/modules/)"
    NOTE_LINE="- Table/column descriptions and ADR references go in DBML notes."
  else
    ORIGIN="ORM models and migrations (\`$MIGRATE_CMD\`). The DBML (db/schema.generated.dbml) is derived"; GEN="db/schema.generated.dbml, docs/schema/"; OVERVIEW="db/schema.generated.dbml"
    NOTE_LINE="- Table/column descriptions and ADR references go in .tbls.yml comments: (not in generated files or ORM code)."
  fi
  UNIT_BLOCK="$(cat <<EOF
## DB schema (erd plugin)
- This folder is an ERD unit (\`erd.env\`, $DIALECT, ERD_LANG=en). Source of truth: $ORIGIN.
- After changing the schema, run \`make erd$P_ARG\` from the repo root to refresh docs/schema and include it in the same commit.
- Never edit generated files: $GEN.
- Before any work that references tables, columns or relations (queries, models, API/DTOs, migrations, UI forms), check: overview $OVERVIEW → module docs/schema/viewpoint-*.md → table docs/schema/$TABLE_DOC (columns, constraints, indexes, relations, ADR labels). Do not guess columns.
$NOTE_LINE
- Design/changes /erd:design, review /erd:review, sync /erd:sync.
EOF
)"
fi
if [ $DRY = 1 ]; then say "~" "$(agent_file "$U")" "erd:unit block (dry-run)"
else printf '%s\n' "$UNIT_BLOCK" | bash "$INJECT" "$(agent_file "$U")" erd:unit - | sed "s#$ROOT/##"; fi

# Monorepo (a unit other than the root exists): unit-list block at the root
UNITS="$(find "$ROOT" -name erd.env -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sed -E "s#^$ROOT/?##; s#/?erd\.env\$##" | sed 's#^$#.#' | sort)"
if [ "$UNIT" != "." ] || [ "$(printf '%s\n' "$UNITS" | grep -c .)" -gt 1 ]; then
  LIST="$(for u in $UNITS; do d=$(grep -h '^ERD_DIALECT=' "$ROOT/$u/erd.env" 2>/dev/null | cut -d= -f2); s=$(grep -h '^ERD_SOURCE=' "$ROOT/$u/erd.env" 2>/dev/null | cut -d= -f2); echo "  - \`$u\` ($d, $s)"; done)"
  if [ "$L" = ko ]; then
    ROOT_BLOCK="$(printf '%s\n%s\n%s\n%s' "## ERD 단위 (erd 플러그인)" "- 단위 = DB 하나 = erd.env 가 있는 폴더. 각 단위 폴더의 CLAUDE.md(또는 AGENTS.md)에 세부 규칙이 있다." "$LIST" "- 전체 문서 갱신: \`make erd\`, 하나만: \`make erd P=<단위>\`, 목록: \`make erd-list\`.")"
  else
    ROOT_BLOCK="$(printf '%s\n%s\n%s\n%s' "## ERD units (erd plugin)" "- Unit = one DB = a folder with erd.env. Each unit's CLAUDE.md (or AGENTS.md) has the detailed rules." "$LIST" "- Refresh all docs: \`make erd\`, one unit: \`make erd P=<unit>\`, list: \`make erd-list\`.")"
  fi
  if [ $DRY = 1 ]; then say "~" "$(agent_file "$ROOT")" "erd:units block (dry-run)"
  else printf '%s\n' "$ROOT_BLOCK" | bash "$INJECT" "$(agent_file "$ROOT")" erd:units - | sed "s#$ROOT/##"; fi
fi

echo "INSTALL_RESULT=$([ $WARN = 0 ] && echo ok || echo warn)"
