---
name: init
description: 프로젝트에 DBML+tbls 기반 ERD 관리 구조를 처음 세팅한다. 프로젝트를 스캔해 스키마 원본(DBML vs ORM/마이그레이션)을 정하고, 템플릿(erd.env, .tbls.yml, erd.mk, scripts/erd-doc.sh)을 설치한 뒤 다음 단계(design/import)로 이어 준다. "ERD 세팅", "erd 초기화", "이 프로젝트에 ERD 관리 도입"에 사용.
argument-hint: "[프로젝트 경로]"
---

# /erd:init — ERD 관리 구조 세팅

공용 자료: `${CLAUDE_PLUGIN_ROOT}/shared/` (scripts, templates, references)

## 1. 사전 점검
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh` 실행. `MISSING` 에 dbml2sql/tbls 가 있으면 `/erd:doctor` 절차로 먼저 해결할지 묻는다 (세팅 자체는 도구 없이도 진행 가능).
- 이미 `erd.env` 또는 `.tbls.yml` 이 있으면 **새로 세팅하지 말고** 현재 구성을 요약한 뒤 `/erd:sync` 나 `/erd:design` 을 안내한다.

## 2. 프로젝트 스캔
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect-project.sh <프로젝트 루트>` 실행.
- 결과에서 다음을 정리해 사용자에게 보여 준다 (5줄 이내):
  - DB 종류 (단서 없으면 질문)
  - ORM/마이그레이션 도구
  - 참고할 자산: 화면·API 소스, ERD·ADR 문서, 기존 DB

## 3. 스키마 원본 결정
`${CLAUDE_PLUGIN_ROOT}/shared/references/source-of-truth.md` 의 결정표로 `ERD_SOURCE` 를 제안하고 **사용자 확인**을 받는다.
- `migrations` 이면 `${CLAUDE_PLUGIN_ROOT}/shared/references/migration-tools.md` 에서 도구에 맞는 `ERD_MIGRATE_CMD` 를 찾아 제안한다. 프로젝트 설정 파일(alembic env.py, prisma datasource 등)이 `DATABASE_URL` 을 읽는지 확인하고, 아니면 필요한 수정을 제안만 한다(사용자 승인 후 수정).

## 4. 템플릿 설치
템플릿 위치: `${CLAUDE_PLUGIN_ROOT}/shared/templates/`. **기존 파일은 덮어쓰지 않는다.**

| 템플릿 | 설치 위치 | 처리 |
|---|---|---|
| `erd.env` | 프로젝트 루트 | `ERD_DIALECT`, `ERD_SOURCE`, `ERD_MIGRATE_CMD` 채우기 |
| `.tbls.yml` | 프로젝트 루트 | `__PROJECT_NAME__` 치환. migrations 이면 관리용 테이블 `exclude` 추가 |
| `erd.mk` | 프로젝트 루트 | Makefile 이 있으면 끝에 `include erd.mk` 추가(사용자 확인), 없으면 `Makefile` 을 `include erd.mk` 한 줄로 생성 |
| `scripts/erd-doc.sh` | `scripts/erd-doc.sh` | 복사 후 `chmod +x`. `scripts/` 가 다른 용도로 쓰이면 위치를 상의 |
| `ERD_GUIDE.md` | `docs/ERD_GUIDE.md` | 그대로 복사 |
| `db/schema.dbml`, `db/modules/_example.dbml` | `db/` | `ERD_SOURCE=dbml` 일 때만. `__PROJECT_NAME__`, `__DB_TYPE__`(PostgreSQL/MySQL) 치환 |

복사 예: `[ -e erd.env ] || cp ${CLAUDE_PLUGIN_ROOT}/shared/templates/erd.env ./erd.env` (복사한 `scripts/erd-doc.sh` 는 `chmod +x`)
`erd.env` 의 값에 공백이 있으면 작은따옴표로 감싼다 (예: `ERD_MIGRATE_CMD='alembic upgrade head'`).
`.gitignore` 에 `dbml-error.log` 를 추가한다.

## 5. 에이전트 지침 추가
프로젝트의 `CLAUDE.md`(없으면 `AGENTS.md` 확인, 둘 다 없으면 `CLAUDE.md` 생성)에 아래 절을 추가한다(이미 있으면 생략). `ERD_SOURCE` 에 맞는 줄만 남긴다.

```markdown
## DB 스키마 (erd 플러그인)
- 스키마 원본: <dbml: db/modules/*.dbml | migrations: ORM 모델·마이그레이션>. 설정은 erd.env.
- 스키마를 바꾸면 `make erd` 로 docs/schema 를 갱신하고 같은 커밋에 포함한다.
- db/schema.sql, db/schema.generated.dbml, docs/schema/ 는 생성물이므로 직접 수정하지 않는다.
- 현재 구조 파악: docs/schema/README.md, 모듈별 docs/schema/viewpoint-*.md, 기계용 docs/schema/schema.json.
- 설계·수정은 /erd:design, 검토는 /erd:review, 동기화는 /erd:sync.
```

## 6. 첫 문서 생성 또는 다음 단계
- `ERD_SOURCE=migrations`: 바로 `make erd` 실행 → 결과 요약 → viewpoints(모듈) 구성을 제안하고 `.tbls.yml` 에 반영 → 다시 `make erd`.
- `ERD_SOURCE=dbml`:
  - 참고할 자산(화면·API 소스, 문서, 기존 DB)이 있으면 → `/erd:import` 로 이어간다.
  - 아무것도 없으면 → `/erd:design` 의 대화형 초기 설계로 이어간다.
  - `_example.dbml` 은 첫 모듈을 만든 뒤 삭제한다.

## 마무리 보고
설치한 파일 목록, 결정한 `ERD_SOURCE`, 다음에 할 일(명령 1~2개)만 짧게 알린다.
