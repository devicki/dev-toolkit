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

자연어로 요청해도 맞는 스킬이 선택됩니다 (예: "주문 기능에 필요한 테이블 설계해줘"). 스킬 설명에 "쓰지 않을 때"가 적혀 있어 비슷한 요청끼리 서로 가로채지 않습니다.

## make 명령 (레포 루트)

| 명령 | 용도 |
|---|---|
| `make erd [P=<단위>]` | 문서 생성 + lint |
| `make erd-check [P=<단위>]` | 문서 최신 여부 (CI) |
| `make erd-check-changed [BASE=origin/main]` | 기준 브랜치 대비 스키마가 바뀐 단위만 검사 (PR) |
| `make erd-sql`, `make erd-list`, `make erd-view` | DBML→SQL, 단위 목록, 터미널 보기 |

실패하면 마지막 줄에 `ERD_EXIT=<코드> <분류>` 가 찍힙니다 — 코드표는 [shared/references/errors.md](shared/references/errors.md).

## 프로젝트에 생기는 파일

```
# 레포 루트 (하나)
erd.mk                   # make erd / erd-check / erd-sql / erd-list / erd-view  [P=<단위>]
scripts/erd-doc.sh       # (DBML|마이그레이션) → 임시 DB → tbls 문서
scripts/erd-changed.sh   # 기준 브랜치 대비 바뀐 단위 탐지
docs/ERD_GUIDE.md        # 팀원용 작업 규칙

# ERD 단위 폴더 (단일 레포면 루트와 같음)
erd.env                  # 스키마 원본(dbml|migrations), DB 종류, 마이그레이션 명령, 관련 소스
.tbls.yml                # 문서 위치, Mermaid ERD, 모듈(viewpoints), lint 규칙
db/schema.dbml           # (dbml 원본일 때) 진입점
db/modules/*.dbml        # (dbml 원본일 때) 모듈별 설계
docs/schema/             # 생성 문서: README.md, viewpoint-*.md, 테이블별 md, schema.json
```

## 모노레포

**ERD 단위 = DB 하나 = `erd.env` 가 있는 폴더**입니다. 서비스별 DB 라면 서비스 폴더마다, 공유 DB 라면 스키마를 가진 폴더 하나에 둡니다.
`scripts/erd-doc.sh` 와 `erd.mk` 는 레포 루트에 하나만 두고, `make erd` (전체) / `make erd P=apps/api` (하나) 로 실행합니다.
스킬은 현재 위치에서 가장 가까운 `erd.env` 를 대상으로 삼고, 애매하면 묻거나 `--project <폴더>` 로 지정할 수 있습니다.
DB 가 없는 앱(프론트 등)은 `erd.env` 의 `ERD_RELATED_SOURCES` 로 연결해 import·review 때 함께 참고합니다.

```
monorepo/
├── erd.mk  scripts/erd-doc.sh
├── apps/api/      erd.env .tbls.yml db/ docs/schema/   (PostgreSQL)
├── apps/billing/  erd.env .tbls.yml docs/schema/       (MySQL)
└── apps/web/      (api 의 관련 소스)
```

## 요구 사항

- tbls, @dbml/cli (Node 18+) — `/erd:doctor` 가 설치 가능
- 임시 DB: Docker, 또는 접근 가능한 PostgreSQL/MySQL 서버 (`make erd PG=postgres://user:pass@host:5432`)
- 지원 DB: PostgreSQL, MySQL (dbml 원본 기준)

## 개발

- 회귀 테스트: `PG=postgres://user:pass@localhost:5432 plugins/erd/tests/run.sh` (또는 Docker). 임시 DB 가 없으면 DB 시나리오는 SKIP
- 변경 이력: [CHANGELOG.md](CHANGELOG.md)

## 여러 계정이 같은 서버를 쓸 때

tbls 가 공용 `/tmp/go-graphviz` 에서 권한 오류를 낼 수 있습니다. 관리자가 `sudo apt install libpam-tmpdir` 후 각 계정 재로그인을 권장합니다. `scripts/erd-doc.sh` 는 TMPDIR 이 없으면 자동으로 개인 임시 폴더를 사용합니다.
