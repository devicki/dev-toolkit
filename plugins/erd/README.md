# erd — ERD 설계·문서화·유지보수 플러그인

DBML 로 설계하고, tbls 로 모듈별 문서·ERD(Mermaid)·lint 를 만들어 Git 으로 관리합니다.
Alembic·Prisma·Flyway 등 기존 마이그레이션 도구가 있는 프로젝트는 그 도구를 원본으로 두고 문서를 파생시킵니다.

## 스킬

| 명령 | 용도 |
|---|---|
| `/erd:doctor` | tbls, @dbml/cli, Docker/psql 점검과 설치 (설치 전 확인) |
| `/erd:init` | 프로젝트 스캔 → 스키마 원본 결정 → 템플릿 설치 → 다음 단계 안내 |
| `/erd:import` | 화면·API 소스, ORM·마이그레이션, ERD·ADR 문서, 실행 중인 DB 에서 DBML 생성 |
| `/erd:design` | 대화형 설계·수정 (초기 도메인 설계, 모듈·테이블·컬럼 변경) |
| `/erd:review` | 백엔드·프론트 소스와 대조한 검토, 심각도별 개선안 |
| `/erd:sync` | 문서 갱신, drift 점검, 마이그레이션 생성 연동, CI 검사 |

자연어로 요청해도 맞는 스킬이 선택됩니다 (예: "주문 기능에 필요한 테이블 설계해줘").

## 프로젝트에 생기는 파일

```
erd.env                  # 스키마 원본(dbml|migrations), DB 종류, 마이그레이션 명령
.tbls.yml                # 문서 위치, Mermaid ERD, 모듈(viewpoints), lint 규칙
erd.mk                   # make erd / erd-check / erd-sql / erd-view
scripts/erd-doc.sh       # (DBML|마이그레이션) → 임시 DB → tbls 문서
db/schema.dbml           # (dbml 원본일 때) 진입점
db/modules/*.dbml        # (dbml 원본일 때) 모듈별 설계
docs/schema/             # 생성 문서: README.md, viewpoint-*.md, 테이블별 md, schema.json
docs/ERD_GUIDE.md        # 팀원용 작업 규칙
```

## 요구 사항

- tbls, @dbml/cli (Node 18+) — `/erd:doctor` 가 설치 가능
- 임시 DB: Docker, 또는 접근 가능한 PostgreSQL/MySQL 서버 (`make erd PG=postgres://user:pass@host:5432`)
- 지원 DB: PostgreSQL, MySQL (dbml 원본 기준)

## 여러 계정이 같은 서버를 쓸 때

tbls 가 공용 `/tmp/go-graphviz` 에서 권한 오류를 낼 수 있습니다. 관리자가 `sudo apt install libpam-tmpdir` 후 각 계정 재로그인을 권장합니다. `scripts/erd-doc.sh` 는 TMPDIR 이 없으면 자동으로 개인 임시 폴더를 사용합니다.
