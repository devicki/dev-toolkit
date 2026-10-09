---
name: import
description: >
  기존 자산(화면·API 소스, ORM·마이그레이션, ERD·ADR 문서, 실행 중 DB)에서 DBML 생성 또는 기존 DBML 보강. 산출물: db/modules/*.dbml + [추정] 목록.
  트리거: "소스코드에서 ERD 뽑아줘", "문서 DBML로 옮겨줘", "이 화면 보고 ERD 보강" / "reverse engineer ERD".
  비활성: 요구사항 기반 새 설계(→ design), 품질 검토(→ review).
argument-hint: "[code|orm|docs|db|augment] [경로...] [--project <단위 폴더>]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
---

# /erd:import — 기존 자산에서 DBML 만들기·보강

> **한 줄 정의**: 이미 있는 것(코드·문서·DB)에서 스키마를 뽑아 DBML 로 옮긴다. 새 요구사항 설계는 design 이 맡는다.
> **핵심 산출물**: `<단위>/db/modules/<모듈>.dbml`, `<단위>/docs/schema/`, `[추정]` 목록

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `scripts/find-units.sh`, `scripts/detect-project.sh <단위>` — 대상 단위·출처 후보 탐색
- `references/rules.md` — 강제 규칙·금지 (필수)
- `references/dbml-conventions.md` — DBML 작성 규칙·모듈 분할·규모 감각
- `references/migration-tools.md` — ORM/마이그레이션 → DBML 경로, `sql2dbml`/`db2dbml`
- `references/units.md` — 단위 결정·다른 DB 참조 표기
- `references/report-templates.md` — 마무리 보고 양식(3번)
- `references/errors.md` — `ERD_EXIT` 대응

## 강제 규칙 (최우선) — 전체는 `rules.md`
1. 코드·문서에서 **확인한 것만** 확정값으로 쓴다. 추론한 타입·길이·null·관계 방향은 note 에 `[추정]` (R7).
2. 문서 생성은 `make erd P=<단위>` 로만 (R1). `dbml2sql` 을 직접 돌려 문법을 확인하지 않는다 — 오류여도 exit 0.
3. 출처끼리 다르면 임의로 고르지 말고 차이 목록을 보여 주고 결정을 받는다.

## 0단계: 대상 단위·사전 조건
- `units.md` "대상 단위 결정" (`--project` → 가장 가까운 erd.env → 하나뿐이면 그것 → 질문). 시작할 때 `대상: <단위> (<DB>, ERD_SOURCE=<값>)` 를 밝힌다.
- `erd.env` 가 없으면 `/erd:init` 먼저.
- 출처 후보: `detect-project.sh <단위>` + `erd.env` 의 `ERD_RELATED_SOURCES` 폴더.

## 1단계: 모드 선택
요청에서 분명하면 묻지 않는다. 모호할 때만 한 번 묻는다. 여러 출처를 함께 쓸 수 있다 (예: orm 기준 + code 로 보강).

| 모드 | 상황 | 초반 접근 |
|---|---|---|
| **orm** | ORM 모델·마이그레이션이 있음 (`ERD_SOURCE=migrations`) | `make erd P=<단위>` → `db/schema.generated.dbml` + 문서 → 모델 코드와 대조 |
| **db** | 실행 중인 DB 만 있음 | 접속 정보를 받아 `db2dbml` → 모듈 분할 |
| **code** | 화면·API·DTO 소스만 있음 (DB 미구현) | 엔티티 후보 추출 → 사용자 검증 → 컬럼·관계 |
| **docs** | ERD·ADR·기획·테이블 정의서 | 문서 수집 → DBML 이관 → 문서 간·코드와의 차이 보고 |
| **augment** | **이미 DBML 이 있고** 새 소스(기능·화면)로 보강 | 기존 DBML 읽기 → 새 소스에서 추가분만 추출 → 기존 테이블과 매칭(재사용/컬럼 추가/새 테이블) → diff 로 제안 |

## 2단계: 모드별 절차

### orm
1. `make erd P=<단위>` (원본은 마이그레이션). 실패하면 `ERD_EXIT` 로 `errors.md`.
2. 마이그레이션이 없거나 실행 불가면 모델 코드를 읽어 DBML 초안 — "코드에서 추론한 초안"이라고 명시, 불확실한 값은 `[추정]`.
3. 모델 ↔ 생성 결과 차이(모델엔 있는데 마이그레이션에 없는 필드 등)를 보고.

### db
1. 접속 정보는 사용자에게 받는다. **읽기 전용 계정 권장**, 운영 DB 면 한 번 더 확인.
2. `db2dbml postgres '<conn>' -o <단위>/db/schema.imported.dbml` (MySQL: `mysql`) — 이 명령은 읽기만 하므로 R1 예외.
3. "모듈 분할"로 `db/modules/*.dbml` 재구성.

### code
단위 폴더 + `ERD_RELATED_SOURCES` 를 읽는다. 다른 단위(다른 DB) 소속으로 보이는 엔티티는 넣지 말고 "다른 단위 후보"로 따로 보고.

| 소스 | 단서 |
|---|---|
| 프론트 폼 | 필드 이름·타입·필수·maxLength, select 옵션(상태값) |
| 프론트 목록·상세 | 표시 컬럼, 정렬·필터·검색(→ 인덱스 후보) |
| 라우트·메뉴 | 도메인 경계(→ 모듈 후보) |
| API 스펙 (OpenAPI/GraphQL) | 리소스=테이블 후보, 중첩 경로(`/orders/{id}/items` → FK) |
| 백엔드 DTO·서비스 | 저장·조회 필드, 조인, 트랜잭션 묶음 |

1. 엔티티 후보 표 `엔티티 | 근거 파일 | 근거` → 사용자가 빼거나 합칠 것 확인.
2. 컬럼 추출 (불확실 → `[추정]`), 관계 정리, N:M 은 조인 테이블.
3. 공통 컬럼(id, created_at 등)은 프로젝트 관례를 따른다.

### docs
1. 형식별로 읽는다: Markdown/텍스트 표, 이미지 ERD(내용을 읽어 옮김), SQL/DBML 내보내기(`sql2dbml` — 읽기 전용 변환이라 R1 예외), 엑셀 테이블 정의서.
2. ADR 은 스키마에 영향을 주는 **결정**(소프트 삭제, 멀티테넌트, ID 전략)을 뽑아 Project/테이블 Note 에 `ADR-xxx` 참조.
3. 이관 후 원 문서에 "DBML(db/modules)로 이관됨" 표시를 제안 (수정은 승인 후).

### augment
1. 기존 `db/modules/*.dbml` 과 `docs/schema/schema.json` 을 먼저 읽는다 (0단계: 선행 산출물 확인).
2. 새 소스에서 필요한 데이터를 code 모드 방식으로 추출하되, **추가분만** 정리한다.
3. 기존 테이블과 매칭: 같은 개념이면 컬럼 추가, 새 개념이면 새 테이블, 애매하면 질문.
4. 변경 전/후 diff 로 제안 → 확인 후 반영. 기존 테이블·컬럼 이름 변경은 하지 않는다 (필요하면 별도 제안).

## 3단계: 모듈 분할·저장·문서화
- 테이블을 업무 도메인별로 `db/modules/<모듈>.dbml` 에 저장 (`dbml-conventions.md`, 규모 감각 참고). 경계 근거(라우트·패키지·FK 밀집도)를 제안하고 확인.
- `db/schema.dbml` 에 `use * from './modules/<모듈>'`, `.tbls.yml` viewpoints 에 모듈 추가 (id = 파일명).
- `make erd P=<단위>` → 실패 시 `ERD_EXIT` 대응 → lint 경고 중 자동 수정 가능한 것(note 누락)은 고칠지 묻는다.

## 판단 규칙
| 조건 | 결과 |
|---|---|
| 코드에 타입·제약이 명시됨 (엔티티 어노테이션, 마이그레이션) | 확정값 |
| 화면·DTO 에서만 추론 | `[추정]` |
| 출처 간 불일치 | 확정하지 않고 차이 목록으로 질문 |
| 다른 DB 소속으로 보임 | 이 단위에서 제외, "다른 단위 후보" 보고 |

## 에러 처리
`references/errors.md` (`ERD_EXIT` 코드별) + 아래.
| 상황 | 동작 |
|---|---|
| `db2dbml` 접속 실패 | 접속 정보 확인 요청, 추정으로 진행 금지 |
| 이미지 ERD 가 판독 불가 | 판독 못 한 부분을 목록으로 알리고 `[TBD]` |

## 체크리스트 (보고 전)
- [ ] `make erd P=<단위>` ✔ (또는 실패 코드 보고)
- [ ] 모든 테이블이 모듈(viewpoint)에 속함
- [ ] `[추정]` / `[TBD]` 목록을 보고에 포함
- [ ] 출처 간 차이는 결정을 받았거나 미결로 표시
- [ ] 보고는 `report-templates.md` 3번 양식

## 관련 스킬
- `/erd:design` — `[추정]`·`[TBD]` 를 대화로 확정, 이후 기능 추가 설계
- `/erd:review` — 가져온 스키마를 코드와 대조 검토
- `/erd:sync` — 이후 문서 유지·CI
