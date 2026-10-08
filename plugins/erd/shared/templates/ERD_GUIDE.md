# ERD 작업 가이드

이 프로젝트의 ERD는 Claude Code `erd` 플러그인(devicki/dev-toolkit)으로 관리합니다.

## 원칙
- 스키마 원본은 `erd.env` 의 `ERD_SOURCE` 가 정한다.
  - `dbml` : `db/modules/*.dbml` 이 원본. 테이블 변경은 여기서만.
  - `migrations` : ORM/마이그레이션이 원본. DBML(`db/schema.generated.dbml`)과 문서는 파생물.
- `db/schema.sql`, `docs/schema/` 는 자동 생성물이므로 직접 고치지 않는다.
- 스키마를 바꾸면 `make erd` 로 문서를 갱신하고 같은 커밋에 올린다.

## 명령
| 명령 | 설명 |
|---|---|
| `make erd` | 문서 생성 + lint (Docker 또는 `PG=`/`MY=` 로 기존 서버) |
| `make erd-check` | 문서 최신 여부 검사 (CI용) |
| `make erd-sql` | DBML → `db/schema.sql` |
| `make erd-view` | 터미널에서 문서 보기 (glow) |

## Claude Code 명령
| 명령 | 용도 |
|---|---|
| `/erd:doctor` | 도구 점검·설치 |
| `/erd:design` | 대화형 설계·수정 |
| `/erd:review` | 소스코드 대비 검토·개선 |
| `/erd:sync` | 문서 갱신, 코드·DB와 차이 점검, 마이그레이션 연동 |

## 문서 보는 곳
- 전체: `docs/schema/README.md`
- 모듈별: `docs/schema/viewpoint-<모듈>.md`
- 테이블별: `docs/schema/<스키마>.<테이블>.md`
