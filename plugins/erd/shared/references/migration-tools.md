# 마이그레이션·ORM 도구 연동

> 기준: 2026-10 확인. 도구별 명령·옵션은 버전마다 다를 수 있으므로 실행 전 프로젝트에 설치된 버전의 `--help` 로 확인한다.

`scripts/detect-project.sh` 가 찾은 도구에 맞춰 아래 방식으로 연동한다.
공통 원리: **도구가 원본이면 그 도구로 임시 DB에 스키마를 만들고, tbls 가 그 DB를 문서화한다.**
설정은 `erd.env` 의 `ERD_SOURCE=migrations` + `ERD_MIGRATE_CMD` (임시 DB 주소는 `DATABASE_URL` 로 전달됨).

## 도구별 ERD_MIGRATE_CMD

| 도구 | 감지 단서 | ERD_MIGRATE_CMD 예 | 비고 |
|---|---|---|---|
| Alembic | `alembic.ini`, `alembic/versions/` | `alembic upgrade head` | `env.py` 가 `DATABASE_URL` 을 읽는지 확인. 아니면 `alembic -x url=$DATABASE_URL upgrade head` 형태로 env.py 를 맞추도록 제안 |
| Django | `*/migrations/0001_initial.py` | `python manage.py migrate --noinput` | settings 가 `DATABASE_URL`(dj-database-url 등)을 읽어야 함 |
| Prisma | `schema.prisma` | `npx prisma migrate deploy` | `datasource db { url = env("DATABASE_URL") }` 확인. 마이그레이션 폴더가 없으면 `npx prisma db push --skip-generate` |
| Drizzle | `drizzle.config.*` | `npx drizzle-kit migrate` | config 의 dbCredentials 가 env 를 읽는지 확인 |
| TypeORM | `ormconfig*`, `@Entity(` | `npx typeorm migration:run -d <data-source 파일>` | |
| Sequelize | `.sequelizerc` | `npx sequelize-cli db:migrate --url "$DATABASE_URL"` | |
| Knex | `knexfile.*` | `npx knex migrate:latest` | knexfile 이 env 를 읽는지 확인 |
| Flyway | `V1__*.sql` | `flyway -url="$(echo $DATABASE_URL | sed -E 's#^postgres://([^:]+):([^@]+)@([^/?]+)/([^?]+).*#jdbc:postgresql://\3/\4#')" -user=postgres -password=erd -locations=filesystem:<경로> migrate` | JDBC URL 변환 필요. 마이그레이션이 순수 SQL 이면 `for f in $(ls <경로>/V*__*.sql | sort -V); do psql "$DATABASE_URL" -f $f; done` 도 가능 |
| Liquibase | `changelog*.xml/yaml` | `liquibase --url=jdbc:... --changelog-file=<파일> update` | Flyway 와 같은 JDBC 변환 |
| JPA/Hibernate (마이그레이션 없음) | `@Entity` 만 있음 | (원본 불명확) | `ddl-auto` 로 생성되는 구조라면 사용자와 협의. 실행 중인 개발 DB를 `db2dbml` 로 추출 후 `ERD_SOURCE=dbml` 로 전환하는 방안 제시 |
| MyBatis | `*Mapper.xml` | (스키마 원본 아님) | DDL 파일이나 개발 DB 에서 추출 |
| Rails | `db/schema.rb`, `db/migrate/` | `bin/rails db:schema:load` | |
| Laravel | `database/migrations/` | `php artisan migrate --force` | `.env` 의 DB_* 를 DATABASE_URL 에서 나눠 넣어야 할 수 있음 |
| EF Core | `DbContext`, `Migrations/` | `dotnet ef database update --connection "<변환된 연결 문자열>"` | |
| golang-migrate | `*.up.sql` | `migrate -path <경로> -database "$DATABASE_URL" up` | |
| goose | `migrations/*.sql` (goose 주석) | `goose -dir <경로> postgres "$DATABASE_URL" up` | |
| Atlas | `atlas.hcl` | `atlas migrate apply --url "$DATABASE_URL" --dir file://<경로>` | |
| GORM AutoMigrate | `gorm.Model` | (원본 = Go 구조체) | AutoMigrate 를 실행하는 작은 명령을 제안하거나 개발 DB 추출 |

명령이 프로젝트 의존성 설치·가상환경을 필요로 하면(예: `poetry run alembic upgrade head`, `uv run ...`) 그 형태로 쓴다.
`ERD_MIGRATE_CMD` 는 **임시 DB에만** 실행된다. 운영·공유 DB 주소를 넣지 않는다.

## 관리용 테이블 제외 (.tbls.yml `exclude`)

`alembic_version`, `django_migrations`, `django_content_type`(필요 시), `_prisma_migrations`, `__drizzle_migrations`, `typeorm_metadata`, `SequelizeMeta`, `knex_migrations`, `knex_migrations_lock`, `flyway_schema_history`, `databasechangelog`, `databasechangeloglock`, `schema_migrations`, `ar_internal_metadata`, `migrations`(Laravel), `__EFMigrationsHistory`, `goose_db_version`, `atlas_schema_revisions`

## ERD_SOURCE=dbml 일 때 DB 반영 (마이그레이션 생성)

`db/schema.sql` 은 매번 전체 DDL 이다. 실제 DB 에 반영하는 방법은 단계에 따라 다르다.

1. **개발 초기 (데이터 보존 불필요)**: 개발 DB 를 `db/schema.sql` 로 재생성.
2. **데이터 보존 필요 / 운영 DB 존재**: 변경분만 담은 마이그레이션이 필요하다. 마이그레이션 도구가 없다면 Atlas 를 제안한다.
   ```bash
   # 이전 커밋의 schema.sql 대비 변경분 마이그레이션 생성 (Docker 필요)
   atlas migrate diff <변경이름> \
     --dir "file://db/migrations" \
     --to "file://db/schema.sql" \
     --dev-url "docker://postgres/16/dev"
   # 적용
   atlas migrate apply --url "<대상 DB>" --dir "file://db/migrations"
   ```
   - 생성된 SQL 은 **반드시 사람이 검토**한다 (컬럼 rename 이 drop+add 로 나오는 등).
   - 이미 다른 마이그레이션 도구를 도입할 계획이면 그 도구를 우선한다. 도구 도입 여부는 사용자 결정.
3. 마이그레이션 도구를 도입하면 `ERD_SOURCE` 를 `migrations` 로 바꿀지 사용자와 상의한다
   (Atlas 처럼 SQL 원본을 유지하는 방식이면 `dbml` 유지 가능).

## 기존 스키마에서 DBML 뽑기 (import)

| 출처 | 방법 |
|---|---|
| ORM/마이그레이션 | 임시 DB에 적용(`make erd`, ERD_SOURCE=migrations) → `db2dbml` 결과가 `db/schema.generated.dbml` 에 생김 |
| Prisma | 위 방법, 또는 `prisma-dbml-generator` (generator 추가 필요, 사용자 확인) |
| DDL 파일 / dump | `sql2dbml <파일> --postgres -o db/schema.dbml` |
| 실행 중인 DB | `db2dbml postgres '<conn>' -o db/schema.dbml` (읽기 전용 계정 권장) |
| 모델 코드만 (DB 없음) | 코드를 읽고 DBML 을 직접 작성 (mode: import, from-code) |
