#!/usr/bin/env bash
# 프로젝트를 스캔해 ERD 작업에 필요한 단서를 요약한다. (읽기 전용, 항상 exit 0)
# 사용법: detect-project.sh [프로젝트 루트]
set -u
set -f   # 패턴 문자열이 글롭으로 펼쳐지지 않도록
ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "경로 없음: $ROOT"; exit 0; }

EXCL='-not -path */node_modules/* -not -path */.git/* -not -path */vendor/* -not -path */.venv/* -not -path */venv/* -not -path */dist/* -not -path */build/* -not -path */target/* -not -path */.next/*'
f() { find . -maxdepth "${2:-6}" $EXCL -type f -name "$1" 2>/dev/null | head -"${3:-5}"; }
d() { find . -maxdepth "${2:-6}" $EXCL -type d -path "$1" 2>/dev/null | head -"${3:-5}"; }
g() { grep -rIl --exclude-dir={node_modules,.git,vendor,.venv,venv,dist,build,target,.next} -E "$1" . 2>/dev/null | head -"${2:-5}"; }
# 파일 목록 중 패턴을 가진 파일만 (BSD/GNU 공통: xargs -r 대신 루프)
grepf() { local pat="$1" x; while IFS= read -r x; do [ -n "$x" ] && grep -lE "$pat" "$x" 2>/dev/null; done; }
show() {
  local label="$1"; shift
  local hits; hits=$(printf '%s\n' $* | sed '/^[[:space:]]*$/d' | sort -u | head -8)
  [ -n "$hits" ] || return 0
  echo "- **$label**"; printf '%s\n' "$hits" | sed 's/^/    /'; FOUND=1
}

echo "# 프로젝트 스캔: $(pwd)"
echo

echo "## 1. 기존 ERD 관리 상태"
FOUND=0
show "DBML 파일" "$(f '*.dbml')"
show "tbls 설정" "$(f '.tbls.yml' 3) $(f 'tbls.yml' 3)"
show "tbls 생성 문서" "$(f 'schema.json' 4 | grepf '"tables"')"
show "erd 플러그인 설정(erd.env)" "$(f 'erd.env' 3)"
[ $FOUND = 0 ] && echo "- 없음 (초기 구축 대상)"
echo

echo "## 2. ORM / 마이그레이션 도구"
FOUND=0
show "Alembic (Python/SQLAlchemy)" "$(f 'alembic.ini') $(d '*/alembic/versions')"
show "SQLAlchemy 모델" "$(g 'declarative_base|DeclarativeBase|mapped_column|Column\(' 5 | grep -E '\.py$')"
show "Django migrations" "$(f '0001_initial.py' 7)"
show "Prisma" "$(f 'schema.prisma')"
show "Drizzle" "$(f 'drizzle.config.*')"
show "TypeORM" "$(f 'ormconfig*') $(g '@Entity\(' 5 | grep -E '\.ts$')"
show "Sequelize" "$(f '.sequelizerc' 3) $(d '*/seeders')"
show "Knex" "$(f 'knexfile.*')"
show "MikroORM" "$(f 'mikro-orm.config.*')"
show "Flyway" "$(find . -maxdepth 8 $EXCL -type f -name 'V[0-9]*__*.sql' 2>/dev/null | head -5)"
show "Liquibase" "$(f '*changelog*.xml') $(f '*changelog*.yaml') $(f '*changelog*.yml')"
show "JPA/Hibernate 엔티티" "$(g '@Entity|@Table\(' 5 | grep -E '\.(java|kt)$')"
show "MyBatis 매퍼" "$(f '*Mapper.xml')"
show "Rails" "$(f 'schema.rb' 3) $(d './db/migrate' 3)"
show "Laravel" "$(d './database/migrations' 3)"
show "EF Core" "$(g 'DbContext' 5 | grep -E '\.cs$') $(d '*/Migrations' 4)"
show "golang-migrate / goose" "$(find . -maxdepth 6 $EXCL -type f \( -name '*.up.sql' -o -name '*_*.sql' -path '*migrations*' \) 2>/dev/null | head -5)"
show "Atlas" "$(f 'atlas.hcl' 3)"
show "GORM" "$(g 'gorm\.Model|gorm:\"' 5 | grep -E '\.go$')"
[ $FOUND = 0 ] && echo "- 감지되지 않음 (DBML을 원본으로 하는 구성이 적합)"
echo

echo "## 3. DB 종류 단서"
FOUND=0
show "PostgreSQL" "$(g 'postgres(ql)?://|psycopg|asyncpg|pg_|\"pg\"|org\.postgresql|provider *= *\"postgresql\"' 5)"
show "MySQL/MariaDB" "$(g 'mysql://|mariadb|pymysql|mysql2|com\.mysql|provider *= *\"mysql\"' 5)"
show "SQLite" "$(g 'sqlite:|sqlite3|provider *= *\"sqlite\"' 5)"
show "SQL Server/Oracle" "$(g 'sqlserver|mssql|oracle' 3)"
show "docker-compose DB 서비스" "$(f 'docker-compose*.yml' 3 | grepf 'image: *(postgres|mysql|mariadb)') $(f 'compose*.yml' 3 | grepf 'image: *(postgres|mysql|mariadb)')"
[ $FOUND = 0 ] && echo "- 단서 없음 (사용자에게 확인)"
echo

echo "## 4. 화면·API 소스 (엔티티 추출 후보)"
FOUND=0
show "프론트엔드" "$(f 'package.json' 3 | grepf '"(react|vue|next|nuxt|svelte|@angular/core)"')"
show "API 스펙" "$(f 'openapi*.y*ml') $(f 'openapi*.json') $(f 'swagger*.y*ml') $(f 'swagger*.json') $(f '*.graphql')"
show "DTO/스키마 (TS)" "$(g 'interface [A-Z][A-Za-z]+(Dto|Request|Response)|z\.object\(' 5 | grep -E '\.tsx?$')"
show "DTO/스키마 (Python)" "$(g 'class [A-Z][A-Za-z]+\((BaseModel|Schema)\)' 5 | grep -E '\.py$')"
show "DTO (Java/Kotlin)" "$(g 'class [A-Z][A-Za-z]+(Dto|Request|Response)' 5 | grep -E '\.(java|kt)$')"
[ $FOUND = 0 ] && echo "- 없음"
echo

echo "## 5. 설계 문서"
FOUND=0
show "ADR" "$(d '*adr*' 4) $(d '*decisions*' 4)"
show "ERD/DB 설계 문서" "$(find . -maxdepth 5 $EXCL -type f \( -iname '*erd*' -o -iname '*schema*.md' -o -iname '*database*.md' -o -iname '*data-model*' -o -iname '*테이블*' -o -iname '*데이터*' \) 2>/dev/null | grep -v '\.dbml$' | head -8)"
show "OpenSpec" "$(d './openspec' 2)"
show "에이전트 지침" "$(f 'CLAUDE.md' 3) $(f 'AGENTS.md' 3)"
[ $FOUND = 0 ] && echo "- 없음"
exit 0
