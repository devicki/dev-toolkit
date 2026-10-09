# ERD 단위와 모노레포

> 기준: erd 플러그인 0.3.0 — 2026-10.

## 개념

**ERD 단위 = DB(스키마) 하나 = `erd.env` 가 있는 폴더 하나.**

- 단일 레포·단일 DB: 레포 루트가 유일한 단위.
- 모노레포: DB 를 가진 서비스 폴더마다 단위를 둔다. DB 가 없는 앱(프론트 등)은 단위가 아니라 **관련 소스**다.

단위 폴더 안의 경로(`db/`, `docs/schema/`, `.tbls.yml`, `erd.env` 의 상대 경로)는 모두 **단위 폴더 기준**이다.
`scripts/erd-doc.sh` 와 `erd.mk` 는 **레포 루트에 하나만** 둔다.

```
monorepo/
├── erd.mk  Makefile(include erd.mk)  scripts/erd-doc.sh  docs/ERD_GUIDE.md
├── apps/api/        ← 단위: erd.env .tbls.yml db/ docs/schema/ CLAUDE.md
├── apps/billing/    ← 단위: erd.env .tbls.yml docs/schema/ CLAUDE.md
└── apps/web/        ← 단위 아님 (api 의 관련 소스: ERD_RELATED_SOURCES)
```

## 대상 단위 결정 (모든 스킬 공통)

1. 인자에 `--project <폴더>`(또는 `-p <폴더>`)가 있으면 그 폴더.
2. 없으면 `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/find-units.sh` 의 "현재 위치의 대상 단위":
   - 현재 위치에서 위로 가장 가까운 `erd.env` → 그 단위.
   - 레포에 단위가 하나뿐 → 그 단위.
   - 여러 개인데 현재 위치가 어느 단위에도 속하지 않음 → 사용자의 요청 내용(언급한 서비스·테이블·파일)으로 추론하고, 애매하면 단위 목록을 보여 주고 고르게 한다.
   - `/erd:sync`, `/erd:review` 는 "전체"를 고를 수 있다 (단위별로 차례로 수행).
3. 작업을 시작할 때 대상 단위를 한 줄로 밝힌다: `대상: apps/api (PostgreSQL, ERD_SOURCE=dbml)`.
4. 명령 실행은 레포 루트에서 `make erd P=<단위>` 또는 `scripts/erd-doc.sh <모드> <단위>`.

## 모노레포 유형 판별 (init)

| 유형 | 판별 단서 | 단위 배치 |
|---|---|---|
| 공유 DB 하나 + 여러 앱 | 마이그레이션/ORM 이 한 곳(예: `packages/db`, `apps/api`)에만 있음, 다른 앱은 그 패키지를 import | 스키마를 가진 폴더 하나만 단위. 나머지 앱은 `ERD_RELATED_SOURCES` |
| 서비스별 DB | 서비스마다 마이그레이션/ORM, 서로 다른 DB 접속 설정(docker-compose 의 DB 서비스 여러 개) | 서비스마다 단위 |
| 혼합 | 일부 서비스만 DB 소유 | DB 소유 서비스만 단위 |
| 판단 불가 | 단서 부족 | `find-units.sh` 결과를 보여 주고 사용자에게 질문 |

같은 DB 를 두 서비스가 함께 쓰는데 마이그레이션도 두 곳에 있으면(안티패턴 가능) 임의로 정하지 말고 사용자에게 어느 쪽이 원본인지 묻는다.

## 관련 소스 (ERD_RELATED_SOURCES)

단위의 `erd.env` 에 이 DB 를 쓰는 다른 폴더를 적는다 (레포 루트 기준, 쉼표 구분).

```
ERD_RELATED_SOURCES='apps/web,apps/admin'
```

`/erd:import`(code), `/erd:review`, `/erd:design` 은 단위 폴더 + 이 폴더들의 화면·API 소스를 함께 읽는다.

## 서비스 간 참조 (DB 가 다른 단위끼리)

- DB 가 다르면 FK 를 걸 수 없다. DBML `ref` 를 쓰지 말고 note 로 표시한다:
  `user_id bigint [not null, note: '회원 ID → api: users.id (다른 DB, FK 없음)']`
- 이런 컬럼은 `/erd:review` 에서 타입·의미 일관성을 양쪽 단위 문서(`<단위>/docs/schema/schema.json`)로 대조한다.
- 같은 DB 의 다른 스키마(PostgreSQL schema)라면 한 단위 안에서 `schema.table` 로 FK 가능.

## 에이전트 지침 배치

- 각 단위 폴더에 `CLAUDE.md`(단위 전용 DB 스키마 절). Claude Code 는 작업 중인 하위 폴더의 CLAUDE.md 도 읽는다.
- 레포 루트 `CLAUDE.md` 에는 단위 목록과 `make erd [P=<단위>]` 사용법만 짧게.

## CI

루트에서 `make erd-check` 는 모든 단위를 검사하고 하나라도 다르면 실패한다.
PR 에서는 `make erd-check-changed BASE=origin/<기본 브랜치>` 로 **스키마가 바뀐 단위만** 검사할 수 있다 (`scripts/erd-changed.sh` 가 원격 기준 브랜치 대비 커밋·미커밋·새 파일을 단위별로 묶음).
