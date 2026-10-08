# DBML 작성 규칙

문법 전체: https://dbml.dbdiagram.io/docs/  (모듈 시스템: https://dbml.dbdiagram.io/syntax/module-system)

## 파일 구조

```
db/
├── schema.dbml            # 진입점: Project 블록 + use 목록
└── modules/
    ├── user.dbml          # 모듈 = 업무 도메인 단위 (회원, 주문, 자산 …)
    └── order.dbml
```

- 모듈 하나 = 파일 하나 = `.tbls.yml` viewpoint 하나 (id 를 파일명과 같게).
- 다른 모듈 테이블은 `use { table users } from './user'` 로 가져와 참조한다. `use` 는 전이되지 않는다.
- 진입점은 `use * from './modules/<모듈>'` 만 둔다. 테이블 정의를 넣지 않는다.
- `TableGroup`, 색상, sticky note 는 dbdiagram 유료 기능에서만 시각화되므로 모듈 분리는 **파일**로 한다.

## 다른 ERD 단위(다른 DB) 참조

모노레포에서 DB 가 다른 서비스의 테이블은 `ref` 로 연결할 수 없다. note 로 표시한다 (`units.md` 참고):

```dbml
user_id bigint [not null, note: '회원 ID → api: users.id (다른 DB, FK 없음)']
```

## 명명

| 대상 | 규칙 | 예 |
|---|---|---|
| 테이블 | snake_case 복수형 | `users`, `order_items` |
| 컬럼 | snake_case | `created_at` |
| PK | `id` | |
| FK | `<참조 테이블 단수>_id` | `user_id` |
| 인덱스 | `idx_<테이블>_<컬럼>` / 유니크 `uq_<테이블>_<컬럼>` | `idx_orders_user_id` |
| 불리언 | `is_` / `has_` 접두사 | `is_active` |
| 일시 | `_at` 접미사, 날짜만이면 `_on` / `_date` | `paid_at` |

프로젝트에 이미 다른 규칙이 있으면(기존 테이블, ORM 설정) **기존 규칙을 따른다**. 새 규칙을 강요하지 않는다.

## 필수 사항 (tbls lint 가 검사)

- 모든 테이블에 `Note`, 모든 컬럼에 `note` (업무 의미를 한국어로).
- FK 컬럼에는 인덱스 (`indexes { user_id [name: 'idx_orders_user_id'] }`).
- 모든 테이블은 어느 모듈(viewpoint)에 속해야 한다.
- 다른 테이블과 관계가 하나도 없는 테이블은 의도된 것인지 note 에 적는다.

## 권장 패턴

```dbml
Table orders {
  id bigint [pk, increment, note: 'PK']
  user_id bigint [not null, ref: > users.id, note: '주문한 회원']
  status varchar(20) [not null, default: 'pending', note: 'pending | paid | canceled']
  total_amount numeric(12,2) [not null, default: 0, note: '주문 총액(원)']
  created_at timestamptz [not null, default: `now()`, note: '생성 일시']
  updated_at timestamptz [not null, default: `now()`, note: '수정 일시']
  deleted_at timestamptz [note: '소프트 삭제 일시']

  indexes {
    user_id [name: 'idx_orders_user_id']
    (user_id, created_at) [name: 'idx_orders_user_id_created_at']
  }
  Note: '주문'
}
```

- 상태값은 `enum` 보다 `varchar + note` 를 기본으로 한다(마이그레이션이 쉬움). 값 집합이 고정이고 DB 차원 검증이 필요하면 `enum` 또는 `checks`.
- 금액은 `numeric(p,s)`, 부동소수점 금지.
- 시간은 PostgreSQL 이면 `timestamptz`.
- 공통 컬럼(`created_at` 등)이 반복되면 `TablePartial` 사용 가능:
  ```dbml
  TablePartial timestamps {
    created_at timestamptz [not null, default: `now()`, note: '생성 일시']
    updated_at timestamptz [not null, default: `now()`, note: '수정 일시']
  }
  Table users { id bigint [pk]  ~timestamps  Note: '회원' }
  ```

## 변환 명령 (@dbml/cli)

| 명령 | 용도 |
|---|---|
| `dbml2sql db/schema.dbml --postgres -o db/schema.sql` | DBML → DDL (`--mysql`, `--mssql`, `--oracle`) |
| `sql2dbml dump.sql --postgres -o db/schema.dbml` | DDL → DBML |
| `db2dbml postgres '<conn>' -o db/schema.dbml` | 실제 DB → DBML (`mysql`, `mssql`, `snowflake`, `bigquery`, `oracle`) |

`dbml2sql` 은 `Note` 를 `COMMENT ON ...` 으로 변환하므로 tbls 문서에 설명이 그대로 들어간다.
변환 실패 시 `dbml-error.log` 가 생기므로 내용을 확인하고 지운다.
