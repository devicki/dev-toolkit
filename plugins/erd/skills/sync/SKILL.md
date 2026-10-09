---
name: sync
description: >
  ERD 최신 유지 — 문서 재생성, 문서·원본·DB 차이(drift) 점검, DBML 변경분 마이그레이션 생성, CI 검사. 산출물: docs/schema, 차이 리포트, 마이그레이션 초안.
  트리거: "ERD 최신화", "문서 갱신", "스키마 차이 확인", "마이그레이션 만들어줘", "make erd 실패" / "schema drift".
  비활성: 설계·수정(→ design), 품질 검토(→ review), 최초 세팅(→ init).
argument-hint: "[doc|drift|migrate|ci] [--project <단위>|--all-units]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
  - "Bash(make erd*)"
  - "Bash(scripts/erd-changed.sh *)"
  - "Bash(git status *)"
  - "Bash(git diff *)"
  - "Bash(git rev-parse *)"
---

# /erd:sync — 동기화와 유지보수

> **한 줄 정의**: 생성물·원본·실제 DB 를 맞춰 둔다. 무엇을 바꿀지는 사용자가 정한다.
> **핵심 산출물**: `<단위>/docs/schema/`, 차이 점검 리포트(`report-templates.md` 2번), 마이그레이션 초안, CI 설정

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — 강제 규칙·금지 (필수)
- `references/errors.md` — `ERD_EXIT` 코드별 대응 (실패 시 필수)
- `references/source-of-truth.md`, `references/migration-tools.md` — 원본별 비교·마이그레이션
- `references/tbls-guide.md` — tbls 옵션, 공용 /tmp 문제
- `references/report-templates.md` — 차이 점검 리포트(2번), 마무리(3번)
- 프로젝트의 `make erd`, `make erd-check`, `make erd-check-changed`, `scripts/erd-changed.sh`

## 강제 규칙 (최우선) — 전체는 `rules.md`
1. 문서 생성·검사는 `make erd*` 로만 (R1). 실패하면 `ERD_EXIT` 코드를 그대로 보고하고 `errors.md` 대로 대응 (R5).
2. 차이는 **제안만**. 어느 쪽을 맞출지는 사용자가 정한다 — 운영 DB 에만 있는 긴급 수정일 수 있다.
3. 마이그레이션은 생성까지만. **대상 DB 적용은 사용자가 직접** 하거나 명시적으로 요청할 때만 (R6).

## 0단계: 대상
- `units.md` "대상 단위 결정". 레포 루트에서 단위 지정 없이 `doc`/`drift` 면 모든 단위(`make erd`).
- `erd.env` 가 없으면 `/erd:init`.

## 1단계: 모드
인자가 없으면 `doc` → `drift` 순. 필요할 때 `migrate`/`ci` 를 제안한다.

| 모드 | 상황 | 진행 |
|---|---|---|
| **doc** | 문서 갱신 | `make erd [P=<단위>]` → 변경 문서(`git status <단위>/docs/schema`)·lint 요약 → viewpoint 없는 새 테이블이면 모듈 제안 후 `.tbls.yml` 추가 → 재실행 |
| **drift** | 차이 점검 | 아래 비교표 → 2번 리포트 |
| **migrate** | DB 반영 (dbml 원본) | 아래 절차 |
| **ci** | 자동 검사 | 아래 절차 |

### drift 비교표
| 비교 | 방법 |
|---|---|
| 문서 ↔ 원본 | `make erd-check [P=<단위>]` (PR 이면 `make erd-check-changed BASE=<ref>`) |
| ORM 모델 ↔ 마이그레이션 (migrations) | 도구 확인 명령: `alembic check`, `python manage.py makemigrations --check --dry-run`, `npx prisma migrate diff …`(설치 버전 `--help` 확인). 없으면 모델 코드 ↔ `docs/schema` 직접 대조 |
| DBML ↔ 백엔드 엔티티 (dbml) | 엔티티·모델 코드를 읽어 테이블·컬럼·타입·null·관계 대조 |
| 원본 ↔ 실제 개발/운영 DB | 사용자가 접속 정보를 줄 때만, 읽기 전용 계정 권장: `tbls diff '<DSN>' <단위>/docs/schema` (읽기만 하므로 R1 예외) |

### migrate (ERD_SOURCE=dbml)
1. 마이그레이션 도구·디렉터리가 있는지 확인. 없으면 선택지: (a) 개발 초기 → `db/schema.sql` 재생성으로 충분 (b) Atlas 도입 (c) 사람이 작성. **도입 결정은 사용자.**
2. Atlas (단위 폴더에서, 선택 도구 — 없으면 설치 안내만):
   `atlas migrate diff <이름> --dir file://db/migrations --to file://db/schema.sql --dev-url docker://postgres/16/dev` (MySQL: `docker://mysql/8/dev`)
3. 생성 SQL 의 위험 요소를 보고: DROP, rename 이 drop+add 로 나온 경우, 기존 데이터가 있는데 NOT NULL 추가.
- `ERD_SOURCE=migrations` 면 이 절차 대신 프로젝트 도구의 생성 명령을 안내·실행 (사용자 확인 후).

### ci
CI 에 검사를 추가한다 (사용자 확인 후). PR 은 바뀐 단위만, main 은 전체를 권장.
```yaml
name: erd
on: [pull_request]
jobs:
  erd-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }          # 기준 브랜치 비교에 필요
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm install -g @dbml/cli
      - run: |
          V=1.96.1
          curl -sSL https://github.com/k1LoW/tbls/releases/download/v$V/tbls_v${V}_linux_amd64.tar.gz | sudo tar xz -C /usr/local/bin tbls
      - run: make erd-check-changed BASE=origin/${{ github.base_ref }}
```
- migrations 원본이면 언어 런타임·의존성 설치 단계를 추가. GitLab 등은 같은 단계를 그 형식으로.
- lint 경고도 실패로 하려면 단위 `erd.env` 에 `ERD_CHECK_LINT=strict`.

## 에러 처리
`references/errors.md` 가 기준이다. 자주 나오는 것:
| ERD_EXIT | 동작 |
|---|---|
| 1 | 문서가 낡음 → `make erd P=<단위>` 후 함께 커밋 안내 |
| 3 | `/erd:doctor` |
| 5 | Docker 권한 또는 `PG=` 로 개발용 서버 사용 안내 |
| 7 | `ERD_MIGRATE_CMD` 를 단위 폴더에서 직접 실행해 재현·보고 |
| 8 | 메시지에 /tmp 권한이면 `tbls-guide.md` 절차 |

## 체크리스트 (보고 전)
- [ ] 실행한 명령과 결과(✔ 또는 `ERD_EXIT`)를 그대로 보고
- [ ] drift 는 2번 리포트 양식, 결정은 사용자에게 남김
- [ ] 커밋 대상 파일 목록 제시 (`<단위>/docs/schema/`, 원본 변경분)

## 관련 스킬
- `/erd:design` — drift 결과 원본을 고칠 때
- `/erd:review` — 변경분 품질 검토 (`--changed`)
- `/erd:doctor` — 도구 문제
