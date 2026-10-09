#!/usr/bin/env bash
# 레포 구조를 보고 ERD 단위(= DB 하나 = erd.env 하나)를 찾는다. (읽기 전용, 항상 exit 0)
# 사용법: find-units.sh [--json] [시작 위치(기본: 현재 폴더)]
# 출력: 레포 루트, 모노레포 단서, 기존 단위, 현재 위치의 대상 단위, 새 단위 후보, DB 없는 소스 폴더
set -u
set -f
FMT=text; START_ARG="."
while [ $# -gt 0 ]; do case "$1" in --json) FMT=json; shift;; *) START_ARG="$1"; shift;; esac; done
# 물리 경로로 통일 (macOS: /var → /private/var 처럼 git 은 심볼릭 링크를 푼 경로를 돌려준다)
START="$(cd "$START_ARG" 2>/dev/null && pwd -P || pwd -P)"
ROOT="$(git -C "$START" rev-parse --show-toplevel 2>/dev/null || echo "$START")"
ROOT="$(cd "$ROOT" && pwd -P)"
cd "$ROOT" || exit 0

PRUNE='-name node_modules -o -name .git -o -name vendor -o -name .venv -o -name venv -o -name dist -o -name build -o -name target -o -name .next -o -name .turbo'
ffind() { find . -maxdepth "${1:-6}" \( $PRUNE \) -prune -o "${@:2}" -print 2>/dev/null; }
rel() { local p="${1#./}"; echo "${p:-.}"; }
envval() { grep -h "^$2=" "$1/erd.env" 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^'//; s/'\$//; s/^\"//; s/\"\$//"; }
jstr() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

# 마커 파일 → 그 파일을 소유한 패키지/서비스 루트(가장 가까운 매니페스트 폴더)로 올림
MANIFESTS="package.json pyproject.toml setup.py requirements.txt go.mod pom.xml build.gradle build.gradle.kts composer.json Gemfile Cargo.toml"
pkg_root() {
  local d; d="$(dirname "$1")"
  while :; do
    [ -f "$d/erd.env" ] && { rel "$d"; return; }                       # 이미 단위인 폴더
    case "$(basename "$(dirname "$d")")" in apps|services|packages|modules) rel "$d"; return;; esac   # 워크스페이스 관례 폴더의 하위
    for m in $MANIFESTS; do [ -f "$d/$m" ] && { rel "$d"; return; }; done
    [ -n "$(find "$d" -maxdepth 1 -name '*.csproj' -print -quit 2>/dev/null)" ] && { rel "$d"; return; }
    [ "$d" = "." ] && { echo "."; return; }
    d="$(dirname "$d")"
  done
}

# ── 수집 ─────────────────────────────────────────────
MONO_HINTS=""
for m in pnpm-workspace.yaml turbo.json nx.json lerna.json rush.json go.work settings.gradle settings.gradle.kts; do
  [ -f "$m" ] && MONO_HINTS="$MONO_HINTS|$m"
done
grep -q '"workspaces"' package.json 2>/dev/null && MONO_HINTS="$MONO_HINTS|package.json workspaces"
grep -q '^\[tool.uv.workspace\]\|^\[tool.poetry.packages\]' pyproject.toml 2>/dev/null && MONO_HINTS="$MONO_HINTS|pyproject workspace"
grep -q '<modules>' pom.xml 2>/dev/null && MONO_HINTS="$MONO_HINTS|maven multi-module"
MONO=0; [ -n "$MONO_HINTS" ] && MONO=1
DIR_HINTS=""
for d in apps services packages modules backend frontend; do
  [ -d "$d" ] || continue
  n="$(find "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" -ge 1 ] && DIR_HINTS="$DIR_HINTS|$d/ (${n}개 하위 폴더)"
done

EXIST="$(ffind 8 -name erd.env -type f | sed 's#/erd.env$##' | sort)"
NEXIST=$(printf '%s' "$EXIST" | grep -c . || true)

d="$START"; TARGET=""; REASON=""
while :; do
  [ -f "$d/erd.env" ] && { TARGET="$(rel ".${d#$ROOT}")"; REASON="nearest"; break; }
  { [ "$d" = "$ROOT" ] || [ "$d" = "/" ]; } && break
  d="$(dirname "$d")"
done
if [ -z "$TARGET" ]; then
  case "$NEXIST" in 0) REASON="none";; 1) TARGET="$(rel "$EXIST")"; REASON="only";; *) REASON="ambiguous";; esac
fi

CANDS=""
add() { CANDS="$CANDS
$(pkg_root "$1")|$2"; }
for f in $(ffind 7 -type f \( -name alembic.ini -o -name schema.prisma -o -name 'drizzle.config.*' -o -name 'ormconfig*' -o -name knexfile.js -o -name knexfile.ts -o -name .sequelizerc -o -name 'mikro-orm.config.*' -o -name atlas.hcl -o -name schema.rb -o -name '*.dbml' \)); do
  case "$f" in
    *alembic.ini) add "$f" Alembic;; *schema.prisma) add "$f" Prisma;; *drizzle.config.*) add "$f" Drizzle;;
    *ormconfig*) add "$f" TypeORM;; *knexfile*) add "$f" Knex;; *.sequelizerc) add "$f" Sequelize;;
    *mikro-orm*) add "$f" MikroORM;; *atlas.hcl) add "$f" Atlas;; *schema.rb) add "$f" Rails;; *.dbml) add "$f" DBML;;
  esac
done
for f in $(ffind 9 -type f -name '0001_initial.py'); do add "$f" Django; done
for f in $(ffind 10 -type f -name 'V1__*.sql'); do add "$f" Flyway; done
for f in $(ffind 9 -type f \( -name '*changelog*.xml' -o -name '*changelog*.yaml' -o -name '*changelog*.yml' \)); do add "$f" Liquibase; done
for f in $(ffind 7 -type d -path '*/database/migrations'); do add "$f/x" Laravel; done
for f in $(ffind 8 -type f -name '*.up.sql'); do add "$f" golang-migrate; done
for f in $(ffind 7 -type f -name '*.csproj' -exec grep -q 'EntityFrameworkCore' {} \;); do add "$f" "EF Core"; done
for f in $(ffind 8 -type f \( -name '*.java' -o -name '*.kt' \) -exec grep -q '@Entity' {} \; | head -50); do add "$f" JPA; done
CAND_LINES="$(printf '%s\n' "$CANDS" | grep -v '^$' | sort -u | awk -F'|' '
  { if ($1 in tools) tools[$1] = tools[$1] ", " $2; else tools[$1] = $2 }
  END { for (k in tools) printf "%s|%s\n", k, tools[k] }' | sort)"

FRONT="$(for f in $(ffind 4 -type f -name package.json -exec grep -qE '"(react|vue|next|nuxt|svelte|@angular/core)"' {} \;); do pkg_root "$f"; done | sort -u)"

is_unit() { local u; for u in $EXIST; do [ "$(rel "$u")" = "$1" ] && return 0; done; return 1; }

# ── 출력 ─────────────────────────────────────────────
if [ "$FMT" = json ]; then
  printf '{"root":%s,"monorepo":%s,"monorepo_hints":[' "$(jstr "$ROOT")" "$([ $MONO = 1 ] && echo true || echo false)"
  first=1; IFS='|'; for h in ${MONO_HINTS#|}; do [ -z "$h" ] && continue; [ $first = 1 ] || printf ','; first=0; jstr "$h"; done; unset IFS
  printf '],"units":['
  first=1
  for u in $EXIST; do
    [ $first = 1 ] || printf ','; first=0
    printf '{"path":%s,"dialect":%s,"source":%s,"related":%s}' "$(jstr "$(rel "$u")")" "$(jstr "$(envval "$u" ERD_DIALECT)")" "$(jstr "$(envval "$u" ERD_SOURCE)")" "$(jstr "$(envval "$u" ERD_RELATED_SOURCES)")"
  done
  printf '],"target":%s,"target_reason":%s,"candidates":[' "$([ -n "$TARGET" ] && jstr "$TARGET" || echo null)" "$(jstr "$REASON")"
  first=1
  printf '%s\n' "$CAND_LINES" | while IFS='|' read -r dir tools; do
    [ -z "$dir" ] && continue
    [ $first = 1 ] || printf ','; first=0
    printf '{"path":%s,"tools":%s,"is_unit":%s}' "$(jstr "$dir")" "$(jstr "$tools")" "$(is_unit "$dir" && echo true || echo false)"
  done
  printf '],"frontends":['
  first=1; for f in $FRONT; do [ $first = 1 ] || printf ','; first=0; jstr "$f"; done
  printf ']}\n'
  exit 0
fi

echo "# ERD 단위 탐색"
echo "레포 루트: $ROOT"
echo
echo "## 모노레포 단서"
IFS='|'; for h in ${MONO_HINTS#|} ${DIR_HINTS#|}; do [ -n "$h" ] && echo "- $h"; done; unset IFS
[ -z "$MONO_HINTS$DIR_HINTS" ] && echo "- 워크스페이스 설정 없음"
echo
echo "## 기존 ERD 단위 (erd.env)"
if [ -n "$EXIST" ]; then
  for u in $EXIST; do printf -- '- %-28s ERD_DIALECT=%s ERD_SOURCE=%s\n' "$(rel "$u")" "$(envval "$u" ERD_DIALECT)" "$(envval "$u" ERD_SOURCE)"; done
else
  echo "- 없음"
fi
echo
echo "## 현재 위치의 대상 단위"
case "$REASON" in
  nearest) echo "- $TARGET  (현재 위치에서 가장 가까운 erd.env)";;
  only) echo "- $TARGET  (레포에 단위가 하나뿐)";;
  none) echo "- 없음 (아직 세팅 전 → /erd:init)";;
  ambiguous) echo "- 미정: 단위가 ${NEXIST}개 → 사용자에게 고르게 하거나 --project <폴더> 로 지정";;
esac
echo
echo "## 새 단위 후보 (DB 스키마 단서가 있는 서비스 폴더)"
if [ -n "$CAND_LINES" ]; then
  printf '%s\n' "$CAND_LINES" | while IFS='|' read -r dir tools; do
    printf -- '- %-28s %s%s\n' "$dir" "$tools" "$(is_unit "$dir" && echo '  ← 이미 단위')"
  done
else
  echo "- 스키마 단서 없음 (신규 설계라면 레포 루트 또는 백엔드 폴더 하나를 단위로)"
fi
echo
echo "## DB 없는 소스 폴더 (참고용: 화면·API)"
if [ -n "$FRONT" ]; then for f in $FRONT; do echo "- $f  (프론트엔드)"; done; else echo "- 없음"; fi
exit 0
