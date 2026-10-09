---
name: review
description: >
  ERD를 백엔드·프론트 소스와 대조해 검수, 심각도별 개선안. 전체·모듈·테이블·PR 변경분. 산출물: 고정 양식 검수 리포트.
  트리거: "ERD 검토", "스키마 리뷰", "코드랑 ERD 맞는지", "PR 스키마 변경 검토" / "review the schema".
  비활성: 설계·수정 요청(→ design), 기계적 차이 확인(→ sync drift).
argument-hint: "[모듈|테이블|all] [--changed [<기준 ref>]] [--fix] [--project <단위>|--all-units]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
  - "Bash(scripts/erd-changed.sh *)"
  - "Bash(git rev-parse *)"
  - "Bash(git diff *)"
---

# /erd:review — 검수와 개선 제안

> **한 줄 정의**: 근거(코드·문서)가 있는 문제만 고정 양식으로 보고한다. 반영은 사용자가 고른 항목만.
> **핵심 산출물**: `report-templates.md` 1번 "검수 리포트"

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/review-checklist.md` — 핵심 위반 C1~C5, 체크리스트, **심각도 판단표** (필수)
- `references/report-templates.md` — 검수 리포트 양식 (필수)
- `references/rules.md` — 강제 규칙·금지
- `references/units.md` — 단위 결정, 다른 DB 참조 대조
- `scripts/detect-project.sh <단위>` — 소스 위치
- 프로젝트의 `scripts/erd-changed.sh` — 변경분 모드

## 강제 규칙 (최우선) — 전체는 `rules.md`
1. **근거 없는 일반론 금지.** 각 지적에 `파일:줄` 또는 문서 위치를 단다. 근거를 못 찾으면 "확인 필요".
2. 심각도는 **판단표대로**. 즉석 기준을 쓰지 않는다.
3. 출력은 **검수 리포트 양식 그대로**. 끝에 데이터 기준(커밋·문서 생성 시각).
4. 검토 중에는 파일을 수정하지 않는다. `--fix` 또는 사용자 선택 후에만 반영 (R4).

## 0단계: 대상·기준 자료
- 대상 단위: `units.md` "대상 단위 결정". `--all-units` 면 단위별로 차례로 하고 마지막에 단위 간 참조(X1) 점검.
- 기준: `docs/schema/schema.json` (없거나 원본보다 오래됐으면 `make erd P=<단위>` 먼저) + 원본(DBML 또는 ORM 모델) + `make erd` 의 lint 경고.
- 데이터 기준: `git rev-parse --short HEAD` (+ `git diff --quiet || echo dirty`), `docs/schema/README.md` 수정 시각.

## 1단계: 범위 (모드)
요청에서 분명하면 묻지 않는다.
| 범위 | 상황 | 대상 |
|---|---|---|
| 변경분 `--changed [ref]` | PR·브랜치 검토 | `scripts/erd-changed.sh --base <ref>` (기본: 원격 기본 브랜치) 의 schema·related 파일과 그 테이블만 |
| 모듈·테이블 | 인자로 지정 | 해당 viewpoint·테이블 + 직접 참조 테이블 |
| 전체 | 인자 없음 | 테이블 30개 초과면 모듈 목록을 보여 주고 우선순위 질문 |

## 2단계: 소스 대조
`detect-project.sh <단위>` 로 위치를 찾고 범위의 코드만 읽는다 (단위 폴더 + `ERD_RELATED_SOURCES`).
- 백엔드: 엔티티·모델, 리포지토리·쿼리(WHERE/ORDER BY/JOIN), 저장·검증 로직, DTO
- 프론트: 폼(필수·길이·옵션), 목록(정렬·필터), 상세 표시 데이터
- 문서: ADR, 설계 문서
- 다른 DB 참조 note(`→ <단위>: …`)는 상대 단위 `docs/schema/schema.json` 과 대조
- 모듈이 많으면 모듈별로 Explore 서브에이전트에 탐색을 나눈다. prompt 에 단위 경로·대상 테이블·찾을 것(C1~C5 근거)을 빠짐없이 넣고, 이미 띄운 에이전트는 새로 만들지 말고 `SendMessage` 로 재사용한다. 서로 독립인 모듈은 한 응답에서 병렬로.

## 3단계: 판정
1. **핵심 위반 C1~C5 먼저** 전부 판정.
2. 나머지 체크리스트(P·M·D·N·A·X·U).
3. `review-checklist.md` 판단표로 심각도.

## 4단계: 보고
`report-templates.md` 1번 양식 그대로. 코드 쪽을 고쳐야 하는 문제는 "코드 수정 제안" 절로.

## 5단계: 반영 (선택)
- `--fix` 또는 사용자가 고른 항목만. 방식은 `/erd:design` 4단계와 같다.
- 운영 데이터 영향이 있는 변경은 마이그레이션 전략을 함께 제시하고 자동 반영하지 않는다.
- 반영 후 `make erd P=<단위>`.

## 에러 처리
| 상황 | 동작 |
|---|---|
| `make erd` 실패 | `errors.md` (`ERD_EXIT`) — 문서 없이 검토를 진행하지 말고 먼저 해결하거나, 원본만으로 검토한다고 명시 |
| `erd-changed.sh` exit 2 (기준 ref 없음) | `--changed <ref>` 로 지정 요청 |
| 소스 위치를 못 찾음 | 해당 항목 "확인 필요", 추정 금지 |

## 체크리스트 (보고 전)
- [ ] C1~C5 모두 판정함 (통과 항목은 ✅ 절에)
- [ ] 모든 지적에 근거 위치가 있음
- [ ] 심각도가 판단표와 일치
- [ ] 데이터 기준 줄 포함

## 관련 스킬
- `/erd:design` — 고른 항목 반영
- `/erd:sync` — 문서·원본·DB 차이 점검(drift), CI 의 `erd-check-changed`
