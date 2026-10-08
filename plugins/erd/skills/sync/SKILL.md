---
name: sync
description: ERD를 최신 상태로 유지한다 — tbls 문서 재생성, 문서·DBML·ORM 모델·실제 DB 간 차이(drift) 점검, DBML 변경분 마이그레이션 생성 연동(Atlas/Alembic 등), CI 검사 설정. "ERD 최신화", "문서 갱신", "스키마랑 코드 차이 확인", "마이그레이션 만들어줘", "CI에 erd 검사 추가"에 사용.
argument-hint: "[doc|drift|migrate|ci]"
---

# /erd:sync — 동기화와 유지보수

공용 자료: `${CLAUDE_PLUGIN_ROOT}/shared/references/` — `source-of-truth.md`, `migration-tools.md`, `tbls-guide.md`

`erd.env` 가 없으면 `/erd:init` 부터 진행한다. 인자가 없으면 `doc` → `drift` 순으로 수행하고, 필요할 때 `migrate`/`ci` 를 제안한다.

## doc — 문서 갱신
1. `make erd` (기존 서버 사용 시 `make erd PG=...`). 임시 DB 수단(Docker/psql)이 없으면 `/erd:doctor` 안내.
2. 결과 요약: 변경된 문서(`git status docs/schema`), lint 경고.
3. 새 테이블이 어느 viewpoint 에도 없으면(requireViewpoints 경고) 소속 모듈을 제안하고 `.tbls.yml` 에 추가 → 재실행.

## drift — 차이 점검
원본 종류에 따라 비교 대상을 고른다. 각 차이는 `항목 | 원본 쪽 | 비교 대상 쪽 | 조치 제안` 표로 보고한다.

| 비교 | 방법 |
|---|---|
| 문서 ↔ 원본 | `make erd-check` (다르면 doc 수행 제안) |
| ORM 모델 ↔ 마이그레이션 (migrations) | 도구의 확인 명령 사용: `alembic check`, `python manage.py makemigrations --check --dry-run`, `npx prisma migrate diff ...`(설치된 Prisma 버전의 `--help` 로 옵션 확인) 등. 없으면 모델 코드와 `docs/schema` 를 직접 대조 |
| DBML ↔ 백엔드 엔티티 (dbml) | 엔티티/모델 코드를 읽어 테이블·컬럼·타입·null·관계 대조 |
| 원본 ↔ 실제 개발/운영 DB | 사용자가 접속 정보를 줄 때만. `tbls diff '<DSN>' docs/schema` (읽기 전용 계정 권장) |

조치는 제안만 하고, 어느 쪽을 맞출지는 사용자가 정한다 (원본이 항상 옳다고 가정하지 않는다 — 운영 DB 에만 있는 긴급 수정일 수 있음).

## migrate — DB 반영용 마이그레이션 (ERD_SOURCE=dbml)
`migration-tools.md` 의 "ERD_SOURCE=dbml 일 때 DB 반영" 을 따른다.
1. 프로젝트에 마이그레이션 디렉터리/도구가 있는지 확인. 없으면 선택지를 제시: (a) 개발 초기라 `db/schema.sql` 재생성으로 충분 (b) Atlas 도입 (c) 사람이 작성. 도입 결정은 사용자.
2. Atlas 사용 시: `atlas migrate diff <이름> --dir file://db/migrations --to file://db/schema.sql --dev-url docker://postgres/16/dev` (MySQL: `docker://mysql/8/dev`).
3. 생성된 SQL 을 검토해 위험 요소(DROP, rename 이 drop+add 로 나온 경우, NOT NULL 추가 시 기존 데이터)를 보고한다. **대상 DB 에 적용은 사용자가 직접** 하거나 명시적으로 요청할 때만.

ERD_SOURCE=migrations 이면 이 단계 대신 프로젝트 도구의 마이그레이션 생성 명령을 안내/실행한다(사용자 확인 후).

## ci — 자동 검사
CI 에 `make erd-check` 를 추가한다(사용자 확인 후). GitHub Actions 예:

```yaml
name: erd
on: [pull_request]
jobs:
  erd-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm install -g @dbml/cli
      - run: |
          V=1.96.1
          curl -sSL https://github.com/k1LoW/tbls/releases/download/v$V/tbls_v${V}_linux_amd64.tar.gz | sudo tar xz -C /usr/local/bin tbls
      - run: make erd-check
```
(ERD_SOURCE=migrations 이면 마이그레이션 실행에 필요한 언어 런타임·의존성 설치 단계를 추가한다.)
GitLab 등 다른 CI 면 같은 단계를 그 형식으로 옮긴다.

## 마무리 보고
수행한 작업, 발견한 차이 수, 사용자가 결정할 항목, 커밋 대상 파일 목록.
