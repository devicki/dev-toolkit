# 오류 대응표

> 기준: `scripts/erd-doc.sh` (erd 플러그인 0.3.0), tbls 1.96, @dbml/cli 10.3 — 2026-10
> 실패하면 출력 마지막 줄에 `ERD_EXIT=<코드> <분류>` 가 찍힌다. 코드로 원인을 고르고 아래 동작을 따른다.
> **추정으로 넘어가지 말 것**: 원인을 고치지 못했으면 실패 사실과 메시지를 그대로 보고한다.

## erd-doc.sh 종료 코드

| 코드 | 분류 | 흔한 원인 | 동작 |
|---|---|---|---|
| 0 | 성공 | | 결과 요약 |
| 1 | diff / lint | `check` 에서 문서가 현재 스키마와 다름, `docs/schema` 없음, `ERD_CHECK_LINT=strict` 인데 lint 경고 | `make erd P=<단위>` 로 재생성 후 함께 커밋하도록 안내. CI 실패라면 어느 단위인지 밝힌다 |
| 2 | usage / config | 단위가 여러 개인데 미지정, 단위 폴더 없음, 잘못된 모드, `erd.env` 값 오류(DIALECT/SOURCE), DBML 진입 파일 없음, `.tbls.yml` 없음, migrations 인데 `ERD_MIGRATE_CMD` 비어 있음 | 메시지대로 인자·`erd.env` 를 고친다. 설정 파일이 없으면 `/erd:init` |
| 3 | missing-tool | tbls, dbml2sql, psql, docker, mysql 없음 | `/erd:doctor` 로 점검·설치. 직접 설치 명령을 즉석에서 만들지 않는다 |
| 4 | dbml | DBML 문법 오류 (`파일(줄,칸): 메시지`) | 해당 위치를 고친다. **dbml2sql 은 오류여도 exit 0** 이라 스크립트가 로그로 판정한다 — 직접 dbml2sql 을 돌려 성공으로 착각하지 말 것 |
| 5 | tempdb | Docker 데몬 접근 불가, 컨테이너 90초 내 미준비, PG/MySQL 접속 실패, CREATE DATABASE 권한 없음 | Docker 권한(그룹 추가·재로그인) 또는 `PG=postgres://...` 로 기존 서버 사용을 안내. 접속 정보는 사용자에게 받는다 |
| 6 | apply | `db/schema.sql` 적용 중 SQL 오류 (없는 타입, 잘못된 기본값 표현식, 예약어 컬럼명, 방언 불일치) | 출력된 SQL 오류 줄을 보고 DBML 을 고친다. `db/schema.sql` 을 직접 고치지 않는다 |
| 7 | migrate | `ERD_MIGRATE_CMD` 실패 (의존성 미설치, `DATABASE_URL` 미사용, 마이그레이션 자체 오류) | 명령을 단위 폴더에서 직접 실행해 재현하고 원인을 보고. 프로젝트 설정 수정은 사용자 확인 후 |
| 8 | tbls | tbls 실행 실패: `.tbls.yml` 문법, viewpoint 에 없는 테이블 이름, **공용 `/tmp/go-graphviz` 권한 문제** | 메시지에 "/tmp 권한"이 있으면 `tbls-guide.md` 의 "공용 /tmp 문제". 그 외는 `.tbls.yml` 수정 |

## 스크립트 밖에서 자주 만나는 상황

| 상황 | 동작 |
|---|---|
| `make: scripts/erd-doc.sh: Permission denied` | `chmod +x scripts/erd-doc.sh` |
| `make erd` 가 레포 루트가 아닌 곳에서 실행됨 | 레포 루트로 이동해서 실행 (`erd.mk` 는 루트 기준) |
| `erd.env` 값에 공백이 있어 `syntax error` | 값을 작은따옴표로 감싼다 (`ERD_MIGRATE_CMD='alembic upgrade head'`) |
| lint 경고만 있고 성공(0) | 경고 목록을 요약해 보고. 자동 수정 가능한 것(note 누락 등)은 고칠지 묻는다 |
| 운영 DB 주소가 `PG=` / `ERD_MIGRATE_CMD` 에 들어가려 함 | **중단**. 임시·개발 DB 만 허용 (`rules.md`) |
