# tbls 사용 가이드

> 기준: tbls 1.96.1 (https://github.com/k1LoW/tbls) — 2026-10 확인. 다른 버전이면 `tbls <명령> --help` 로 옵션을 확인한다.

공식: https://github.com/k1LoW/tbls

## 이 플러그인에서의 역할

tbls 는 **실제 DB**(임시 DB)를 읽어 다음을 만든다. 직접 실행하지 말고 레포 루트에서 `make erd [P=<단위>]` / `scripts/erd-doc.sh <모드> <단위>` 를 쓴다. 아래 경로는 ERD 단위 폴더 기준이다.

- `docs/schema/README.md` : 전체 테이블 목록 + 전체 ERD (Mermaid)
- `docs/schema/viewpoint-<id>.md` : 모듈별 테이블 + 모듈 ERD
- `docs/schema/<schema>.<table>.md` : 테이블별 컬럼·제약조건·인덱스·관계
- `docs/schema/schema.json` : 기계가 읽는 전체 스키마 (AI가 구조 파악에 사용 가능)

## 주요 명령 (DSN 은 erd-doc.sh 가 만든다)

| 명령 | 용도 |
|---|---|
| `tbls doc --dsn <DSN> --rm-dist` | 문서 재생성 |
| `tbls diff <DSN> docs/schema` | 문서와 DB 차이 (차이 있으면 출력) |
| `tbls lint --dsn <DSN>` | `.tbls.yml` 의 lint 규칙 검사 |
| `tbls out --dsn <DSN> -t mermaid --viewpoint <id>` | 모듈 ERD만 출력 |

DSN 형식: `postgres://user:pass@host:5432/db?sslmode=disable`, `mysql://user:pass@host:3306/db`, `sqlite:///path/to.db`

## .tbls.yml 핵심

```yaml
name: my_project
docPath: docs/schema
er:
  format: mermaid
viewpoints:
  - id: order            # db/modules/order.dbml 과 같은 이름
    name: 주문 모듈
    desc: 주문과 주문 상품 (참조하는 users 포함)
    tables: [orders, order_items, users]
lint:
  requireTableComment: { enabled: true }
  requireColumnComment: { enabled: true }
  requireForeignKeyIndex: { enabled: true }
  unrelatedTable: { enabled: true }
  requireViewpoints: { enabled: true }
```

- viewpoint 의 `tables` 에는 모듈 소속 테이블 + **참조하는 다른 모듈의 핵심 테이블**을 넣어 관계가 보이게 한다.
- 테이블 이름에 스키마 접두사가 붙는 DB(PostgreSQL `public.` 이외 스키마)는 `schema.table` 형식으로 쓴다.
- 사용 가능한 lint 규칙: requireTableComment, requireColumnComment(exclude, excludeTables), requireIndexComment, requireConstraintComment, requireTriggerComment, requireTableLabels, unrelatedTable, columnCount(max), requireColumns(columns), duplicateRelations, requireForeignKeyIndex, labelStyleBigQuery, requireViewpoints.
- ORM 이 만든 관리용 테이블(`alembic_version`, `_prisma_migrations`, `django_migrations`, `flyway_schema_history`, `schema_migrations` 등)은 문서에서 제외한다:
  ```yaml
  exclude:
    - alembic_version
  ```

## comments — 코드·DB 를 건드리지 않고 문서에 설명·ADR 연결

`ERD_SOURCE=migrations` 단위에서 ADR 참조나 설명을 남기는 곳. `make erd` 때 tbls 가 DB 구조에 덧붙여 문서를 만든다.

```yaml
comments:
  - table: users                     # public 스키마는 접두사 생략 가능
    tableComment: "회원. ADR-003: 소프트 삭제"
    columnComments:
      deleted_at: "삭제 시각, NULL=활성 (ADR-003)"
    labels: [ADR-003]                # README 테이블 목록의 Labels 열에 표시 → ADR 별 영향 테이블 검색
```

1.96.1 에서 확인한 동작:
- **설정의 `tableComment`/`columnComments` 는 DB 주석을 대체**한다(합치지 않음). DB 에 주석이 있으면 `docs/schema/<table>.md` 의 기존 문구를 앞에 두고 ADR 을 덧붙인다. 지정하지 않은 컬럼은 DB 주석 그대로.
- `tbls lint` 의 `requireTableComment`/`requireColumnComment` 는 설정 주석도 인정한다.
- 설정만 바꾸고 `make erd` 를 안 돌리면 `make erd-check` 가 차이로 잡는다 (문서와 같은 커밋에).
- ADR 은 결정 번호 + 한 줄 요약만. 본문은 ADR 문서에 두고 복사하지 않는다.

## 공용 /tmp 문제 (여러 계정이 같은 서버에서 tbls 사용)

증상: `panic: open /tmp/go-graphviz/...: permission denied` (`erd-doc.sh` 는 `ERD_EXIT=8 tbls` 와 안내문을 출력)
원인: tbls 내부 라이브러리가 공용 `/tmp/go-graphviz` 에 캐시를 만들고, 먼저 실행한 계정만 접근 가능.

해결 (권장 순):
1. 서버 관리자: `sudo apt install libpam-tmpdir` → 각 계정 재로그인 시 `TMPDIR=/tmp/user/<UID>` 자동 설정.
   - 재로그인해도 안 되면 IDE 서버·herdr·tmux 등 오래 떠 있던 프로세스 때문. `sudo loginctl terminate-user <계정>` 후 재접속.
2. 계정별: `TMPDIR` 을 개인 폴더로 지정하고 실행 (`scripts/erd-doc.sh` 는 TMPDIR 이 비어 있으면 자동으로 `~/.cache/erd-tmp` 사용).
3. 하지 말 것: `/tmp/go-graphviz` 에 chmod 777 (실행 코드 캐시라 보안 위험).
