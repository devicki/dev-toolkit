#!/usr/bin/env bash
# 레포 구조를 보고 ERD 단위(= DB 하나 = erd.env 하나)를 찾는다. (읽기 전용, 항상 exit 0)
# 사용법: find-units.sh [시작 위치(기본: 현재 폴더)]
# 출력: 레포 루트, 모노레포 여부, 기존 단위, 현재 위치의 대상 단위, 새 단위 후보
set -u
set -f
START="$(cd "${1:-.}" 2>/dev/null && pwd || pwd)"
ROOT="$(git -C "$START" rev-parse --show-toplevel 2>/dev/null || echo "$START")"
cd "$ROOT" || exit 0

PRUNE='-name node_modules -o -name .git -o -name vendor -o -name .venv -o -name venv -o -name dist -o -name build -o -name target -o -name .next -o -name .turbo'
ffind() { find . -maxdepth "${1:-6}" \( $PRUNE \) -prune -o "${@:2}" -print 2>/dev/null; }
rel() { local p="${1#./}"; echo "${p:-.}"; }

# 마커 파일 → 그 파일을 소유한 패키지/서비스 루트(가장 가까운 매니페스트 폴더)로 올림
MANIFESTS="package.json pyproject.toml setup.py requirements.txt go.mod pom.xml build.gradle build.gradle.kts composer.json Gemfile Cargo.toml"
pkg_root() {
  local d; d="$(dirname "$1")"
  while :; do
    for m in $MANIFESTS; do [ -f "$d/$m" ] && { rel "$d"; return; }; done
    [ -n "$(find "$d" -maxdepth 1 -name '*.csproj' -print -quit 2>/dev/null)" ] && { rel "$d"; return; }
    [ "$d" = "." ] && { echo "."; return; }
    d="$(dirname "$d")"
  done
}

echo "# ERD 단위 탐색"
echo "레포 루트: $ROOT"
echo

echo "## 모노레포 단서"
MONO=0
for m in pnpm-workspace.yaml turbo.json nx.json lerna.json rush.json go.work settings.gradle settings.gradle.kts; do
  [ -f "$m" ] && { echo "- $m"; MONO=1; }
done
grep -q '"workspaces"' package.json 2>/dev/null && { echo "- package.json workspaces"; MONO=1; }
grep -q '^\[tool.uv.workspace\]\|^\[tool.poetry.packages\]' pyproject.toml 2>/dev/null && { echo "- pyproject workspace"; MONO=1; }
grep -q '<modules>' pom.xml 2>/dev/null && { echo "- maven multi-module"; MONO=1; }
for d in apps services packages modules backend frontend; do
  [ -d "$d" ] && [ "$(find "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)" -ge 1 ] && echo "- $d/ ($(find "$d" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')개 하위 폴더)"
done
[ $MONO = 0 ] && echo "- 워크스페이스 설정 없음"
echo

echo "## 기존 ERD 단위 (erd.env)"
EXIST="$(ffind 8 -name erd.env -type f | sed 's#/erd.env$##' | sort)"
if [ -n "$EXIST" ]; then
  for u in $EXIST; do
    printf -- '- %-28s %s\n' "$(rel "$u")" "$(grep -hE '^ERD_(DIALECT|SOURCE)=' "$u/erd.env" | tr '\n' ' ')"
  done
else
  echo "- 없음"
fi
echo

echo "## 현재 위치의 대상 단위"
d="$START"; TARGET=""
while :; do
  [ -f "$d/erd.env" ] && { TARGET="$d"; break; }
  { [ "$d" = "$ROOT" ] || [ "$d" = "/" ]; } && break
  d="$(dirname "$d")"
done
if [ -n "$TARGET" ]; then
  echo "- $(rel ".${TARGET#$ROOT}")  (현재 위치에서 가장 가까운 erd.env)"
else
  n=$(printf '%s' "$EXIST" | grep -c . || true)
  case "$n" in
    0) echo "- 없음 (아직 세팅 전 → /erd:init)";;
    1) echo "- $(rel "$EXIST")  (레포에 단위가 하나뿐)";;
    *) echo "- 미정: 단위가 ${n}개 → 사용자에게 고르게 하거나 --project <폴더> 로 지정";;
  esac
fi
echo

echo "## 새 단위 후보 (DB 스키마 단서가 있는 서비스 폴더)"
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

if [ -n "$(printf '%s' "$CANDS" | grep -v '^$')" ]; then
  printf '%s\n' "$CANDS" | grep -v '^$' | sort -u | awk -F'|' '
    { if ($1 in tools) tools[$1] = tools[$1] ", " $2; else tools[$1] = $2 }
    END { for (k in tools) printf "%s|%s\n", k, tools[k] }' | sort | while IFS='|' read -r dir tools; do
      mark=""; for u in $EXIST; do [ "$(rel "$u")" = "$dir" ] && mark="  ← 이미 단위"; done
      printf -- '- %-28s %s%s\n' "$dir" "$tools" "$mark"
    done
else
  echo "- 스키마 단서 없음 (신규 설계라면 레포 루트 또는 백엔드 폴더 하나를 단위로)"
fi
echo
echo "## DB 없는 소스 폴더 (참고용: 화면·API)"
for f in $(ffind 4 -type f -name package.json -exec grep -qE '"(react|vue|next|nuxt|svelte|@angular/core)"' {} \;); do
  echo "- $(pkg_root "$f")  (프론트엔드)"
done | sort -u
exit 0
