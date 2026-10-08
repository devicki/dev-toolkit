---
name: init
description: 프로젝트(단일 레포 또는 모노레포)에 DBML+tbls 기반 ERD 관리 구조를 처음 세팅한다. 레포 구조를 스캔해 ERD 단위(DB별)를 정하고, 단위마다 스키마 원본(DBML vs ORM/마이그레이션)을 결정해 템플릿을 설치한 뒤 다음 단계(design/import)로 이어 준다. "ERD 세팅", "erd 초기화", "이 프로젝트에 ERD 관리 도입", "모노레포 서비스별 ERD"에 사용.
argument-hint: "[--project <단위 폴더>]"
---

# /erd:init — ERD 관리 구조 세팅

공용 자료: `${CLAUDE_PLUGIN_ROOT}/shared/` — scripts, templates, references (`units.md`, `source-of-truth.md`, `migration-tools.md`)

## 1. 사전 점검
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh` 실행. `MISSING` 에 dbml2sql/tbls 가 있으면 `/erd:doctor` 절차로 먼저 해결할지 묻는다 (세팅 자체는 도구 없이도 진행 가능).

## 2. 레포 구조와 ERD 단위 파악
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/find-units.sh` 실행 (레포 루트, 모노레포 단서, 기존 단위, 새 단위 후보, DB 없는 소스 폴더).
- `${CLAUDE_PLUGIN_ROOT}/shared/references/units.md` 의 "모노레포 유형 판별"로 단위 배치를 제안한다.
  - 단일 레포: 레포 루트가 단위 (기존 동작).
  - 모노레포: DB 를 가진 서비스 폴더마다 단위. 공유 DB 면 스키마를 가진 폴더 하나만 단위.
  - `--project <폴더>` 가 주어지면 그 폴더 하나만 세팅.
- 제안 예 (사용자 확인 받기):
  ```
  ERD 단위 제안
  - apps/api      PostgreSQL · Alembic → ERD_SOURCE=migrations
  - apps/billing  MySQL · Prisma       → ERD_SOURCE=migrations
  관련 소스: apps/web → apps/api
  ```
- 이미 단위(`erd.env`)가 있는 폴더는 다시 세팅하지 않는다. 현재 구성을 요약하고 빠진 단위만 추가할지 묻는다.

## 3. 단위별 상세 스캔과 스키마 원본 결정
단위마다:
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect-project.sh <단위 폴더>` 실행 → DB 종류, ORM/마이그레이션, 참고 자산 정리.
- `source-of-truth.md` 결정표로 `ERD_SOURCE` 를 제안하고 확인을 받는다.
- `migrations` 이면 `migration-tools.md` 에서 `ERD_MIGRATE_CMD` 를 찾는다. 명령은 **단위 폴더에서** 실행된다. 프로젝트 설정(alembic env.py, prisma datasource 등)이 `DATABASE_URL` 을 읽는지 확인하고, 아니면 수정안을 제안만 한다(승인 후 수정).

## 4. 템플릿 설치
템플릿: `${CLAUDE_PLUGIN_ROOT}/shared/templates/`. **기존 파일은 덮어쓰지 않는다** (예: `[ -e X ] || cp ...`).

**레포 루트에 한 번:**

| 템플릿 | 위치 | 처리 |
|---|---|---|
| `scripts/erd-doc.sh` | `scripts/erd-doc.sh` | 복사 후 `chmod +x`. 이미 있으면 플러그인 버전과 비교해 갱신할지 묻는다 |
| `erd.mk` | 루트 | `Makefile` 이 있으면 끝에 `include erd.mk` 추가(확인), 없으면 `include erd.mk` 한 줄로 생성 |
| `ERD_GUIDE.md` | `docs/ERD_GUIDE.md` | 그대로 복사 |
| `.gitignore` | 루트 | `dbml-error.log` 추가 |

**단위 폴더마다:**

| 템플릿 | 처리 |
|---|---|
| `erd.env` | `ERD_DIALECT`, `ERD_SOURCE`, `ERD_MIGRATE_CMD`, `ERD_RELATED_SOURCES` 채우기. 공백 있는 값은 작은따옴표 |
| `.tbls.yml` | `__PROJECT_NAME__` → 단위 이름(예: `api`). migrations 이면 관리용 테이블 `exclude` 추가 |
| `db/schema.dbml`, `db/modules/_example.dbml` | `ERD_SOURCE=dbml` 일 때만. `__PROJECT_NAME__`, `__DB_TYPE__`(PostgreSQL/MySQL) 치환 |

## 5. 에이전트 지침 추가
- **단위 폴더**의 `CLAUDE.md`(없으면 생성, `AGENTS.md` 만 있으면 그쪽)에 추가 (이미 있으면 생략, 원본 종류에 맞는 줄만):
  ```markdown
  ## DB 스키마 (erd 플러그인)
  - 이 폴더가 ERD 단위다 (erd.env). 스키마 원본: <dbml: db/modules/*.dbml | migrations: ORM 모델·마이그레이션>.
  - 스키마를 바꾸면 레포 루트에서 `make erd P=<이 폴더>` 로 docs/schema 를 갱신하고 같은 커밋에 포함한다.
  - db/schema.sql, db/schema.generated.dbml, docs/schema/ 는 생성물이므로 직접 수정하지 않는다.
  - 구조 파악: docs/schema/README.md, 모듈별 docs/schema/viewpoint-*.md, 기계용 docs/schema/schema.json.
  - 설계·수정 /erd:design, 검토 /erd:review, 동기화 /erd:sync.
  ```
- **모노레포면 루트** `CLAUDE.md` 에 단위 목록만 짧게:
  ```markdown
  ## ERD 단위 (erd 플러그인)
  - apps/api (PostgreSQL), apps/billing (MySQL). 전체 문서 갱신: `make erd`, 하나만: `make erd P=apps/api`.
  ```

## 6. 첫 문서 생성 또는 다음 단계 (단위별)
- `migrations`: `make erd P=<단위>` → 결과 요약 → viewpoints(모듈) 구성을 제안해 `.tbls.yml` 에 반영 → 다시 실행.
- `dbml`:
  - 참고 자산(화면·API 소스, 문서, 기존 DB)이 있으면 → `/erd:import --project <단위>`.
  - 없으면 → `/erd:design --project <단위>` 의 대화형 초기 설계.
  - `_example.dbml` 은 첫 모듈을 만든 뒤 삭제.

## 마무리 보고
단위 목록(폴더·DB·원본), 설치한 파일, 다음에 할 일(명령 1~2개)만 짧게.
