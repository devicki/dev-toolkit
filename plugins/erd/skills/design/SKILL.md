---
name: design
description: >
  대화형 ERD 설계·수정 — 초기 도메인 설계, 기능별 테이블, 테이블·컬럼·관계 변경. 원본(DBML/ORM)에 반영하고 문서 갱신. 산출물: 변경된 원본 + docs/schema.
  트리거: "주문 테이블 설계해줘", "회원에 등급 추가", "이 기능에 필요한 테이블" / "design the schema".
  비활성: 검토만(→ review), 코드·문서에서 추출(→ import).
argument-hint: "[설계할 기능·모듈·변경 내용] [--project <단위 폴더>]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
---

# /erd:design — 대화형 설계·수정

> **한 줄 정의**: 요구사항을 질문으로 좁혀 스키마로 옮긴다. 가져오기는 import, 검토는 review 가 맡는다.
> **핵심 산출물**: 변경된 스키마 원본 + `<단위>/docs/schema/viewpoint-<모듈>.md`

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — 강제 규칙·금지 (필수)
- `references/dbml-conventions.md` — 명명·note·인덱스·모듈·**바꾸기 비싼 것·규모 감각** (필수)
- `references/source-of-truth.md` — 원본별 변경 대상
- `references/migration-tools.md` — migrations 원본일 때 마이그레이션 생성
- `references/units.md` — 단위 결정·다른 DB 참조
- `references/report-templates.md` — 마무리 보고(3번)
- `references/errors.md` — `ERD_EXIT` 대응

## 강제 규칙 (최우선) — 전체는 `rules.md`
1. **제안 → 확인 → 반영**. 확정 전에는 원본 파일을 바꾸지 않는다 (R4).
2. 원본만 고친다: `dbml` → `db/modules/*.dbml`, `migrations` → 모델 + 새 마이그레이션. migrations 원본에서 DBML 은 제안용(`db/proposals/<이름>.dbml`)으로만 (R3).
3. 문서는 `make erd P=<단위>` 로만 갱신 (R1).
4. 모르면 `[TBD]` 로 두고 진행한다. 질문 때문에 멈추지 않는다 (R7).

## 0단계: 맥락 (매번)
- 대상 단위: `units.md` "대상 단위 결정". `대상: <단위> (<DB>, ERD_SOURCE=<값>)` 를 밝힌다. `erd.env` 가 없으면 `/erd:init`.
- **선행 산출물부터**: `docs/schema/README.md`, 관련 `viewpoint-*.md`, 테이블 문서를 읽는다. 없거나 오래됐으면 `make erd P=<단위>`.
- 관련 소스(단위 폴더 + `ERD_RELATED_SOURCES`)의 화면·API·엔티티를 **질문 전에** 읽는다. 코드로 알 수 있는 것은 묻지 않는다.

## 1단계: 모드 판단 (묻지 않고 요청에서 판단)
| 모드 | 상황 | 진행 |
|---|---|---|
| 초기 설계 | 테이블이 거의 없음 | 아래 질문 순서 1→5 |
| 기능 추가 | 새 화면·요구사항 | 저장할 데이터 → 기존 테이블 재사용 여부 → 새 테이블 |
| 변경 | 기존 테이블·컬럼 수정 | 변경 전/후 diff + 영향 코드(grep) + 데이터 이관 위험 |

## 2단계: 질문 — 한 번에 한 묶음(1~3개)
필수와 선택을 나눈다. 이미 답했거나 요청·코드에서 분명한 것은 다시 묻지 않는다.

| 순서 | 필수 | 선택 |
|---|---|---|
| 1 | 핵심 대상(명사)과 주요 행위(동사) | |
| 2 | 사용자 역할·조직 구조, 멀티테넌트 여부 | 권한 모델 |
| 3 | 대상 간 관계와 수량 (1:N, N:M) | |
| 4 | 상태 흐름 | 이력 보관 필요 여부 |
| 5 | 삭제 정책(소프트 삭제?) | 감사 컬럼, 다국어·통화 |

**먼저 확정할 것**(`dbml-conventions.md` "바꾸기 비싼 것"): 테이블·컬럼 이름, 모듈 id, PK 전략, 테넌트 키. 이것들은 확인을 받고 넘어간다.

## 3단계: 설계안 — 단계마다 체크포인트
1. **개념 수준**: Mermaid erDiagram (테이블·관계, 핵심 컬럼만) → "이 구조가 맞나요? 빠진 관계가 있나요?"
2. **상세 DBML**: `dbml-conventions.md` 규칙(note, FK 인덱스, 명명) → 확인.
3. 선택이 갈리는 결정(상태값 enum vs varchar, 이력 분리, 다형 관계)은 장단점 1줄씩 + 추천안.
4. 규모 감각 신호(모듈당 30개 초과, 컬럼 50개 초과 등)가 보이면 한 번 짚는다.

## 4단계: 반영
- 새 모듈: `db/modules/<모듈>.dbml` + `db/schema.dbml` 에 `use` + `.tbls.yml` viewpoint (id = 파일명).
- 다른 모듈 참조: `use { table x } from './<모듈>'`. 다른 단위(다른 DB) 참조: FK 대신 note (`units.md`).
- `make erd P=<단위>` → 실패 시 `ERD_EXIT` 로 `errors.md` → lint 경고 처리.
- migrations 원본: 모델 수정 → 프로젝트 도구로 마이그레이션 생성(예: `alembic revision --autogenerate -m ...`, 사용자 확인 후) → 생성 결과 검토 보고 → `make erd P=<단위>`.

## 5단계: DB 반영 안내 (dbml 원본)
| 단계 | 안내 |
|---|---|
| 데이터 보존 불필요 (개발 초기) | 개발 DB 를 `db/schema.sql` 로 재생성 |
| 데이터 보존 필요 | `/erd:sync migrate` 로 변경분 마이그레이션 (Atlas 등) |

## 판단 규칙
| 조건 | 결과 |
|---|---|
| 요구되지 않은 테이블·컬럼 | 추가하지 않고 제안만 |
| 기존 규칙(명명·타입·공통 컬럼)과 충돌 | 기존 규칙을 따른다. 바꾸려면 "규칙 변경 제안" |
| 사용자가 답하지 않은 필수 항목 | `[TBD]` + 합리적 기본값으로 진행, 끝에 보고 |

## 에러 처리
`references/errors.md`. 특히 `ERD_EXIT=4`(DBML 문법)·`6`(SQL 적용)은 DBML 을 고쳐 재실행한다.

## 체크리스트 (보고 전)
- [ ] 모든 새 테이블 `Note`, 모든 새 컬럼 `note`
- [ ] FK 컬럼 인덱스
- [ ] 새 테이블이 viewpoint(모듈)에 속함
- [ ] `make erd P=<단위>` ✔
- [ ] `[TBD]` 목록 보고
- [ ] 보고는 `report-templates.md` 3번 양식

## 관련 스킬
- `/erd:review` — 설계 결과를 코드와 대조 검토
- `/erd:sync` — DB 반영용 마이그레이션(migrate), CI
- `/erd:import` — 기존 소스에서 먼저 뽑아올 것이 있을 때
