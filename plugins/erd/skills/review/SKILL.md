---
name: review
description: 현재 ERD(DBML·tbls 문서·실제 스키마)를 백엔드·프론트 소스코드와 대조해 검토하고 개선안을 제시한다 — 무결성, 코드 정합성, 인덱스·성능, 정규화, 명명, ADR 일치. 전체 또는 모듈·테이블 단위. "ERD 검토", "스키마 리뷰", "이 모듈 테이블 괜찮은지 봐줘", "코드랑 ERD 맞는지 확인"에 사용.
argument-hint: "[모듈|테이블|all] [--fix] [--project <단위 폴더>|--all-units]"
---

# /erd:review — 검토와 개선 제안

공용 자료: `${CLAUDE_PLUGIN_ROOT}/shared/references/review-checklist.md`(필수), `dbml-conventions.md`

## 대상 ERD 단위
`${CLAUDE_PLUGIN_ROOT}/shared/references/units.md` 의 "대상 단위 결정"을 따른다 (`--project <폴더>` → 가장 가까운 erd.env → 단위가 하나면 그것 → 아니면 질문. `--all-units` 면 모든 단위를 차례로 검토하고 마지막에 서비스 간 참조 일관성을 점검).
시작할 때 `대상: <단위> (<DB>, ERD_SOURCE=<값>)` 를 한 줄로 밝힌다. 아래의 경로(`db/`, `docs/schema/`, `.tbls.yml`, `erd.env`)는 모두 **단위 폴더 기준**이고, 명령은 레포 루트에서 `make erd P=<단위>` 로 실행한다.

## 1. 범위와 기준 자료
- 인자로 범위(모듈/테이블)를 받는다. 없으면 전체를 훑고, 테이블이 30개를 넘으면 모듈 목록을 보여 주고 우선순위를 묻는다.
- 스키마 기준: `docs/schema/schema.json` (없거나 오래됐으면 `make erd P=<단위>` 먼저) + `db/modules/*.dbml`(또는 ORM 모델).
- `make erd P=<단위>` 결과의 lint 경고도 검토 입력으로 쓴다.

## 2. 소스 대조
`bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect-project.sh <단위 폴더>` 로 소스 위치를 찾고, 범위에 해당하는 코드만 읽는다. `ERD_RELATED_SOURCES` 폴더(프론트 등)도 포함한다.
- 다른 단위를 note 로 참조하는 컬럼(`→ <단위>: <테이블>.<컬럼> (다른 DB)`)은 상대 단위의 `docs/schema/schema.json` 과 타입·의미를 대조한다.
- 백엔드: 엔티티/모델, 리포지토리·쿼리(WHERE/ORDER BY/JOIN), 서비스의 저장·검증 로직, DTO
- 프론트: 폼(필수·길이·옵션), 목록(정렬·필터·페이지), 상세 화면의 표시 데이터
- 문서: ADR, 기획·설계 문서
테이블이 많으면 모듈별로 서브에이전트(Explore)에 코드 탐색을 나눠 맡겨도 된다.

## 3. 체크리스트 적용
`review-checklist.md` 의 1~6 절을 범위에 적용한다. 근거 없는 일반론은 쓰지 않는다.
각 발견 사항은 다음 형식:

```
🔴 [무결성] orders.user_id 에 FK 없음
  근거: OrderService.java:42 에서 users 조회 후 저장, DB 제약 없음
  제안: user_id bigint [not null, ref: > users.id]
  영향: 기존 데이터에 고아 행이 있으면 마이그레이션 실패 → 사전 점검 쿼리 첨부
```

## 4. 보고
- 요약 표: 심각도별 개수, 모듈별 개수
- 상세: 🔴 → 🟡 → 🔵 순, 각 항목에 근거·제안(DBML diff)·영향
- 코드 쪽을 고쳐야 하는 문제(예: 화면 검증이 DB 제약보다 느슨함)는 "코드 수정 제안"으로 따로 묶는다.

## 5. 반영 (선택)
- `--fix` 가 있거나 사용자가 요청하면, **선택한 항목만** 반영한다. 반영 방식은 `/erd:design` 의 3단계(반영)와 같다.
- 운영 데이터에 영향이 있는 변경은 마이그레이션 전략(단계적 적용, 백필)을 함께 제시하고 자동 반영하지 않는다.
- 반영 후 `make erd P=<단위>` 로 문서·lint 를 갱신한다.

## 원칙
- 프로젝트가 이미 정한 규칙·ADR 과 충돌하는 제안은 "규칙 변경 제안"으로 구분한다.
- 추측과 사실을 구분한다. 코드에서 확인 못 한 것은 "확인 필요"로 표시.
