---
name: init
description: >
  프로젝트(단일·모노레포)에 ERD 관리 구조 세팅: ERD 단위·스키마 원본 결정 후 템플릿 설치. 산출물: erd.env, .tbls.yml, erd.mk, scripts/erd-*.sh.
  트리거: "ERD 세팅", "erd 초기화", "ERD 관리 도입" / "set up erd".
  비활성: erd.env 가 이미 있는 단위의 설계(→ design)·문서 갱신(→ sync).
argument-hint: "[--project <단위 폴더>]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
---

# /erd:init — ERD 관리 구조 세팅

> **한 줄 정의**: 어디가 ERD 단위이고 무엇이 원본인지 정한 뒤, 스크립트로 파일을 설치한다. 테이블 설계는 하지 않는다(→ design/import).
> **핵심 산출물**: 단위마다 `erd.env`·`.tbls.yml`(·`db/`), 루트에 `erd.mk`·`scripts/erd-doc.sh`·`scripts/erd-changed.sh`

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `scripts/find-units.sh [--json]` — 레포 구조·기존 단위·후보 (아래에 자동 실행 결과)
- `scripts/detect-project.sh <단위>` — 단위별 DB 종류·ORM·참고 자산
- `scripts/install-templates.sh` — **설치 필수 헬퍼** (멱등, 덮어쓰지 않음, CLAUDE.md 마커 블록)
- `scripts/check-tools.sh` — 도구 점검
- `references/units.md` — 단위 개념·모노레포 유형 판별
- `references/source-of-truth.md` — 원본 결정표
- `references/migration-tools.md` — 도구별 `ERD_MIGRATE_CMD`
- `references/rules.md` — 강제 규칙·금지

## 현재 레포 (자동 탐색 결과)

!`bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/find-units.sh || true`

## 강제 규칙 (최우선) — 전체는 `rules.md`
1. 파일 설치는 **반드시** `install-templates.sh` 로 한다. `cp`·`sed` 로 템플릿을 손수 다루지 않는다 (R2).
2. 단위 배치와 `ERD_SOURCE` 는 **제안 후 사용자 확인**을 받아 확정한다 (R4).
3. 프로젝트 설정(alembic env.py, prisma datasource 등) 수정이 필요하면 제안만 하고 승인 후 수정한다.

## 0단계: 사전 조건
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh` — dbml2sql/tbls 가 없으면 `/erd:doctor` 를 먼저 할지 묻는다 (세팅은 도구 없이도 가능).
- 위 탐색 결과에 기존 단위가 있으면 그 단위는 다시 세팅하지 않는다. 요약하고 빠진 단위만 추가할지 묻는다.

## 1단계: 단위 배치 결정
`units.md` "모노레포 유형 판별"로 제안한다. `--project <폴더>` 가 있으면 그 폴더 하나만.

| 상황 | 단위 |
|---|---|
| 단일 레포 | 레포 루트 (`.`) |
| 공유 DB + 여러 앱 | 스키마를 가진 폴더 하나. 나머지 앱은 `--related` |
| 서비스별 DB | DB 를 가진 서비스 폴더마다 |
| 판단 불가 | 탐색 결과를 보여 주고 질문 |

제안 예 (확인 받기):
```
ERD 단위 제안
- apps/api   PostgreSQL · Alembic → migrations (alembic upgrade head)
- apps/pay   MySQL · 없음         → dbml
관련 소스: apps/web → apps/api
```

## 2단계: 단위별 원본 결정
- `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/detect-project.sh <단위>` → DB 종류, ORM/마이그레이션, 참고 자산.
- `source-of-truth.md` 결정표로 `dbml` / `migrations` 제안. DB 종류 단서가 없으면 묻는다.
- `migrations` 면 `migration-tools.md` 에서 `ERD_MIGRATE_CMD` 를 고른다 (단위 폴더에서 실행, `DATABASE_URL` 로 임시 DB 전달).

## 3단계: 설치 — 헬퍼 실행
단위마다 (레포 루트에서):
```bash
bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-templates.sh \
  --unit <단위> --name <영문 이름> --dialect <postgres|mysql> --source <dbml|migrations> \
  [--migrate-cmd '<명령>'] [--related '<폴더,폴더>']
```
- 출력의 `+`(생성) `=`(유지) `~`(갱신) `!`(확인 필요)를 요약해 보고한다. 마지막 줄이 `INSTALL_RESULT=ok` 가 아니면 `!` 항목을 설명한다.
- `!` scripts 가 플러그인 버전과 다르면: 로컬 수정이 있는지 `git diff` 로 보고 사용자 확인 후 `--update-scripts` 로 재실행.
- 먼저 `--dry-run` 으로 보여 주고 확인받아도 된다 (파일이 많은 모노레포 권장).
- CLAUDE.md(또는 AGENTS.md) 블록은 스크립트가 넣는다. 직접 편집하지 않는다.

## 4단계: 첫 문서 또는 다음 단계 (단위별)
| 원본 | 다음 |
|---|---|
| `migrations` | `make erd P=<단위>` → 결과 요약 → 모듈(viewpoints) 구성을 제안해 `.tbls.yml` 에 반영 → 다시 `make erd P=<단위>` |
| `dbml` + 참고 자산 있음 | `/erd:import --project <단위>` |
| `dbml` + 자산 없음 | `/erd:design --project <단위>` (대화형 초기 설계). `_example.dbml` 은 첫 모듈 후 삭제 |

## 에러 처리
`references/errors.md` + 아래.
| 상황 | 동작 |
|---|---|
| install-templates.sh exit 2 | 인자 오류 메시지대로 수정해 재실행 (이름은 영문·숫자·_·-) |
| `make erd` 실패 | `ERD_EXIT` 코드로 `errors.md` 대응 |

## 체크리스트 (보고 전)
- [ ] 단위 배치·원본을 사용자가 확인했다
- [ ] 모든 단위에서 `INSTALL_RESULT=ok` (또는 `!` 항목 설명)
- [ ] migrations 단위는 `make erd P=<단위>` 를 한 번 돌려 결과를 확인했다
- [ ] 보고는 `report-templates.md` 3번 양식 (단위 목록·설치 파일·다음 단계)

## 관련 스킬
- `/erd:doctor` — 도구가 없을 때
- `/erd:import` — 기존 소스·문서·DB 에서 DBML 만들기
- `/erd:design` — 대화형 초기 설계
