# 스키마 원본(Source of Truth) 결정

> 기준: erd 플러그인 0.3.0 — 2026-10.

ERD 작업을 시작하기 전에 **무엇이 스키마의 원본인지**부터 정한다. 원본이 둘이면 서로를 덮어쓰며 어긋난다.
결정 결과는 ERD 단위 폴더의 `erd.env` 의 `ERD_SOURCE` 에 기록한다 (단위마다 다를 수 있다, `units.md`).

## 결정표

| 프로젝트 상태 | ERD_SOURCE | 원본 | DBML의 역할 | 스키마 변경 흐름 |
|---|---|---|---|---|
| 신규, 마이그레이션 도구 없음 | `dbml` | `db/modules/*.dbml` | 설계 원본 | DBML 수정 → `make erd` → (DB 반영 시) 마이그레이션 SQL 생성 |
| ORM/마이그레이션 도구 있음 | `migrations` | ORM 모델 + 마이그레이션 | 파생 문서 (`db/schema.generated.dbml`) | 모델 수정 → 마이그레이션 생성(기존 도구) → `make erd` |
| 화면·API 소스만 있음 (DB 미구현) | `dbml` | 추출한 초안 DBML → 사용자 확정 후 원본 | 설계 원본 | 신규와 동일 |
| ERD·ADR 문서만 있음 | `dbml` | 문서 → DBML 이관 후 DBML이 원본 | 설계 원본 | 신규와 동일. 원 문서에는 "DBML로 이관됨" 표시 권장 |
| 운영 DB만 있음 (코드에 스키마 없음) | `dbml` | `db2dbml` 로 추출한 DBML | 설계 원본 | 이후 변경은 DBML → 마이그레이션 |

## 판단 규칙

1. `detect-project.sh <단위 폴더>` 결과에 마이그레이션 도구가 있으면 **기본값은 `migrations`**.
   - 단, 마이그레이션이 사실상 버려진 상태(최근 커밋 없음, 실제 DB와 크게 다름)라면 사용자에게 확인한다.
2. 마이그레이션 도구가 없고 DBML도 없으면 `dbml`.
3. `migrations` 인데 사용자가 "DBML로 먼저 설계하고 싶다"고 하면:
   - DBML은 **설계 제안서**로 쓴다(`db/proposals/<이름>.dbml`).
   - 확정되면 ORM 모델·마이그레이션에 반영하고, 문서는 `make erd` 로 다시 생성한다.
   - DBML을 원본으로 바꾸는 것은 팀 합의가 필요한 결정이므로 사용자 확인 없이 하지 않는다.
4. 판단이 애매하면 결정표를 보여 주고 사용자에게 고르게 한다.

## 원본별 금지 사항

- `dbml`: `docs/schema/`, `db/schema.sql` 을 직접 수정하지 않는다.
- `migrations`: `db/schema.generated.dbml` 을 손으로 고치지 않는다(다음 `make erd` 에서 덮어써짐). 이미 적용된 마이그레이션 파일을 수정하지 않는다.
