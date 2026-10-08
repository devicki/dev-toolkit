---
name: import
description: 기존 자산에서 DBML/ERD를 만들어 낸다 — 화면·프론트 소스, 백엔드 API·DTO, ORM 모델·마이그레이션, 기존 ERD·ADR·기획 문서, 실행 중인 DB. 출처를 자동 감지하거나 인자로 지정(code|orm|docs|db). "소스코드에서 ERD 뽑아줘", "기존 문서 DBML로 옮겨줘", "ORM 모델 기준으로 ERD 만들어줘"에 사용.
argument-hint: "[code|orm|docs|db] [경로...] [--project <단위 폴더>]"
---

# /erd:import — 기존 자산에서 DBML 만들기

공용 자료: `${CLAUDE_PLUGIN_ROOT}/shared/references/` — `source-of-truth.md`, `dbml-conventions.md`, `migration-tools.md`

## 대상 ERD 단위
`${CLAUDE_PLUGIN_ROOT}/shared/references/units.md` 의 "대상 단위 결정"을 따른다 (`--project <폴더>` → 가장 가까운 erd.env → 단위가 하나면 그것 → 아니면 질문).
시작할 때 `대상: <단위> (<DB>, ERD_SOURCE=<값>)` 를 한 줄로 밝힌다. 아래의 경로(`db/`, `docs/schema/`, `.tbls.yml`, `erd.env`)는 모두 **단위 폴더 기준**이고, 명령은 레포 루트에서 `make erd P=<단위>` 로 실행한다.

## 0. 준비
- `erd.env` 가 없으면 `/erd:init` 을 먼저 진행한다 (init 이 import 로 다시 넘겨 준다).
- 출처가 인자로 없으면 `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect-project.sh <단위 폴더>` 결과와 `erd.env` 의 `ERD_RELATED_SOURCES` 폴더(모노레포의 프론트 등)에서 후보를 고르고, 여러 개면 사용자에게 우선순위를 묻는다. 여러 출처를 함께 쓸 수 있다 (예: ORM 이 기준, 화면 소스로 보강).

## 출처별 절차

### A. orm — ORM 모델·마이그레이션 (ERD_SOURCE=migrations)
1. `erd.env` 의 `ERD_MIGRATE_CMD` 로 `make erd P=<단위>` 실행 → `docs/schema/` 와 `db/schema.generated.dbml` 생성.
2. 마이그레이션이 없거나 실행 불가하면 모델 코드를 직접 읽어 DBML 초안을 작성한다(아래 C 의 추출 규칙 사용). 이때는 "코드에서 추론한 초안"임을 명시.
3. 모델 코드와 생성 결과를 대조해 차이(모델엔 있는데 마이그레이션에 없는 필드 등)를 보고한다.

### B. db — 실행 중인 DB
1. 접속 정보는 사용자에게 받는다. **읽기 전용 계정 권장**, 운영 DB 라면 한 번 더 확인.
2. `db2dbml postgres '<conn>' -o db/schema.imported.dbml` (MySQL 은 `mysql`).
3. 결과를 모듈 단위로 나눠 `db/modules/*.dbml` 로 재구성(아래 "모듈 분할").

### C. code — 화면·프론트·백엔드 소스 (DB 없음)
단위 폴더 + `ERD_RELATED_SOURCES` 폴더를 함께 읽는다. 다른 단위(다른 DB)의 엔티티로 보이는 것은 이 단위에 넣지 말고 "다른 단위 소속 후보"로 따로 보고한다.

추출 대상과 단서:

| 소스 | 엔티티/컬럼 단서 |
|---|---|
| 프론트 폼 | 입력 필드 이름·타입·필수·maxLength, select 옵션(상태값) |
| 프론트 목록·상세 | 표시 컬럼, 정렬·필터·검색 조건(→ 인덱스 후보) |
| 라우트·메뉴 | 업무 도메인 경계(→ 모듈 후보) |
| API 스펙(OpenAPI/GraphQL) | 리소스 = 테이블 후보, 스키마 필드, 경로의 중첩 관계(`/orders/{id}/items` → FK) |
| 백엔드 DTO/서비스 | 저장·조회 필드, 관계 조회(join), 트랜잭션 묶음 |
| 타입 정의 | TS interface, zod, pydantic, Java record 등 |

절차:
1. 엔티티 후보 목록을 먼저 보여 준다: `엔티티 | 근거 파일 | 추정 근거`. 사용자가 빼거나 합칠 것을 확인한다.
2. 엔티티별 컬럼을 추출하고, **확실하지 않은 값은 note 에 `[추정]` 을 붙인다** (타입, 길이, null 여부, 관계 방향).
3. 관계(1:N, N:M)를 정리하고 N:M 은 조인 테이블로 만든다.
4. 추가로 필요한 공통 컬럼(id, created_at 등)은 프로젝트 관례를 따른다.
5. 결과 DBML 을 모듈 파일로 저장 → `make erd P=<단위>` → 생성된 문서 경로와 `[추정]` 항목 목록을 보고하고, 사용자와 하나씩 확정한다(`/erd:design` 대화로 이어도 됨).

### D. docs — 기존 ERD·ADR·기획 문서
1. 문서 형식별로 읽는다: Markdown/텍스트 표, 이미지 ERD(이미지면 내용을 읽어 옮김), ERDCloud·dbdiagram 내보내기(SQL/DBML 이면 `sql2dbml`), 엑셀 테이블 정의서.
2. ADR 은 스키마에 영향을 주는 **결정**(예: 소프트 삭제 채택, 멀티테넌트 방식, ID 전략)을 뽑아 DBML 의 Project Note 또는 해당 테이블 Note 에 `ADR-xxx` 로 참조를 남긴다.
3. 문서끼리, 또는 문서와 코드가 다르면 임의로 고르지 말고 차이 목록을 보여 주고 결정을 받는다.
4. 이관 후 원 문서에는 "DBML(db/modules)로 이관됨" 표시를 제안한다(수정은 사용자 승인 후).

## 모듈 분할
- 테이블을 업무 도메인별로 묶어 `db/modules/<모듈>.dbml` 로 저장 (`dbml-conventions.md`).
- 모듈 경계 근거: 라우트/패키지 구조, 테이블 접두사, FK 밀집도. 제안 후 사용자 확인.
- `db/schema.dbml` 에 `use` 추가, `.tbls.yml` 에 viewpoint 추가 (모듈 id = 파일명).

## 마무리
1. `make erd P=<단위>` 실행 (ERD_SOURCE=dbml). 실패하면 `dbml-error.log`/오류 메시지를 보고 DBML 을 고친다.
2. lint 경고를 정리해 보고: 자동으로 고칠 수 있는 것(note 누락 등)은 고칠지 묻는다.
3. 보고: 만든 파일, 테이블 수, 모듈 목록, `[추정]` 항목 수, 확인이 필요한 결정 사항.
