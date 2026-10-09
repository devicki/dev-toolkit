#!/usr/bin/env bash
# Scan a project and summarize the hints needed for ERD work. (Read-only, always exit 0)
# Usage: detect-project.sh [project root]
set -u
set -f   # keep pattern strings from expanding as globs
ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "Path not found: $ROOT"; exit 0; }

EXCL='-not -path */node_modules/* -not -path */.git/* -not -path */vendor/* -not -path */.venv/* -not -path */venv/* -not -path */dist/* -not -path */build/* -not -path */target/* -not -path */.next/*'
f() { find . -maxdepth "${2:-6}" $EXCL -type f -name "$1" 2>/dev/null | head -"${3:-5}"; }
d() { find . -maxdepth "${2:-6}" $EXCL -type d -path "$1" 2>/dev/null | head -"${3:-5}"; }
g() { grep -rIl --exclude-dir={node_modules,.git,vendor,.venv,venv,dist,build,target,.next} -E "$1" . 2>/dev/null | head -"${2:-5}"; }
# Keep only listed files that contain the pattern (BSD/GNU portable: a loop instead of xargs -r)
grepf() { local pat="$1" x; while IFS= read -r x; do [ -n "$x" ] && grep -lE "$pat" "$x" 2>/dev/null; done; }
show() {
  local label="$1"; shift
  local hits; hits=$(printf '%s\n' $* | sed '/^[[:space:]]*$/d' | sort -u | head -8)
  [ -n "$hits" ] || return 0
  echo "- **$label**"; printf '%s\n' "$hits" | sed 's/^/    /'; FOUND=1
}

echo "# Project scan: $(pwd)"
echo

echo "## 1. Existing ERD setup"
FOUND=0
show "DBML files" "$(f '*.dbml')"
show "tbls config" "$(f '.tbls.yml' 3) $(f 'tbls.yml' 3)"
show "tbls generated docs" "$(f 'schema.json' 4 | grepf '"tables"')"
show "erd plugin config (erd.env)" "$(f 'erd.env' 3)"
[ $FOUND = 0 ] && echo "- none (initial setup needed)"
echo

echo "## 2. ORM / migration tools"
FOUND=0
show "Alembic (Python/SQLAlchemy)" "$(f 'alembic.ini') $(d '*/alembic/versions')"
show "SQLAlchemy models" "$(g 'declarative_base|DeclarativeBase|mapped_column|Column\(' 5 | grep -E '\.py$')"
show "Django migrations" "$(f '0001_initial.py' 7)"
show "Prisma" "$(f 'schema.prisma')"
show "Drizzle" "$(f 'drizzle.config.*')"
show "TypeORM" "$(f 'ormconfig*') $(g '@Entity\(' 5 | grep -E '\.ts$')"
show "Sequelize" "$(f '.sequelizerc' 3) $(d '*/seeders')"
show "Knex" "$(f 'knexfile.*')"
show "MikroORM" "$(f 'mikro-orm.config.*')"
show "Flyway" "$(find . -maxdepth 8 $EXCL -type f -name 'V[0-9]*__*.sql' 2>/dev/null | head -5)"
show "Liquibase" "$(f '*changelog*.xml') $(f '*changelog*.yaml') $(f '*changelog*.yml')"
show "JPA/Hibernate entities" "$(g '@Entity|@Table\(' 5 | grep -E '\.(java|kt)$')"
show "MyBatis mappers" "$(f '*Mapper.xml')"
show "Rails" "$(f 'schema.rb' 3) $(d './db/migrate' 3)"
show "Laravel" "$(d './database/migrations' 3)"
show "EF Core" "$(g 'DbContext' 5 | grep -E '\.cs$') $(d '*/Migrations' 4)"
show "golang-migrate / goose" "$(find . -maxdepth 6 $EXCL -type f \( -name '*.up.sql' -o -name '*_*.sql' -path '*migrations*' \) 2>/dev/null | head -5)"
show "Atlas" "$(f 'atlas.hcl' 3)"
show "GORM" "$(g 'gorm\.Model|gorm:\"' 5 | grep -E '\.go$')"
[ $FOUND = 0 ] && echo "- none detected (a setup with DBML as the source of truth fits)"
echo

echo "## 3. Database hints"
FOUND=0
show "PostgreSQL" "$(g 'postgres(ql)?://|psycopg|asyncpg|pg_|\"pg\"|org\.postgresql|provider *= *\"postgresql\"' 5)"
show "MySQL/MariaDB" "$(g 'mysql://|mariadb|pymysql|mysql2|com\.mysql|provider *= *\"mysql\"' 5)"
show "SQLite" "$(g 'sqlite:|sqlite3|provider *= *\"sqlite\"' 5)"
show "SQL Server/Oracle" "$(g 'sqlserver|mssql|oracle' 3)"
show "docker-compose DB services" "$(f 'docker-compose*.yml' 3 | grepf 'image: *(postgres|mysql|mariadb)') $(f 'compose*.yml' 3 | grepf 'image: *(postgres|mysql|mariadb)')"
[ $FOUND = 0 ] && echo "- no hints (ask the user)"
echo

echo "## 4. UI/API sources (entity candidates)"
FOUND=0
show "Frontend" "$(f 'package.json' 3 | grepf '"(react|vue|next|nuxt|svelte|@angular/core)"')"
show "API specs" "$(f 'openapi*.y*ml') $(f 'openapi*.json') $(f 'swagger*.y*ml') $(f 'swagger*.json') $(f '*.graphql')"
show "DTO/schemas (TS)" "$(g 'interface [A-Z][A-Za-z]+(Dto|Request|Response)|z\.object\(' 5 | grep -E '\.tsx?$')"
show "DTO/schemas (Python)" "$(g 'class [A-Z][A-Za-z]+\((BaseModel|Schema)\)' 5 | grep -E '\.py$')"
show "DTO (Java/Kotlin)" "$(g 'class [A-Z][A-Za-z]+(Dto|Request|Response)' 5 | grep -E '\.(java|kt)$')"
[ $FOUND = 0 ] && echo "- none"
echo

echo "## 5. Design docs"
FOUND=0
show "ADR" "$(d '*adr*' 4) $(d '*decisions*' 4)"
show "ERD/DB design docs" "$(find . -maxdepth 5 $EXCL -type f \( -iname '*erd*' -o -iname '*schema*.md' -o -iname '*database*.md' -o -iname '*data-model*' -o -iname '*테이블*' -o -iname '*데이터*' \) 2>/dev/null | grep -v '\.dbml$' | head -8)"
show "OpenSpec" "$(d './openspec' 2)"
show "Agent instructions" "$(f 'CLAUDE.md' 3) $(f 'AGENTS.md' 3)"
[ $FOUND = 0 ] && echo "- none"
exit 0
